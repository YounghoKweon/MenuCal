// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MenuCal",
    // Calendar(.dangi) — 한국 음력 — 이 macOS 26+ API라서 26을 최소로 한다 (이 기기 전용 앱)
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "MenuCal",
            path: "Sources/MenuCal",
            swiftSettings: [
                // 모듈 전체를 @MainActor 기본 격리로: 단일 UI 앱에 딱 맞고
                // DateFormatter/ObservableObject 등을 어노테이션 없이 안전하게 쓴다.
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
