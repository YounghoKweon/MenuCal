import SwiftUI
import AppKit
import ServiceManagement

/// 설정 화면 (팝오버 안 페이지 스왑):
/// 메뉴바 형식 / 이벤트 / 세계시계 도시 관리 / 일반(로그인 시 자동 실행).
struct SettingsView: View {
    @EnvironmentObject private var ticker: Ticker
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var eventService: EventService
    @EnvironmentObject private var cityStore: CityStore
    let onBack: () -> Void

    @State private var isAddingCity = false
    @State private var cityQuery = ""
    @State private var launchAtLogin = false

    private static let presets: [(label: String, format: String)] = [
        ("기본", "M/d(E) HH:mm:ss"),
        ("초 없이", "M/d(E) HH:mm"),
        ("한국식", "M월 d일(E) a h:mm"),
        ("ISO", "yyyy-MM-dd HH:mm:ss"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Text("설정")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            formatSection
            Divider()
            eventSection
            Divider()
            worldClockSection
            Divider()
            generalSection
        }
        .onAppear {
            launchAtLogin = bundled && SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - 메뉴바 형식

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("메뉴바 날짜/시간 형식")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("두 줄로 표시 (폭 간소화)", isOn: $settings.twoLineMode)
                .toggleStyle(.checkbox)
                .font(.caption)
                .onChange(of: settings.twoLineMode) { _, on in
                    // 모드 전환 시 기본값이 자연스럽도록 시드
                    if on {
                        if settings.menuBarFormat == AppSettings.defaultFormat {
                            settings.menuBarFormat = AppSettings.defaultLine1TwoLine
                        }
                        if settings.menuBarFormatLine2.trimmingCharacters(in: .whitespaces).isEmpty {
                            settings.menuBarFormatLine2 = AppSettings.defaultLine2
                        }
                    } else if settings.menuBarFormat == AppSettings.defaultLine1TwoLine {
                        settings.menuBarFormat = AppSettings.defaultFormat
                    }
                }

            TextField(settings.twoLineMode ? "윗줄 (예: M/d(E))" : "M/d(E) HH:mm:ss",
                      text: $settings.menuBarFormat)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            if settings.twoLineMode {
                TextField("아랫줄 (예: HH:mm:ss)", text: $settings.menuBarFormatLine2)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            // 실시간 미리보기 (매초 갱신)
            HStack(alignment: .center, spacing: 5) {
                Text("미리보기")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if settings.twoLineMode {
                    VStack(spacing: 0) {
                        Text(preview)
                            .font(.system(size: 9).weight(.medium))
                            .monospacedDigit()
                        Text(previewLine2)
                            .font(.system(size: 9).weight(.medium))
                            .monospacedDigit()
                    }
                } else {
                    Text(preview)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.08)))

            if !settings.twoLineMode {
                HStack(spacing: 4) {
                    ForEach(Self.presets, id: \.format) { preset in
                        Button(preset.label) { settings.menuBarFormat = preset.format }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }
                }
            }

            Text("""
            M=월 d=일 E=요일 EEEE=요일(긴) HH=24시 h=12시 \
            a=오전/오후 mm=분 ss=초 yyyy=연도 (Unicode 형식)
            """)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 이벤트

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("이벤트")
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper("다가오는 이벤트 표시 기간: \(settings.lookaheadDays)일",
                    value: $settings.lookaheadDays, in: 1...30)
                .font(.caption)
                .onChange(of: settings.lookaheadDays) { _, days in
                    eventService.setLookahead(days)
                }
            Stepper("최근 이벤트 표시 기간: \(settings.lookbackDays)일",
                    value: $settings.lookbackDays, in: 1...30)
                .font(.caption)
                .onChange(of: settings.lookbackDays) { _, days in
                    eventService.setLookback(days)
                }
            Text("이벤트가 있으면 메뉴바에 🔔 표시 → 팝오버를 열면\n사라지고, 다음날 0시에 다시 나타납니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Picker("달력 열 때", selection: $settings.calendarOpensToToday) {
                Text("항상 오늘 달").tag(true)
                Text("마지막 본 달").tag(false)
            }
            .pickerStyle(.radioGroup)
            .font(.caption)
        }
    }

