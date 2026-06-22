// Reproducible layer generator for the HanjaKey app icon (spec 008, v5 — layered glass).
// Renders four 1024x1024 PNG layers (no platform mask — Icon Composer/actool applies it):
//   background.png  solid celadon plate (back)
//   ja.png          Hanja 字 (deep celadon, Myeongjo) lower-right — FLAT; frosted by the panel above it
//   panel.png       pale celadon triangle (lower-right) — the GLASS panel; sits in front of 字
//   han.png         Hangul 한 (cream, Pretendard) upper-left — FLAT, front, fully inside (reads 한)
// Layer/z-order + glass flags live in icon.json. Fonts: Pretendard-Black (한), NotoSerifKR-Black (字) — OFL.
// Usage: swift gen_icon.swift <output-Assets-dir>
import CoreGraphics
import CoreText
import ImageIO
import Foundation
import UniformTypeIdentifiers

let S = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// Design space: a 220-unit square, top-left origin, y-DOWN (matches the SVG mockup) -> CG (y-UP) at 1024px.
let K = Double(S) / 220.0
func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * K, y: Double(S) - y * K) }
func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a))
}
func newContext() -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let c = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                      space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.clear(CGRect(x: 0, y: 0, width: S, height: S))
    return c
}
func writePNG(_ c: CGContext, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let img = c.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    if !CGImageDestinationFinalize(dest) { FileHandle.standardError.write("write failed: \(name)\n".data(using: .utf8)!) }
    print("wrote \(name)")
}

// ---- celadon base (full square) ----
do {
    let c = newContext()
    c.setFillColor(rgb(0x5d, 0x91, 0x72))
    c.fill(CGRect(x: 0, y: 0, width: S, height: S))
    writePNG(c, "background.png")
}

// ---- pale panel: lower-right triangle on transparent (becomes the frosted glass layer) ----
do {
    let c = newContext()
    c.beginPath()
    c.move(to: P(0, 170)); c.addLine(to: P(220, 55))
    c.addLine(to: P(220, 220)); c.addLine(to: P(0, 220)); c.closePath()
    c.setFillColor(rgb(0xdc, 0xeb, 0xe2))
    c.fillPath()
    writePNG(c, "panel.png")
}

// ---- glyph layers (positions baked in; icon.json keeps them neutral) ----
func glyphLayer(_ text: String, psName: String, sizeDesign: Double,
                centerX: Double, centerY: Double, color: CGColor, file: String) {
    let c = newContext()
    let font = CTFontCreateWithName(psName as CFString, CGFloat(sizeDesign * K), nil)
    let resolved = CTFontCopyPostScriptName(font) as String
    if resolved != psName {
        FileHandle.standardError.write("WARN \(file): font '\(psName)' resolved to '\(resolved)'\n".data(using: .utf8)!)
    }
    let attrs = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attrs)!)
    c.textPosition = .zero
    let ink = CTLineGetImageBounds(line, c)
    let center = P(centerX, centerY)
    c.textPosition = CGPoint(x: center.x - ink.midX, y: center.y - ink.midY)
    CTLineDraw(line, c)
    writePNG(c, file)
}

// 字 — Myeongjo serif, deep celadon, lower-right, sits BEHIND the glass panel (flat — panel frosts it).
glyphLayer("字", psName: "NotoSerifKR-Black", sizeDesign: 116, centerX: 152, centerY: 156,
           color: rgb(0x1c, 0x3a, 0x2e), file: "ja.png")
// 한 — Pretendard, cream, upper-left, fully inside (ㅎ intact -> reads 한). Flat, front.
glyphLayer("한", psName: "Pretendard-Black", sizeDesign: 108, centerX: 66, centerY: 62,
           color: rgb(0xf7, 0xf4, 0xec), file: "han.png")
