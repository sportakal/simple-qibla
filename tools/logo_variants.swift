// Logo varyantlarını logo-varyantlar/ klasörüne üretir (1024px + karşılaştırma sayfası).
// Kullanım: swift tools/logo_variants.swift  (proje kök dizininden)
import CoreGraphics
import Foundation
import ImageIO

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let emerald = [rgb(0.07, 0.42, 0.31), rgb(0.02, 0.21, 0.16)]
let night = [rgb(0.10, 0.12, 0.11), rgb(0.03, 0.04, 0.04)]
let sand = [rgb(0.98, 0.96, 0.91), rgb(0.93, 0.89, 0.80)]
let gold = rgb(0.87, 0.73, 0.42)
let cream = rgb(0.98, 0.96, 0.91)
let ink = rgb(0.06, 0.07, 0.07)
let deepGreen = rgb(0.04, 0.30, 0.22)

func background(_ ctx: CGContext, _ colors: [CGColor]) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
}

func rounded(_ c: CGPoint, _ size: CGFloat, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: c.x - size / 2, y: c.y - size / 2, width: size, height: size),
           cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor) {
    ctx.addPath(path); ctx.setFillColor(color); ctx.fillPath()
}

func ring(_ ctx: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat, color: CGColor, cutout: CGPath? = nil) {
    ctx.saveGState()
    if let cutout {
        ctx.addRect(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.addPath(cutout)
        ctx.clip(using: .evenOdd)
    }
    ctx.setStrokeColor(color); ctx.setLineWidth(width)
    ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    ctx.restoreGState()
}

/// Merkezden yukarı (yerel koordinatta) bakan eşkenar dörtgen ibre.
func needle(_ ctx: CGContext, center: CGPoint, angle: CGFloat, width: CGFloat, north: CGFloat, south: CGFloat, head: CGColor, tail: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: -angle)
    func tri(_ tip: CGFloat, _ color: CGColor) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: tip))
        ctx.addLine(to: CGPoint(x: width, y: 0))
        ctx.addLine(to: CGPoint(x: -width, y: 0))
        ctx.closePath()
        ctx.setFillColor(color); ctx.fillPath()
    }
    tri(-south, tail)
    tri(north, head)
    ctx.restoreGState()
}

struct Variant { let name: String; let note: String; let draw: (CGContext) -> Void }

let variants: [Variant] = [
    Variant(name: "1-pusula-zumrut", note: "Pusula ibresi halkadaki altın Kâbe'yi gösterir") { ctx in
        background(ctx, emerald)
        let c = CGPoint(x: 512, y: 488), k = CGPoint(x: 512, y: 488 + 318)
        ring(ctx, center: c, radius: 318, width: 20, color: rgb(1, 1, 1, 0.20), cutout: rounded(k, 184, 50))
        needle(ctx, center: c, angle: 0, width: 66, north: 228, south: 200, head: cream, tail: rgb(1, 1, 1, 0.26))
        fill(ctx, rounded(k, 132, 24), gold)
    },
    Variant(name: "2-pusula-gece", note: "Aynı fikir, koyu zemin ve yeşil ibre") { ctx in
        background(ctx, night)
        let c = CGPoint(x: 512, y: 488), k = CGPoint(x: 512, y: 488 + 318)
        ring(ctx, center: c, radius: 318, width: 20, color: rgb(1, 1, 1, 0.14), cutout: rounded(k, 184, 50))
        let mint = rgb(0.40, 0.84, 0.66)
        needle(ctx, center: c, angle: 0, width: 66, north: 228, south: 200, head: mint, tail: rgb(0.40, 0.84, 0.66, 0.28))
        fill(ctx, rounded(k, 132, 24), gold)
    },
    Variant(name: "3-pusula-kum", note: "Açık kum zemin, zümrüt ibre — sıcak ve sakin") { ctx in
        background(ctx, sand)
        let c = CGPoint(x: 512, y: 488), k = CGPoint(x: 512, y: 488 + 318)
        ring(ctx, center: c, radius: 318, width: 20, color: rgb(0.04, 0.30, 0.22, 0.16), cutout: rounded(k, 184, 50))
        needle(ctx, center: c, angle: 0, width: 66, north: 228, south: 200, head: deepGreen, tail: rgb(0.04, 0.30, 0.22, 0.22))
        fill(ctx, rounded(k, 132, 24), ink)
        ctx.setFillColor(gold); ctx.fill(CGRect(x: 512 - 66, y: 806 + 18, width: 132, height: 20))
    },
    Variant(name: "4-egik-ibre", note: "Hareket hissi veren eğik ibre, Kâbe dik durur") { ctx in
        background(ctx, emerald)
        let c = CGPoint(x: 512, y: 512), a = CGFloat.pi / 4
        let k = CGPoint(x: c.x + 318 * sin(a), y: c.y + 318 * cos(a))
        ring(ctx, center: c, radius: 318, width: 20, color: rgb(1, 1, 1, 0.20), cutout: rounded(k, 184, 50))
        needle(ctx, center: c, angle: a, width: 62, north: 228, south: 200, head: cream, tail: rgb(1, 1, 1, 0.26))
        fill(ctx, rounded(k, 132, 24), gold)
    },
    Variant(name: "5-halka-kesik", note: "İbresiz: açık uçlu halka ve tepedeki Kâbe — en yalın") { ctx in
        background(ctx, emerald)
        let c = CGPoint(x: 512, y: 470), k = CGPoint(x: 512, y: 470 + 300)
        ring(ctx, center: c, radius: 300, width: 64, color: cream, cutout: rounded(k, 250, 70))
        fill(ctx, rounded(k, 160, 30), gold)
        ctx.setFillColor(cream); ctx.fillEllipse(in: CGRect(x: c.x - 44, y: c.y - 44, width: 88, height: 88))
    },
    Variant(name: "6-nokta-cizgi", note: "Uygulamadaki görünümün özeti: sen → Kâbe") { ctx in
        background(ctx, emerald)
        let you = CGPoint(x: 512, y: 300), k = CGPoint(x: 512, y: 700)
        ctx.setStrokeColor(cream); ctx.setLineWidth(30); ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [0.1, 62])
        ctx.move(to: CGPoint(x: you.x, y: you.y + 90)); ctx.addLine(to: CGPoint(x: k.x, y: k.y - 110)); ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setFillColor(cream); ctx.fillEllipse(in: CGRect(x: you.x - 60, y: you.y - 60, width: 120, height: 120))
        ctx.setFillColor(deepGreen); ctx.fillEllipse(in: CGRect(x: you.x - 26, y: you.y - 26, width: 52, height: 52))
        fill(ctx, rounded(k, 210, 30), ink)
        ctx.setFillColor(gold); ctx.fill(CGRect(x: k.x - 105, y: k.y + 34, width: 210, height: 30))
    },
    Variant(name: "7-altin-gece", note: "Siyah zemin, ince altın çizgiler — daha premium") { ctx in
        background(ctx, night)
        let c = CGPoint(x: 512, y: 488), k = CGPoint(x: 512, y: 488 + 318)
        ring(ctx, center: c, radius: 318, width: 10, color: rgb(0.87, 0.73, 0.42, 0.55), cutout: rounded(k, 170, 44))
        needle(ctx, center: c, angle: 0, width: 54, north: 230, south: 200, head: gold, tail: rgb(0.87, 0.73, 0.42, 0.25))
        fill(ctx, rounded(k, 118, 20), gold)
    },
    Variant(name: "8a-kum-egik", note: "Kum zemin + eğik ibre (45°), siyah-altın Kâbe") { ctx in
        sandDiagonal(ctx, angle: .pi / 4, ringAlpha: 0.16)
    },
    Variant(name: "8b-kum-egik-dar", note: "Kum + eğik ibre (35°), daha ince halka") { ctx in
        sandDiagonal(ctx, angle: .pi * 35 / 180, ringAlpha: 0.12, ringWidth: 14)
    },
    Variant(name: "8c-kum-egik-altin-ibre", note: "Kum + eğik ibre, ibre ucu altın vurgulu") { ctx in
        sandDiagonal(ctx, angle: .pi / 4, ringAlpha: 0.16, goldTip: true)
    },
]

