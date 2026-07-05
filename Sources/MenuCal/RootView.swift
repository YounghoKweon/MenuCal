import SwiftUI
import AppKit

/// 팝오버 루트: 달력 + 다가오는 이벤트 + 세계시계 + 푸터.
/// 톱니 버튼으로 설정 페이지와 스왑.
struct RootView: View {
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView { showingSettings = false }
            } else {
                VStack(spacing: 10) {
                    CalendarView()
                    Divider()
                    UpcomingEventsView()
                    Divider()
                    WorldClockView()
                    Divider()
                    FooterView(showingSettings: $showingSettings)
                }
            }
        }
        .padding(12)
        .frame(width: 264)
    }
}

/// 설정 진입 + 종료.
struct FooterView: View {
    @Binding var showingSettings: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("설정")

            Spacer()

            Button("종료") { NSApp.terminate(nil) }
                .font(.caption)
                .keyboardShortcut("q")
        }
    }
}
