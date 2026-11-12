import Contacts
import Foundation
import Testing
@testable import MenuCal

private let seoul: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return c
}()

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    seoul.date(from: DateComponents(year: y, month: m, day: d))!
}

private func contactDate(_ name: String, _ label: String, month: Int, day: Int, year: Int? = nil) -> ContactDate {
    ContactDate(name: name, label: label, date: DateComponents(year: year, month: month, day: day))
}

@Test func 기간_안의_날짜를_해마다_종일_일정으로_펼친다() {
    let dates = [contactDate("강성범", "결혼기념일", month: 5, day: 20, year: 2010)]
    let events = dates.occurrences(from: day(2026, 1, 1), to: day(2028, 1, 1), calendar: seoul)
    #expect(events.map(\.start) == [day(2026, 5, 20), day(2027, 5, 20)])
    #expect(events.allSatisfy { $0.isAllDay && $0.title == "강성범 결혼기념일" })
}

@Test func 기간_밖의_날짜는_만들지_않는다() {
    let dates = [contactDate("강성범", "결혼기념일", month: 5, day: 20)]
    let events = dates.occurrences(from: day(2026, 6, 1), to: day(2026, 12, 1), calendar: seoul)
    #expect(events.isEmpty)
}

@Test func 해가_바뀌는_기간도_포함한다() {
    let dates = [contactDate("황태일", "기념일", month: 1, day: 3)]
    let events = dates.occurrences(from: day(2026, 12, 1), to: day(2027, 2, 1), calendar: seoul)
    #expect(events.map(\.start) == [day(2027, 1, 3)])
}

@Test func 시스템_라벨은_한국어로_사용자_라벨은_그대로_쓴다() {
    #expect(ContactDate.displayLabel(CNLabelDateAnniversary) == "기념일")
    #expect(ContactDate.displayLabel(CNLabelOther) == "기타")
    #expect(ContactDate.displayLabel(nil) == "기타")
    #expect(ContactDate.displayLabel("결혼기념일") == "결혼기념일")
}
