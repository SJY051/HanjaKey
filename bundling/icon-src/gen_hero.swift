// Hero / social-preview card generator (spec 008 M3) — 1280x640.
// Cream ground + the glass app icon (left, soft shadow) + wordmark + bilingual tagline (right).
// Usage: swift gen_hero.swift <out.png> <icon.png>
import CoreGraphics
import CoreText
import ImageIO
import Foundation
import UniformTypeIdentifiers

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "hero.png"
let iconPath = args.count > 2 ? args[2] : "icon.png"
let W = 1280, H = 640

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: CGFloat(a))
}
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// cream ground
ctx.setFillColor(rgb(0xF2, 0xEA, 0xD9))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// glass app icon, left, with a soft shadow to lift it off the ground
if let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: iconPath) as CFURL, nil),
   let icon = CGImageSourceCreateImageAtIndex(src, 0, nil) {
    let s: CGFloat = 420
    let rect = CGRect(x: 130, y: (CGFloat(H) - s)/2, width: s, height: s)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 48, color: rgb(0x1c, 0x3a, 0x2e, 0.30))
    ctx.draw(icon, in: rect)
    ctx.restoreGState()
}

func drawText(_ s: String, font: String, size: CGFloat, color: CGColor, x: CGFloat, baseline: CGFloat) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, s as CFString,
            [kCTFontAttributeName: f, kCTForegroundColorAttributeName: color] as CFDictionary)!)
    ctx.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(line, ctx)
}

let tx: CGFloat = 600
drawText("HanjaKey", font: "Pretendard-Black", size: 104, color: rgb(0x1c, 0x3a, 0x2e), x: tx, baseline: 362)
drawText("가벼운 macOS용 한글 → 한자·특수문자 변환기", font: "Pretendard-SemiBold", size: 30,
         color: rgb(0x3a, 0x5a, 0x4a), x: tx, baseline: 300)
drawText("A lightweight Hangul → Hanja & symbol converter for macOS", font: "Pretendard-Medium", size: 23,
         color: rgb(0x6a, 0x83, 0x74), x: tx, baseline: 256)

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                           UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
_ = CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
