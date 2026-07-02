import Foundation

/// 표시 상태 — 사용량/burn 으로 결정(스프라이트 모션 강도·상태 문구).
enum CompanionStateKind: String, Sendable {
    case egg, idle, working, focus, tired, sleep, levelUp
}

/// 앱 언어. 포켓몬 이름은 PokéAPI 다국어 names 에서 가져온다.
enum AppLanguage: String, Codable, Sendable, CaseIterable {
    case ko, en, ja
    /// PokéAPI language.name 후보(첫 매칭 사용)
    var apiCodes: [String] {
        switch self {
        case .ko: return ["ko"]
        case .en: return ["en"]
        case .ja: return ["ja-Hrkt", "ja"]
        }
    }
    var label: String {
        switch self { case .ko: return "한국어"; case .en: return "English"; case .ja: return "日本語" }
    }
}

/// 희귀도 — PokéAPI capture_rate / is_legendary 로 판정.
enum Rarity: String, Codable, Sendable {
    case common, uncommon, rare, legendary
    /// 정렬 순위(높을수록 희귀). 도감 정렬 — legendary→rare→uncommon→common.
    var sortRank: Int {
        switch self {
        case .common:    return 0
        case .uncommon:  return 1
        case .rare:      return 2
        case .legendary: return 3
        }
    }
    static func from(captureRate: Int, isLegendary: Bool, isMythical: Bool) -> Rarity {
        if isLegendary || isMythical { return .legendary }
        if captureRate <= 45 { return .rare }
        if captureRate <= 120 { return .uncommon }
        return .common
    }
}

/// 토큰 경제 — 실측 평균(~253M/일) 기준.
/// 졸업 총량 T 는 같은 희귀도면 진화 단계 수와 무관하게 동일.
/// 형태 k개 라인에서 i번째 형태 성장 비용 = T·i / (k(k+1)/2) → 합 = T, 단계↑일수록 비용↑.
enum PokemonBalance {
    /// 알 부화 임계 — 이만큼 토큰을 써야 알이 깨진다(즉시 부화 대신 기대감). 초과분은 부화체 성장에 이월.
    static let eggHatchThreshold = 5_000_000

    static func graduationTotal(_ rarity: Rarity) -> Int {
        switch rarity {
        case .common:    return    750_000_000
        case .uncommon:  return  1_875_000_000
        case .rare:      return  3_000_000_000
        case .legendary: return  6_000_000_000
        }
    }
    /// stageIndex(0-based)에서 다음 단계/졸업까지 필요한 토큰.
    static func phaseThreshold(rarity: Rarity, totalForms k: Int, stageIndex: Int) -> Int {
        let kk = max(1, k)
        let i = stageIndex + 1                         // 1-based
        let total = Double(graduationTotal(rarity))
        let denom = Double(kk * (kk + 1)) / 2.0
        return Int((total * Double(i) / denom).rounded())
    }
}

/// PokéAPI evolution-chain 을 파싱한 트리. 분기(evolves_to 다수)를 children 으로.
struct EvoNode: Codable, Sendable {
    let speciesID: Int
    let children: [EvoNode]

    /// 최장 경로 길이(형태 수). 분기는 보통 같은 깊이라 대표값으로 사용.
    var depth: Int { 1 + (children.map(\.depth).max() ?? 0) }
    func node(withID id: Int) -> EvoNode? {
        if speciesID == id { return self }
        for c in children { if let f = c.node(withID: id) { return f } }
        return nil
    }
    /// 이 노드에서 도달 가능한 모든 최종체 id
    var finalIDs: [Int] {
        children.isEmpty ? [speciesID] : children.flatMap(\.finalIDs)
    }
}

/// 부화 시 확정되는 라인 정보(트리 + 희귀도 + 다국어 이름).
struct EvoLine: Sendable {
    let baseID: Int
    let tree: EvoNode
    let rarity: Rarity
    /// speciesID → (langCode → name)
    let names: [Int: [String: String]]
    var totalForms: Int { tree.depth }
    func localizedName(_ id: Int, _ lang: AppLanguage) -> String {
        guard let byLang = names[id] else { return "#\(id)" }
        for code in lang.apiCodes { if let n = byLang[code] { return n } }
        return byLang["en"] ?? "#\(id)"
    }
}

/// 성격 — 본가 25종. 부화 시 확정, 능력치 영향 없음(개체 아이덴티티 표시용).
enum PokemonNature: String, Codable, Sendable, CaseIterable {
    case hardy, lonely, brave, adamant, naughty
    case bold, docile, relaxed, impish, lax
    case timid, hasty, serious, jolly, naive
    case modest, mild, quiet, bashful, rash
    case calm, gentle, sassy, careful, quirky

