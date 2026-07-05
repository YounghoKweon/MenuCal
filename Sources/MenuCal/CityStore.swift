import Foundation
import Combine

/// 세계시계 도시.
/// nonisolated: JSONDecoder/Encoder(비격리 제네릭)가 Codable 합성을 쓸 수 있도록
/// MainActor 기본 격리에서 제외한다.
nonisolated struct City: Codable, Identifiable, Hashable {
    let name: String       // 한국어 표시명 (예: "샌프란시스코")
    let timeZoneID: String // 예: "America/Los_Angeles"

    // 샌프란시스코/LA/시애틀이 같은 시간대를 공유하므로 timeZoneID는 id로 부적합
    var id: String { name }
    var timeZone: TimeZone? { TimeZone(identifier: timeZoneID) }
}

/// 도시 목록 저장소 (UserDefaults 영속화).
final class CityStore: ObservableObject {
    private static let defaultsKey = "worldClockCities.v1"

    @Published var cities: [City] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([City].self, from: data) {
            cities = decoded
        } else {
            // 첫 실행 기본값 (서울은 로컬이라 제외)
            cities = [
                City(name: "뉴욕", timeZoneID: "America/New_York"),
                City(name: "런던", timeZoneID: "Europe/London"),
                City(name: "도쿄", timeZoneID: "Asia/Tokyo"),
            ]
        }
    }

    func add(_ city: City) {
        guard !cities.contains(where: { $0.id == city.id }) else { return }
        cities.append(city)
    }

    func remove(_ city: City) {
        cities.removeAll { $0.id == city.id }
    }

    /// 드래그 앤 드롭 순서 변경 (SwiftUI onMove용)
    func moveCities(fromOffsets source: IndexSet, toOffset destination: Int) {
        cities.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// 주요 도시 프리셋 (한국어 이름, tz database 식별자)
    /// 참고: "UTC"는 knownTimeZoneIdentifiers에 없어서 검색 폴백으로는 안 잡힘 → 프리셋에 직접 포함
    static let presets: [City] = [
        City(name: "UTC (협정시)", timeZoneID: "UTC"),
        City(name: "서울", timeZoneID: "Asia/Seoul"),
        City(name: "도쿄", timeZoneID: "Asia/Tokyo"),
        City(name: "베이징", timeZoneID: "Asia/Shanghai"),
        City(name: "홍콩", timeZoneID: "Asia/Hong_Kong"),
        City(name: "타이베이", timeZoneID: "Asia/Taipei"),
        City(name: "싱가포르", timeZoneID: "Asia/Singapore"),
        City(name: "방콕", timeZoneID: "Asia/Bangkok"),
        City(name: "하노이", timeZoneID: "Asia/Ho_Chi_Minh"),
        City(name: "자카르타", timeZoneID: "Asia/Jakarta"),
        City(name: "마닐라", timeZoneID: "Asia/Manila"),
        City(name: "뭄바이", timeZoneID: "Asia/Kolkata"),
        City(name: "두바이", timeZoneID: "Asia/Dubai"),
        City(name: "이스탄불", timeZoneID: "Europe/Istanbul"),
        City(name: "모스크바", timeZoneID: "Europe/Moscow"),
        City(name: "파리", timeZoneID: "Europe/Paris"),
        City(name: "베를린", timeZoneID: "Europe/Berlin"),
        City(name: "런던", timeZoneID: "Europe/London"),
        City(name: "마드리드", timeZoneID: "Europe/Madrid"),
        City(name: "뉴욕", timeZoneID: "America/New_York"),
        City(name: "토론토", timeZoneID: "America/Toronto"),
        City(name: "시카고", timeZoneID: "America/Chicago"),
        City(name: "덴버", timeZoneID: "America/Denver"),
        City(name: "샌프란시스코", timeZoneID: "America/Los_Angeles"),
        City(name: "로스앤젤레스", timeZoneID: "America/Los_Angeles"),
        City(name: "시애틀", timeZoneID: "America/Los_Angeles"),
        City(name: "밴쿠버", timeZoneID: "America/Vancouver"),
        City(name: "멕시코시티", timeZoneID: "America/Mexico_City"),
        City(name: "상파울루", timeZoneID: "America/Sao_Paulo"),
        City(name: "호놀룰루", timeZoneID: "Pacific/Honolulu"),
        City(name: "시드니", timeZoneID: "Australia/Sydney"),
        City(name: "멜버른", timeZoneID: "Australia/Melbourne"),
        City(name: "오클랜드", timeZoneID: "Pacific/Auckland"),
    ]
}
