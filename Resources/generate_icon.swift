import AppKit

// MenuCal 앱 아이콘 생성기 — "달력 + 시계" 디자인
// 실행: swift Resources/generate_icon.swift
//   → Resources/AppIcon.icns (16~1024px 전 해상도) 생성
// build.sh 는 생성된 AppIcon.icns 를 번들에 넣는다 (이 스크립트는 빌드 때 실행되지 않음).

let REF: CGFloat = 1024 // 설계 기준 좌표계

// MARK: - 유틸

func roundedRectPath(_ r: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

/// macOS 앱 아이콘 표준: 1024 캔버스 안에 824×824 몸체, 반경 ~180
func bodyRect() -> NSRect { NSRect(x: 100, y: 100, width: 824, height: 824) }
let BODY_RADIUS: CGFloat = 180

func hex(_ s: String, _ a: CGFloat = 1) -> NSColor {
    var h = s; if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt32(h, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff)/255,
                   green: CGFloat((v >> 8) & 0xff)/255,
                   blue: CGFloat(v & 0xff)/255, alpha: a)
}

func softShadow(blur: CGFloat, dy: CGFloat, alpha: CGFloat) {
    let sh = NSShadow()
    sh.shadowBlurRadius = blur
    sh.shadowOffset = NSSize(width: 0, height: -dy)
    sh.shadowColor = NSColor.black.withAlphaComponent(alpha)
    sh.set()
}

// MARK: - 아이콘 그리기 (1024 기준 좌표계)

func drawIcon() {
    let body = bodyRect()
    NSGraphicsContext.saveGraphicsState()
    softShadow(blur: 40, dy: 16, alpha: 0.22)
    roundedRectPath(body, radius: BODY_RADIUS).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    roundedRectPath(body, radius: BODY_RADIUS).addClip()
    NSGradient(colors: [hex("#3A93FF"), hex("#1462E6")])!.draw(in: body, angle: -90)

    // 하얀 달력 페이지 (안쪽)
    let page = NSRect(x: body.minX + 120, y: body.minY + 150, width: body.width - 240, height: body.height - 300)
    NSGraphicsContext.saveGraphicsState()
    softShadow(blur: 30, dy: 10, alpha: 0.25)
    NSColor.white.setFill()
    roundedRectPath(page, radius: 70).fill()
    NSGraphicsContext.restoreGraphicsState()

    // 페이지 헤더 밴드
    NSGraphicsContext.saveGraphicsState()
    roundedRectPath(page, radius: 70).addClip()
    let ph = NSRect(x: page.minX, y: page.maxY - 120, width: page.width, height: 120)
    hex("#1462E6").setFill(); NSBezierPath(rect: ph).fill()
    NSGraphicsContext.restoreGraphicsState()

    // 달력 점 그리드 (3행 x 5열)
    hex("#9BB8E8").setFill()
    let gx = page.minX + 70, gy = page.minY + 90
    let colGap = (page.width - 140) / 4, rowGap: CGFloat = 95, dot: CGFloat = 34
    for row in 0..<3 { for col in 0..<5 {
        let c = NSRect(x: gx + CGFloat(col)*colGap - dot/2, y: gy + CGFloat(2-row)*rowGap - dot/2, width: dot, height: dot)
        NSBezierPath(ovalIn: c).fill()
    } }

    // 시계 배지 (우하단, 페이지에 걸침)
    let R: CGFloat = 190
    let cc = NSPoint(x: body.maxX - 210, y: body.minY + 210)
    NSGraphicsContext.saveGraphicsState()
    softShadow(blur: 26, dy: 8, alpha: 0.3)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: cc.x-R, y: cc.y-R, width: 2*R, height: 2*R)).fill()
    NSGraphicsContext.restoreGraphicsState()
    hex("#1462E6").setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: cc.x-R+14, y: cc.y-R+14, width: 2*R-28, height: 2*R-28)); ring.lineWidth = 20; ring.stroke()
    // 시침/분침
    hex("#22304A").setStroke()
    let hh = NSBezierPath(); hh.move(to: cc); hh.line(to: NSPoint(x: cc.x, y: cc.y + R*0.5)); hh.lineWidth = 24; hh.lineCapStyle = .round; hh.stroke()
    let mm = NSBezierPath(); mm.move(to: cc); mm.line(to: NSPoint(x: cc.x + R*0.62, y: cc.y + R*0.18)); mm.lineWidth = 24; mm.lineCapStyle = .round; mm.stroke()
    hex("#F0384A").setFill(); NSBezierPath(ovalIn: NSRect(x: cc.x-18, y: cc.y-18, width: 36, height: 36)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - 렌더 → iconset → icns

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.cgContext.scaleBy(x: CGFloat(pixels)/REF, y: CGFloat(pixels)/REF)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

// 픽셀 크기 → iconset 파일명(중복 매핑 포함)
let mapping: [(Int, [String])] = [
    (16,  ["icon_16x16"]),
    (32,  ["icon_16x16@2x", "icon_32x32"]),
    (64,  ["icon_32x32@2x"]),
    (128, ["icon_128x128"]),
    (256, ["icon_128x128@2x", "icon_256x256"]),
    (512, ["icon_256x256@2x", "icon_512x512"]),
    (1024,["icon_512x512@2x"]),
]
for (px, names) in mapping {
    let data = renderPNG(pixels: px)
    for name in names { try! data.write(to: iconset.appendingPathComponent("\(name).png")) }
}

let icns = scriptDir.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["--convert", "icns", iconset.path, "--output", icns.path]
try! proc.run(); proc.waitUntilExit()
try? fm.removeItem(at: iconset)
print(proc.terminationStatus == 0 ? "✅ \(icns.path)" : "❌ iconutil 실패 (\(proc.terminationStatus))")
