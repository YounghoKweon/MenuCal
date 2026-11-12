import Foundation
import SwiftUI
import Testing
@testable import MenuCal

private func ev(_ id: String, _ title: String, day: Int, hour: Int = 0) -> DayEvent {
    DayEvent(id: id, title: title,
             start: Date(timeIntervalSince1970: TimeInterval(day * 86_400 + hour * 3_600)),
             isAllDay: hour == 0, calendarTitle: "", color: .gray)
}

@Test func 같은_날_같은_제목의_종일_일정은_하나로_합친다() {
    let events = [
        ev("a", "황태일's Birthday", day: 1),
        ev("b", "황태일's Birthday", day: 1),
        ev("c", "황태일's Birthday", day: 1),
    ]
    #expect(events.mergingDuplicates().map(\.id) == ["a"])
}

@Test func 시작_시각과_제목이_같은_일정은_하나로_합친다() {
    let events = [
        ev("a", "회의", day: 1, hour: 9),
        ev("b", "회의", day: 1, hour: 9),
    ]
    #expect(events.mergingDuplicates().map(\.id) == ["a"])
}

@Test func 제목이나_시작_시각이_다르면_남긴다() {
    let events = [
        ev("a", "황태일's Birthday", day: 1),
        ev("b", "김철수's Birthday", day: 1),
        ev("c", "황태일's Birthday", day: 2),
        ev("d", "회의", day: 1, hour: 9),
        ev("e", "회의", day: 1, hour: 15),
    ]
    #expect(events.mergingDuplicates().map(\.id) == ["a", "b", "c", "d", "e"])
}
