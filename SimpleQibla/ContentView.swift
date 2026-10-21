import MapKit
import SwiftUI

enum MapMode: CaseIterable {
    case north, compass

    var next: MapMode {
        let all = MapMode.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var icon: String {
        switch self {
        case .north: "location.north.line"
        case .compass: "safari.fill"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .north: "North up"
        case .compass: "Compass"
        }
    }
}

/// Haritanın anlık kamera bilgisi.
/// Harita her karede bunu günceller; yalnızca `heading` gözlemlenir ve onu da
/// sadece kıble oku okur. Böylece ana görünüm her karede yeniden çizilmez.
@MainActor
@Observable
final class CameraState {
    var heading: Double = 0
    @ObservationIgnored var distance: Double = ContentView.closeDistance
    @ObservationIgnored var center: CLLocationCoordinate2D?
    /// Programatik kamera animasyonu bitene kadar pusula takibi haritaya dokunmaz;
    /// aksi halde her yön güncellemesi animasyonu yarıda keser (ör. zoom gerçekleşmez).
    @ObservationIgnored private var animatingUntil = Date.distantPast

    /// Uygulamanın en son istediği kamera. Haritadan gelen değer bundan farklıysa
    /// değişikliği kullanıcı yapıyordur (kaydırma, yakınlaştırma).
    @ObservationIgnored private var expected: MapCamera?
    @ObservationIgnored private var userActiveUntil = Date.distantPast

    /// MapKit bu kamera yüksekliğinin üstünde (≈500 km'den geniş alan) haritayı
    /// döndürmez, yönü kuzeye sabitler. Simülatörde ölçüldü: 1.200 km döner, 2.000 km dönmez.
    static let maxRotatableDistance: Double = 1_500_000

    var canRotate: Bool { distance <= Self.maxRotatableDistance }

    var isAnimating: Bool { Date() < animatingUntil }
    /// Kullanıcı haritayı elle hareket ettiriyor; pusula bu sırada araya girmez.
    var isUserInteracting: Bool { Date() < userActiveUntil }

    func beginAnimation(duration: TimeInterval) {
        animatingUntil = Date().addingTimeInterval(duration + 0.1)
    }

    /// Programatik her kamera değişikliğinden önce çağrılır.
    func expect(_ camera: MapCamera?) {
        expected = camera
    }

    /// Kâbe butonunun yönlü kısmi görünümü; ikinci dokunuşu ayırt etmek için tutulur.
    @ObservationIgnored var partialKaabaTarget: MapCamera?
    static let partialKaabaDistance: Double = 1_200_000

    /// Kısmi görünümdeyiz ve kullanıcı haritayı oynatmadı.
    var isShowingPartialKaabaView: Bool {
        guard let target = partialKaabaTarget, let center else { return false }
        return !Self.differs(target, MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 0))
    }

    func update(_ camera: MapCamera) {
        if !isAnimating, let expected, Self.differs(expected, camera) {
            userActiveUntil = Date().addingTimeInterval(0.8)
        }
        distance = camera.distance
        center = camera.centerCoordinate
        if abs(Qibla.delta(camera.heading, heading)) >= 0.3 {
            heading = camera.heading
        }
    }

    private static func differs(_ a: MapCamera, _ b: MapCamera) -> Bool {
        let moved = CLLocation(latitude: a.centerCoordinate.latitude, longitude: a.centerCoordinate.longitude)
            .distance(from: CLLocation(latitude: b.centerCoordinate.latitude, longitude: b.centerCoordinate.longitude))
        return moved > max(2, a.distance * 0.01) || abs(a.distance - b.distance) > a.distance * 0.02
    }
}

struct ContentView: View {
    @State private var locator = LocationManager()
    @State private var camera = CameraState()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var mode: MapMode = .north
    @State private var didCenter = false
    /// Bkz. `Qibla.isAligned(offset:wasAligned:)`.
    @State private var isAligned = false
    /// iPhone Duo iç ekranında (ve geniş pencerelerde) `.regular` olur.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Geniş ekranda kartlar bu genişliği aşmaz; harita görünür kalır.
    private static let panelWidth: CGFloat = 420

    /// Bina ölçeğinde en yakın zoom (metre cinsinden kamera yüksekliği).
    static let closeDistance: Double = 250

