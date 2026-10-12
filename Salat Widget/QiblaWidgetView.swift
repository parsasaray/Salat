//
//  QiblaWidgetView.swift
//  Salat Widget
//
//  A widget cannot read the compass, so this shows the Qibla as a map direction:
//  the arrow points where the Qibla is with the top of the widget as north.
//

import SwiftUI
import WidgetKit

/// The Qibla as a dot riding on a ring, with north at the gap at the top. A widget cannot read
/// the compass, so this is a map direction: face north and the dot shows where to turn.
struct QiblaRing: View {
    let bearing: Double
    /// Fraction of the ring's diameter taken by the logo; 0 hides it
    var logoScale: CGFloat = 0.42
    var lineWidth: CGFloat = 3
    var showsNorth = true

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let dot = lineWidth * 2.6
            let radius = size / 2 - dot / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let angle = bearing.radians
            ZStack {
                Circle()
                    .trim(from: 0.045, to: 0.955)
                    .stroke(.primary.opacity(0.4), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                if logoScale > 0 {
                    Image("MosqueGlyph")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * logoScale, height: size * logoScale)
                        .position(center)
                }
                if showsNorth {
                    Text("N")
                        .font(.system(size: max(8, size * 0.13), weight: .bold))
                        .position(x: center.x, y: center.y - radius + dot + 1)
                }
                Circle()
                    .fill(.primary)
                    .frame(width: dot, height: dot)
                    .widgetAccentable()
                    .position(x: center.x + radius * CGFloat(sin(angle)),
                              y: center.y - radius * CGFloat(cos(angle)))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Qibla \(Theme.degrees(bearing))")
    }
}

struct QiblaWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular: return true
        default: return false
        }
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory { Color.clear } else { Theme.background }
            }
    }

    @ViewBuilder
    private var content: some View {
        let snapshot = entry.snapshot
        if !snapshot.hasLocation {
            NeedsLocationView(snapshot: snapshot)
        } else {
            let bearing = snapshot.qiblaBearing
            let point = Qibla.compassPoint(for: bearing)
            switch family {
            case .accessoryInline:
                Label("Qibla \(Theme.degrees(bearing)) \(point)", systemImage: "location.north.fill")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    QiblaRing(bearing: bearing, lineWidth: 2.5)
                        .padding(4)
                }
            default:
                QiblaRing(bearing: bearing)
                    .padding(8)
            }
        }
    }
}
