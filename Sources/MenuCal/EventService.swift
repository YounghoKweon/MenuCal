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
    @Published private(set) var upcoming: [DayEvent] = []       // 윈도우 내 전체, 시간순
    @Published private(set) var byDay: [DayKey: [DayEvent]] = [:] // 달력 점 표시용

    private let store = EKEventStore()
    private var lookaheadDays: Int
    private let cal = Calendar.current

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

    /// [오늘 0시, +lookaheadDays) 윈도우의 이벤트를 다시 읽는다
    func refresh() {
        guard authState == .authorized else { return }
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: lookaheadDays, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var list: [DayEvent] = []
        var grouped: [DayKey: [DayEvent]] = [:]
        for e in events {
            let color: Color
            if let c = e.calendar, let ns = c.color {
                color = Color(nsColor: ns)
            } else {
                color = .accentColor
            }
            // 반복 이벤트는 eventIdentifier가 같으므로 발생 시각을 붙여 유일화
            let ev = DayEvent(
                id: (e.eventIdentifier ?? UUID().uuidString) + "@\(e.startDate.timeIntervalSince1970)",
                title: e.title ?? "(제목 없음)",
                start: e.startDate,
                isAllDay: e.isAllDay,
                calendarTitle: e.calendar?.title ?? "",
                color: color
            )
            list.append(ev)
            grouped[DayKey(date: e.startDate, calendar: cal), default: []].append(ev)
        }
        upcoming = list
        byDay = grouped
    }

    /// 시스템 설정의 캘린더 개인정보 보호 화면 열기 (거부 상태 안내용)
    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
