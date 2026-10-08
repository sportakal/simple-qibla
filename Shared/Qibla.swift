import CoreLocation

enum Qibla {
    static let kaaba = CLLocationCoordinate2D(latitude: 21.422487, longitude: 39.826206)

    /// Verilen konumdan Kâbe'ye büyük daire başlangıç açısı (kuzeyden saat yönünde, 0–360).
    static func bearing(from c: CLLocationCoordinate2D) -> Double {
        let φ1 = c.latitude * .pi / 180
        let φ2 = kaaba.latitude * .pi / 180
        let Δλ = (kaaba.longitude - c.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    static func cardinal(_ deg: Double) -> String {
        let names = [
            String(localized: "cardinal.n", defaultValue: "N", comment: "Kuzey kısaltması"),
            String(localized: "cardinal.ne", defaultValue: "NE", comment: "Kuzeydoğu kısaltması"),
            String(localized: "cardinal.e", defaultValue: "E", comment: "Doğu kısaltması"),
            String(localized: "cardinal.se", defaultValue: "SE", comment: "Güneydoğu kısaltması"),
            String(localized: "cardinal.s", defaultValue: "S", comment: "Güney kısaltması"),
            String(localized: "cardinal.sw", defaultValue: "SW", comment: "Güneybatı kısaltması"),
            String(localized: "cardinal.w", defaultValue: "W", comment: "Batı kısaltması"),
            String(localized: "cardinal.nw", defaultValue: "NW", comment: "Kuzeybatı kısaltması"),
        ]
        return names[Int((deg + 22.5) / 45) % 8]
    }

    /// İki açı arasındaki işaretli fark (-180…180).
    static func delta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    /// İki nokta arasındaki büyük daire yayının orta noktası.
    static func midpoint(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let φ1 = a.latitude * .pi / 180, λ1 = a.longitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let bx = cos(φ2) * cos(Δλ), by = cos(φ2) * sin(Δλ)
        let φ = atan2(sin(φ1) + sin(φ2), sqrt((cos(φ1) + bx) * (cos(φ1) + bx) + by * by))
        let λ = λ1 + atan2(by, cos(φ1) + bx)
        return CLLocationCoordinate2D(latitude: φ * 180 / .pi, longitude: λ * 180 / .pi)
    }

    /// Bir noktadan verilen başlangıç açısıyla `distance` metre gidilince varılan nokta.
    static func destination(from c: CLLocationCoordinate2D, bearing: Double, distance: Double) -> CLLocationCoordinate2D {
        let δ = distance / 6_371_000, θ = bearing * .pi / 180
        let φ1 = c.latitude * .pi / 180, λ1 = c.longitude * .pi / 180
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        return CLLocationCoordinate2D(latitude: φ2 * 180 / .pi, longitude: λ2 * 180 / .pi)
    }

    /// Titremeyi önlemek için histerezisli hizalanma: 3° içinde hizalanır, 6° dışında bozulur.
    static func isAligned(offset: Double, wasAligned: Bool) -> Bool {
        wasAligned ? abs(offset) <= 6 : abs(offset) < 3
    }
}
