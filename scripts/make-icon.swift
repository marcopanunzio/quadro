// Genera Resources/AppIcon.icns: composizione alla Mondrian ("quadro") con i colori Flexoki.
// Uso: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
let output = root.appendingPathComponent("Resources/AppIcon.icns")

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let paper = color(0xFFFCF0)
let ink = color(0x100F0F)
let orange = color(0xDA702C)
let blue = color(0x4385BE)
let yellow = color(0xD0A215)

/// Disegna l'icona su una tela 1024×1024 (origine in alto a sinistra).
func draw(in ctx: CGContext) {
    // Griglia macOS: forma 824×824 centrata, raggio ~185.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: CGColor(gray: 0, alpha: 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(paper)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.translateBy(x: tile.minX, y: tile.minY)

    // Blocchi colorati (coordinate nella forma 824×824).
    let blocks: [(CGRect, CGColor)] = [
        (CGRect(x: 0, y: 0, width: 300, height: 250), blue),
        (CGRect(x: 300, y: 250, width: 524, height: 310), orange),
        (CGRect(x: 0, y: 640, width: 300, height: 184), yellow),
    ]
    for (rect, fill) in blocks {
        ctx.setFillColor(fill)
        ctx.fill(rect)
    }

    // Linee nere della composizione.
    let line: CGFloat = 30
    ctx.setFillColor(ink)
    let lines: [CGRect] = [
        CGRect(x: 300 - line / 2, y: 0, width: line, height: 824),       // verticale sinistra
        CGRect(x: 620 - line / 2, y: 0, width: line, height: 250),       // verticale alta destra
        CGRect(x: 620 - line / 2, y: 560, width: line, height: 264),     // verticale bassa destra
        CGRect(x: 0, y: 250 - line / 2, width: 824, height: line),       // orizzontale alta
        CGRect(x: 300, y: 560 - line / 2, width: 524, height: line),     // orizzontale destra
        CGRect(x: 0, y: 640 - line / 2, width: 300, height: line),       // orizzontale sinistra
    ]
    for rect in lines { ctx.fill(rect) }
    ctx.restoreGState()

    // Bordo sottile per staccare l'icona su sfondi chiari.
    ctx.addPath(shape)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.12))
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = CGFloat(size) / 1024
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)
    draw(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try png(size: 1024).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-1024.png"))
print(output.path)
