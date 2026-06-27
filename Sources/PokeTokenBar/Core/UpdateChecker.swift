import AppKit
import Observation

/// GitHub 릴리스 최신 버전을 확인해 새 버전이 있으면 팝오버에 알린다.
/// 실제 설치는 brew 사용자면 `brew upgrade`, 그 외엔 릴리스 페이지 열기(저위험·인프라 0).
@MainActor
@Observable
final class UpdateChecker {
    struct Available: Equatable { let version: String; let url: String }

    private(set) var available: Available?
    private(set) var isUpdating = false

    let currentVersion: String
    private let repo = "chattymin/PokeTokenBar"
    private let clock: () -> Date
    private var lastChecked: Date?

    init(currentVersion: String? = nil, clock: @escaping () -> Date = Date.init) {
        self.currentVersion = currentVersion
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        self.clock = clock
    }

    /// 최신 릴리스 조회 → 새 버전이고 사용자가 그 버전을 'skip' 하지 않았으면 available 설정.
    /// minInterval 보다 자주 호출되면 무시(레이트리밋 보호).
    func check(minInterval: TimeInterval = 1800) async {
        if let last = lastChecked, clock().timeIntervalSince(last) < minInterval { return }
        lastChecked = clock()
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = json["html_url"] as? String else { return }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let skipped = UserDefaults.standard.string(forKey: "skippedUpdateVersion")
        if Self.isNewer(latest, than: currentVersion), latest != skipped {
            available = Available(version: latest, url: html)
        } else {
            available = nil
        }
    }

    /// 이 버전은 다시 알리지 않음.
    func skipCurrent() {
        if let v = available?.version { UserDefaults.standard.set(v, forKey: "skippedUpdateVersion") }
        available = nil
    }

    /// 업데이트 적용: brew cask 설치본이면 `brew upgrade` 후 재시작, 아니면 릴리스 페이지.
    func applyUpdate() {
        guard let update = available else { return }
        guard !isUpdating else { return }
        isUpdating = true
        Task { @MainActor in
            let upgraded = await Task.detached { Self.brewUpgradeIfInstalled() }.value
            isUpdating = false
            if upgraded {
                Self.relaunch()
            } else if let u = URL(string: update.url) {
                AppLog.write("update: brew upgrade unavailable/failed → opening release page")
                NSWorkspace.shared.open(u)
            }
        }
    }

    // MARK: 버전 비교

    /// a 가 b 보다 높은 semver 인가. ("2.0.10" > "2.0.9" 등 숫자 비교)
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: brew 적용 (nonisolated — 블로킹 Process 는 detached 에서)

    /// brew cask 설치본이면 업그레이드. 설치본이 아니거나 brew 없으면 false(→ 릴리스 페이지 폴백).
    private nonisolated static func brewUpgradeIfInstalled() -> Bool {
        guard let brew = BinaryLocator.resolve("brew", staticPaths: [
            "/opt/homebrew/bin/brew", "/usr/local/bin/brew",
        ]) else { return false }
        guard run(brew, ["list", "--cask", "poke-token-bar"], timeout: 20) else { return false }
        return run(brew, ["upgrade", "--cask", "poke-token-bar"], timeout: 300)
    }

    private nonisolated static func run(_ binary: String, _ args: [String], timeout: TimeInterval) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate(); return false }
        return process.terminationStatus == 0
    }

    /// 교체된 새 번들을 다시 띄우고 현재 인스턴스 종료(분리된 sh 가 종료를 기다렸다 open).
    private static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // 경로를 스크립트 문자열에 보간하지 않고 positional 인자($1)로 전달 — 셸 인젝션 차단.
        task.arguments = ["-c", "sleep 2; open \"$1\"", "sh", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
