import XCTest
@testable import PokeTokenBar

// MARK: 경제

final class PokemonBalanceTests: XCTestCase {
    func testGraduationTotalIsConstantPerRarityRegardlessOfStages() {
        for rarity in [Rarity.common, .uncommon, .rare, .legendary] {
            let T = PokemonBalance.graduationTotal(rarity)
            for k in 1...3 {
                let sum = (0..<k).reduce(0) { $0 + PokemonBalance.phaseThreshold(rarity: rarity, totalForms: k, stageIndex: $1) }
                // 반올림 오차 허용
                XCTAssertLessThanOrEqual(abs(sum - T), 2, "rarity=\(rarity) k=\(k) sum=\(sum) T=\(T)")
            }
        }
    }
    func testHigherStageCostsMore() {
        for k in 2...3 {
            for i in 0..<(k - 1) {
                XCTAssertLessThan(
                    PokemonBalance.phaseThreshold(rarity: .common, totalForms: k, stageIndex: i),
                    PokemonBalance.phaseThreshold(rarity: .common, totalForms: k, stageIndex: i + 1))
            }
        }
    }
    func testRarerCostsMore() {
        XCTAssertLessThan(PokemonBalance.graduationTotal(.common), PokemonBalance.graduationTotal(.uncommon))
        XCTAssertLessThan(PokemonBalance.graduationTotal(.uncommon), PokemonBalance.graduationTotal(.rare))
        XCTAssertLessThan(PokemonBalance.graduationTotal(.rare), PokemonBalance.graduationTotal(.legendary))
    }
    func testRarityDerivation() {
        XCTAssertEqual(Rarity.from(captureRate: 255, isLegendary: false, isMythical: false), .common)
        XCTAssertEqual(Rarity.from(captureRate: 90, isLegendary: false, isMythical: false), .uncommon)
        XCTAssertEqual(Rarity.from(captureRate: 45, isLegendary: false, isMythical: false), .rare)
        XCTAssertEqual(Rarity.from(captureRate: 3, isLegendary: true, isMythical: false), .legendary)
    }
}

// MARK: 부화 풀 (가중 선택)

final class PokemonPoolTests: XCTestCase {
    func testTotalWeightMatchesEntries() {
        // common 8개×8 + uncommon 1×4 + rare 7×2 + legendary 1×1 = 83
        XCTAssertEqual(PokemonPool.totalWeight, 83)
    }

    func testPickMapsEachRollAndRespectsPerEntryWeight() {
        // 0..<totalWeight 전 구간을 훑으면 각 엔트리는 정확히 weight(tier) 회 선택돼야 한다.
        var counts: [Int: Int] = [:]
        for roll in 0..<PokemonPool.totalWeight {
            counts[PokemonPool.pick(roll: roll), default: 0] += 1
        }
        for e in PokemonPool.entries {
            XCTAssertEqual(counts[e.id], PokemonPool.weight(e.tier), "id=\(e.id) tier=\(e.tier)")
        }
        // 모든 엔트리가 한 번 이상 선택 가능
        XCTAssertEqual(Set(counts.keys), Set(PokemonPool.entries.map(\.id)))
    }

    func testRarerTierIsLessLikelyThanCommon() {
        let common = PokemonPool.weight(.common)
        XCTAssertGreaterThan(common, PokemonPool.weight(.uncommon))
        XCTAssertGreaterThan(PokemonPool.weight(.uncommon), PokemonPool.weight(.rare))
        XCTAssertGreaterThan(PokemonPool.weight(.rare), PokemonPool.weight(.legendary))
        // 집계: common tier 총가중 > rare tier 총가중 > legendary
        func tierTotal(_ t: Rarity) -> Int {
            PokemonPool.entries.filter { $0.tier == t }.reduce(0) { $0 + PokemonPool.weight($1.tier) }
        }
        XCTAssertGreaterThan(tierTotal(.common), tierTotal(.rare))
        XCTAssertGreaterThan(tierTotal(.rare), tierTotal(.legendary))
    }

    func testPickRollWrapsSafely() {
        // roll 이 범위를 넘어도(% 처리) 유효한 id 반환
        XCTAssertTrue(PokemonPool.entries.map(\.id).contains(PokemonPool.pick(roll: PokemonPool.totalWeight)))
        XCTAssertTrue(PokemonPool.entries.map(\.id).contains(PokemonPool.pick(roll: 99_999)))
    }
}

