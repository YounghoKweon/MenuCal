import Foundation
import Combine

/// 사용자 설정 (UserDefaults 영속).
final class AppSettings: ObservableObject {
    static let defaultFormat = "M/d(E) HH:mm:ss"

    static let defaultLine1TwoLine = "M/d(E)"
    static let defaultLine2 = "HH:mm:ss"

    /// 메뉴바 날짜/시간 형식 (Unicode date format pattern). 두 줄 모드에선 윗줄.
    @Published var menuBarFormat: String {
        didSet { UserDefaults.standard.set(menuBarFormat, forKey: "menuBarFormat") }
    }

    /// 두 줄 표시 (메뉴바 폭 간소화: 윗줄 날짜 / 아랫줄 시간)
    @Published var twoLineMode: Bool {
        didSet { UserDefaults.standard.set(twoLineMode, forKey: "twoLineMode") }
    }

    /// 두 줄 모드의 아랫줄 형식
    @Published var menuBarFormatLine2: String {
        didSet { UserDefaults.standard.set(menuBarFormatLine2, forKey: "menuBarFormatLine2") }
    }

    /// 다가오는 이벤트 표시 기간 (일)
    @Published var lookaheadDays: Int {
        didSet { UserDefaults.standard.set(lookaheadDays, forKey: "lookaheadDays") }
    }

    /// 넛지를 마지막으로 확인한 날 ("yyyy-MM-dd"). 자정이 지나면 값이 달라져 넛지가 되살아난다.
    @Published var lastNudgeAckDay: String {
        didSet { UserDefaults.standard.set(lastNudgeAckDay, forKey: "lastNudgeAckDay") }
    }

    init() {
        let d = UserDefaults.standard
        menuBarFormat = d.string(forKey: "menuBarFormat") ?? Self.defaultFormat
        twoLineMode = d.bool(forKey: "twoLineMode")
        menuBarFormatLine2 = d.string(forKey: "menuBarFormatLine2") ?? Self.defaultLine2
        let days = d.integer(forKey: "lookaheadDays")
        lookaheadDays = days == 0 ? 7 : days
        lastNudgeAckDay = d.string(forKey: "lastNudgeAckDay") ?? ""
    }

    /// 오늘 날짜 문자열 ("yyyy-MM-dd") — 넛지 확인 기록용
    static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
