import Foundation
import Observation

/// 게임 상태의 출처. UsageStore(사용량 출처)의 값을 읽어 XP/레벨/표시 상태를 갱신한다.
/// 성장/해금 로직을 UsageStore 에 넣지 않고 분리.
@MainActor
@Observable
final class CompanionStore {
    private(set) var state = CompanionState()
    private(set) var level = 1
    private(set) var todayXP = 0
    private(set) var displayState: CompanionStateKind = .egg
    private(set) var justLeveledUp = false
    private var levelUpUntil: Date?

    private let clock: () -> Date
    private let fileURL: URL

    var name: String { state.displayName }
    var isMaxed: Bool { level >= CompanionBalance.maxLevel }

    /// 현재 레벨 진행분 / 다음 레벨까지
    var xpIntoLevel: Int { state.totalXP - CompanionBalance.cumulativeXP(toReach: level) }
    var xpForNextLevel: Int {
        guard !isMaxed else { return max(1, xpIntoLevel) }
        return CompanionBalance.cumulativeXP(toReach: level + 1) - CompanionBalance.cumulativeXP(toReach: level)
    }
    var levelProgress: Double {
        guard xpForNextLevel > 0 else { return 1 }
        return min(1, max(0, Double(xpIntoLevel) / Double(xpForNextLevel)))
    }
    /// 다음 레벨까지 남은 토큰 추정 — 팝오버 "다음 낮잠 자리까지 N tokens"
    var tokensToNextLevel: Int {
        guard !isMaxed else { return 0 }
        let needXP = max(0, CompanionBalance.cumulativeXP(toReach: level + 1) - state.totalXP)
        // xp = sqrt(tok/divisor)*mult  →  tok = (xp/mult)^2 * divisor
        let x = Double(needXP) / CompanionBalance.xpMultiplier
        return Int((x * x * CompanionBalance.tokenXPDivisor).rounded())
    }

    init(clock: @escaping () -> Date = Date.init, fileURL: URL? = nil) {
        self.clock = clock
        self.fileURL = fileURL ?? Self.defaultURL()
        load()
        level = CompanionBalance.level(forXP: state.totalXP)
        if state.hatched { displayState = .idle }
    }

    static func defaultURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TokenMac")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("companion-state.json")
    }

    /// UsageStore 갱신 후 호출. 토큰 증분 → XP, 표시 상태 결정. 중복 지급 없음.
    func update(todayTokens: Int, todayDate: String, monthTotal: Int,
                burnTier: SpinTier, limitWarning: Bool, hasUsageData: Bool) {
        let prevLevel = level
        let isBackfillNow = !state.didApplyInitialBackfill

        if !state.didApplyInitialBackfill {
            // 데이터 도착 전(앱 기동 직후 빈 새로고침)에는 부화/소급하지 않는다 — 알 유지.
            // 이걸 막지 않으면 빈 데이터로 backfill 이 소진돼 기존 사용량 소급 성장이 사라진다.
            guard hasUsageData, monthTotal > 0 || todayTokens > 0 else {
                displayState = .egg
                return
            }
            // 최초 소급: 월 누적으로 초기 레벨 부여(근사), 알 부화
            state.totalXP = CompanionBalance.xp(forTokens: max(monthTotal, todayTokens))
            state.claimedTodayXP = CompanionBalance.xp(forTokens: todayTokens)
            state.lastDate = todayDate
            state.didApplyInitialBackfill = true
            state.hatched = todayTokens > 0 || monthTotal > 0
        } else {
            if todayDate != state.lastDate {           // 자정 경계
                state.lastDate = todayDate
                state.claimedTodayXP = 0
                if todayTokens > 0 { state.streakDays += 1 }
            }
            // 오늘 XP 증분만 적립 (sqrt 곡선 일관성 유지)
            let todayXPNow = CompanionBalance.xp(forTokens: todayTokens)
            if todayXPNow > state.claimedTodayXP {
                state.totalXP += todayXPNow - state.claimedTodayXP
                state.claimedTodayXP = todayXPNow
                state.hatched = true
            }
        }

        level = CompanionBalance.level(forXP: state.totalXP)
        todayXP = CompanionBalance.xp(forTokens: todayTokens)

        if level > prevLevel && !isBackfillNow {   // 최초 소급 부화는 레벨업 연출 아님
            justLeveledUp = true
            levelUpUntil = clock().addingTimeInterval(4)
        } else if let until = levelUpUntil, clock() > until {
            justLeveledUp = false; levelUpUntil = nil
        }

        displayState = computeState(burnTier: burnTier, limitWarning: limitWarning,
                                    hasUsageData: hasUsageData, today: todayTokens)
        save()
    }

    private func computeState(burnTier: SpinTier, limitWarning: Bool,
                              hasUsageData: Bool, today: Int) -> CompanionStateKind {
        if !state.hatched { return .egg }
        if justLeveledUp { return .levelUp }
        if limitWarning { return .tired }
        if !hasUsageData || today == 0 { return .sleep }
        switch burnTier {
        case .idle: return .idle
        case .normal: return .working
        case .fast, .blazing: return .focus
        }
    }

    // MARK: 영속
    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(CompanionState.self, from: data) else { return }
        state = s
    }
    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL)
    }
}
