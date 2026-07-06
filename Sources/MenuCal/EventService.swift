import EventKit
import SwiftUI
import Combine

/// 팝오버·달력에 표시할 이벤트의 경량 스냅샷 (EKEvent는 non-Sendable이라 즉시 변환)
nonisolated struct DayEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let isAllDay: Bool
    let calendarTitle: String
    let color: Color
}

/// EventKit 래퍼: macOS 캘린더(구글 계정 연동 포함)에서 이벤트를 읽어온다.
/// Google 캘린더는 시스템 설정 > 인터넷 계정에 Google 계정을 추가하면 함께 보인다.
final class EventService: ObservableObject {
    enum AuthState {
        case notDetermined // 아직 권한 요청 안 함
        case denied        // 거부됨/제한됨
        case authorized    // 전체 접근
    }

    @Published private(set) var authState: AuthState = .notDetermined
    @Published private(set) var upcoming: [DayEvent] = []       // lookahead 윈도우 내 전체, 시간순 — "다가오는 이벤트"용
    @Published private(set) var byDay: [DayKey: [DayEvent]] = [:] // 달력 점/날짜 상세용 — lookahead와 독립, 과거·먼 미래도 포함

    private let store = EKEventStore()
    private var lookaheadDays: Int
    private let cal = Calendar.current
    /// byDay를 읽을 기준 달(달력이 현재 표시 중인 달). 이 달 앞뒤로 넉넉히 로드한다.
    private var calendarAnchor = Calendar.current.startOfDay(for: Date())

    init(lookaheadDays: Int) {
        self.lookaheadDays = lookaheadDays
        refreshAuthState()
        if authState == .authorized { refresh() }

        // 캘린더 DB 변경(추가/수정/동기화) 시 자동 갱신
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .EKEventStoreChanged, object: store)
    }

    var hasUpcoming: Bool { !upcoming.isEmpty }

    func refreshAuthState() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: authState = .authorized
        case .notDetermined: authState = .notDetermined
        default: authState = .denied
        }
    }

    /// 최초 연동 버튼에서 호출 — 시스템 권한 대화상자 표시
    func requestAccess() {
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                authState = granted ? .authorized : .denied
                if granted { refresh() }
            } catch {
                authState = .denied
            }
        }
    }

    func setLookahead(_ days: Int) {
        lookaheadDays = max(1, days)
        refresh()
    }

    @objc private func storeChanged() {
        refresh()
    }

    /// "다가오는 이벤트" 목록과 달력 점/상세를 모두 다시 읽는다.
    func refresh() {
        refreshUpcoming()
        refreshCalendar()
    }

    /// 달력이 표시하는 달이 바뀌면 호출 — 그 달 주변 이벤트를 다시 읽어 점/상세를 채운다.
    /// (lookahead 윈도우와 무관하므로 과거·먼 미래 달로 이동해도 항상 표시된다)
    func focusCalendar(on month: Date) {
        calendarAnchor = month
        refreshCalendar()
    }

    /// [오늘 0시, +lookaheadDays) 윈도우 — "다가오는 이벤트" 목록/넛지용
    private func refreshUpcoming() {
        guard authState == .authorized else { return }
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: lookaheadDays, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        upcoming = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(Self.snapshot)
    }

    /// 표시 중인 달 앞뒤 ±2개월 윈도우 — 달력 점/날짜 상세용.
    /// lookahead와 독립이라, 어제·과거·먼 미래도 그 달을 보면 항상 점/상세가 뜬다.
    private func refreshCalendar() {
        guard authState == .authorized else { return }
        guard let start = cal.date(byAdding: .month, value: -2, to: calendarAnchor),
              let end = cal.date(byAdding: .month, value: 2, to: calendarAnchor) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var grouped: [DayKey: [DayEvent]] = [:]
        for e in store.events(matching: predicate) {
            grouped[DayKey(date: e.startDate, calendar: cal), default: []].append(Self.snapshot(e))
        }
        for k in grouped.keys {
            grouped[k]?.sort { $0.start < $1.start } // 각 날짜 내 시간순
        }
        byDay = grouped
    }

    /// EKEvent(non-Sendable)를 경량 스냅샷으로 변환
    private static func snapshot(_ e: EKEvent) -> DayEvent {
        let color: Color
        if let c = e.calendar, let ns = c.color {
            color = Color(nsColor: ns)
        } else {
            color = .accentColor
        }
        // 반복 이벤트는 eventIdentifier가 같으므로 발생 시각을 붙여 유일화
        return DayEvent(
            id: (e.eventIdentifier ?? UUID().uuidString) + "@\(e.startDate.timeIntervalSince1970)",
            title: e.title ?? "(제목 없음)",
            start: e.startDate,
            isAllDay: e.isAllDay,
            calendarTitle: e.calendar?.title ?? "",
            color: color
        )
    }

    /// 시스템 설정의 캘린더 개인정보 보호 화면 열기 (거부 상태 안내용)
    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