// MARK: 헬퍼

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct StubProvider: PokeProviding {
    let value: EvoLine
    func line(baseSpeciesID: Int) async throws -> EvoLine { value }
}

private func allIDs(_ n: EvoNode) -> [Int] { [n.speciesID] + n.children.flatMap(allIDs) }
private func makeLine(base: Int, tree: EvoNode, rarity: Rarity = .common) -> EvoLine {
    var names: [Int: [String: String]] = [:]
    for id in allIDs(tree) { names[id] = ["en": "P\(id)", "ko": "포\(id)", "ja": "ポ\(id)"] }
    return EvoLine(baseID: base, tree: tree, rarity: rarity, names: names)
}
private func node(_ id: Int, _ children: [EvoNode] = []) -> EvoNode { EvoNode(speciesID: id, children: children) }
// 3단 선형: 1→2→3
private let linear3 = makeLine(base: 1, tree: node(1, [node(2, [node(3)])]))
// 분기: 10 → {11,12,13}
private let branch3 = makeLine(base: 10, tree: node(10, [node(11), node(12), node(13)]))
// 무진화: 20
private let noEvo = makeLine(base: 20, tree: node(20))
private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

// MARK: 스토어

@MainActor
final class CompanionStoreTests: XCTestCase {
    private func store(_ line: EvoLine, seed: UInt64 = 7) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-\(UUID().uuidString).json")
        return CompanionStore(provider: StubProvider(value: line), clock: { fixedNow }, fileURL: url, rng: SeededRNG(seed: seed))
    }

    func testInstallBaselineExcludesPreInstallUsage() {
        let s = store(linear3)
        // 데이터 도착 전 → baseline 미설정
        s.update(todayTokens: 0, todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: false)
        XCTAssertFalse(s.state.installBaselineSet)
        // 첫 실데이터 → baseline = 그 시점 today(이전 사용량 미카운트)
        s.update(todayTokens: 48_000_000, todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertTrue(s.state.installBaselineSet)
        XCTAssertEqual(s.state.usedSinceInstall, 0)
        // 이후 증가분만 누적
        s.update(todayTokens: 148_000_000, todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        XCTAssertEqual(s.state.usedSinceInstall, 100_000_000)
    }

    private func base(_ s: CompanionStore) {
        s.update(todayTokens: 0, todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
    }
    private func use(_ s: CompanionStore, _ today: Int) {
        s.update(todayTokens: today, todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
    }

    func testEggDoesNotHatchBelowThreshold() async {
        let s = store(linear3)
        base(s)
        use(s, 500_000)   // < 1M
        XCTAssertEqual(s.state.eggUsage, 500_000)
        XCTAssertTrue(s.isEgg)
        await s.hatchIfNeeded()
        XCTAssertNil(s.state.active)   // 임계 미만 → 미부화
    }

    func testEggHatchesAtThreshold() async {
        let s = store(linear3)
        base(s)
        use(s, PokemonBalance.eggHatchThreshold)   // = 1M
        XCTAssertEqual(s.state.eggUsage, PokemonBalance.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertNotNil(s.state.active)
        XCTAssertEqual(s.state.eggUsage, 0)
    }

    func testEggOverflowCarriesToHatchedMon() async {
        let s = store(linear3)
        base(s)
        use(s, PokemonBalance.eggHatchThreshold + 500_000)   // 임계 초과 0.5M
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.active?.usedAtStage, 500_000)   // 초과분 이월
    }

    func testNewEggAfterGraduationReincubates() async {
        let s = store(noEvo)
        base(s)
        use(s, PokemonBalance.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertNotNil(s.state.active)
        s.applyUsage(PokemonBalance.graduationTotal(.common))   // 무진화 졸업
        XCTAssertNil(s.state.active)
        XCTAssertEqual(s.state.eggUsage, 0)                     // 새 알 인큐베이션 리셋
        await s.hatchIfNeeded()                                 // eggUsage=0 → 즉시 부화 안 함
        XCTAssertNil(s.state.active)
    }

    func testStateDecodesWithoutEggUsage() throws {
        // 기존 저장(필드 없음)도 깨지지 않고 eggUsage=0 으로 로드
        let json = #"{"installBaselineSet":true,"usedSinceInstall":5,"claimedTodayTokens":5,"lastDate":"d","active":null,"dex":[],"collectedFinals":[],"language":"ko"}"#
        let state = try JSONDecoder().decode(CompanionState.self, from: Data(json.utf8))
        XCTAssertEqual(state.eggUsage, 0)
        XCTAssertEqual(state.usedSinceInstall, 5)
    }

    func testEvolvesThroughLineAndGraduatesWithFullChain() async {
        let s = store(linear3)
        await s.hatch(baseID: 1)
        XCTAssertEqual(s.currentSpeciesID, 1)
        XCTAssertEqual(s.state.active?.totalForms, 3)
        s.applyUsage(PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 0)) // →2
        XCTAssertEqual(s.currentSpeciesID, 2)
        s.applyUsage(PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 1)) // →3 (final)
        XCTAssertEqual(s.currentSpeciesID, 3)
        XCTAssertTrue(s.isFinalStage)
        s.applyUsage(PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 2)) // 졸업
        XCTAssertNil(s.state.active)
        XCTAssertEqual(s.dexEntries.count, 1)
        XCTAssertEqual(s.dexEntries[0].chainOrder, [1, 2, 3])   // 라인 전체 보존
        XCTAssertEqual(s.justGraduated, "포3")
    }

    func testNoEvolutionGraduatesAtSingleThreshold() async {
        let s = store(noEvo)
        await s.hatch(baseID: 20)
        XCTAssertTrue(s.isFinalStage)
        s.applyUsage(PokemonBalance.graduationTotal(.common))   // 무진화: 단일 임계 = T
        XCTAssertEqual(s.dexEntries.count, 1)
        XCTAssertEqual(s.dexEntries[0].chainOrder, [20])
    }

    func testBranchingPrefersUncollectedFinals() async {
        let s = store(branch3)
        let evo = PokemonBalance.phaseThreshold(rarity: .common, totalForms: 2, stageIndex: 0)
        let grad = PokemonBalance.phaseThreshold(rarity: .common, totalForms: 2, stageIndex: 1)
        var finals: [Int] = []
        for _ in 0..<3 {
            await s.hatch(baseID: 10)
            s.applyUsage(evo)    // 분기 진화
            s.applyUsage(grad)   // 졸업
            finals.append(s.dexEntries.last!.finalID)
        }
        XCTAssertEqual(Set(finals).count, 3)   // 같은 base 재부화 시 매번 다른 분기
        XCTAssertEqual(Set(finals), [11, 12, 13])
    }

    func testPersistenceRoundTrip() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-persist-\(UUID().uuidString).json")
        let s1 = CompanionStore(provider: StubProvider(value: linear3), clock: { fixedNow }, fileURL: url, rng: SeededRNG(seed: 1))
        await s1.hatch(baseID: 1)
        s1.applyUsage(PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 0))
        s1.setLanguage(.ja)
        let s2 = CompanionStore(provider: StubProvider(value: linear3), clock: { fixedNow }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertEqual(s2.state.active?.currentID, 2)
        XCTAssertEqual(s2.state.active?.stageIndex, 1)
        XCTAssertEqual(s2.language, .ja)
    }

    func testLocalizedName() async {
        let s = store(linear3)
        await s.hatch(baseID: 1)
        XCTAssertEqual(s.displayName, "포1")
        s.setLanguage(.en); XCTAssertEqual(s.displayName, "P1")
        s.setLanguage(.ja); XCTAssertEqual(s.displayName, "ポ1")
    }
}

