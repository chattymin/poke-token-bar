import XCTest
@testable import PokeTokenBar

// companion 표시 상태(displayState) 전이 — update() 입력 조합에 따른 결과 검증.
// SeededRNG / StubProvider 는 CompanionTests.swift 의 내부 헬퍼를 재사용한다.

private func dnode(_ id: Int, _ children: [EvoNode] = []) -> EvoNode { EvoNode(speciesID: id, children: children) }
private func dline(base: Int, rarity: Rarity = .common) -> EvoLine {
    EvoLine(baseID: base, tree: dnode(base, [dnode(base + 1, [dnode(base + 2)])]),
            rarity: rarity, names: [:])
}
private let dNow = Date(timeIntervalSince1970: 1_700_000_000)

/// 테스트에서 시계를 전진시키기 위한 가변 박스 (이벤트 윈도우 만료 제어용).
private final class ClockBox: @unchecked Sendable {
    nonisolated(unsafe) var now: Date
    init(_ d: Date) { now = d }
}

@MainActor
final class CompanionDisplayStateTests: XCTestCase {
    private func hatchedStore(rarity: Rarity = .common) async -> (CompanionStore, ClockBox) {
        let clock = ClockBox(dNow)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-disp-\(UUID().uuidString).json")
        let s = CompanionStore(provider: StubProvider(value: dline(base: 1, rarity: rarity)),
                               clock: { clock.now }, fileURL: url, rng: SeededRNG(seed: 5))
        await s.hatch(baseID: 1)
        return (s, clock)
    }

    func testEggWhenNoUsageData() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-disp-\(UUID().uuidString).json")
        let s = CompanionStore(provider: StubProvider(value: dline(base: 1)),
                               clock: { dNow }, fileURL: url, rng: SeededRNG(seed: 1))
        s.update(todayTokens: 0, todayDate: "d", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: false)
        XCTAssertEqual(s.displayState, .egg)
    }

    func testLevelUpDuringEventWindow() async {
        let (s, _) = await hatchedStore()
        // 이벤트 윈도우가 살아있는 동안(시계 미전진) → levelUp 유지
        s.update(todayTokens: 100, todayDate: "d", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .levelUp)
    }

    func testWorkingAfterEventExpires() async {
        let (s, clock) = await hatchedStore()
        clock.now = dNow.addingTimeInterval(60)   // 이벤트 만료
        s.update(todayTokens: 100, todayDate: "d", monthTotal: 0, burnTier: .normal, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .working)
    }

    func testFocusOnHighBurn() async {
        let (s, clock) = await hatchedStore()
        clock.now = dNow.addingTimeInterval(60)
        s.update(todayTokens: 100, todayDate: "d", monthTotal: 0, burnTier: .blazing, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .focus)
    }

    func testTiredWhenLimitWarning() async {
        let (s, clock) = await hatchedStore()
        clock.now = dNow.addingTimeInterval(60)
        s.update(todayTokens: 100, todayDate: "d", monthTotal: 0, burnTier: .normal, limitWarning: true, hasUsageData: true)
        XCTAssertEqual(s.displayState, .tired)
    }

    func testSleepWhenZeroUsageToday() async {
        let (s, clock) = await hatchedStore()
        clock.now = dNow.addingTimeInterval(60)
        s.update(todayTokens: 0, todayDate: "d", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.displayState, .sleep)
    }

    // MARK: 알(egg) 인큐베이션 파생값

    func testEggProgressAndTokensToHatch() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-disp-\(UUID().uuidString).json")
        let s = CompanionStore(provider: StubProvider(value: dline(base: 1)),
                               clock: { dNow }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertTrue(s.isEgg)
        XCTAssertEqual(s.eggProgress, 0)
        XCTAssertEqual(s.eggTokensToHatch, PokemonBalance.eggHatchThreshold)

        // 임계의 40% 사용
        s.update(todayTokens: 0, todayDate: "d", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        let part = PokemonBalance.eggHatchThreshold * 2 / 5
        s.update(todayTokens: part, todayDate: "d", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.eggProgress, 0.4, accuracy: 0.001)
        XCTAssertEqual(s.eggTokensToHatch, PokemonBalance.eggHatchThreshold - part)
        XCTAssertTrue(s.eggStarted)
    }
}
