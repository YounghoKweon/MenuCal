import AppKit

// MARK: - 디버그 CLI (터미널에서 동작 검증용, 앱 실행과 무관)
// .build/debug/MenuCal --print-holidays 2026  → 해당 연도 공휴일 목록 출력 후 종료
// .build/debug/MenuCal --print-title          → 현재 메뉴바 타이틀 문자열 출력 후 종료
// .build/debug/MenuCal --print-clocks         → 프리셋 도시별 현재 시각 / 날짜 배지 / 서머타임 출력 후 종료
// .build/debug/MenuCal --print-month 2026-08  → 달력 6주 격자 출력 후 종료 (이전/다음 달 채움 칸은 괄호)
let cliArgs = CommandLine.arguments
if let idx = cliArgs.firstIndex(of: "--print-month"), idx + 1 < cliArgs.count {
    let parts = cliArgs[idx + 1].split(separator: "-").compactMap { Int($0) }
    let fill = !cliArgs.contains("--no-fill")
    guard parts.count == 2,
          let month = CalendarView.cal.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)) else {
        print("사용법: --print-month YYYY-MM [--no-fill]")
        exit(1)
    }
    let cells = CalendarView.monthCells(for: month, calendar: CalendarView.cal, fillAdjacent: fill)
    print("일    월    화    수    목    금    토")
    for row in 0..<6 {
        let line = (0..<7).map { col -> String in
            guard let c = cells[row * 7 + col] else { return "    " }
            let year = c.key.year == parts[0] ? "" : "\(c.key.year)/" // 해가 넘어간 채움 칸만 연도 표기
            let label = c.isCurrentMonth ? "\(c.key.day)" : "(\(year)\(c.key.month)/\(c.key.day))"
            return label.padding(toLength: max(4, label.count), withPad: " ", startingAt: 0)
        }
        print(line.joined(separator: " "))
    }
    exit(0)
}
if let idx = cliArgs.firstIndex(of: "--print-holidays"), idx + 1 < cliArgs.count, let year = Int(cliArgs[idx + 1]) {
    let holidays = HolidayProvider.holidays(inYear: year)
    let sorted = holidays.keys.sorted { ($0.month, $0.day) < ($1.month, $1.day) }
    for key in sorted {
        let weekday = HolidayProvider.weekdaySymbol(of: key)
        print(String(format: "%04d-%02d-%02d(%@) %@", key.year, key.month, key.day, weekday, holidays[key] ?? ""))
    }
    exit(0)
}
if cliArgs.contains("--print-title") {
    print(ClockFormatter.menuBarTitle(Date()))
    exit(0)
}
if cliArgs.contains("--print-clocks") {
    let now = Date()
    for city in CityStore.presets {
        guard let tz = city.timeZone else { continue }
        let day = ClockFormatter.dayOffsetLabel(ClockFormatter.dayOffset(remote: tz, now: now)) ?? ""
        let dst = ClockFormatter.dstDescription(tz, now: now) ?? ""
        print("\(city.name)\t\(ClockFormatter.cityClockString(now, timeZone: tz))\t\(day)\t\(dst)")
    }
    exit(0)
}

// MARK: - 앱 부트스트랩

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController()
    }
}

// 툴팁 표시 지연 단축. AppKit 기본값은 2초대라 팝오버를 잠깐 띄웠다 닫는 사용 패턴에선 사실상 안 뜬다.
// register라 사용자가 defaults로 덮어쓸 수 있고, 이 앱 안에서만 적용된다.
UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 500])

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // 독 아이콘 없음 — 번들 없이 실행해도 적용
app.run()
