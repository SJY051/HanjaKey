// Menu-bar template mark generator (spec 008 M2).
// Renders a single glyph (default 字 — distinct from the macOS Korean input indicator "한",
// and matches the app icon's Hanja glyph) as:
//   menubar-mark.pdf          vector, 18x18pt, black-on-transparent — the SHIPPED template image
//                             (glyph baked to outlines: no runtime font dependency; tints via isTemplate)
//   menubar-mark-preview.png  raster preview on a light ground — for review only
// Default font Noto Sans CJK KR-Bold (covers 字; clean at menu-bar size). Pretendard lacks Hanja.
// Usage: swift gen_menubar.swift <output-dir> [glyph] [postscript-font]
import CoreGraphics
import CoreText
import ImageIO
import Foundation
import UniformTypeIdentifiers

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "."
let text = args.count > 2 ? args[2] : "字"
let psName = args.count > 3 ? args[3] : "NotoSansCJKkr-Bold"

func drawGlyph(_ ctx: CGContext, canvas: CGFloat, fontSize: CGFloat) {
    let font = CTFontCreateWithName(psName as CFString, fontSize, nil)
    let attrs = [kCTFontAttributeName: font,
                 kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1)] as CFDictionary
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attrs)!)
    ctx.textPosition = .zero
    let ink = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: canvas / 2 - ink.midX, y: canvas / 2 - ink.midY)
    CTLineDraw(line, ctx)
}

// 1) vector PDF at 18x18pt (menu-bar size); glyph ~14pt leaves a small breathing margin.
let pt: CGFloat = 18
var box = CGRect(x: 0, y: 0, width: pt, height: pt)
let pdfURL = URL(fileURLWithPath: outDir).appendingPathComponent("menubar-mark.pdf")
let pdf = CGContext(pdfURL as CFURL, mediaBox: &box, nil)!
pdf.beginPDFPage(nil)
drawGlyph(pdf, canvas: pt, fontSize: 14)
pdf.endPDFPage()
pdf.closePDF()
print("wrote menubar-mark.pdf")

// 2) raster preview at 72px on a light ground so the black glyph is visible for review.
let px = 72
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let bmp = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
bmp.setFillColor(CGColor(gray: 0.93, alpha: 1))
bmp.fill(CGRect(x: 0, y: 0, width: px, height: px))
drawGlyph(bmp, canvas: CGFloat(px), fontSize: CGFloat(px) * 14.0 / 18.0)
let img = bmp.makeImage()!
let pngURL = URL(fileURLWithPath: outDir).appendingPathComponent("menubar-mark-preview.png")
let dest = CGImageDestinationCreateWithURL(pngURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
_ = CGImageDestinationFinalize(dest)
print("wrote menubar-mark-preview.png")
