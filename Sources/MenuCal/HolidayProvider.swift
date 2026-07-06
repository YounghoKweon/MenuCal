import Foundation

/// 달력 셀 매칭용 단순 날짜 키.
/// DateComponents를 키로 쓰면 isLeapMonth nil/false 불일치로 등호 비교가 깨지는
/// 함정이 있어서 명시적 구조체를 쓴다.
nonisolated struct DayKey: Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }
}

/// 한국 공휴일 계산기.
/// 하드코딩 대신 계산: 양력 고정일 + 한국 음력(`Calendar.dangi`)으로
/// 설날·부처님오신날·추석을 아무 연도나 산출하고, 대체공휴일 규칙을 적용한다.
///
/// 알려진 한계: 선거일·정부 지정 임시공휴일은 법으로 계산 불가라 미포함.
enum HolidayProvider {

    private static var cache: [Int: [DayKey: String]] = [:]

    /// 공휴일은 한국(Asia/Seoul) 기준 날짜로 계산
    private static let greg: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return c
    }()

    /// 한국 음력 (lunisolar)
    private static let dangi: Calendar = {
        var c = Calendar(identifier: .dangi)
        c.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return c
    }()

    static func holidays(inYear year: Int) -> [DayKey: String] {
        if let cached = cache[year] { return cached }
        let computed = compute(year: year)
        cache[year] = computed
        return computed
    }

    private static var lunarCache: [DayKey: (month: Int, day: Int, isLeap: Bool)] = [:]

    /// 주어진 양력 날짜의 음력 월/일 (달력 셀의 흐린 음력 표시용).
    /// 정오(Asia/Seoul) 기준으로 변환해 자정 경계 오차를 피한다.
    static func lunar(for key: DayKey) -> (month: Int, day: Int, isLeap: Bool)? {
        if let cached = lunarCache[key] { return cached }
        guard let date = greg.date(from: DateComponents(
            year: key.year, month: key.month, day: key.day, hour: 12)) else { return nil }
        let c = dangi.dateComponents([.month, .day], from: date)
        guard let m = c.month, let d = c.day else { return nil }
        let info = (month: m, day: d, isLeap: c.isLeapMonth ?? false)
        lunarCache[key] = info
        return info
    }

    /// 디버그 CLI 출력용 요일 기호
    static func weekdaySymbol(of key: DayKey) -> String {
        guard let date = greg.date(from: DateComponents(year: key.year, month: key.month, day: key.day)) else { return "?" }
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        return symbols[greg.component(.weekday, from: date) - 1]
    }

    // MARK: - 계산

    private static func compute(year: Int) -> [DayKey: String] {
        var result: [DayKey: String] = [:]

        func key(of date: Date) -> DayKey { DayKey(date: date, calendar: greg) }
        func gregDate(_ month: Int, _ day: Int) -> Date {
            greg.date(from: DateComponents(year: year, month: month, day: day))!
        }
        func weekday(_ date: Date) -> Int { greg.component(.weekday, from: date) } // 1=일 ... 7=토

        // 1) 양력 고정 공휴일
        let fixed: [(Int, Int, String)] = [
            (1, 1, "신정"), (3, 1, "삼일절"), (5, 5, "어린이날"), (6, 6, "현충일"),
            (8, 15, "광복절"), (10, 3, "개천절"), (10, 9, "한글날"), (12, 25, "성탄절"),
        ]
        for (m, d, name) in fixed {
            result[DayKey(year: year, month: m, day: d)] = name
        }

        // 2) 음력 공휴일 — 해당 그레고리안 연도의 모든 날을 스캔해 dangi 월/일 매칭
        //    (윤달 제외: 설날·부처님오신날·추석은 항상 평달 기준)
        var seolnal: Date?
        var buddha: Date?
        var chuseok: Date?
        var cursor = gregDate(1, 1)
        let end = greg.date(byAdding: .year, value: 1, to: cursor)!
        while cursor < end {
            let c = dangi.dateComponents([.month, .day], from: cursor)
            if c.isLeapMonth != true {
                switch (c.month, c.day) {
                case (1, 1): seolnal = cursor
                case (4, 8): buddha = cursor
                case (8, 15): chuseok = cursor
                default: break
                }
            }
            cursor = greg.date(byAdding: .day, value: 1, to: cursor)!
        }

        /// 이름들을 result에 넣되, 기존 공휴일과 겹치면 이름을 합치고 겹침 여부를 돌려준다
        /// (예: 2017년 개천절 = 추석 연휴 첫날, 2025년 어린이날 = 부처님오신날)
        func insert(_ dates: [Date], _ names: [String]) -> Bool {
            var overlapped = false
            for (d, name) in zip(dates, names) {
                let k = key(of: d)
                if let existing = result[k] {
                    result[k] = "\(existing)·\(name)"
                    overlapped = true
                } else {
                    result[k] = name
                }
            }
            return overlapped
        }

        var seolBlock: [Date] = []
        var chuseokBlock: [Date] = []
        var seolOverlapped = false
        var chuseokOverlapped = false
        var buddhaOverlapped = false

        if let s = seolnal {
            seolBlock = [-1, 0, 1].map { greg.date(byAdding: .day, value: $0, to: s)! }
            seolOverlapped = insert(seolBlock, ["설날 연휴", "설날", "설날 연휴"])
        }
        if let c = chuseok {
            chuseokBlock = [-1, 0, 1].map { greg.date(byAdding: .day, value: $0, to: c)! }
            chuseokOverlapped = insert(chuseokBlock, ["추석 연휴", "추석", "추석 연휴"])
        }
        if let b = buddha {
            buddhaOverlapped = insert([b], ["부처님오신날"])
        }

        // 3) 대체공휴일 (관공서의 공휴일에 관한 규정, 2023년 확대 기준)
        //    - 삼일절·광복절·개천절·한글날·어린이날·부처님오신날·성탄절:
        //      토·일요일 또는 다른 공휴일과 겹치면 대체
        //    - 설·추석 연휴: 일요일 또는 다른 공휴일과 겹치면 대체
        //    - 신정·현충일: 대상 아님
        //    대체일 = 겹친 날(연휴는 마지막 날) 다음의 첫 번째 비공휴일(토·일 제외)
        var anchors: [(after: Date, reason: String)] = []

        let satSunSubjects: Set<String> = ["삼일절", "광복절", "개천절", "한글날", "어린이날", "성탄절"]
        for (m, d, name) in fixed where satSunSubjects.contains(name) {
            let dt = gregDate(m, d)
            if weekday(dt) == 1 || weekday(dt) == 7 {
                anchors.append((after: dt, reason: name))
            }
        }
        if let b = buddha, weekday(b) == 1 || weekday(b) == 7 || buddhaOverlapped {
            anchors.append((after: b, reason: "부처님오신날"))
        }
        for (block, name, overlapped) in [(seolBlock, "설날", seolOverlapped), (chuseokBlock, "추석", chuseokOverlapped)] where !block.isEmpty {
            let hasSunday = block.contains { weekday($0) == 1 }
            if hasSunday || overlapped {
                anchors.append((after: block.last!, reason: name))
            }
        }

        // 앞 날짜부터 처리 — 대체일이 이미 공휴일이면 다음 날로 밀리는 체인 대응
        anchors.sort { $0.after < $1.after }
        for anchor in anchors {
            var t = greg.date(byAdding: .day, value: 1, to: anchor.after)!
            while weekday(t) == 1 || weekday(t) == 7 || result[key(of: t)] != nil {
                t = greg.date(byAdding: .day, value: 1, to: t)!
            }
            result[key(of: t)] = "대체공휴일(\(anchor.reason))"
        }

        return result
    }
}
