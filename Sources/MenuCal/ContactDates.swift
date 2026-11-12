import Contacts
import SwiftUI

/// 연락처 카드의 "날짜" 항목 하나(결혼기념일 등).
/// 생일은 macOS 생일 캘린더가 이미 일정으로 만들므로 여기에 넣지 않는다.
nonisolated struct ContactDate {
    let name: String
    let label: String
    let date: DateComponents

    /// 앱에 한국어 리소스가 없어 CNLabeledValue.localizedString은 영어를 돌려준다.
    static func displayLabel(_ raw: String?) -> String {
        switch raw {
        case CNLabelDateAnniversary: "기념일"
        case CNLabelOther, nil: "기타"
        case let custom?: custom
        }
    }

    /// 모든 연락처의 날짜 항목을 읽는다. 호출 전에 연락처 권한이 있어야 한다.
    static func load(from store: CNContactStore) -> [ContactDate] {
        let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactDatesKey as CNKeyDescriptor]
        var result: [ContactDate] = []
        try? store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            for labeled in contact.dates {
                result.append(ContactDate(name: name,
                                          label: displayLabel(labeled.label),
                                          date: labeled.value as DateComponents))
            }
        }
        return result
    }
}

extension [ContactDate] {
    /// [start, end) 안에서 해마다 돌아오는 날을 종일 일정으로 펼친다.
    /// 날짜에 음력 같은 다른 달력이 붙어 있으면 그 달력으로 계산한다.
    nonisolated func occurrences(from start: Date, to end: Date, calendar: Calendar) -> [DayEvent] {
        flatMap { cd -> [DayEvent] in
            guard let month = cd.date.month, let day = cd.date.day else { return [] }
            var dateCal = cd.date.calendar ?? Calendar(identifier: .gregorian)
            dateCal.timeZone = calendar.timeZone
            var match = DateComponents(month: month, day: day)
            match.isLeapMonth = cd.date.isLeapMonth

            var events: [DayEvent] = []
            var cursor = start.addingTimeInterval(-1)
            while let next = dateCal.nextDate(after: cursor, matching: match, matchingPolicy: .nextTime),
                  next < end {
                let title = "\(cd.name) \(cd.label)"
                events.append(DayEvent(id: "contact:\(title)@\(next.timeIntervalSince1970)",
                                       title: title, start: next, isAllDay: true,
                                       calendarTitle: "연락처", color: .orange))
                cursor = next
            }
            return events
        }
    }
}