    // MARK: - 세계시계 도시 관리

    private var worldClockSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("세계시계 도시")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isAddingCity.toggle()
                    cityQuery = ""
                } label: {
                    Image(systemName: isAddingCity ? "xmark.circle.fill" : "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isAddingCity ? "닫기" : "도시 추가")
            }

            if isAddingCity {
                TextField("도시 검색 (한국어 또는 영문)", text: $cityQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(citySearchResults) { city in
                            Button {
                                cityStore.add(city)
                                isAddingCity = false
                                cityQuery = ""
                            } label: {
                                HStack {
                                    Text(city.name).font(.system(size: 12))
                                    Spacer()
                                    Text(city.timeZoneID)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                        }
                        if citySearchResults.isEmpty {
                            Text("검색 결과 없음")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(height: 110)
            } else if cityStore.cities.isEmpty {
                Text("+ 버튼으로 도시를 추가하세요")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                // 드래그 앤 드롭으로 순서 변경 (List + onMove)
                List {
                    ForEach(cityStore.cities) { city in
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 8))
                                .foregroundStyle(.quaternary)
                            Text(city.name).font(.system(size: 12))
                            Spacer()
                            Text(city.timeZoneID)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Button {
                                cityStore.remove(city)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("삭제")
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        cityStore.moveCities(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 22)
                .frame(height: min(CGFloat(cityStore.cities.count) * 24, 168))

                Text("행을 드래그하면 순서를 바꿀 수 있어요")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var citySearchResults: [City] {
        let q = cityQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return CityStore.presets }

        var results = CityStore.presets.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.timeZoneID.localizedCaseInsensitiveContains(q)
        }
        // 프리셋에 없는 도시는 전체 tz database에서 폴백 검색 (예: Kathmandu)
        if results.count < 8 {
            let existing = Set(results.map(\.timeZoneID))
            let extra = TimeZone.knownTimeZoneIdentifiers
                .filter { $0.localizedCaseInsensitiveContains(q) && !existing.contains($0) }
                .prefix(20)
                .map { City(name: $0, timeZoneID: $0) }
            results += extra
        }
        return results
    }

    // MARK: - 일반

    /// 번들 없는 `swift run` 바이너리에서는 SMAppService를 쓸 수 없다
    private var bundled: Bool { Bundle.main.bundleIdentifier != nil }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("일반")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.caption)
                .disabled(!bundled)
                .onChange(of: launchAtLogin) { _, enable in
                    guard bundled else { return }
                    let currentlyEnabled = SMAppService.mainApp.status == .enabled
                    guard enable != currentlyEnabled else { return } // onAppear 동기화로 인한 no-op 방지
                    do {
                        if enable {
                            if SMAppService.mainApp.status == .requiresApproval {
                                SMAppService.openSystemSettingsLoginItems()
                            }
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // 실패 시 실제 상태로 원복
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
    }

    // MARK: - 미리보기 렌더링

    /// 입력한 형식을 즉석 DateFormatter로 렌더 — 실제 메뉴바는 1초 내 자동 반영
    private var preview: String {
        render(settings.menuBarFormat,
               fallback: settings.twoLineMode ? AppSettings.defaultLine1TwoLine : AppSettings.defaultFormat)
    }

    private var previewLine2: String {
        render(settings.menuBarFormatLine2, fallback: AppSettings.defaultLine2)
    }

    private func render(_ format: String, fallback: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.calendar = Calendar(identifier: .gregorian)
        let trimmed = format.trimmingCharacters(in: .whitespaces)
        f.dateFormat = trimmed.isEmpty ? fallback : trimmed
        return f.string(from: ticker.now)
    }
}
