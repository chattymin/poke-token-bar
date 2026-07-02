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
    private var menuSpriteKey: String?   // "id-shiny" — 같은 종이라도 shiny 여부가 바뀌면 재로딩
    private var menuFrames: [(image: NSImage, delay: TimeInterval)] = []
    private var menuIndex = 0
    private var menuTimer: Timer?
    private var menuLoadGen = 0     // async 로드 경합 방지
    private var displayAwake = true     // 디스플레이 켜짐 여부 (꺼지면 메뉴 애니메이션 정지 — 배터리)

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
        observeDisplaySleep()
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
        syncMenuAnimation()   // 가시성 상태 주기적 재평가(occlusion 이 잘못 멈춰도 자가 복구)
    }

    /// UsageStore 값 → CompanionStore (사용량 적립 + 표시 상태). 매 관찰 변경 시 호출.
    private func updateCompanion() {
        companion.update(
            todayTokens: store.todayTotalTokens,
            todayDate: LocalUsageReader.todayKey(),
            monthTotal: store.monthTotalTokens,
            burnTier: store.burnTier,
            limitWarning: store.isLimitWarning,
            hasUsageData: store.hasUsageData)
    }

    // MARK: 메뉴바 애니메이션

    /// 현재 포켓몬에 맞춰 메뉴바 프레임을 준비. 종이 바뀐 경우에만 재로딩.
    /// 정적 스프라이트로 먼저 보여주고, animated GIF 가 받아지면 교체한다(메뉴바도 GIF로 움직임).
    /// 에너지 통제는 ① delay 하한 0.2s(≈5fps) ② 안 보이면 정지(menuShouldAnimate) ③ 저전력 모드
    /// 에선 GIF 생략(가벼운 bob)로 처리한다 — 통제된 저프레임 + 비가시 시 정지로 저전력.
    private func ensureMenuAnimation(forceRebuild: Bool = false) {
        let id = companion.currentSpeciesID
        let shiny = companion.currentIsShiny
        let key = id.map { "\($0)-\(shiny)" }
        if !forceRebuild, key == menuSpriteKey, !menuFrames.isEmpty { return }   // 이미 이 개체로 애니메이션 중
        menuSpriteKey = key
        menuLoadGen += 1
        let gen = menuLoadGen

        guard let id else {                  // 알: 2프레임 bob
            setMenuFrames(Self.eggFrames())
            return
        }
        // 정적 스프라이트 bob 을 먼저(없으면 받아와서). GIF 가 받아지면 아래에서 교체.
        if let cached = SpriteLoader.cachedImage(speciesID: id, shiny: shiny) {
            setMenuFrames(Self.bobFrames(from: cached))
        } else {
            setMenuFrames(Self.eggFrames())
            Task { @MainActor [weak self] in
                guard let self, gen == self.menuLoadGen,
                      let sprite = await SpriteLoader.image(speciesID: id, shiny: shiny) else { return }
                guard gen == self.menuLoadGen else { return }
                self.setMenuFrames(Self.bobFrames(from: sprite))
            }
        }

        // 풀 GIF 애니메이션(저전력 모드에서는 생략하고 bob 유지). delay 하한 0.1s(≤10fps)로 redraw 통제.
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        Task { @MainActor [weak self] in
            guard let self, gen == self.menuLoadGen else { return }
            // shiny GIF 미제공 종이면 일반 GIF 폴백
            var data = await SpriteStore.shared.data(speciesID: id, animated: true, shiny: shiny)
            if data == nil, shiny {
                data = await SpriteStore.shared.data(speciesID: id, animated: true, shiny: false)
            }
            guard let data else { return }
            let raw = GIFDecoder.frames(from: data)
            guard raw.count > 1, gen == self.menuLoadGen else { return }
            // 메뉴바 GIF 는 delay 하한 0.2s(≈5fps)로 캡 — 22px 스프라이트엔 충분하고 저전력.
            self.setMenuFrames(raw.map { (Self.menuBarImage(from: $0.image, up: false), max(0.2, $0.delay)) })
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
        menuTimer = nil
        guard !menuFrames.isEmpty else { return }
        let frame = menuFrames[menuIndex % menuFrames.count]
        statusItem.button?.image = frame.image   // 현재 프레임은 항상 반영(정지 중에도 올바른 스프라이트)
        // 화면 꺼짐/메뉴바 가림(occlusion) 또는 단일 프레임이면 다음 프레임 예약 안 함 → 정지(낭비 제거).
        guard menuShouldAnimate, menuFrames.count > 1 else { return }
        let timer = Timer(timeInterval: frame.delay, repeats: false) { [weak self] _ in
            // 메인 런루프에서 발화 → Task 없이 동기 처리(프레임당 Task 할당 제거, 배터리)
            MainActor.assumeIsolated {
                guard let self else { return }
                self.menuIndex = (self.menuIndex + 1) % self.menuFrames.count
                self.advanceMenu()
            }
        }
        timer.tolerance = frame.delay * 0.3   // 웨이크업 코얼레싱 (배터리)
        RunLoop.main.add(timer, forMode: .common)
        menuTimer = timer
    }

    /// 메뉴바가 실제로 보이고(occlusion) 화면이 켜져 있을 때만 애니메이션 — 안 보이면 정지(낭비 제거).
    private var menuShouldAnimate: Bool {
        displayAwake && (statusItem.button?.window?.occlusionState.contains(.visible) ?? true)
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

    // MARK: 디스플레이 / 메뉴바 가시성 (에너지 절약 — 안 보이면 애니메이션 정지)

    private func observeDisplaySleep() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setDisplayAwake(false) }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setDisplayAwake(true) }
        }
        // 메뉴바가 가려지면(풀스크린 등으로 occlusion) 애니메이션 정지, 다시 보이면 재개.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncMenuAnimation() }
        }
    }

    private func setDisplayAwake(_ awake: Bool) {
        displayAwake = awake
        syncMenuAnimation()
    }

    /// menuShouldAnimate 상태에 맞춰 애니메이션을 재개/정지한다(멱등 — 중복 호출 안전).
    private func syncMenuAnimation() {
        if menuShouldAnimate {
            if menuTimer == nil { advanceMenu() }   // 재개
        } else {
            menuTimer?.invalidate()
            menuTimer = nil
        }
    }
}
