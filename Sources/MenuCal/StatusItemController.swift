import AppKit
import SwiftUI

extension Notification.Name {
    /// 달력에서 ← / → 키로 달 이동 (delta: Int in userInfo)
    static let menuCalMoveMonth = Notification.Name("MenuCalMoveMonth")
}

/// 두 줄 모드용 메뉴바 라벨 데이터
final class StatusLabelModel: ObservableObject {
    @Published var line1 = ""
    @Published var line2 = ""
}

/// 두 줄 모드용 메뉴바 라벨: VStack이라 세로 중앙 정렬이 구조적으로 보장된다
struct StatusItemLabel: View {
    @ObservedObject var model: StatusLabelModel

    var body: some View {
        VStack(spacing: -1) {
            Text(model.line1)
            Text(model.line2)
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// 클릭을 아래 NSStatusBarButton으로 통과시키는 호스팅 뷰
/// (버튼의 클릭 처리/하이라이트를 그대로 유지하기 위해)
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// 메뉴바 아이템 + 1초 타이머 + 팝오버를 관리하는 컨트롤러.
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let ticker = Ticker()
    private let cityStore = CityStore()
    private let settings = AppSettings()
    private let eventService: EventService
    private let labelModel = StatusLabelModel()
    private var twoLineHosting: NSHostingView<StatusItemLabel>?
    private var keyMonitor: Any?
    private var timer: Timer?
    private var lastPopoverClose = Date.distantPast
    private var lastFormat: String
    private var lastFormatLine2: String
    private var lastDay: DayKey

    override init() {
        eventService = EventService(lookaheadDays: settingsLookahead())
        lastFormat = ""
        lastFormatLine2 = ""
        lastDay = DayKey(date: Date(), calendar: Calendar.current)
        super.init()

        ClockFormatter.setMenuBarFormat(settings.menuBarFormat)
        ClockFormatter.setMenuBarFormatLine2(settings.menuBarFormatLine2)
        lastFormat = settings.menuBarFormat
        lastFormatLine2 = settings.menuBarFormatLine2

        if let button = statusItem.button {
            // monospaced digit: 매초 갱신돼도 너비가 흔들리지 않음 (Tahoe 호버 캡슐 펌핑 방지).
            // attributedTitle 대신 일반 title — 투명 메뉴바의 적응형(vibrant) 렌더링을 유지.
            let size = NSFont.menuBarFont(ofSize: 0).pointSize
            button.font = .monospacedDigitSystemFont(ofSize: size, weight: .regular)
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.delegate = self
        let hosting = NSHostingController(
            rootView: RootView()
                .environmentObject(ticker)
                .environmentObject(cityStore)
                .environmentObject(settings)
                .environmentObject(eventService)
        )
        hosting.sizingOptions = .preferredContentSize // SwiftUI 고유 크기를 팝오버가 따라감
        popover.contentViewController = hosting

        tick()
        startTimer()
        installKeyMonitor()

        // 잠자기 해제 → 타이머 재정렬 + 즉시 갱신
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(clockNeedsRealign),
            name: NSWorkspace.didWakeNotification, object: nil)
        // 수동 시간 변경
        NotificationCenter.default.addObserver(
            self, selector: #selector(clockNeedsRealign),
            name: .NSSystemClockDidChange, object: nil)
        // 시간대 변경
        NotificationCenter.default.addObserver(
            self, selector: #selector(timeZoneChanged),
            name: .NSSystemTimeZoneDidChange, object: nil)
    }

    // MARK: - 타이머

    private func startTimer() {
        timer?.invalidate()
        // 다음 정수 초에 정렬해서 시작 → 표시가 항상 초 경계에 맞음
        let nextSecond = Date(timeIntervalSinceReferenceDate:
            floor(Date().timeIntervalSinceReferenceDate) + 1)
        // 블록 API는 @Sendable이라 MainActor 상태에 접근 불가 → selector 기반 사용
        let t = Timer(fireAt: nextSecond, interval: 1, target: self,
                      selector: #selector(tick), userInfo: nil, repeats: true)
        t.tolerance = 0.05 // tolerance는 늦는 쪽만 허용되므로 표시 초는 항상 정확
        RunLoop.main.add(t, forMode: .common) // 메뉴/팝오버 추적 중에도 계속 틱
        timer = t
    }

    @objc private func tick() {
        let now = Date()

        // 설정 변경 폴링 (1Hz면 충분, Combine 격리 문제 회피)
        if settings.menuBarFormat != lastFormat {
            lastFormat = settings.menuBarFormat
            ClockFormatter.setMenuBarFormat(lastFormat)
        }
        if settings.menuBarFormatLine2 != lastFormatLine2 {
            lastFormatLine2 = settings.menuBarFormatLine2
            ClockFormatter.setMenuBarFormatLine2(lastFormatLine2)
        }

        // 자정 롤오버: 이벤트 재조회 → 넛지 확인 여부도 새 날짜 기준으로 갱신됨
        let today = DayKey(date: now, calendar: Calendar.current)
        if today != lastDay {
            lastDay = today
            eventService.refresh()
        }

        let nudge = nudgeActive(now: now) ? "🔔 " : ""
        if settings.twoLineMode {
            // 두 줄 모드: 커스텀 SwiftUI 뷰로 렌더 (attributedTitle은 위쪽 정렬돼 버림)
            setTwoLineInstalled(true)
            labelModel.line1 = nudge + ClockFormatter.menuBarTitle(now)
            labelModel.line2 = ClockFormatter.menuBarLine2String(now)
            updateTwoLineWidth()
        } else {
            setTwoLineInstalled(false)
            statusItem.button?.title = nudge + ClockFormatter.menuBarTitle(now)
        }
        ticker.now = now
    }

    // MARK: - 두 줄 모드 렌더링

    /// 폭 측정용 폰트 (StatusItemLabel의 11pt medium과 일치해야 함)
    private static let twoLineFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

    private func setTwoLineInstalled(_ installed: Bool) {
        guard let button = statusItem.button else { return }
        if installed {
            guard twoLineHosting == nil else { return }
            button.title = "" // 텍스트 렌더링은 호스팅 뷰가 담당
            let host = PassthroughHostingView(rootView: StatusItemLabel(model: labelModel))
            host.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                host.topAnchor.constraint(equalTo: button.topAnchor),
                host.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            twoLineHosting = host
        } else if let host = twoLineHosting {
            host.removeFromSuperview()
            twoLineHosting = nil
            statusItem.length = NSStatusItem.variableLength
        }
    }

    /// 빈 title이라 버튼 고유 폭이 0이 되므로, 텍스트 폭을 직접 재서 length를 지정
    private func updateTwoLineWidth() {
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.twoLineFont]
        let w1 = (labelModel.line1 as NSString).size(withAttributes: attrs).width
        let w2 = (labelModel.line2 as NSString).size(withAttributes: attrs).width
        let width = ceil(max(w1, w2)) + 6 // 좌우 여백 (최소한만 — 아이템 간 간격은 시스템이 따로 줌)
        if abs(statusItem.length - width) > 0.5 {
            statusItem.length = width
        }
    }

    /// 넛지: 다가오는 이벤트가 있고, 오늘 아직 확인 안 했으면 표시
    private func nudgeActive(now: Date) -> Bool {
        eventService.hasUpcoming && settings.lastNudgeAckDay != AppSettings.dayString(now)
    }

    @objc private func clockNeedsRealign() {
        startTimer()
        eventService.refresh()
        tick()
    }

    @objc private func timeZoneChanged() {
        ClockFormatter.refreshTimeZones()
        clockNeedsRealign()
    }

    // MARK: - 키보드 (달력 ← / → 월 이동)

    /// 팝오버가 열려 있을 때 ← / → 키를 가로채 달력의 달을 이동시킨다.
    /// 한 번만 설치하고 `popover.isShown`으로 게이팅 → 닫혀 있으면 그냥 통과.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            // ⌘/⌥/⌃/⇧ 수식키가 있으면 (예: ⌘Q) 가로채지 않음.
            // 방향키는 .function/.numericPad 플래그를 항상 달고 오므로 그건 무시해야 한다.
            let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.modifierFlags.intersection(modifiers).isEmpty else { return event }
            // 텍스트 편집 중이면 커서 이동에 양보 (설정 화면 입력 필드)
            if event.window?.firstResponder is NSTextView { return event }
            switch event.keyCode {
            case 123: // ←
                NotificationCenter.default.post(name: .menuCalMoveMonth, object: nil, userInfo: ["delta": -1])
                return nil // 이벤트 소비 → 비프음 방지
            case 124: // →
                NotificationCenter.default.post(name: .menuCalMoveMonth, object: nil, userInfo: ["delta": 1])
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - 팝오버

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if Date().timeIntervalSince(lastPopoverClose) > 0.2 {
            // transient 팝오버는 mouseDown에 닫히고 mouseUp 액션이 또 열 수 있음 → 재열림 가드
            guard let button = statusItem.button else { return }
            eventService.refresh() // 열 때 최신 이벤트로
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate() // 액세서리 앱: 검색 TextField가 키보드 포커스를 받도록
            // 팝오버 창을 key로 만들어 ← / → 등 키 입력을 바로 받도록 한다
            // (TextField가 없는 달력만 있을 땐 자동으로 key가 되지 않음)
            popover.contentViewController?.view.window?.makeKey()

            // 팝오버를 열어 이벤트를 봤으면 넛지 확인 처리 → 다음 자정에 리셋
            if nudgeActive(now: Date()) {
                settings.lastNudgeAckDay = AppSettings.dayString(Date())
                tick()
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        lastPopoverClose = Date()
    }
}

/// StatusItemController.init에서 settings 프로퍼티 초기화 전에 lookahead를 읽기 위한 헬퍼
private func settingsLookahead() -> Int {
    let days = UserDefaults.standard.integer(forKey: "lookaheadDays")
    return days == 0 ? 7 : days
}
