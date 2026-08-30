import SwiftUI

/// 달력 한 칸. `isCurrentMonth`가 false면 첫 주/마지막 주 빈칸을 메운 이전·다음 달 날짜다.
nonisolated struct GridDay: Hashable {
    let key: DayKey
    let isCurrentMonth: Bool
}

/// 월 달력 그리드: ◀ ▶ 월 이동, 오늘 버튼, 일=빨강/토=파랑, 오늘 하이라이트,
/// 공휴일 빨간날 + 이벤트 점, 날짜 클릭 시 아래 상세 영역에 공휴일 이름/일정 표시.
struct CalendarView: View {
    @EnvironmentObject private var ticker: Ticker
    @EnvironmentObject private var eventService: EventService
    @EnvironmentObject private var settings: AppSettings
    @State private var displayedMonth: Date = CalendarView.firstOfMonth(Date())
    @State private var selectedDay: DayKey?

    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ko_KR")
        c.firstWeekday = 1 // 일요일 시작
        return c
    }()

    private static let columns = Array(repeating: GridItem(.fixed(32), spacing: 0), count: 7)

    var body: some View {
        let todayKey = DayKey(date: ticker.now, calendar: Self.cal)
        let cells = Self.monthCells(for: displayedMonth, calendar: Self.cal,
                                    fillAdjacent: settings.fillAdjacentMonths)
        let holidays = Self.holidays(covering: cells, selected: selectedDay)

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
                    dayCell(cell: cells[i], column: i % 7,
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
            // ← ↑ / → ↓ 키로 달 이동 (StatusItemController의 keyDown 모니터가 발신)
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
    private func dayCell(cell: GridDay?, column: Int,
                         holidays: [DayKey: String], todayKey: DayKey) -> some View {
        if let cell {
            let key = cell.key
            let day = key.day
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
                        .foregroundStyle(textColor(isToday: isToday, isHoliday: holidayName != nil,
                                                   column: column, isCurrentMonth: cell.isCurrentMonth))
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

    private func textColor(isToday: Bool, isHoliday: Bool, column: Int, isCurrentMonth: Bool) -> Color {
        if isToday { return .white }
        if !isCurrentMonth { return .primary.opacity(0.25) } // 이전/다음 달 채움 칸은 짙은 회색
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

    /// 6주(42칸) 격자. `fillAdjacent`면 1일이 있는 행의 앞 빈칸을 이전 달 말일들로,
    /// 말일이 있는 행의 뒤 빈칸을 다음 달 1일부터로 메운다. 그 뒤 남는 행은 계속 비워 둔다.
    static func monthCells(for monthDate: Date, calendar: Calendar, fillAdjacent: Bool) -> [GridDay?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthDate),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            return Array(repeating: nil, count: 42)
        }
        let first = interval.start
        let year = calendar.component(.year, from: first)
        let month = calendar.component(.month, from: first)
        let firstWeekday = calendar.component(.weekday, from: first) // 1=일 ... 7=토
        let blanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [GridDay?] = Array(repeating: nil, count: blanks)
        cells += dayRange.map { GridDay(key: DayKey(year: year, month: month, day: $0), isCurrentMonth: true) }
        let filled = cells.count
        let lastRowEnd = (filled + 6) / 7 * 7 // 말일이 있는 행의 끝
        cells += Array(repeating: nil, count: 42 - filled)
        guard fillAdjacent else { return cells }

        if blanks > 0,
           let prev = calendar.date(byAdding: .month, value: -1, to: first),
           let prevRange = calendar.range(of: .day, in: .month, for: prev) {
            let py = calendar.component(.year, from: prev)
            let pm = calendar.component(.month, from: prev)
            for i in 0..<blanks {
                cells[i] = GridDay(key: DayKey(year: py, month: pm, day: prevRange.upperBound - blanks + i),
                                   isCurrentMonth: false)
            }
        }
        if lastRowEnd > filled, let next = calendar.date(byAdding: .month, value: 1, to: first) {
            let ny = calendar.component(.year, from: next)
            let nm = calendar.component(.month, from: next)
            for i in filled..<lastRowEnd {
                cells[i] = GridDay(key: DayKey(year: ny, month: nm, day: i - filled + 1),
                                   isCurrentMonth: false)
            }
        }
        return cells
    }

    /// 격자에 걸친 연도(12월↔1월 채움이면 두 해) + 선택 날짜의 연도까지 공휴일을 합친다.
    private static func holidays(covering cells: [GridDay?], selected: DayKey?) -> [DayKey: String] {
        var years = Set(cells.compactMap { $0?.key.year })
        if let selected { years.insert(selected.year) }
        guard years.count > 1 else {
            return years.first.map { HolidayProvider.holidays(inYear: $0) } ?? [:]
        }
        var merged: [DayKey: String] = [:]
        for y in years { merged.merge(HolidayProvider.holidays(inYear: y)) { a, _ in a } }
        return merged
    }
}
