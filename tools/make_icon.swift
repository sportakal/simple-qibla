// App ikonu (açık, koyu, renklendirilmiş) ve launch logosunu (açık, koyu) üretir.
// Tasarım: logo-varyantlar/8a-kum-egik — kum zemin, eğik pusula ibresi, halkada dik duran Kâbe.
// Kullanım: swift tools/make_icon.swift  (proje kök dizininden)
import CoreGraphics
import Foundation
import ImageIO

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let gold = rgb(0.87, 0.73, 0.42)
let ink = rgb(0.06, 0.07, 0.07)
let deepGreen = rgb(0.04, 0.30, 0.22)
let mint = rgb(0.40, 0.84, 0.66)

struct Palette {
    var background: [CGColor]?   // nil → şeffaf
    var ring: CGColor
    var needle: CGColor
    var tail: CGColor
    var kaaba: CGColor
    var band: CGColor?           // Kâbe üzerindeki altın kuşak
}

let light = Palette(
    background: [rgb(0.98, 0.96, 0.91), rgb(0.93, 0.89, 0.80)],
    ring: rgb(0.04, 0.30, 0.22, 0.16),
    needle: deepGreen,
    tail: rgb(0.04, 0.30, 0.22, 0.22),
    kaaba: ink,
    band: gold
)
let dark = Palette(
    background: [rgb(0.10, 0.12, 0.11), rgb(0.03, 0.04, 0.04)],
    ring: rgb(1, 1, 1, 0.14),
    needle: mint,
    tail: rgb(0.40, 0.84, 0.66, 0.28),
    kaaba: gold,
    band: nil
)
// iOS renklendirilmiş ikon: gri tonlu, sistem kendi rengini uygular.
let tinted = Palette(
    background: [rgb(0, 0, 0), rgb(0, 0, 0)],
    ring: rgb(1, 1, 1, 0.22),
    needle: rgb(1, 1, 1),
    tail: rgb(1, 1, 1, 0.30),
    kaaba: rgb(1, 1, 1),
    band: nil
)
var launchLight = light; launchLight.background = nil
var launchDark = dark; launchDark.background = nil

/// 1024x1024 koordinat sisteminde çizer (y yukarı).
func draw(_ ctx: CGContext, _ p: Palette) {
    let angle = CGFloat.pi / 4
    let center = CGPoint(x: 492, y: 492)
    let ringRadius: CGFloat = 318
    let kaabaSize: CGFloat = 132
    let kaabaCenter = CGPoint(x: center.x + ringRadius * sin(angle), y: center.y + ringRadius * cos(angle))

    func kaabaPath(inset: CGFloat) -> CGPath {
        let s = kaabaSize + inset * 2
        let r = CGRect(x: kaabaCenter.x - s / 2, y: kaabaCenter.y - s / 2, width: s, height: s)
        return CGPath(roundedRect: r, cornerWidth: 24 + inset, cornerHeight: 24 + inset, transform: nil)
    }

    if let colors = p.background {
        let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
    }

    // Halka, Kâbe'nin etrafında boşluk bırakacak şekilde kesilir.
    ctx.saveGState()
    ctx.addRect(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    ctx.addPath(kaabaPath(inset: 26))
    ctx.clip(using: .evenOdd)
    ctx.setStrokeColor(p.ring)
    ctx.setLineWidth(20)
    ctx.strokeEllipse(in: CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
    ctx.restoreGState()

    // Eğik ibre: dolgun kuzey yarısı Kâbe'yi gösterir, güney yarısı soluk.
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: -angle)
    let w: CGFloat = 62
    func half(_ tipY: CGFloat, _ color: CGColor) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: tipY))
        ctx.addLine(to: CGPoint(x: w, y: 0))
        ctx.addLine(to: CGPoint(x: -w, y: 0))
        ctx.closePath()
        ctx.setFillColor(color)
        ctx.fillPath()
    }
    half(-200, p.tail)
    half(228, p.needle)
    ctx.restoreGState()

    // Kâbe dik durur.
    ctx.addPath(kaabaPath(inset: 0))
    ctx.setFillColor(p.kaaba)
    ctx.fillPath()
    if let band = p.band {
        ctx.setFillColor(band)
        ctx.fill(CGRect(x: kaabaCenter.x - kaabaSize / 2, y: kaabaCenter.y + 18, width: kaabaSize, height: 20))
    }
}

func render(size: Int, palette: Palette, to path: String) {
    let opaque = palette.background != nil
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: info)!
    ctx.setShouldAntialias(true)
    let s = CGFloat(size) / 1024
    ctx.scaleBy(x: s, y: s)
    draw(ctx, palette)
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("✓ \(path)")
}

let assets = "SimpleQibla/Assets.xcassets"
render(size: 1024, palette: light, to: "\(assets)/AppIcon.appiconset/AppIcon.png")
// Saat ikonu: sistem daireye kırpar; çizim merkezde kaldığı için aynı tasarım kullanılır.
render(size: 1024, palette: light, to: "SimpleQibla Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
render(size: 1024, palette: dark, to: "\(assets)/AppIcon.appiconset/AppIcon-Dark.png")
render(size: 1024, palette: tinted, to: "\(assets)/AppIcon.appiconset/AppIcon-Tinted.png")
// Launch logosu: 140pt, açık ve koyu görünüm
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    render(size: 140 * scale, palette: launchLight, to: "\(assets)/LaunchLogo.imageset/LaunchLogo\(suffix).png")
    render(size: 140 * scale, palette: launchDark, to: "\(assets)/LaunchLogo.imageset/LaunchLogo-Dark\(suffix).png")
}
