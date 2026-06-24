import XCTest
@testable import TokenMac

final class CompanionBalanceTests: XCTestCase {
    func testXPMonotonicAndCurve() {
        XCTAssertEqual(CompanionBalance.xp(forTokens: 0), 0)
        // sqrt 곡선: 1M → floor(sqrt(1000)*4)=126
        XCTAssertEqual(CompanionBalance.xp(forTokens: 1_000_000), 126)
        // 10배 토큰이 10배 XP 가 아님(sqrt)
        XCTAssertLessThan(CompanionBalance.xp(forTokens: 10_000_000),
                          CompanionBalance.xp(forTokens: 1_000_000) * 10)
        XCTAssertGreaterThan(CompanionBalance.xp(forTokens: 10_000_000),
                             CompanionBalance.xp(forTokens: 1_000_000))
    }

    func testLevelCurveIncreasingAndCapped() {
        XCTAssertEqual(CompanionBalance.level(forXP: 0), 1)
        XCTAssertEqual(CompanionBalance.cumulativeXP(toReach: 1), 0)
        // 누적 임계값 단조 증가
        for l in 1..<CompanionBalance.maxLevel {
            XCTAssertLessThan(CompanionBalance.cumulativeXP(toReach: l),
                              CompanionBalance.cumulativeXP(toReach: l + 1))
        }
        // 매우 큰 XP 는 maxLevel 로 캡
        XCTAssertEqual(CompanionBalance.level(forXP: 100_000_000), CompanionBalance.maxLevel)
        // 임계값 직전/직후
        let xp5 = CompanionBalance.cumulativeXP(toReach: 5)
        XCTAssertEqual(CompanionBalance.level(forXP: xp5), 5)
        XCTAssertEqual(CompanionBalance.level(forXP: xp5 - 1), 4)
    }
}

@MainActor
final class CompanionStoreTests: XCTestCase {
    private func tempStore(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-test-\(UUID().uuidString).json")
        return CompanionStore(clock: { now }, fileURL: url)
    }

    func testBackfillHatchesAndSetsLevel() {
        let s = tempStore()
        s.update(todayTokens: 2_000_000, todayDate: "2026-06-23", monthTotal: 50_000_000,
                 burnTier: .normal, limitWarning: false, hasUsageData: true)
        XCTAssertTrue(s.state.didApplyInitialBackfill)
        XCTAssertTrue(s.state.hatched)
        XCTAssertGreaterThan(s.level, 1)
        XCTAssertEqual(s.displayState, .working)   // burn normal
    }

    func testNoDoubleCountSameDay() {
        let s = tempStore()
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        let xpAfterFirst = s.state.totalXP
        // 같은 날 같은 값 재호출 → totalXP 불변(중복 지급 없음)
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.state.totalXP, xpAfterFirst)
    }

    func testTodayIncrementAccrues() {
        let s = tempStore()
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        let before = s.state.totalXP
        // 오늘 토큰이 더 쌓이면 증분만큼 XP 증가
        s.update(todayTokens: 4_000_000, todayDate: "2026-06-23", monthTotal: 4_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertGreaterThan(s.state.totalXP, before)
    }

    func testMidnightRolloverResetsClaim() {
        let s = tempStore()
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        let day1 = s.state.totalXP
        // 다음 날(오늘 토큰 다시 0부터) → claimedTodayXP 리셋, 새 적립 가능
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-24", monthTotal: 2_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertGreaterThan(s.state.totalXP, day1)
        XCTAssertEqual(s.state.lastDate, "2026-06-24")
    }

    func testEmptyDataDoesNotConsumeBackfill() {
        let s = tempStore()
        // 기동 직후 빈 새로고침(데이터 없음) → 알 유지, backfill 미소진
        s.update(todayTokens: 0, todayDate: "2026-06-23", monthTotal: 0,
                 burnTier: .idle, limitWarning: false, hasUsageData: false)
        XCTAssertFalse(s.state.didApplyInitialBackfill)
        XCTAssertFalse(s.state.hatched)
        XCTAssertEqual(s.displayState, .egg)
        // 실제 누적 데이터 도착 → 이제 소급 부화(높은 레벨)
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 200_000_000,
                 burnTier: .normal, limitWarning: false, hasUsageData: true)
        XCTAssertTrue(s.state.didApplyInitialBackfill)
        XCTAssertTrue(s.state.hatched)
        XCTAssertGreaterThan(s.level, 3)   // 소급으로 레벨 점프
    }

    func testStateMapping() {
        let s = tempStore()
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .idle)
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .blazing, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .focus)
        s.update(todayTokens: 1_000_000, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: true, hasUsageData: true)
        XCTAssertEqual(s.displayState, .tired)
        s.update(todayTokens: 0, todayDate: "2026-06-23", monthTotal: 1_000_000,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .sleep)
    }

    func testPersistenceRoundTrip() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-persist-\(UUID().uuidString).json")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let s1 = CompanionStore(clock: { now }, fileURL: url)
        s1.update(todayTokens: 5_000_000, todayDate: "2026-06-23", monthTotal: 80_000_000,
                  burnTier: .normal, limitWarning: false, hasUsageData: true)
        let lvl = s1.level
        let s2 = CompanionStore(clock: { now }, fileURL: url)
        XCTAssertEqual(s2.level, lvl)
        XCTAssertTrue(s2.state.hatched)
    }
}
