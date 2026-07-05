import SwiftUI

/// 다가오는 이벤트 섹션: 연동 상태별 UI + 이벤트 목록.
struct UpcomingEventsView: View {
    @EnvironmentObject private var ticker: Ticker
    @EnvironmentObject private var eventService: EventService
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("다가오는 이벤트")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if eventService.authState == .authorized {
                    Text("\(settings.lookaheadDays)일")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            switch eventService.authState {
            case .notDetermined:
                VStack(alignment: .leading, spacing: 4) {
                    Button("캘린더 연동하기") { eventService.requestAccess() }
                        .font(.caption)
                    Text("Google 캘린더는 시스템 설정 > 인터넷 계정에\nGoogle 계정을 추가하면 함께 표시됩니다.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

            case .denied:
                VStack(alignment: .leading, spacing: 4) {
                    Text("캘린더 접근이 거부되어 있어요.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("개인정보 보호 설정 열기") { EventService.openPrivacySettings() }
                        .font(.caption)
                }

            case .authorized:
                if eventService.upcoming.isEmpty {
                    Text("\(settings.lookaheadDays)일 내 일정 없음")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 2)
                } else {
                    eventList
                }
            }
        }
    }

    private var eventList: some View {
        let todayKey = DayKey(date: ticker.now, calendar: Calendar.current)
        let rows = eventService.upcoming.prefix(12)

        return ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(rows)) { ev in
                    HStack(spacing: 6) {
                        Circle().fill(ev.color).frame(width: 5, height: 5)
                        Text(relativeDayLabel(ev.start, todayKey: todayKey))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        Text(ev.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(ev.isAllDay ? "" : ClockFormatter.cityTimeString(ev.start, timeZone: .current))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxHeight: 110)
    }

    /// "오늘" / "내일" / "7/8(수)"
    private func relativeDayLabel(_ date: Date, todayKey: DayKey) -> String {
        let cal = Calendar.current
        let key = DayKey(date: date, calendar: cal)
        if key == todayKey { return "오늘" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ticker.now)),
           key == DayKey(date: tomorrow, calendar: cal) {
            return "내일"
        }
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekday = symbols[cal.component(.weekday, from: date) - 1]
        return "\(key.month)/\(key.day)(\(weekday))"
    }
}
