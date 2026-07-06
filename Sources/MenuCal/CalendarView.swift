import SwiftUI

/// 월 달력 그리드: ◀ ▶ 월 이동, 오늘 버튼, 일=빨강/토=파랑, 오늘 하이라이트,
/// 공휴일 빨간날 + 이벤트 점, 날짜 클릭 시 아래 상세 영역에 공휴일 이름/일정 표시.
struct CalendarView: View {
    @EnvironmentObject private var ticker: Ticker
    @EnvironmentObject private var eventService: EventService
    @EnvironmentObject private var settings: AppSettings
    @State private var displayedMonth: Date = CalendarView.firstOfMonth(Date())
    @State private var selectedDay: DayKey?

    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ko_KR")
        c.firstWeekday = 1 // 일요일 시작
        return c
    }()

    private static let columns = Array(repeating: GridItem(.fixed(32), spacing: 0), count: 7)

    var body: some View {
        let year = Self.cal.component(.year, from: displayedMonth)
        let month = Self.cal.component(.month, from: displayedMonth)
        let holidays = HolidayProvider.holidays(inYear: year)
        let todayKey = DayKey(date: ticker.now, calendar: Self.cal)
        let cells = Self.monthCells(for: displayedMonth, calendar: Self.cal)

        VStack(spacing: 6) {
            header

            LazyVGrid(columns: Self.columns, spacing: 1) {
                // 요일 헤더
                ForEach(Array("일월화수목금토".enumerated()), id: \.offset) { index, ch in
                    Text(String(ch))
                        .font(.caption2)
                        .foregroundStyle(index == 0 ? Color.red.opacity(0.75)
                                       : index == 6 ? Color.blue.opacity(0.75)
                                       : Color.secondary)
                }
                // 항상 42셀(6주) — 월 이동 시 팝오버 높이가 튀지 않게
                ForEach(0..<42, id: \.self) { i in
                    dayCell(day: cells[i], column: i % 7,
                            year: year, month: month,
                            holidays: holidays, todayKey: todayKey)
                }
            }

            detailArea(holidays: holidays, todayKey: todayKey)
        }
        .onAppear {
            // 최초 표시 때만 오늘로 세팅 (마지막 본 달 유지 모드여도 첫 오픈엔 기준점 필요).
            // 재오픈은 지속 호스팅 뷰라 onAppear가 다시 안 뜨므로 아래 알림으로 처리한다.
            if selectedDay == nil { resetToToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuCalPopoverDidOpen)) { _ in
            // 팝오버가 열릴 때마다: 설정이 "항상 오늘"이면 오늘 달로 복귀, 아니면 보던 달 유지
            if settings.calendarOpensToToday { resetToToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuCalMoveMonth)) { note in
            // ← / → 키로 달 이동 (StatusItemController의 keyDown 모니터가 발신)
            moveMonth(note.userInfo?["delta"] as? Int ?? 0)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(ClockFormatter.monthTitle(displayedMonth))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            monthButton("chevron.left", delta: -1, help: "이전 달")
            Button("오늘") { resetToToday() }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            monthButton("chevron.right", delta: 1, help: "다음 달")
        }
        .padding(.horizontal, 2)
    }

    /// 이전/다음 달 이동 버튼 — 넉넉한 히트 영역으로 클릭하기 쉽게.
    private func monthButton(_ systemName: String, delta: Int, help: String) -> some View {
        Button { moveMonth(delta) } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 26)   // 넉넉한 클릭 히트 영역
                .contentShape(Rectangle())       // 빈 픽셀까지 클릭 가능
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    // MARK: - 날짜 셀

    @ViewBuilder
    private func dayCell(day: Int?, column: Int, year: Int, month: Int,
                         holidays: [DayKey: String], todayKey: DayKey) -> some View {
        if let day {
            let key = DayKey(year: year, month: month, day: day)
            let holidayName = holidays[key]
            let isToday = key == todayKey
            let isSelected = key == selectedDay
            let dayEvents = eventService.byDay[key] ?? []
            let lunar = Self.lunarLabel(for: key)

            VStack(spacing: 1) {
                // 이벤트 점 (캘린더 색상, 최대 3개) — 날짜 위에 두어 눈에 잘 띄게, 없어도 자리 유지
                HStack(spacing: 2) {
                    ForEach(Array(dayEvents.prefix(3).enumerated()), id: \.offset) { _, ev in
                        Circle().fill(ev.color).frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 4)

                ZStack {
                    if isToday {
                        Circle().fill(Color.accentColor).frame(width: 21, height: 21)
                    } else if isSelected {
                        Circle().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1.2)
                            .frame(width: 21, height: 21)
                    }
                    Text("\(day)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(textColor(isToday: isToday, isHoliday: holidayName != nil, column: column))
                }
                .frame(height: 22)

                // 음력 (5의 배수일만) — 작고 흐리게, 날짜에 바짝 붙여서, 없어도 자리 유지
                Text(lunar ?? " ")
                    .font(.system(size: 7))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(height: 8)
                    .padding(.top, -3)
            }
            .frame(width: 32, height: 38)
            .contentShape(Rectangle()) // 빈 픽셀까지 클릭/호버 히트 영역
            .onTapGesture { selectedDay = key }
            .help(holidayName ?? (dayEvents.isEmpty ? "" : "\(dayEvents.count)개 일정"))
        } else {
            Color.clear.frame(width: 32, height: 38)
        }
    }

    private func textColor(isToday: Bool, isHoliday: Bool, column: Int) -> Color {
        if isToday { return .white }
        if isHoliday || column == 0 { return .red }
        if column == 6 { return .blue }
        return .primary
    }

    // MARK: - 선택 날짜 상세 (툴팁 대신 항상 보이는 영역)

    @ViewBuilder
    private func detailArea(holidays: [DayKey: String], todayKey: DayKey) -> some View {
        let key = selectedDay ?? todayKey
        let holidayName = holidays[key]
        let dayEvents = eventService.byDay[key] ?? []

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(dayLabel(key, todayKey: todayKey))
                    .font(.caption.weight(.semibold))
                if let holidayName {
                    Text(holidayName)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            if dayEvents.isEmpty {
                if holidayName == nil {
                    Text("일정 없음")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                ForEach(dayEvents.prefix(4)) { ev in
                    HStack(spacing: 5) {
                        Circle().fill(ev.color).frame(width: 5, height: 5)
                        Text(ev.title)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(ev.isAllDay ? "하루 종일" : ClockFormatter.cityTimeString(ev.start, timeZone: .current))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if dayEvents.count > 4 {
                    Text("외 \(dayEvents.count - 4)건")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
    }

    /// 상세 영역의 날짜 라벨: "오늘 7/5(일)" / "7/8(수)"
    private func dayLabel(_ key: DayKey, todayKey: DayKey) -> String {
        let prefix = key == todayKey ? "오늘 " : ""
        guard let date = Self.cal.date(from: DateComponents(year: key.year, month: key.month, day: key.day)) else {
            return "\(prefix)\(key.month)/\(key.day)"
        }
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let weekday = symbols[Self.cal.component(.weekday, from: date) - 1]
        return "\(prefix)\(key.month)/\(key.day)(\(weekday))"
    }

    // MARK: - 날짜 계산

    private static func firstOfMonth(_ date: Date) -> Date {
        cal.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func moveMonth(_ delta: Int) {
        // 항상 1일 기준으로 이동 → 31일 클램핑 문제 없음
        displayedMonth = Self.cal.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
        // 이동한 달 주변 이벤트를 다시 로드해 점/상세가 항상 뜨도록
        eventService.focusCalendar(on: displayedMonth)
    }

    /// 현재 달 + 오늘 선택으로 복귀하고 그 달 이벤트를 로드
    private func resetToToday() {
        displayedMonth = Self.firstOfMonth(ticker.now)
        selectedDay = DayKey(date: ticker.now, calendar: Self.cal)
        eventService.focusCalendar(on: displayedMonth)
    }

    /// 음력 "월.일" (윤달은 "윤" 접두). 5의 배수일(5·10·15·20·25·30)만 반환, 그 외엔 nil.
    private static func lunarLabel(for key: DayKey) -> String? {
        guard let l = HolidayProvider.lunar(for: key), l.day % 5 == 0 else { return nil }
        return "\(l.isLeap ? "윤" : "")\(l.month).\(l.day)"
    }

    private static func monthCells(for monthDate: Date, calendar: Calendar) -> [Int?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthDate),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            return Array(repeating: nil, count: 42)
        }
        let firstWeekday = calendar.component(.weekday, from: interval.start) // 1=일 ... 7=토
        let blanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: blanks)
        cells += dayRange.map { Optional($0) }
        cells += Array(repeating: nil, count: 42 - cells.count)
        return cells
    }
}