// MARK: 도감 정렬 / 요약

@MainActor
final class DexSortingTests: XCTestCase {
    func testSortRankOrdersRarityAscendingByValue() {
        XCTAssertLessThan(Rarity.common.sortRank, Rarity.uncommon.sortRank)
        XCTAssertLessThan(Rarity.uncommon.sortRank, Rarity.rare.sortRank)
        XCTAssertLessThan(Rarity.rare.sortRank, Rarity.legendary.sortRank)
    }

    func testDexEntriesSortedLegendaryFirstThenRecency() async {
        // common 라인 2개(시각 다름) + legendary 라인 1개를 같은 store 에 졸업시킨다.
        // StubProvider 는 라인 1개만 주므로, 라인별로 store 를 분리하지 않고
        // 직접 졸업 흐름을 재현: 무진화(단일 임계) 라인을 hatch→applyUsage 로 졸업.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-\(UUID().uuidString).json")
        var tick = 0
        // 라인을 바꿔가며 졸업시키기 위해 가변 provider 사용.
        let provider = MutableProvider()
        let s = CompanionStore(provider: provider,
                               clock: { fixedNow.addingTimeInterval(TimeInterval(tick)) },
                               fileURL: url, rng: SeededRNG(seed: 3))

        // common #1 (가장 먼저)
        provider.line = makeLine(base: 100, tree: node(100), rarity: .common)
        tick = 1; await s.hatch(baseID: 100)
        s.applyUsage(PokemonBalance.graduationTotal(.common))

        // common #2 (더 나중)
        provider.line = makeLine(base: 101, tree: node(101), rarity: .common)
        tick = 2; await s.hatch(baseID: 101)
        s.applyUsage(PokemonBalance.graduationTotal(.common))

        // legendary (가장 나중이지만 희귀도가 더 높음)
        provider.line = makeLine(base: 200, tree: node(200), rarity: .legendary)
        tick = 3; await s.hatch(baseID: 200)
        s.applyUsage(PokemonBalance.graduationTotal(.legendary))

        XCTAssertEqual(s.dexEntries.count, 3)
        let sorted = s.dexEntriesSorted
        // legendary 가 맨 앞
        XCTAssertEqual(sorted[0].rarity, .legendary)
        XCTAssertEqual(sorted[0].finalID, 200)
        // 그다음 common 끼리는 최신(101)이 먼저
        XCTAssertEqual(sorted[1].rarity, .common)
        XCTAssertEqual(sorted[1].finalID, 101)
        XCTAssertEqual(sorted[2].finalID, 100)

        // 희귀도별 카운트
        XCTAssertEqual(s.dexCount(.common), 2)
        XCTAssertEqual(s.dexCount(.legendary), 1)
        XCTAssertEqual(s.dexCount(.rare), 0)
    }
}

