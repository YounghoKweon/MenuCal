import SwiftUI

/// 세계시계 섹션 (보기 전용 — 도시 추가/삭제는 설정에서).
struct WorldClockView: View {
    @EnvironmentObject private var ticker: Ticker
    @EnvironmentObject private var store: CityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("세계시계")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.cities.isEmpty {
                Text("설정 ⚙ 에서 도시를 추가하세요")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
            } else {
                ForEach(store.cities) { city in
                    cityRow(city)
                }
            }
        }
    }

    private func cityRow(_ city: City) -> some View {
        HStack(spacing: 6) {
            Text(city.name)
                .font(.system(size: 12))

            if let tz = city.timeZone,
               let label = ClockFormatter.dayOffsetLabel(ClockFormatter.dayOffset(remote: tz, now: ticker.now)) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }

            Spacer()

            if let tz = city.timeZone {
                Text(ClockFormatter.cityClockString(ticker.now, timeZone: tz))
                    .font(.system(size: 12))
                    .monospacedDigit()
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }
}