    private var coordinate: CLLocationCoordinate2D? { locator.location?.coordinate }
    private var bearing: Double? { coordinate.map(Qibla.bearing(from:)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            map

            Group {
                if horizontalSizeClass == .regular {
                    // Geniş ekran: kartlar solda dar bir sütunda, butonlar sağ kenarda.
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            hint
                            infoCard
                        }
                        .frame(maxWidth: Self.panelWidth)
                        Spacer(minLength: 0)
                        controls
                    }
                } else {
                    VStack(spacing: 12) {
                        // Yön ipucu butonların solunda durur; böylece alttaki kartın yüksekliği
                        // değişmez ve butonlar kaymaz.
                        HStack(alignment: .bottom, spacing: 12) {
                            hint
                            Spacer(minLength: 0)
                            controls
                        }
                        infoCard
                    }
                }
            }
            .animation(.snappy, value: mode)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background {
            if mode == .compass {
                CompassFollower(locator: locator, camera: camera, position: $position, bearing: bearing, isAligned: $isAligned)
            }
        }
        .background {
            InterfaceOrientationReader { locator.setHeadingOrientation($0) }
        }
        .overlay(alignment: .top) {
            if mode == .compass {
                CompassBanner(locator: locator)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 560 : .infinity)
                    .padding(.top, 8)
            }
        }
        .overlay {
            if locator.authorization == .denied || locator.authorization == .restricted {
                PermissionView()
            }
        }
        .onAppear { locator.start() }
        .onChange(of: locator.location) { _, location in
            guard let location, !didCenter else { return }
            didCenter = true
            setCamera(center: location.coordinate, distance: Self.closeDistance, animated: false)
            #if DEBUG
            // Screenshot için: `-DemoCompass YES` pusula moduna, `-DemoKaaba YES` Kâbe görünümüne geçer.
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "DemoCompass") {
                // Harita yeni kamerayı bildirmeden mod değişirse eski (geniş) görünüme döner.
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    mode = .compass
                }
            }
            if defaults.bool(forKey: "DemoKaaba") {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    fitKaaba()
                }
            }
            #endif
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .compass {
                locator.startHeading()
            } else {
                locator.stopHeading()
                isAligned = false
            }
            // Sadece yön değişir; merkez ve zoom olduğu gibi kalır.
            guard let center = camera.center ?? coordinate else { return }
            setCamera(center: center, distance: camera.distance, animated: true)
        }
        .onChange(of: isAligned) { _, aligned in
            if aligned { Haptics.celebrate() }
        }
    }

    private var map: some View {
        Map(position: $position) {
            if let coordinate, let bearing {
                MapPolyline(coordinates: [coordinate, Qibla.kaaba], contourStyle: .geodesic)
                    .stroke(.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                Annotation("", coordinate: coordinate, anchor: .center) {
                    // Harita döndükçe ok ekranda kıbleyi göstermeye devam eder.
                    QiblaMarker(bearing: bearing, camera: camera, aligned: isAligned)
                }
            }
            Annotation(String(localized: "Kaaba"), coordinate: Qibla.kaaba, anchor: .center) {
                KaabaPin()
            }
        }
        .mapStyle(.hybrid(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            camera.update(context.camera)
        }
        .ignoresSafeArea()
    }

    // MARK: - Kamera

    private func setCamera(center: CLLocationCoordinate2D, distance: Double, animated: Bool) {
        // Pusula modunda harita telefonun baktığı yöne döner (gerçek dünyaya hizalı).
        let heading = mode == .compass && locator.isCompassReliable ? (locator.heading ?? camera.heading) : 0
        let target = MapCamera(centerCoordinate: center, distance: distance, heading: heading, pitch: 0)
        let newPosition = MapCameraPosition.camera(target)
        camera.expect(target)
        if animated {
            camera.beginAnimation(duration: 0.6)
            withAnimation(.easeInOut(duration: 0.6)) { position = newPosition }
        } else {
            position = newPosition
        }
    }

    /// Konuma döner; çok uzaktaysak ya da zaten konumdaysak bina ölçeğine yaklaşır,
    /// değilse zoom korunur. Böylece ikinci dokunuş her zaman yakınlaştırır.
    private func recenter() {
        guard let coordinate else { return }
        let alreadyCentered = camera.center.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) < max(15, camera.distance * 0.05)
        } ?? false
        let distance = camera.distance > 3000 || alreadyCentered ? Self.closeDistance : camera.distance
        setCamera(center: coordinate, distance: distance, animated: true)
    }

    /// Kâbe butonu.
    /// - Kuzey modunda ya da pusula güvenilmezken: kullanıcı ve Kâbe kuzey yukarı sığdırılır.
    /// - Pusula modunda yol dönebilen ölçeğe sığıyorsa: yön korunarak sığdırılır.
    /// - Sığmıyorsa: dönebilen en uzak ölçeğe kadar kıble yönünde uzaklaşılır (Kâbe ekran
    ///   dışında kalır, çizgi yönü gösterir). İkinci dokunuşta tüm yol kuzey yukarı gösterilir.
    /// Her durumda sonrasında harita serbesttir, istenirse gezilebilir.
    private func fitKaaba() {
        guard let coordinate, let bearing else { return }
        let rotating = mode == .compass && locator.isCompassReliable
        let heading = rotating ? (locator.heading ?? camera.heading) : 0
        let span = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: Qibla.kaaba.latitude, longitude: Qibla.kaaba.longitude))
        // Yön keyfi olabildiği için dar kenara (genişliğe) göre sığdırılır.
        let fullDistance = max(span * 3, 2000)

        if rotating, fullDistance <= CameraState.maxRotatableDistance {
            fly(to: MapCamera(centerCoordinate: Qibla.midpoint(coordinate, Qibla.kaaba), distance: fullDistance, heading: heading, pitch: 0))
        } else if rotating, !camera.isShowingPartialKaabaView {
            let distance = CameraState.partialKaabaDistance
            // Kullanıcı ekranda kalacak kadar kıble yönünde ilerlenmiş bir merkez.
            let center = Qibla.destination(from: coordinate, bearing: bearing, distance: distance * 0.05)
            let target = MapCamera(centerCoordinate: center, distance: distance, heading: heading, pitch: 0)
            fly(to: target)
            camera.partialKaabaTarget = target
        } else {
            let a = MKMapPoint(coordinate), b = MKMapPoint(Qibla.kaaba)
            let rect = MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            let padded = rect.insetBy(dx: -rect.width * 0.3 - 1000, dy: -rect.height * 0.45 - 1000)
            camera.expect(nil)
            camera.beginAnimation(duration: 0.8)
            withAnimation(.easeInOut(duration: 0.8)) { position = .rect(padded) }
        }
    }

    private func fly(to target: MapCamera) {
        camera.expect(target)
        camera.beginAnimation(duration: 0.8)
        withAnimation(.easeInOut(duration: 0.8)) { position = .camera(target) }
    }

    // MARK: - Arayüz

    @ViewBuilder
    private var hint: some View {
        if mode == .compass, let bearing {
            CompassHint(locator: locator, bearing: bearing, aligned: isAligned)
                .transition(.opacity.combined(with: .move(edge: .leading)))
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            Button {
                mode = mode.next
            } label: {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(mode.title)
            Divider().frame(width: 48)
            Button {
                fitKaaba()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Show the Kaaba")
            Divider().frame(width: 48)
            Button {
                recenter()
            } label: {
                Image(systemName: "location.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Back to my location")
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var infoCard: some View {
        VStack(spacing: 10) {
            if let bearing {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: mode.icon)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityLabel(mode.title)
                    Text("Qibla")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(Int(bearing.rounded()))°")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(Qibla.cardinal(bearing))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Finding your location…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            LocationNotice(locator: locator)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 2)
        .animation(.snappy, value: mode)
    }
}

// MARK: - Pusula takibi

/// Pusula verisini dinleyip haritayı döndüren görünmez görünüm.
/// Sık değişen yön verisi yalnızca burada okunur; ana görünüm etkilenmez.
private struct CompassFollower: View {
    let locator: LocationManager
    let camera: CameraState
    @Binding var position: MapCameraPosition
    let bearing: Double?
    @Binding var isAligned: Bool

    var body: some View {
        Color.clear
            .onChange(of: locator.heading) { _, heading in
                guard let heading else {
                    isAligned = false
                    return
                }
                // Hassasiyet düşükken pusula kapalıdır; harita kuzeyde sabit kalır.
                if locator.isCompassReliable, camera.canRotate, !camera.isAnimating, !camera.isUserInteracting {
                    rotate(to: heading, animated: false)
                }
                updateAlignment(heading: heading)
            }
            .onChange(of: locator.isCompassReliable) { _, reliable in
                // Pusula kapanırken kuzeye, düzelince yeniden telefonun yönüne yumuşakça döner.
                rotate(to: reliable ? (locator.heading ?? 0) : 0, animated: true)
            }
    }

    private func rotate(to heading: Double, animated: Bool) {
        guard let center = camera.center ?? locator.location?.coordinate else { return }
        let target = MapCamera(centerCoordinate: center, distance: camera.distance, heading: heading, pitch: 0)
        let newPosition = MapCameraPosition.camera(target)
        camera.expect(target)
        if animated {
            camera.beginAnimation(duration: 0.5)
            withAnimation(.easeInOut(duration: 0.5)) { position = newPosition }
        } else {
            position = newPosition
        }
    }

    private func updateAlignment(heading: Double) {
        // Pusula güvenilir değilken "hizalandınız" demek yanıltıcı olur.
        guard let bearing, locator.isCompassReliable else {
            if isAligned { isAligned = false }
            return
        }
        let aligned = Qibla.isAligned(offset: Qibla.delta(bearing, heading), wasAligned: isAligned)
        if aligned != isAligned { isAligned = aligned }
    }
}

/// Arayüzün o anki yönünü pusulaya bildirir. iPhone Duo'nun iç ekranı uygulamanın
/// dikey kilidini dikkate almaz; yatay açıldığında yön buna göre düzeltilmezse
/// harita ve ok 90° yanlış döner.
private struct InterfaceOrientationReader: UIViewRepresentable {
    let onChange: (CLDeviceOrientation) -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: ((CLDeviceOrientation) -> Void)?
        private var observation: NSKeyValueObservation?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Ekran geometrisi değiştikçe (döndürme, açma/kapama) yeniden okunur.
            observation = window?.windowScene?.observe(\.effectiveGeometry, options: [.initial, .new]) { [weak self] scene, _ in
                let orientation = scene.effectiveGeometry.interfaceOrientation
                MainActor.assumeIsolated { self?.report(orientation) }
            }
        }

        private func report(_ orientation: UIInterfaceOrientation) {
            // UIKit tanımı gereği arayüz yatay-sol iken cihaz yatay-sağdadır.
            let device: CLDeviceOrientation = switch orientation {
            case .portraitUpsideDown: .portraitUpsideDown
            case .landscapeLeft: .landscapeRight
            case .landscapeRight: .landscapeLeft
            default: .portrait
            }
            onChange?(device)
        }
    }
}

/// Pusula modunda butonların solunda duran yön ipucu.
private struct CompassHint: View {
    let locator: LocationManager
    let bearing: Double
    let aligned: Bool

    var body: some View {
        Group {
            if locator.heading != nil, !locator.isCompassReliable {
                note("The map is fixed to north; the compass will turn back on once it's accurate again.", icon: "location.north.line")
            } else if let heading = locator.heading {
                turn(offset: Qibla.delta(bearing, heading))
            } else if !CLLocationManager.headingAvailable() {
                note("This device has no compass.", icon: "safari")
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Preparing compass…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: 230, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func turn(offset: Double) -> some View {
        let degrees = Int(abs(offset).rounded())
        let tint: Color = aligned ? .green : .accentColor
        return HStack(spacing: 12) {
            // Telefonun üst kenarına göre kıblenin nerede olduğunu gösteren ok.
            ZStack {
                Circle().fill(tint.opacity(0.15))
                Image(systemName: aligned ? "checkmark" : "location.north.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(aligned ? 0 : offset))
            }
            .frame(width: 44, height: 44)
            // Açı fiziksel bir yön; Arapçada aynalanmamalı.
            .environment(\.layoutDirection, .leftToRight)
            .animation(.snappy, value: aligned)

            VStack(alignment: .leading, spacing: 2) {
                if aligned {
                    Text("You're facing the Qibla")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: offset > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(tint)
                        .environment(\.layoutDirection, .leftToRight)
                    Group {
                        if offset > 0 {
                            Text("Turn \(degrees)° right")
                        } else {
                            Text("Turn \(degrees)° left")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func note(_ text: LocalizedStringKey, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Hassasiyet uyarıları

/// Pusula güvenilmez olduğunda ekranın üstünde açık şekilde duran bilgi.
/// Hassasiyet düzelince kendiliğinden kaybolur.
private struct CompassBanner: View {
    let locator: LocationManager

    var body: some View {
        Group {
            if let issue = locator.compassIssue {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: issue == .interference ? "exclamationmark.triangle.fill" : "gyroscope")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeat(2), value: issue)
                    VStack(alignment: .leading, spacing: 4) {
                        Group {
                            if issue == .interference {
                                Text("Compass is being disturbed")
                            } else {
                                Text("Low compass accuracy")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        Group {
                            if issue == .interference {
                                Text("Nearby metal objects, magnetic cases or electronics can throw off the direction. Move your phone a little away from them.")
                            } else {
                                Text("Move your phone in a figure 8 a few times; the direction will correct itself.")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if issue == .needsCalibration {
                        FigureEightHint()
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 2)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }
        }
        .animation(.snappy, value: locator.compassIssue)
    }
}

/// Konum hassasiyeti düştüğünde kartın içinde beliren sade satır.
/// Dokununca ne olduğunu ve ne yapılabileceğini kısaca anlatır.
private struct LocationNotice: View {
    let locator: LocationManager
    @State private var expanded = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let issue = locator.locationIssue {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.snappy) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .foregroundStyle(.orange)
                            title(issue)
                                .font(.footnote.weight(.semibold))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(expanded ? Text("Hide details") : Text("Show details"))

                    if expanded {
                        detail(issue)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
        }
        .animation(.snappy, value: locator.locationIssue == nil)
    }

    private func title(_ issue: LocationIssue) -> Text {
        if issue.affectsDirection {
            Text("Low location accuracy (±\(Self.distance(issue.accuracy)))")
        } else {
            Text("Your location is approximate (±\(Self.distance(issue.accuracy)))")
        }
    }

    private func detail(_ issue: LocationIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if issue.affectsDirection {
                Text("The direction may be off by about \(max(1, Int(issue.angularError.rounded())))°. Moving to an open area or near a window helps.")
            } else {
                Text("The Qibla direction isn't affected; only your position on the map may be slightly off.")
            }
            if issue.isReducedAccuracy {
                Button("Turn On Precise Location") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

/// Telefonun 8 çizerek hareket ettirilmesini gösteren küçük animasyon.
private struct FigureEightHint: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate * 1.8
            ZStack {
                Lemniscate()
                    .stroke(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Image(systemName: "iphone")
                    .font(.system(size: 16, weight: .medium))
                    .rotationEffect(.radians(cos(t) * 0.5))
                    .offset(x: 30 * sin(t), y: 30 * sin(t) * cos(t))
            }
        }
        .frame(width: 76, height: 36)
        .accessibilityHidden(true)
    }
}

private struct Lemniscate: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let a = r.width / 2 - 8
        for i in 0...64 {
            let t = Double(i) / 64 * 2 * .pi
            let pt = CGPoint(x: r.midX + a * sin(t), y: r.midY + a * sin(t) * cos(t))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}

// MARK: - Harita işaretleri

/// Kamera yönünü yalnızca bu görünüm okur; harita döndükçe sadece ok yeniden çizilir.
private struct QiblaMarker: View {
    let bearing: Double
    let camera: CameraState
    let aligned: Bool

    var body: some View {
        QiblaArrow(angle: bearing - camera.heading, aligned: aligned)
            // Açı coğrafi; sağdan sola dillerde aynalanırsa ok yanlış yönü gösterir.
            .environment(\.layoutDirection, .leftToRight)
    }
}

struct QiblaArrow: View {
    var angle: Double
    var aligned: Bool

    var body: some View {
        ZStack {
            ArrowShape()
                .fill(aligned ? Color.green : Color.red)
                .overlay(ArrowShape().stroke(.white, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
                .frame(width: 84, height: 108)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                .offset(y: -80)
            Circle().fill(.white).frame(width: 24, height: 24)
            Circle().fill(aligned ? Color.green : Color.red).frame(width: 15, height: 15)
        }
        .frame(width: 280, height: 280)
        // Gölgeli ok tek katmanda hazırlanır; dönüş yalnızca dönüşüm olarak uygulanır.
        .drawingGroup()
        .rotationEffect(.degrees(angle))
        .scaleEffect(aligned ? 1.15 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: aligned)
        .allowsHitTesting(false)
    }
}

struct ArrowShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.68, y: r.minY + r.height * 0.5))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.68, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.minY + r.height * 0.5))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5))
        p.closeSubpath()
        return p
    }
}

struct KaabaPin: View {
    private let gold = Color(red: 0.83, green: 0.69, blue: 0.30)

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color(white: 0.08))
            Rectangle().fill(gold).frame(height: 4).padding(.top, 7)
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

struct PermissionView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text("Location Access Needed")
                .font(.title2.weight(.bold))
            Text("We need access to your location to show the Qibla direction.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(32)
    }
}

#Preview {
    ContentView()
}

enum Haptics {
    /// Kıbleye hizalanınca kısa bir titreşim dizisi.
    static func celebrate() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        let notify = UINotificationFeedbackGenerator()
        impact.prepare()
        notify.prepare()
        impact.impactOccurred(intensity: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { impact.impactOccurred(intensity: 0.8) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { impact.impactOccurred(intensity: 0.6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { notify.notificationOccurred(.success) }
    }
}
