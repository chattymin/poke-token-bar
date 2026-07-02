import AppKit

/// 포켓몬 스프라이트를 런타임에 받아 로컬(Application Support)에 캐시. 레포/번들에 미포함.
actor SpriteStore {
    static let shared = SpriteStore()
    private let base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
    private var mem: [String: Data] = [:]
    private let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeTokenBar/sprites")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    /// 캐시 파일명 키 — 기존 "\(id)-a"/"\(id)-s" 유지, shiny 는 "sh" 접두(구캐시 그대로 유효).
    static func cacheKey(speciesID: Int, animated: Bool, shiny: Bool) -> String {
        "\(speciesID)-\(shiny ? "sh" : "")\(animated ? "a" : "s")"
    }

    func data(speciesID: Int, animated: Bool, shiny: Bool = false) async -> Data? {
        let key = Self.cacheKey(speciesID: speciesID, animated: animated, shiny: shiny)
        if let d = mem[key] { return d }
        let ext = animated ? "gif" : "png"
        let file = dir.appendingPathComponent("\(key).\(ext)")
        if let d = try? Data(contentsOf: file) { mem[key] = d; return d }
        let urlStr: String
        switch (animated, shiny) {
        case (true, false):  urlStr = "\(base)/versions/generation-v/black-white/animated/\(speciesID).gif"
        case (true, true):   urlStr = "\(base)/versions/generation-v/black-white/animated/shiny/\(speciesID).gif"
        case (false, false): urlStr = "\(base)/\(speciesID).png"
        case (false, true):  urlStr = "\(base)/shiny/\(speciesID).png"
        }
        guard let url = URL(string: urlStr),
              let (d, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200, !d.isEmpty else { return nil }
        try? d.write(to: file)
        mem[key] = d
        return d
    }
}

@MainActor
enum SpriteLoader {
    static let cacheDir: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeTokenBar/sprites")
    }()

    /// 디스크 캐시에 이미 있으면 동기 반환(네트워크 없음). 없으면 nil.
    /// shiny 캐시 미스는 일반 캐시로 폴백 — 오프라인에서 live mon 이 알 글리프로 보이는 것 방지.
    static func cachedImage(speciesID: Int, animated: Bool = false, shiny: Bool = false) -> NSImage? {
        let ext = animated ? "gif" : "png"
        let key = SpriteStore.cacheKey(speciesID: speciesID, animated: animated, shiny: shiny)
        let f = cacheDir.appendingPathComponent("\(key).\(ext)")
        if let d = try? Data(contentsOf: f), let img = NSImage(data: d) { return img }
        guard shiny else { return nil }
        return cachedImage(speciesID: speciesID, animated: animated, shiny: false)
    }

    /// 정적 스프라이트. animated=true 면 Gen-V 움직이는 스프라이트(없으면 정적으로 폴백).
    /// shiny=true 는 색이 다른 스프라이트 — 미제공 종이면 일반으로 폴백.
    static func image(speciesID: Int, animated: Bool = false, shiny: Bool = false) async -> NSImage? {
        if animated, let d = await SpriteStore.shared.data(speciesID: speciesID, animated: true, shiny: shiny),
           let img = NSImage(data: d) {
            return img
        }
        if let d = await SpriteStore.shared.data(speciesID: speciesID, animated: false, shiny: shiny),
           let img = NSImage(data: d) {
            return img
        }
        // shiny 미제공 → 일반 폴백
        guard shiny else { return nil }
        return await image(speciesID: speciesID, animated: animated, shiny: false)
    }
}
