// App ikonu (açık, koyu, renklendirilmiş), saat ikonu ve launch logosunu (açık, koyu) üretir.
// Tasarım: uygulamanın kendisi — harita üzerinde konumdan Kâbe'ye uzanan kırmızı kıble çizgisi.
// Kullanım: swift tools/make_icon.swift  (proje kök dizininden)
import CoreGraphics
import Foundation
import ImageIO

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let white = rgb(1, 1, 1)
let red = rgb(1.0, 0.23, 0.19)      // iOS systemRed, uygulamadaki çizgi
let gold = rgb(0.83, 0.69, 0.30)    // KaabaPin kuşağı
let kaabaInk = rgb(0.08, 0.08, 0.08)

struct Palette {
    var land: [CGColor]
    var park: CGColor
    var water: CGColor
    var roadCasing: CGColor
    var road: CGColor
    var mainRoad: CGColor
    var mainCasing: CGColor
    var line: CGColor
    var lineCasing: CGColor
    var dot: CGColor
    var kaaba: CGColor
    var band: CGColor
    var shadow: CGFloat
}

let light = Palette(
    land: [rgb(0.96, 0.95, 0.92), rgb(0.93, 0.92, 0.88)],
    park: rgb(0.78, 0.89, 0.74),
    water: rgb(0.62, 0.81, 0.95),
    roadCasing: rgb(0.86, 0.84, 0.80),
    road: white,
    mainRoad: rgb(0.99, 0.86, 0.52),
    mainCasing: rgb(0.89, 0.72, 0.38),
    line: red, lineCasing: white, dot: red,
    kaaba: kaabaInk, band: gold, shadow: 0.35
)
let dark = Palette(
    land: [rgb(0.17, 0.19, 0.21), rgb(0.11, 0.12, 0.14)],
    park: rgb(0.16, 0.27, 0.20),
    water: rgb(0.10, 0.20, 0.32),
    roadCasing: rgb(0.13, 0.14, 0.16),
    road: rgb(0.27, 0.29, 0.32),
    mainRoad: rgb(0.55, 0.47, 0.30),
    mainCasing: rgb(0.08, 0.09, 0.10),
    line: red, lineCasing: white, dot: red,
    kaaba: kaabaInk, band: gold, shadow: 0.5
)
// iOS renklendirilmiş ikon: gri tonlu, sistem kendi rengini uygular. Çizgi ve Kâbe en parlak öğe.
let tinted = Palette(
    land: [rgb(0, 0, 0), rgb(0, 0, 0)],
    park: rgb(0.10, 0.10, 0.10),
    water: rgb(0.14, 0.14, 0.14),
    roadCasing: rgb(0, 0, 0),
    road: rgb(0.20, 0.20, 0.20),
    mainRoad: rgb(0.30, 0.30, 0.30),
    mainCasing: rgb(0, 0, 0),
    line: white, lineCasing: rgb(0, 0, 0), dot: white,
    kaaba: white, band: rgb(0, 0, 0), shadow: 0
)

struct Layout {
    var from: CGPoint
    var to: CGPoint
    var kaabaSize: CGFloat
}
let iconLayout = Layout(from: CGPoint(x: 290, y: 280), to: CGPoint(x: 720, y: 730), kaabaSize: 230)
// Saat ikonu daireye kırpılır; öğeler merkeze biraz daha yakın durur.
let watchLayout = Layout(from: CGPoint(x: 320, y: 310), to: CGPoint(x: 690, y: 700), kaabaSize: 210)

func stroke(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, _ width: CGFloat, cap: CGLineCap = .round) {
    ctx.addPath(path); ctx.setStrokeColor(color); ctx.setLineWidth(width)
    ctx.setLineCap(cap); ctx.setLineJoin(.round); ctx.strokePath()
}
func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor) {
    ctx.addPath(path); ctx.setFillColor(color); ctx.fillPath()
}
func shadowed(_ ctx: CGContext, _ p: Palette, blur: CGFloat = 18, scale: CGFloat = 1, _ body: () -> Void) {
    ctx.saveGState()
    if p.shadow > 0 {
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: blur, color: rgb(0, 0, 0, p.shadow * scale))
    }
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

