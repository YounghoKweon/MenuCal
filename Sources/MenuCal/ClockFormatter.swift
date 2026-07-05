import Foundation
import Combine

/// 메뉴바·팝오버가 같은 틱에 동기화되도록 하는 공유 "현재 시각".
/// StatusItemController의 1초 타이머가 갱신한다.
final class Ticker: ObservableObject {
    @Published var now = Date()
}

/// DateFormatter 캐시 + 시간대 간 날짜차 계산.
/// (모듈 기본 격리가 @MainActor라서 non-Sendable인 DateFormatter를 안전하게 공유)
enum ClockFormatter {

    private static let koLocale = Locale(identifier: "ko_KR")

    /// 메뉴바 타이틀: "7/5(일) 14:23:45" (형식은 설정에서 변경 가능)
    private static let menuBar: DateFormatter = {
        let f = DateFormatter()
        f.locale = koLocale
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = AppSettings.defaultFormat
        return f
    }()

    /// 두 줄 모드의 아랫줄 (예: "14:23:45")
    private static let menuBarLine2: DateFormatter = {
        let f = DateFormatter()
        f.locale = koLocale
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = AppSettings.defaultLine2
        return f
    }()

    /// 사용자 형식 적용 (빈 문자열이면 기본값으로 폴백)
    static func setMenuBarFormat(_ format: String) {
        let trimmed = format.trimmingCharacters(in: .whitespaces)
        menuBar.dateFormat = trimmed.isEmpty ? AppSettings.defaultFormat : trimmed
    }

    static func setMenuBarFormatLine2(_ format: String) {
        let trimmed = format.trimmingCharacters(in: .whitespaces)
        menuBarLine2.dateFormat = trimmed.isEmpty ? AppSettings.defaultLine2 : trimmed
    }

    static func menuBarLine2String(_ date: Date) -> String {
        menuBarLine2.string(from: date)
    }

    /// 세계시계 행: "14:23"
    private static let cityTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = koLocale
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "HH:mm"
        return f
    }()

    /// 달력 헤더: "2026년 7월"
    private static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = koLocale
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy년 M월"
        return f
    }()

    static func menuBarTitle(_ date: Date) -> String {
        menuBar.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        monthTitle.string(from: date)
    }

    static func cityTimeString(_ date: Date, timeZone: TimeZone) -> String {
        cityTime.timeZone = timeZone
        return cityTime.string(from: date)
    }

    /// 시스템 시간대 변경 시 호출 — 캐시된 포매터의 시간대를 현재로 재설정
    static func refreshTimeZones() {
        NSTimeZone.resetSystemTimeZone()
        menuBar.timeZone = .current
        menuBarLine2.timeZone = .current
        monthTitle.timeZone = .current
    }

    /// 같은 순간을 두 시간대에서 봤을 때의 달력 날짜 차이 (일 단위).
    /// 0 = 같은 날, -1 = 어제, +1 = 내일
    static func dayOffset(remote: TimeZone, now: Date) -> Int {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        var remoteCal = local
        remoteCal.timeZone = remote
        let l = local.dateComponents([.year, .month, .day], from: now)
        let r = remoteCal.dateComponents([.year, .month, .day], from: now)
        // 두 Y/M/D를 "같은" 달력으로 실체화한 뒤 일수 차이를 구한다
        guard let ld = local.date(from: l), let rd = local.date(from: r) else { return 0 }
        return local.dateComponents([.day], from: ld, to: rd).day ?? 0
    }

    static func dayOffsetLabel(_ offset: Int) -> String? {
        switch offset {
        case 0: return nil
        case -1: return "어제"
        case 1: return "내일"
        default: return String(format: "%+d일", offset) // 한국 기준 도달 불가지만 안전망
        }
    }
}