/// Kum zemin, eğik ibre; Kâbe halkanın üzerinde dik durur.
func sandDiagonal(_ ctx: CGContext, angle a: CGFloat, ringAlpha: CGFloat, ringWidth: CGFloat = 20, goldTip: Bool = false) {
    background(ctx, sand)
    let c = CGPoint(x: 512 - 20, y: 512 - 20)
    let k = CGPoint(x: c.x + 318 * sin(a), y: c.y + 318 * cos(a))
    ring(ctx, center: c, radius: 318, width: ringWidth, color: rgb(0.04, 0.30, 0.22, ringAlpha), cutout: rounded(k, 184, 50))
    needle(ctx, center: c, angle: a, width: 62, north: 228, south: 200,
           head: goldTip ? gold : deepGreen, tail: rgb(0.04, 0.30, 0.22, 0.22))
    if goldTip {
        needle(ctx, center: c, angle: a, width: 62, north: 0.1, south: 0, head: deepGreen, tail: deepGreen)
    }
    fill(ctx, rounded(k, 132, 24), ink)
    ctx.setFillColor(gold); ctx.fill(CGRect(x: k.x - 66, y: k.y + 18, width: 132, height: 20))
}

func image(size: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(ctx)
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let dir = "logo-varyantlar"
try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for v in variants {
    save(image(size: 1024, v.draw), "\(dir)/\(v.name).png")
    print("✓ \(dir)/\(v.name).png — \(v.note)")
}

// Karşılaştırma: her varyant büyük (240) ve ana ekran boyutunda (60) maskeli.
let cell = 300, rows = variants.count
let sheet = CGContext(data: nil, width: cell * 2, height: cell * rows, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
sheet.setFillColor(rgb(0.95, 0.95, 0.95)); sheet.fill(CGRect(x: 0, y: 0, width: cell * 2, height: cell * rows))
sheet.setFillColor(rgb(0.12, 0.12, 0.12)); sheet.fill(CGRect(x: cell, y: 0, width: cell, height: cell * rows))
for (i, v) in variants.enumerated() {
    let y = CGFloat(cell * (rows - 1 - i))
    let big = CGRect(x: 30, y: y + 30, width: 240, height: 240)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: big, cornerWidth: 54, cornerHeight: 54, transform: nil)); sheet.clip()
    sheet.draw(image(size: 480, v.draw), in: big)
    sheet.restoreGState()
    for (j, s) in [60, 40].enumerated() {
        let r = CGRect(x: CGFloat(cell + 60 + j * 110), y: y + CGFloat(cell - s) / 2, width: CGFloat(s), height: CGFloat(s))
        sheet.saveGState()
        sheet.addPath(CGPath(roundedRect: r, cornerWidth: CGFloat(s) * 0.225, cornerHeight: CGFloat(s) * 0.225, transform: nil)); sheet.clip()
        sheet.draw(image(size: s * 3, v.draw), in: r)
        sheet.restoreGState()
    }
}
save(sheet.makeImage()!, "\(dir)/_karsilastirma.png")
print("✓ \(dir)/_karsilastirma.png")
