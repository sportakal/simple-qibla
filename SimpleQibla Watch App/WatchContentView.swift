import CoreLocation
import SwiftUI
import WatchKit

/// Saat ekranı: pusula kadranı, Kâbe'yi gösteren ibre ve kısa yön ipucu.
struct WatchContentView: View {
    @State private var locator = LocationManager()
    @State private var isAligned = false
    @Environment(\.scenePhase) private var scenePhase

    private var bearing: Double? { locator.location.map { Qibla.bearing(from: $0.coordinate) } }

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if let bearing {
                        ToolbarItem(placement: .topBarLeading) {
                            Text("\(Int(bearing.rounded()))° \(Qibla.cardinal(bearing))")
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                }
        }
        .onAppear { locator.start() }
        // Pusula yalnızca ekran açıkken çalışır; pil tasarrufu.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                locator.startHeading()
            } else {
                locator.stopHeading()
                isAligned = false
            }
        }
        .onChange(of: locator.heading) { _, heading in
            guard let heading, let bearing, locator.isCompassReliable else {
                if isAligned { isAligned = false }
                return
            }
            let aligned = Qibla.isAligned(offset: Qibla.delta(bearing, heading), wasAligned: isAligned)
            if aligned != isAligned { isAligned = aligned }
        }
        .onChange(of: isAligned) { _, aligned in
            if aligned { WKInterfaceDevice.current().play(.success) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if locator.authorization == .denied || locator.authorization == .restricted {
            ScrollView {
                VStack(spacing: 8) {
                    Image(systemName: "location.slash.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text("Location Access Needed")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Allow location access in Settings to see the Qibla direction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else if let bearing {
            compass(bearing: bearing)
        } else {
            VStack(spacing: 8) {
                ProgressView()
                Text("Finding your location…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compass(bearing: Double) -> some View {
        // Pusula güvenilmezse kadran kuzeye sabitlenir; kullanıcı açıyı kendisi bulur.
        let heading = locator.isCompassReliable ? locator.heading : nil
        return VStack(spacing: 2) {
            WatchDial(heading: heading ?? 0, bearing: bearing, aligned: isAligned)
            hint(bearing: bearing, heading: heading)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 36)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func hint(bearing: Double, heading: Double?) -> some View {
        if let heading {
            let offset = Qibla.delta(bearing, heading)
            let degrees = Int(abs(offset).rounded())
            if isAligned {
                Label("You're facing the Qibla", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if offset > 0 {
                Label("Turn \(degrees)° right", systemImage: "arrow.turn.up.right")
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                Label("Turn \(degrees)° left", systemImage: "arrow.turn.up.left")
                    .environment(\.layoutDirection, .leftToRight)
            }
        } else if let issue = locator.compassIssue, locator.heading != nil {
            VStack(spacing: 0) {
                Text(issue == .interference ? "Compass is being disturbed" : "Low compass accuracy")
                    .foregroundStyle(.orange)
                Text(issue == .interference ? "Move away from metal or magnets." : "Move your wrist in a figure 8.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if !CLLocationManager.headingAvailable() {
            Text("Face \(Int(bearing.rounded()))° from north.")
                .foregroundStyle(.secondary)
        } else {
            Text("Preparing compass…")
                .foregroundStyle(.secondary)
        }
    }
}

/// Bileğin yönüyle dönen kadran; ibre ve Kâbe işareti kıbleyi gösterir.
struct WatchDial: View {
    var heading: Double
    var bearing: Double
    var aligned: Bool

    private let gold = Color(red: 0.87, green: 0.73, blue: 0.42)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let angle = (bearing - heading) * .pi / 180
            let tint: Color = aligned ? .green : .accentColor

            ZStack {
                // Dış halka ve kuzey işareti cihazın yönüyle döner.
                ZStack {
                    ForEach(0..<72, id: \.self) { i in
                        let major = i % 18 == 0
                        Capsule()
                            .fill(major ? Color.primary : Color.secondary.opacity(0.5))
                            .frame(width: major ? 2.5 : 1.2, height: major ? 9 : 5)
                            .offset(y: -radius + (major ? 5 : 3))
                            .rotationEffect(.degrees(Double(i) * 5))
                    }
                    Text(Qibla.cardinal(0))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .offset(y: -radius + 20)
                }
                .rotationEffect(.degrees(-heading))

                // İbre
                WatchNeedle()
                    .fill(tint)
                    .frame(width: size * 0.13, height: size * 0.56)
                    .rotationEffect(.radians(angle))
                Circle()
                    .fill(.black)
                    .frame(width: size * 0.07, height: size * 0.07)

                // Kâbe işareti halka üzerinde dik durur.
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.08))
                    .overlay(alignment: .top) {
                        Rectangle().fill(gold).frame(height: 2.5).padding(.top, 4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(aligned ? .green : gold, lineWidth: 1.5))
                    .frame(width: 17, height: 17)
                    .offset(x: (radius - 26) * sin(angle), y: -(radius - 26) * cos(angle))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Açılar coğrafi; sağdan sola dillerde aynalanmamalı.
            .environment(\.layoutDirection, .leftToRight)
            .animation(.snappy, value: aligned)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Qibla"))
        .accessibilityValue(Text("\(Int(bearing.rounded()))°"))
    }
}

/// Merkezden kıbleye uzanan ok başlı ibre.
struct WatchNeedle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.midY + r.height * 0.12))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    WatchDial(heading: 40, bearing: 152, aligned: false)
}
