import AppKit
import SwiftUI

@main
struct PokeTokenBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메뉴바는 AppDelegate 의 NSStatusItem 이 담당.
        // MenuBarExtra 라벨은 고빈도 갱신 시 재렌더링 폭주로 CPU/메모리 문제가 있어 사용하지 않는다.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var store: UsageStore!
    private var companion: CompanionStore!
    private var updater: UpdateChecker!
    private let navigation = PopoverNavigation()

    // 메뉴바 캐릭터 애니메이션 — 단일 타이머로 프레임 순환.
    // 프레임 = 이미 22px 로 합성된 이미지 + delay. egg/static 은 2프레임 bob, animated 는 GIF 실제 프레임.
    private var menuSpriteID: Int?
    private var menuFrames: [(image: NSImage, delay: TimeInterval)] = []
    private var menuIndex = 0
    private var menuTimer: Timer?
    private var menuLoadGen = 0     // async 로드 경합 방지

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Self.migrateLegacyStorageIfNeeded()   // TokenMac → PokeTokenBar 리네임: 기존 companion/캐시 보존
        store = UsageStore()
        companion = CompanionStore()
        updater = UpdateChecker()
        store.localizationLanguage = companion.language   // 알림 현지화용 미러 시드
        Task { await updater.check() }                    // 기동 시 1회 업데이트 확인

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.eggImage(up: false)
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environment(store).environment(companion).environment(updater).environment(navigation))
        popover.behavior = .transient

        observeStore()
        applyState()
    }

    /// Observation 기반 상태 반영 — store 의 menuTitle/isStale 변경 시 재호출
    private func observeStore() {
        withObservationTracking {
            _ = store.menuTitle
            _ = store.isStale
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyState()
                self.observeStore()
            }
        }
    }

    private func applyState() {
        guard let button = statusItem.button else { return }
        let title = store.menuTitle
        button.title = title.isEmpty ? "" : " " + title
        button.appearsDisabled = store.isStale

        updateCompanion()
        ensureMenuAnimation()
    }

    /// UsageStore 값 → CompanionStore (사용량 적립 + 표시 상태). 매 관찰 변경 시 호출.
    private func updateCompanion() {
        companion.update(
            todayTokens: store.todayTotalTokens,
            todayDate: CcusageProvider.todayKey(),
            monthTotal: store.monthTotalTokens,
            burnTier: store.burnTier,
            limitWarning: store.isLimitWarning,
            hasUsageData: store.hasUsageData)
    }

    // MARK: 메뉴바 애니메이션

    /// 현재 포켓몬에 맞춰 메뉴바 프레임을 준비. 종이 바뀐 경우에만 재로딩.
    /// 즉시(캐시/알)로 먼저 보여주고, animated GIF 가 받아지면 교체.
    private func ensureMenuAnimation() {
        let id = companion.currentSpeciesID
        if id == menuSpriteID, !menuFrames.isEmpty { return }   // 이미 이 종으로 애니메이션 중
        menuSpriteID = id
        menuLoadGen += 1
        let gen = menuLoadGen

        guard let id else {                  // 알: 즉시 2프레임 bob
            setMenuFrames(Self.eggFrames())
            return
        }
        // 캐시된 정적 스프라이트가 있으면 즉시 표시(없으면 알 placeholder)
        if let cached = SpriteLoader.cachedImage(speciesID: id) {
            setMenuFrames(Self.bobFrames(from: cached))
        } else {
            setMenuFrames(Self.eggFrames())
        }
        // animated GIF 우선 시도 → 실패 시 정적 스프라이트
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let data = await SpriteStore.shared.data(speciesID: id, animated: true) {
                let raw = GIFDecoder.frames(from: data)
                if raw.count > 1 {
                    guard gen == self.menuLoadGen else { return }
                    self.setMenuFrames(raw.map { (Self.menuBarImage(from: $0.image, up: false), $0.delay) })
                    return
                }
            }
            if let sprite = await SpriteLoader.image(speciesID: id) {
                guard gen == self.menuLoadGen else { return }
                self.setMenuFrames(Self.bobFrames(from: sprite))
            }
        }
    }

    private func setMenuFrames(_ frames: [(image: NSImage, delay: TimeInterval)]) {
        menuFrames = frames
        menuIndex = 0
        advanceMenu()
    }

    /// 현재 프레임을 메뉴바에 올리고, 그 프레임의 delay 후 다음 프레임 예약(자기 재예약).
    private func advanceMenu() {
        menuTimer?.invalidate()
        guard !menuFrames.isEmpty else { return }
        let frame = menuFrames[menuIndex % menuFrames.count]
        statusItem.button?.image = frame.image
        guard menuFrames.count > 1 else { return }   // 단일 프레임이면 정지
        menuTimer = Timer.scheduledTimer(withTimeInterval: frame.delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.menuIndex = (self.menuIndex + 1) % self.menuFrames.count
                self.advanceMenu()
            }
        }
    }

    // MARK: 프레임 합성 (22px)

    /// 스프라이트 정적 + 가벼운 상하 bob 2프레임 (animated 미지원/로딩 폴백).
    private static func bobFrames(from sprite: NSImage) -> [(image: NSImage, delay: TimeInterval)] {
        [(menuBarImage(from: sprite, up: false), 0.5), (menuBarImage(from: sprite, up: true), 0.5)]
    }

    /// 부화 전/로딩 중 알 글리프 2프레임 bob.
    private static func eggFrames() -> [(image: NSImage, delay: TimeInterval)] {
        [(eggImage(up: false), 0.5), (eggImage(up: true), 0.5)]
    }

    private static func menuBarImage(from sprite: NSImage, up: Bool) -> NSImage {
        let h: CGFloat = 22
        let img = NSImage(size: NSSize(width: h, height: h))
        img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        let off: CGFloat = up ? 1 : 0
        sprite.draw(in: NSRect(x: 1, y: off, width: h - 2, height: h - 2),
                    from: .zero, operation: .sourceOver, fraction: 1)
        img.unlockFocus()
        return img
    }

    /// TokenMac→PokeTokenBar 리네임에 따른 1회 이전: 기존 Application Support 폴더를
    /// 새 이름으로 옮겨 companion 진행상황·스프라이트 캐시·스냅샷을 보존한다(신규 폴더 없을 때만).
    private static func migrateLegacyStorageIfNeeded() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = base.appendingPathComponent("TokenMac")
        let new = base.appendingPathComponent("PokeTokenBar")
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { return }
        try? fm.moveItem(at: old, to: new)
    }

    /// 스프라이트가 아직 없을 때(부화 전/로딩 중) 메뉴바에 표시하는 알 글리프.
    private static func eggImage(up: Bool) -> NSImage {
        let h: CGFloat = 22
        let img = NSImage(size: NSSize(width: h, height: h))
        img.lockFocus()
        let off: CGFloat = up ? 1 : 0
        let s = "🥚" as NSString
        s.draw(in: NSRect(x: 2, y: off, width: h - 2, height: h - 2),
               withAttributes: [.font: NSFont.systemFont(ofSize: 15)])
        img.unlockFocus()
        return img
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            navigation.reset()   // 닫혔다 열리면 항상 Home 으로 (설정 화면 잔류 방지)
            // LSUIElement 앱이 비활성이면 팝오버 내부 버튼 클릭이 무시됨 — show 전에 활성화 보장
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            Task { await updater.check() }   // 팝오버 열 때 재확인(내부 minInterval 디바운스)
        }
    }
}