    /// 본가 공식 번역 명칭 (ko/en/ja).
    func name(_ lang: AppLanguage) -> String {
        let names: (String, String, String)
        switch self {
        case .hardy:   names = ("노력", "Hardy", "がんばりや")
        case .lonely:  names = ("외로움", "Lonely", "さみしがり")
        case .brave:   names = ("용감", "Brave", "ゆうかん")
        case .adamant: names = ("고집", "Adamant", "いじっぱり")
        case .naughty: names = ("개구쟁이", "Naughty", "やんちゃ")
        case .bold:    names = ("대담", "Bold", "ずぶとい")
        case .docile:  names = ("온순", "Docile", "すなお")
        case .relaxed: names = ("무사태평", "Relaxed", "のんき")
        case .impish:  names = ("장난꾸러기", "Impish", "わんぱく")
        case .lax:     names = ("촐랑", "Lax", "のうてんき")
        case .timid:   names = ("겁쟁이", "Timid", "おくびょう")
        case .hasty:   names = ("성급", "Hasty", "せっかち")
        case .serious: names = ("성실", "Serious", "まじめ")
        case .jolly:   names = ("명랑", "Jolly", "ようき")
        case .naive:   names = ("천진난만", "Naive", "むじゃき")
        case .modest:  names = ("조심", "Modest", "ひかえめ")
        case .mild:    names = ("의젓", "Mild", "おっとり")
        case .quiet:   names = ("냉정", "Quiet", "れいせい")
        case .bashful: names = ("수줍음", "Bashful", "てれや")
        case .rash:    names = ("덜렁", "Rash", "うっかりや")
        case .calm:    names = ("차분", "Calm", "おだやか")
        case .gentle:  names = ("얌전", "Gentle", "おとなしい")
        case .sassy:   names = ("건방", "Sassy", "なまいき")
        case .careful: names = ("신중", "Careful", "しんちょう")
        case .quirky:  names = ("변덕", "Quirky", "きまぐれ")
        }
        switch lang { case .ko: return names.0; case .en: return names.1; case .ja: return names.2 }
    }
}

/// 게임 밸런스 — 개체 롤 확률.
enum PokemonOdds {
    /// 색이 다른 포켓몬(shiny) 부화 확률 분모 — 1/64 (본가 1/4096 은 데스크톱 앱 규모에선 평생 못 봄).
    static let shinyDenominator: UInt64 = 64
}

/// 현재 키우는 포켓몬.
struct MonState: Codable, Sendable {
    var baseID: Int
    var pathIDs: [Int]      // 실제 진화 경로(분기 선택 반영)
    var stageIndex: Int     // pathIDs 내 현재 위치
    var usedAtStage: Int    // 현재 형태에서 누적 사용량
    var rarity: Rarity
    var totalForms: Int
    var isShiny = false             // 부화 시 확정, 진화해도 유지
    var nature: PokemonNature?      // 부화 시 확정 (구버전 저장은 nil)
    var currentID: Int { pathIDs[min(stageIndex, pathIDs.count - 1)] }

    init(baseID: Int, pathIDs: [Int], stageIndex: Int, usedAtStage: Int,
         rarity: Rarity, totalForms: Int, isShiny: Bool = false, nature: PokemonNature? = nil) {
        self.baseID = baseID
        self.pathIDs = pathIDs
        self.stageIndex = stageIndex
        self.usedAtStage = usedAtStage
        self.rarity = rarity
        self.totalForms = totalForms
        self.isShiny = isShiny
        self.nature = nature
    }

    // 하위호환 디코딩: shiny/nature 는 구버전 저장에 없음 → 기본값.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseID = try c.decode(Int.self, forKey: .baseID)
        pathIDs = try c.decode([Int].self, forKey: .pathIDs)
        stageIndex = try c.decode(Int.self, forKey: .stageIndex)
        usedAtStage = try c.decode(Int.self, forKey: .usedAtStage)
        rarity = try c.decode(Rarity.self, forKey: .rarity)
        totalForms = try c.decode(Int.self, forKey: .totalForms)
        isShiny = try c.decodeIfPresent(Bool.self, forKey: .isShiny) ?? false
        nature = try c.decodeIfPresent(PokemonNature.self, forKey: .nature)
    }
}

/// 도감 항목 — 라인 전체(초기→최종) 순서 보존.
struct DexEntry: Codable, Sendable, Identifiable {
    var id = UUID().uuidString
    var baseID: Int
    var finalID: Int
    var chainOrder: [Int]   // 초기→최종 종 id
    var rarity: Rarity
    var caughtAt: Date?
    var isShiny = false
    var nature: PokemonNature?

