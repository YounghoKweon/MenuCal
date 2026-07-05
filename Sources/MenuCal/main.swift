import AppKit

// MARK: - 디버그 CLI (터미널에서 동작 검증용, 앱 실행과 무관)
// .build/debug/MenuCal --print-holidays 2026  → 해당 연도 공휴일 목록 출력 후 종료
// .build/debug/MenuCal --print-title          → 현재 메뉴바 타이틀 문자열 출력 후 종료
let cliArgs = CommandLine.arguments
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

// MARK: - 앱 부트스트랩

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // 독 아이콘 없음 — 번들 없이 실행해도 적용
app.run()