/// Hafif eğik sokak ızgarası, su, park ve kıvrımlı bir ana yol.
func drawMap(_ ctx: CGContext, _ p: Palette) {
    let g = CGGradient(colorsSpace: cs, colors: p.land as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

    let water = CGMutablePath()
    water.move(to: CGPoint(x: -10, y: 600))
    water.addCurve(to: CGPoint(x: 420, y: 1034), control1: CGPoint(x: 170, y: 640), control2: CGPoint(x: 330, y: 820))
    water.addLine(to: CGPoint(x: -10, y: 1034))
    water.closeSubpath()
    fill(ctx, water, p.water)

    let park = CGMutablePath()
    park.move(to: CGPoint(x: 700, y: -10))
    park.addLine(to: CGPoint(x: 1034, y: -10))
    park.addLine(to: CGPoint(x: 1034, y: 330))
    park.addCurve(to: CGPoint(x: 700, y: -10), control1: CGPoint(x: 880, y: 300), control2: CGPoint(x: 730, y: 170))
    fill(ctx, park, p.park)

    // Sokaklar su ve parkın üstüne çizilmez.
    ctx.saveGState()
    ctx.addRect(CGRect(x: -100, y: -100, width: 1224, height: 1224))
    ctx.addPath(water)
    ctx.addPath(park)
    ctx.clip(using: .evenOdd)
    ctx.translateBy(x: 512, y: 512)
    ctx.rotate(by: 14 * .pi / 180)
    let grid = CGMutablePath()
    for i in stride(from: -900, through: 900, by: 270) {
        grid.move(to: CGPoint(x: CGFloat(i), y: -1000)); grid.addLine(to: CGPoint(x: CGFloat(i), y: 1000))
        grid.move(to: CGPoint(x: -1000, y: CGFloat(i) + 60)); grid.addLine(to: CGPoint(x: 1000, y: CGFloat(i) + 60))
    }
    stroke(ctx, grid, p.roadCasing, 34, cap: .butt)
    stroke(ctx, grid, p.road, 26, cap: .butt)
    ctx.restoreGState()

    let main = CGMutablePath()
    main.move(to: CGPoint(x: 560, y: -40))
    main.addCurve(to: CGPoint(x: 1064, y: 640), control1: CGPoint(x: 620, y: 300), control2: CGPoint(x: 860, y: 560))
    stroke(ctx, main, p.mainCasing, 50)
    stroke(ctx, main, p.mainRoad, 40)
}

/// Konum noktası, kıble çizgisi ve Kâbe (uygulamadaki QiblaArrow noktası ve KaabaPin gibi).
func drawQibla(_ ctx: CGContext, _ p: Palette, _ l: Layout) {
    let line = CGMutablePath()
    line.move(to: l.from); line.addLine(to: l.to)
    shadowed(ctx, p, blur: 10, scale: 0.7) {
        stroke(ctx, line, p.lineCasing, 58)
        stroke(ctx, line, p.line, 36)
    }

    let r: CGFloat = 72, ir = r * 0.63
    shadowed(ctx, p, blur: 14, scale: 0.85) {
        ctx.setFillColor(p.lineCasing)
        ctx.fillEllipse(in: CGRect(x: l.from.x - r, y: l.from.y - r, width: r * 2, height: r * 2))
    }
    ctx.setFillColor(p.dot)
    ctx.fillEllipse(in: CGRect(x: l.from.x - ir, y: l.from.y - ir, width: ir * 2, height: ir * 2))

    let s = l.kaabaSize
    let k = CGRect(x: l.to.x - s / 2, y: l.to.y - s / 2, width: s, height: s)
    let corner = s * 0.15
    shadowed(ctx, p) {
        fill(ctx, CGPath(roundedRect: k.insetBy(dx: -s * 0.07, dy: -s * 0.07), cornerWidth: corner * 1.4, cornerHeight: corner * 1.4, transform: nil), p.lineCasing)
        fill(ctx, CGPath(roundedRect: k, cornerWidth: corner, cornerHeight: corner, transform: nil), p.kaaba)
        ctx.setFillColor(p.band)
        ctx.fill(CGRect(x: k.minX, y: k.maxY - s * 0.395, width: s, height: s * 0.145))
    }
}

/// `clip`: launch logosu için ikon biçiminde yuvarlatılmış kare, kenarları şeffaf.
func render(size: Int, palette: Palette, layout: Layout = iconLayout, clip: Bool = false, to path: String) {
    let info = clip ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: info)!
    ctx.setShouldAntialias(true)
    let s = CGFloat(size) / 1024
    ctx.scaleBy(x: s, y: s)
    if clip {
        ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024), cornerWidth: 230, cornerHeight: 230, transform: nil))
        ctx.clip()
    }
    drawMap(ctx, palette)
    drawQibla(ctx, palette, layout)
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("✓ \(path)")
}

let assets = "SimpleQibla/Assets.xcassets"
render(size: 1024, palette: light, to: "\(assets)/AppIcon.appiconset/AppIcon.png")
render(size: 1024, palette: dark, to: "\(assets)/AppIcon.appiconset/AppIcon-Dark.png")
render(size: 1024, palette: tinted, to: "\(assets)/AppIcon.appiconset/AppIcon-Tinted.png")
render(size: 1024, palette: light, layout: watchLayout, to: "SimpleQibla Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
// Launch logosu: 140pt, açık ve koyu görünüm
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    render(size: 140 * scale, palette: light, clip: true, to: "\(assets)/LaunchLogo.imageset/LaunchLogo\(suffix).png")
    render(size: 140 * scale, palette: dark, clip: true, to: "\(assets)/LaunchLogo.imageset/LaunchLogo-Dark\(suffix).png")
}
