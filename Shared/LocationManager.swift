import CoreLocation
import Observation

/// Pusula verisinin güvenilirliğiyle ilgili kullanıcıya gösterilecek durum.
enum CompassIssue: Equatable {
    /// Yakında mıknatıs/metal var; manyetik alan olağandışı.
    case interference
    /// Sensör kalibre değil ya da sapma payı yüksek.
    case needsCalibration
}

/// Konum hassasiyetiyle ilgili kullanıcıya gösterilecek durum.
struct LocationIssue: Equatable {
    /// Metre cinsinden yatay hata payı.
    var accuracy: Double
    /// Bu hata payının kıble açısında yaratabileceği en büyük sapma (derece).
    var angularError: Double
    /// Kullanıcı "Yaklaşık Konum" izni vermiş.
    var isReducedAccuracy: Bool

    /// Yön pratikte etkilenmiyorsa yalnızca haritadaki nokta kayar.
    var affectsDirection: Bool { angularError >= 1 }
}

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    /// Yumuşatılmış pusula yönü (gerçek kuzeye göre, 0–360).
    var heading: Double?
    var authorization: CLAuthorizationStatus = .notDetermined
    var compassIssue: CompassIssue?
    var locationIssue: LocationIssue?

    /// Pusula sapma payı kabul edilebilir mi (hizalanma titreşimi bu durumda verilir).
    var isCompassReliable: Bool { heading != nil && compassIssue == nil }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var smoothed: (x: Double, y: Double)?
    @ObservationIgnored private var pendingIssue: CompassIssue?
    @ObservationIgnored private var pendingSince: Date?

    /// Uyarının görünmesi ve kaybolması için durumun ne kadar sürmesi gerektiği.
    /// Anlık dalgalanmalar kullanıcıyı rahatsız etmesin diye.
    private static let showDelay: TimeInterval = 1.5
    private static let hideDelay: TimeInterval = 1.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        // Ham verinin tamamını alıp kendimiz yumuşatıyoruz; yayınlama ayrıca seyreltiliyor.
        manager.headingFilter = kCLHeadingFilterNone
        authorization = manager.authorizationStatus
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func startHeading() {
        #if DEBUG
        // Screenshot için: simülatörde pusula yok; `-DemoHeading <derece>` sabit bir yön verir.
        let demo = UserDefaults.standard.double(forKey: "DemoHeading")
        if demo != 0 {
            // Gerçek pusula gibi sürekli yayınlanır; tek seferlik değer konumdan önce gelip kaçabilir.
            Task { [weak self] in
                var tick = false
                while let self, !Task.isCancelled {
                    self.heading = demo + (tick ? 0.01 : 0)
                    tick.toggle()
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }
            return
        }
        #endif
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    #if os(iOS)
    /// Pusula yönü ekranın üst kenarına göre hesaplanmalı. iPhone Duo'nun iç ekranı
    /// desteklenen yönleri dikkate almaz; arayüz yatay da açılabilir.
    func setHeadingOrientation(_ orientation: CLDeviceOrientation) {
        guard manager.headingOrientation != orientation else { return }
        manager.headingOrientation = orientation
        // Eski yöne göre yumuşatılmış değer 90° geriden gelmesin.
        smoothed = nil
    }
    #endif

    func stopHeading() {
        manager.stopUpdatingHeading()
        heading = nil
        smoothed = nil
        compassIssue = nil
        pendingIssue = nil
        pendingSince = nil
    }

    // MARK: - Pusula

    private func handle(heading raw: Double, accuracy: Double, field: Double) {
        // Açıları birim çember üzerinde yumuşatırız; böylece 359° → 1° geçişi sorunsuz olur.
        let r = raw * .pi / 180
        let alpha = 0.22
        if let s = smoothed {
            smoothed = (s.x + alpha * (cos(r) - s.x), s.y + alpha * (sin(r) - s.y))
        } else {
            smoothed = (cos(r), sin(r))
        }
        let value = (atan2(smoothed!.y, smoothed!.x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)

        // Gereksiz arayüz güncellemelerini önlemek için küçük değişimleri yayınlamayız.
        if heading.map({ abs(Qibla.delta(value, $0)) >= 0.4 }) ?? true {
            heading = value
        }

        updateCompassIssue(accuracy: accuracy, field: field)
    }

    private func updateCompassIssue(accuracy: Double, field: Double) {
        // Dünya'nın manyetik alanı yaklaşık 25–65 µT; çok dışı parazit demektir.
        let interfered = field > 0 && (field > 120 || field < 12)
        let candidate: CompassIssue?
        if interfered {
            candidate = .interference
        } else if accuracy < 0 || accuracy > (compassIssue == nil ? 25 : 18) {
            // Histerezis: uyarı göründükten sonra kaybolması için daha iyi bir değer beklenir.
            candidate = .needsCalibration
        } else {
            candidate = nil
        }

        guard candidate != compassIssue else {
            pendingIssue = nil
            pendingSince = nil
            return
        }
        let now = Date()
        if candidate != pendingIssue || pendingSince == nil {
            pendingIssue = candidate
            pendingSince = now
            return
        }
        let delay = candidate == nil ? Self.hideDelay : Self.showDelay
        if now.timeIntervalSince(pendingSince!) >= delay {
            compassIssue = candidate
            pendingIssue = nil
            pendingSince = nil
        }
    }

    // MARK: - Konum

    private func handle(location new: CLLocation) {
        location = new
        let accuracy = new.horizontalAccuracy
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        guard accuracy >= 0 else { return }

        let distance = new.distance(from: CLLocation(latitude: Qibla.kaaba.latitude, longitude: Qibla.kaaba.longitude))
        let angular = atan(accuracy / max(distance, 1)) * 180 / .pi
        // Haritadaki nokta belirgin şekilde kayıyorsa ya da yön etkileniyorsa bildir.
        let threshold = locationIssue == nil ? 200.0 : 120.0
        if reduced || accuracy > threshold || angular >= 1 {
            locationIssue = LocationIssue(accuracy: accuracy, angularError: angular, isReducedAccuracy: reduced)
        } else {
            locationIssue = nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
            if let location { handle(location: location) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        MainActor.assumeIsolated { handle(location: last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let raw = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        let field = sqrt(newHeading.x * newHeading.x + newHeading.y * newHeading.y + newHeading.z * newHeading.z)
        MainActor.assumeIsolated { handle(heading: raw, accuracy: accuracy, field: field) }
    }

    /// Sistemin tam ekran kalibrasyon penceresi yerine kendi sade uyarımızı gösteririz.
    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { false }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