/// 테스트용 — 라인을 호출 전에 갈아끼울 수 있는 provider. 단일 스레드 테스트 한정.
private final class MutableProvider: PokeProviding, @unchecked Sendable {
    nonisolated(unsafe) var line: EvoLine = makeLine(base: 1, tree: node(1))
    func line(baseSpeciesID: Int) async throws -> EvoLine { line }
}

// MARK: 개체 아이덴티티 (shiny / nature) — v2.2.0

@MainActor
final class CompanionIdentityTests: XCTestCase {
    private func store(_ line: EvoLine, seed: UInt64) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poke-\(UUID().uuidString).json")
        return CompanionStore(provider: StubProvider(value: line), clock: { fixedNow }, fileURL: url, rng: SeededRNG(seed: seed))
    }

    /// 직접 hatch(baseID:) 는 rng 를 shiny → nature 순으로 소비한다. 같은 시드 재생으로 기대값 산출.
    private func expectedRoll(seed: UInt64) -> (shiny: Bool, nature: PokemonNature) {
        var rng = SeededRNG(seed: seed)
        let shiny = rng.next() % PokemonOdds.shinyDenominator == 0
        let nature = PokemonNature.allCases[Int(rng.next() % UInt64(PokemonNature.allCases.count))]
        return (shiny, nature)
    }

    /// 임의 시드에서 부화 롤이 결정적이고 성격이 항상 부여되는지.
    func testHatchAssignsDeterministicShinyAndNature() async {
        for seed: UInt64 in [1, 7, 42, 12345] {
            let s = store(linear3, seed: seed)
            let expected = expectedRoll(seed: seed)
            await s.hatch(baseID: 1)
            XCTAssertEqual(s.state.active?.isShiny, expected.shiny, "seed \(seed)")
            XCTAssertEqual(s.state.active?.nature, expected.nature, "seed \(seed)")
        }
    }

    /// shiny 가 실제로 나오는 시드를 탐색해 true 경로를 검증(1/64 확률이 코드에 존재함을 보장).
    func testShinyPathReachable() async {
        var shinySeed: UInt64?
        for seed: UInt64 in 0..<5000 where expectedRoll(seed: seed).shiny { shinySeed = seed; break }
        guard let seed = shinySeed else { return XCTFail("5000개 시드 중 shiny 없음 — 분모 확인") }
        let s = store(linear3, seed: seed)
        await s.hatch(baseID: 1)
        XCTAssertEqual(s.state.active?.isShiny, true)
        XCTAssertTrue(s.currentIsShiny)
    }

    /// 진화를 거쳐 졸업해도 shiny/nature 가 도감 항목에 보존되는지.
    func testGraduateCarriesIdentityToDex() async {
        let s = store(noEvo, seed: 3)   // 무진화 → 임계 도달 시 바로 졸업
        await s.hatch(baseID: 20)
        let shiny = s.state.active!.isShiny
        let nature = s.state.active!.nature
        XCTAssertNotNil(nature)
        s.applyUsage(PokemonBalance.graduationTotal(.common))
        XCTAssertNil(s.state.active)   // 졸업
        XCTAssertEqual(s.state.dex.count, 1)
        XCTAssertEqual(s.state.dex[0].isShiny, shiny)
        XCTAssertEqual(s.state.dex[0].nature, nature)
    }

    /// 구버전 저장(shiny/nature 키 없음) 디코딩 — 기본값(false/nil)으로 로드.
    func testBackwardCompatibleDecode() throws {
        let old = """
        {"installBaselineSet":true,"usedSinceInstall":100,"eggUsage":0,
         "claimedTodayTokens":100,"lastDate":"d1",
         "active":{"baseID":1,"pathIDs":[1],"stageIndex":0,"usedAtStage":5,"rarity":"common","totalForms":3},
         "dex":[{"id":"x","baseID":4,"finalID":6,"chainOrder":[4,5,6],"rarity":"rare"}],
         "collectedFinals":["4:6"],"language":"ko"}
        """
        let s = try JSONDecoder().decode(CompanionState.self, from: Data(old.utf8))
        XCTAssertEqual(s.active?.isShiny, false)
        XCTAssertNil(s.active?.nature)
        XCTAssertEqual(s.dex[0].isShiny, false)
        XCTAssertNil(s.dex[0].nature)
        // 재인코딩 후 재디코딩도 안정적(라운드트립)
        let round = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(round.active?.isShiny, false)
    }

    /// 부화/진화가 연출 트리거(celebrationSeq)를 올리고, consume 후 비워지는지.
    func testCelebrationFiresOnHatchAndEvolve() async {
        let s = store(linear3, seed: 9)
        XCTAssertEqual(s.celebrationSeq, 0)
        await s.hatch(baseID: 1)
        XCTAssertEqual(s.celebrationSeq, 1)
        if case .hatch = s.celebration {} else { XCTFail("hatch 연출이어야 함: \(String(describing: s.celebration))") }
        s.consumeCelebration()
        XCTAssertNil(s.celebration)
        // 1단계 임계 도달 → 진화 연출
        let thr = PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 0)
        s.applyUsage(thr)
        XCTAssertEqual(s.celebrationSeq, 2)
        XCTAssertEqual(s.celebration, .evolve)
    }

    /// 스프라이트 캐시 키 — 기존 키("25-a"/"25-s") 불변 + shiny 접두.
    func testSpriteCacheKeyScheme() {
        XCTAssertEqual(SpriteStore.cacheKey(speciesID: 25, animated: true, shiny: false), "25-a")
        XCTAssertEqual(SpriteStore.cacheKey(speciesID: 25, animated: false, shiny: false), "25-s")
        XCTAssertEqual(SpriteStore.cacheKey(speciesID: 25, animated: true, shiny: true), "25-sha")
        XCTAssertEqual(SpriteStore.cacheKey(speciesID: 25, animated: false, shiny: true), "25-shs")
    }

    /// 성격 25종 — 3개 언어 명칭이 전부 비어있지 않고 중복 없는지.
    func testNatureNamesComplete() {
        XCTAssertEqual(PokemonNature.allCases.count, 25)
        for lang in AppLanguage.allCases {
            let names = PokemonNature.allCases.map { $0.name(lang) }
            XCTAssertEqual(Set(names).count, 25, "\(lang) 중복/누락")
            XCTAssertFalse(names.contains(where: \.isEmpty))
        }
    }
}