    init(baseID: Int, finalID: Int, chainOrder: [Int], rarity: Rarity,
         caughtAt: Date?, isShiny: Bool = false, nature: PokemonNature? = nil) {
        self.baseID = baseID
        self.finalID = finalID
        self.chainOrder = chainOrder
        self.rarity = rarity
        self.caughtAt = caughtAt
        self.isShiny = isShiny
        self.nature = nature
    }

    // 하위호환 디코딩 (MonState 와 동일 이유).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        baseID = try c.decode(Int.self, forKey: .baseID)
        finalID = try c.decode(Int.self, forKey: .finalID)
        chainOrder = try c.decode([Int].self, forKey: .chainOrder)
        rarity = try c.decode(Rarity.self, forKey: .rarity)
        caughtAt = try c.decodeIfPresent(Date.self, forKey: .caughtAt)
        isShiny = try c.decodeIfPresent(Bool.self, forKey: .isShiny) ?? false
        nature = try c.decodeIfPresent(PokemonNature.self, forKey: .nature)
    }
}

/// 영속 상태(Application Support JSON). 포켓몬 전환 — 이전 커스텀 캐릭터 상태는 폐기(새로 시작).
struct CompanionState: Codable, Sendable {
    // 토큰: 설치 이후만 측정
    var installBaselineSet = false
    var usedSinceInstall = 0
    // 현재 알이 생긴 뒤 쓴 토큰(부화 인큐베이션). 누적(usedSinceInstall)과 별개 — 졸업 후 새 알마다 0.
    var eggUsage = 0
    var claimedTodayTokens = 0
    var lastDate = ""
    // 현재 포켓몬(없으면 알)
    var active: MonState?
    // 도감
    var dex: [DexEntry] = []
    // 소유한 (base,final) 쌍 — 분기 다양성용
    var collectedFinals: Set<String> = []
    var language: AppLanguage = .ko

    init() {}

    // 하위호환 디코딩: 누락 키는 기본값(필드 추가가 기존 저장을 깨지 않도록).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        installBaselineSet = try c.decodeIfPresent(Bool.self, forKey: .installBaselineSet) ?? false
        usedSinceInstall = try c.decodeIfPresent(Int.self, forKey: .usedSinceInstall) ?? 0
        eggUsage = try c.decodeIfPresent(Int.self, forKey: .eggUsage) ?? 0
        claimedTodayTokens = try c.decodeIfPresent(Int.self, forKey: .claimedTodayTokens) ?? 0
        lastDate = try c.decodeIfPresent(String.self, forKey: .lastDate) ?? ""
        active = try c.decodeIfPresent(MonState.self, forKey: .active)
        dex = try c.decodeIfPresent([DexEntry].self, forKey: .dex) ?? []
        collectedFinals = try c.decodeIfPresent(Set<String>.self, forKey: .collectedFinals) ?? []
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .ko
    }
}

/// 부화 후보 base 종 — (PokéAPI 식별자, 선택 가중 tier). 3단/2단/무진화/분기 골고루.
/// tier 는 *선택 확률*만 결정하는 큐레이트 값 — 표시/경제 희귀도는 PokéAPI capture_rate
/// 에서 별도 파생(EvoLine.rarity, 권위 소스)하며 보통 일치한다.
enum PokemonPool {
    static let entries: [(id: Int, tier: Rarity)] = [
        // common — 흔하게 부화
        (10, .common), (16, .common), (172, .common), (129, .common),
        (66, .common), (92, .common), (280, .common), (304, .common),
        // uncommon
        (446, .uncommon),
        // rare — 스타터/이브이 등
        (1, .rare), (4, .rare), (7, .rare), (133, .rare),
        (128, .rare), (131, .rare), (252, .rare),
        // legendary — 드물게
        (144, .legendary),
    ]

    /// tier 별 선택 가중치(엔트리당). 희귀할수록 작다 → 부화 확률 낮음.
    static func weight(_ tier: Rarity) -> Int {
        switch tier {
        case .common:    return 8
        case .uncommon:  return 4
        case .rare:      return 2
        case .legendary: return 1
        }
    }

    static var totalWeight: Int { entries.reduce(0) { $0 + weight($1.tier) } }

    /// 0..<totalWeight 범위 난수로 가중 선택 → base id.
    static func pick(roll: Int) -> Int {
        var r = roll % max(1, totalWeight)
        for e in entries {
            r -= weight(e.tier)
            if r < 0 { return e.id }
        }
        return entries[0].id
    }
}
