import Foundation

/// 캐릭터의 현재 표시 상태 — UsageStore 신호(burn tier/한도)로 결정
enum CompanionStateKind: String, Sendable {
    case egg, idle, working, focus, tired, sleep, levelUp
}

/// XP/레벨 밸런스 — 코드 상수가 아니라 한 곳의 테이블로 (README/설정 노출 대비)
enum CompanionBalance {
    static let tokenXPDivisor = 1_000.0
    static let xpMultiplier = 4.0
    static let maxLevel = 50

    /// 토큰량 → XP. sqrt 곡선 — 많이 쓰면 늘지만 선형은 아니다(10배 써도 10배 성장 X).
    static func xp(forTokens tokens: Int) -> Int {
        guard tokens > 0 else { return 0 }
        return Int((sqrt(Double(tokens) / tokenXPDivisor) * xpMultiplier).rounded(.down))
    }

    /// 레벨 L 에 도달하기 위한 누적 XP. 레벨이 오를수록 필요 XP 증가.
    static func cumulativeXP(toReach level: Int) -> Int {
        let l = max(1, level)
        if l <= 1 { return 0 }
        return Int((20.0 * pow(Double(l - 1), 1.85)).rounded())
    }

    /// 누적 XP → 레벨 (1...maxLevel).
    static func level(forXP xp: Int) -> Int {
        var lvl = 1
        while lvl < maxLevel && cumulativeXP(toReach: lvl + 1) <= xp { lvl += 1 }
        return lvl
    }
}

/// 영속되는 캐릭터 상태(Application Support JSON).
/// Phase 0/1 은 단일 캐릭터. ownedCompanions/eggInventory/등급은 Phase 2+ 에서 추가.
struct CompanionState: Codable, Sendable {
    var displayName = "Mochi"
    var totalXP = 0
    /// 오늘 이미 XP로 환산한 양(중복 지급 방지). 자정에 0으로 리셋.
    var claimedTodayXP = 0
    var didApplyInitialBackfill = false
    /// "오늘" 버킷 날짜(로컬). 바뀌면 claimedTodayXP 리셋.
    var lastDate = ""
    var streakDays = 0
    var hatched = false
}
