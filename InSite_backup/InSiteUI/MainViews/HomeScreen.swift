import Foundation
import HealthKit
import HealthKitUI
import SwiftUI
import Combine

//Home Screen

struct HealthAuthView: View {
    var body: some View {
        HomeScreen(showSignInView: .constant(false))
    }
}
struct ContentPreview: PreviewProvider {
  static var previews: some View {
    HealthAuthView()
      .environmentObject(ThemeManager())
  }
}

extension View {
    func pressable(scale: CGFloat = 0.98) -> some View {
        modifier(Pressable(scale: scale))
    }
}
struct Pressable: ViewModifier {
    @GestureState private var pressed = false
    var scale: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? scale : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
            )
    }
}

private struct InnerWindow<Content: View>: View {
    var diameter: CGFloat
    var insetFactor: CGFloat = 0.72   // 72% of circle width; tweak 0.70–0.78
    @ViewBuilder var content: Content

    var body: some View {
        let w = diameter * insetFactor
        VStack(spacing: 6) {
            content
        }
        .multilineTextAlignment(.center)
        .frame(width: w, height: w * 0.72, alignment: .center)   // rectangle “window”
        .padding(.horizontal, 2)
    }
}




private struct MoodCTAOrb: View {
    var accent: Color
    var title: String

    @ScaledMetric private var size: CGFloat = 60
    @State private var breathe: CGFloat = 0
    @State private var shimmer: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                Circle()
                    .stroke(AngularGradient(
                        gradient: Gradient(colors: [accent.opacity(0.9), accent.opacity(0.3), accent.opacity(0.9)]),
                        center: .center),
                        lineWidth: 2.5
                    )
                    .rotationEffect(.degrees(Double(shimmer)))
                Circle()
                    .fill(accent.gradient)
                    .frame(width: size * 0.65, height: size * 0.65)
                    .scaleEffect(1 + 0.02 * breathe)
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
                    .overlay(
                        Image(systemName: "face.smiling")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    )
            }
            .frame(width: size, height: size)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                    breathe = 1
                }
                withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                    shimmer = 360
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text("Open mood check-in").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}





// MARK: - Therapy Carousel Tile

struct TherapyCarouselTile: View {
    enum Metric: Int, CaseIterable { case basal, isf, cr }

    var activeRange: HourRange?
    var accent: Color

    // Current values
    var basalUph: Double
    var isf: Double
    var carbRatio: Double

    // Optional 3–7 point day-patterns for tiny sparklines (normalized in-view)
    var basalPattern: [Double]? = nil
    var isfPattern: [Double]? = nil
    var crPattern: [Double]? = nil

    

    // Layout
    @ScaledMetric private var diameter: CGFloat = 140
    @ScaledMetric private var ringStroke: CGFloat = 8
    @ScaledMetric private var trackStroke: CGFloat = 10
    @ScaledMetric private var nowDot: CGFloat = 6
    @ScaledMetric private var pieInset: CGFloat = 18

    // Carousel state
    @State private var index: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var lastInteraction: Date = Date()
    @State private var autoAdvanceTick: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var currentMetric: Metric {
        Metric.allCases[index % Metric.allCases.count]
    }

    var body: some View {
        CircleTileBase(diameter: diameter) {
            ZStack {
                // Track ring
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: trackStroke)

                // Active window arc
                if let r = activeRange {
                    TherapyArc(range: r)
                        .stroke(
                            LinearGradient(colors: [accent.opacity(0.85), accent.opacity(0.45)],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                        )
                        .frame(width: diameter * 0.78, height: diameter * 0.78)
                }

//
                let innerW = diameter * 0.74     // safe width inside ring
                let innerH = diameter * 0.62     // safe height; tweak 0.58–0.66

                VStack(spacing: 8) {

                  // Slide content (title + value+unit)
                  SlideStack(index: $index, dragOffset: $dragOffset, reduceMotion: reduceMotion) {
                    ForEach(Array(Metric.allCases.enumerated()), id: \.offset) { _, m in
                      VStack(spacing: 6) {
                        Text(title(for: m))
                          .font(.caption2.weight(.semibold))
                          .foregroundStyle(.secondary)
                          .lineLimit(1)

                        HStack(spacing: 6) {
                          Text(value(for: m))
                            .font(.title3.weight(.semibold))
                            .minimumScaleFactor(0.75)
                          Text(unit(for: m))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .baselineOffset(2)
                        }
                        .lineLimit(1)
                      }
                      .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                  }
                  .simultaneousGesture(swipeGesture)   // don’t block NavigationLink
                  .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: index)

                  // Dots
                  HStack(spacing: 8) {
                    ForEach(0..<Metric.allCases.count, id: \.self) { i in
                      IndicatorDot(active: i == index, accent: accent)
                    }
                  }
                  .padding(.bottom, 2) // tiny air above ring
                }
                .frame(width: innerW, height: innerH)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            lastInteraction = Date()
        }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            // Pause auto-advance ~7s after last interaction
            if Date().timeIntervalSince(lastInteraction) >= 7 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    index = (index + 1) % Metric.allCases.count
                }
            }
            autoAdvanceTick &+= 1
        }
    }

    // MARK: - Timer (every ~3.7s)
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 3.7, on: .main, in: .common).autoconnect()
    }

    // MARK: - Swipe
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { v in
                dragOffset = v.translation.width
            }
            .onEnded { v in
                defer {
                    dragOffset = 0
                    lastInteraction = Date() // pause auto-advance
                }
                let threshold: CGFloat = 40
                if v.translation.width < -threshold {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.18)) {
                        index = (index + 1) % Metric.allCases.count
                    }
                } else if v.translation.width > threshold {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.18)) {
                        index = (index - 1 + Metric.allCases.count) % Metric.allCases.count
                    }
                }
            }
    }

    // MARK: - Helpers
    private func value(for metric: Metric) -> String {
        switch metric {
        case .basal: return String(format: "%.2f", basalUph)
        case .isf:   return String(format: "%.0f", isf)
        case .cr:    return String(format: "%.1f", carbRatio)
        }
    }
    private func unit(for metric: Metric) -> String {
        switch metric {
        case .basal: return "U/hr"
        case .isf:   return "mg/dL/U"
        case .cr:    return "g/U"
        }
    }
    private func title(for metric: Metric) -> String {
        switch metric {
        case .basal: return "Basal now"
        case .isf:   return "ISF now"
        case .cr:    return "CR now"
        }
    }
    private func sparkline(for metric: Metric) -> [Double]? {
        switch metric {
        case .basal: return normalized(basalPattern)
        case .isf:   return normalized(isfPattern)
        case .cr:    return normalized(crPattern)
        }
    }
    private func normalized(_ arr: [Double]?) -> [Double]? {
        guard let arr, arr.count >= 3 else { return nil }
        let minV = arr.min() ?? 0, maxV = arr.max() ?? 1
        let denom = max(maxV - minV, .leastNonzeroMagnitude)
        return arr.map { ($0 - minV) / denom }
    }

    private var accessibilityLabel: String {
        let m = currentMetric
        let valueText = value(for: m) + " " + unit(for: m)
        if let r = activeRange {
            return "Therapy. \(title(for: m)), \(valueText). Active \(fmt(r.startHour))–\(fmt(r.endHour))."
        } else {
            return "Therapy. \(title(for: m)), \(valueText)."
        }
    }
    private func fmt(_ h: Int) -> String {
        let hour = ((h % 24) + 24) % 24
        let f = DateFormatter(); f.dateFormat = "h a"
        var comp = DateComponents(); comp.hour = hour
        let cal = Calendar(identifier: .gregorian)
        return f.string(from: cal.date(from: comp) ?? Date())
    }
}

// MARK: - Slide view
// Update SlideView signature
private struct SlideView: View {
    var metric: TherapyCarouselTile.Metric
    var value: String
    var unit: String
    var title: String
    var accent: Color
    var sparkline: [Double]?
    var innerDiameter: CGFloat   // ← new

    var body: some View {
        InnerWindow(diameter: innerDiameter) {   // ← use passed size
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(value).font(.title3.weight(.semibold))
                    .minimumScaleFactor(0.7)
                Text(unit).font(.caption2).foregroundStyle(.secondary)
                    .baselineOffset(2)
            }
            .lineLimit(1)

            if let spark = sparkline, spark.count > 1 {
                Sparkline(points: spark)
                    .stroke(accent.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(height: 14)
                    .padding(.top, 2)
            } else {
                Color.clear.frame(height: 14).padding(.top, 2)
            }
        }
        .padding(.bottom, 4) // a little extra lift off the ring
    }
}


// MARK: - SlideStack (simple pager with drag offset)

private struct SlideStack<Content: View>: View {
    @Binding var index: Int
    @Binding var dragOffset: CGFloat
    var reduceMotion: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                content()
                    .frame(width: width)
            }
            .offset(x: -CGFloat(index) * width + dragOffset)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: index)
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.25, dampingFraction: 0.9), value: dragOffset)
        }
        .clipped()
    }
}

// MARK: - Indicator

private struct IndicatorDot: View {
    var active: Bool
    var accent: Color
    var body: some View {
        Circle()
            .fill(active ? accent.opacity(0.95) : accent.opacity(0.25))
            .frame(width: 6, height: 6)
    }
}

// MARK: - Sparkline Shape (0...1 points)

private struct Sparkline: Shape {
    var points: [Double]
    func path(in rect: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        var p = Path()
        let stepX = rect.width / CGFloat(points.count - 1)
        let ys = points.map { rect.height * (1 - CGFloat($0)) } // invert (0 at bottom)
        p.move(to: CGPoint(x: 0, y: ys[0]))
        for i in 1..<points.count {
            p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: ys[i]))
        }
        return p
    }
}







struct ActivityItem: Identifiable {
    enum Kind { case site, sync, therapy, note }
    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String?
    let time: Date
}

private struct ActivityTimeline: View {
    var items: [ActivityItem]
    var accent: Color

    @ScaledMetric private var dot: CGFloat = 8
    @ScaledMetric private var pad: CGFloat = 12
    @ScaledMetric private var lineW: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: pad) {
            Text("Recent activity")
                .font(.headline)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: pad) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        // timeline rail + dot
                        VStack {
                            Circle()
                                .fill(color(for: item.kind, accent: accent))
                                .frame(width: dot, height: dot)
                                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                            Rectangle()
                                .fill(
                                    LinearGradient(colors: [
                                        color(for: item.kind, accent: accent).opacity(0.5),
                                        .clear
                                    ], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: lineW)
                                .opacity(0.5)
                                .padding(.top, 2)
                            Spacer(minLength: 0)
                        }

                        // content
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: icon(for: item.kind))
                                    .imageScale(.small)
                                    .foregroundStyle(color(for: item.kind, accent: accent))
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            if let detail = item.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)
                            }
                            Text(timeString(item.time))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func icon(for kind: ActivityItem.Kind) -> String {
        switch kind {
        case .site: return "bandage.fill"
        case .sync: return "arrow.triangle.2.circlepath"
        case .therapy: return "cross.case.fill"
        case .note: return "note.text"
        }
    }
    private func color(for kind: ActivityItem.Kind, accent: Color) -> Color {
        switch kind {
        case .site: return accent
        case .sync: return accent.opacity(0.9)
        case .therapy: return accent.opacity(0.8)
        case .note: return .secondary
        }
    }
    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f.string(from: date)
    }
}



// MARK: - HOME

struct HomeScreen: View {
    @Binding var showSignInView: Bool
    

    // Models
    @ObservedObject private var site = SiteChangeData.shared
    
    @StateObject private var therapyVM = TherapyVM()

    
    @State private var lastSyncText = "Synced recently"
    @State private var therapySummary = "Profile 1 · Basal 0.9–1.1"
    @State private var isSyncing = false
    @State private var syncTick = 0
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: HomeTheme { themeManager.theme }  // computed proxy
    // Layout
    @ScaledMetric private var gridMin: CGFloat = 220
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: gridMin), spacing: 16)] }

    var body: some View {
        NavigationStack {
            ZStack {
                BreathingBackground(theme: theme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // HERO HEADER
                        HeroHeader(accent: theme.accent, lastSyncText: lastSyncText)

                        // CIRCULAR TILES
                        FlowLayout(alignment: .center, spacing: 16) {
                            // Site Change (countdown to 3 days)
                            NavigationLink { SiteChangeUI() } label: {
                                                            SiteChangeTile(
                                                                daysSince: site.daysSinceSiteChange,
                                                                location: site.siteChangeLocation,
                                                                accent: theme.accent
                                                            )
                                                            .floatAndPulse(seed: 0.11)
//                                                            .pressable()
                                                        }
                            .buttonStyle(.plain)
                            
                            // Community (board + crosswords)
                            NavigationLink {
                                CommunityHub()   // ← no accent param now
                            } label: {
                                CommunityTile(accent: theme.accent).floatAndPulse(seed: 0.21)
                            }
                            .buttonStyle(.plain)



                            // Therapy (24h ticks + active window hint)
                            NavigationLink { TherapySettings() } label: {
                                TherapyCarouselTile(
                                        activeRange: therapyVM.currentHourRange,
                                        accent: theme.accent,
                                        basalUph: therapyVM.currentBasal,
                                        isf: therapyVM.currentISF,
                                        carbRatio: therapyVM.currentCarbRatio,
                                        basalPattern: therapyVM.sparklineBasal,   // optional: [Double]? or nil
                                        isfPattern: therapyVM.sparklineISF,       // optional: [Double]? or nil
                                        crPattern: therapyVM.sparklineCR          // optional: [Double]? or nil
                                    )
                                .floatAndPulse(seed: 0.57)
                            }
                            .buttonStyle(.plain)

                            // Sync (liquid-ish wave when syncing)
                            Button {
                                guard !isSyncing else { return }
                                isSyncing = true
                                DataManager.shared.syncHealthData {
                                    isSyncing = false
                                    lastSyncText = "Synced just now"
                                    syncTick &+= 1
                                }
                            } label: {
                                SyncTile(
                                    isSyncing: isSyncing,
                                    accent: theme.accent
                                ).floatAndPulse(seed: 0.97)
                            }
                            .buttonStyle(.plain)
                            .applySuccessHaptic(trigger: syncTick)
                        }
                        .padding(.horizontal, 16)

                        // Recent activity (kept simple for now)
                        let feed: [ActivityItem] = [
                            .init(kind: .site, title: "Site changed", detail: site.siteChangeLocation, time: Date().addingTimeInterval(-60*45)),
                            .init(kind: .sync, title: "Background sync completed", detail: "Health data up to date", time: Date().addingTimeInterval(-60*60*3)),
                            .init(kind: .therapy, title: "Therapy profile confirmed", detail: therapyVM.summaryText, time: Date().addingTimeInterval(-60*60*5))
                        ]

                        ActivityTimeline(items: feed, accent: theme.accent)
                            .padding(.horizontal, 16)

                        // CTA → Mood
                        NavigationLink {
                            MoodPicker()
                        } label: {
                            MoodCTAOrb(accent: theme.accent, title: "How are you feeling?")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(showSignInView: $showSignInView)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.medium)
                            .accessibilityLabel("Settings")
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .task {
                            DataManager.shared.requestAuthorization { _ in }
                            therapyVM.reload()   // ensure it loads on first appear
                        }
            .task {
                DataManager.shared.requestAuthorization { _ in }
            }
        }
    }
}

// MARK: - HERO HEADER

private struct HeroHeader: View {
    var accent: Color
    @ScaledMetric(relativeTo: .title3) private var orbSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title3) private var bearSize: CGFloat = 42

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbBreath: CGFloat = 0

    var lastSyncText: String

    var body: some View {
        HStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("InSite").font(.title2.weight(.semibold))
                    // Mood orb
                    Circle()
                        .fill(accent.gradient)
                        .frame(width: orbSize, height: orbSize)
                        .scaleEffect(reduceMotion ? 1 : 1 + 0.02 * orbBreath)
                        .shadow(color: accent.opacity(0.35), radius: 6, x: 0, y: 2)
                        .accessibilityHidden(true)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                                orbBreath = 1
                            }
                        }
                }
                Text(lastSyncText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Last sync: \(lastSyncText)")
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}







// MARK: - SITE CHANGE TILE (countdown ring)

private struct SiteChangeTile: View {
    var daysSince: Int
    var location: String
    var accent: Color

    @ScaledMetric private var diameter: CGFloat = 140
    @ScaledMetric private var stroke: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    private var progress: Double {
        let goal = 3.0
        return min(1.0, Double(daysSince) / goal)
    }

    var body: some View {
        CircleTileBase(diameter: diameter) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: stroke)

                // Progress ring with slow rotate
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [
                            accent.opacity(0.85),
                            accent.opacity(0.35),
                            accent.opacity(0.85)
                        ], center: .center),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(reduceMotion ? 0 : rotation))

                InnerWindow(diameter: diameter) {
                    Text("Days Since")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("\(daysSince)")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(daysSince) days since site change at \(location)")
    }
}


    // MARK: - Shapes & tiny views

private struct PieSlice: Shape {
        var startAngle: Angle
        var endAngle: Angle

        func path(in rect: CGRect) -> Path {
            var p = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let r = min(rect.width, rect.height) / 2
            p.move(to: center)
            p.addArc(center: center, radius: r, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            p.closeSubpath()
            return p
        }
    }

private struct NowMarker: Shape {
        var hour: Int
        var animatableData: CGFloat {
            get { CGFloat(hour) }
            set { hour = Int(newValue) }
        }
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let radius = min(rect.width, rect.height) / 2
            let angle = CGFloat(hour) / 24.0 * 2 * .pi - .pi / 2
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            p.addEllipse(in: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
            return p
        }
    }

private struct LegendDot: View {
        var color: Color
        var body: some View {
            Circle().fill(color).frame(width: 6, height: 6)
        }
    }

// Arc for a given HourRange (supports wraparound)
private struct TherapyArc: Shape {
    var range: HourRange

    // Convert hour to angle (0h at top, clockwise)
    private func angle(for hour: Double) -> Angle {
        Angle(degrees: (hour / 24.0) * 360.0 - 90.0)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Build one or two arcs depending on wraparound
        let segments: [(Double, Double)] = {
            let s = Double(range.startHour)
            let e = Double(range.endHour)
            if range.startHour <= range.endHour {
                return [(s, e)]
            } else {
                // wrap: 22–5 => [22, 24) and [0, 5]
                return [(s, 24.0), (0.0, e)]
            }
        }()

        for seg in segments {
            let startAngle = angle(for: seg.0)
            let endAngle   = angle(for: seg.1 + 0.999) // include the end hour visually
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        }
        return path
    }
}


// MARK: - SYNC TILE (liquid-ish wave)

private struct SyncTile: View {
    var isSyncing: Bool
    var accent: Color

    @ScaledMetric private var diameter: CGFloat = 140

    var body: some View {
        CircleTileBase(diameter: diameter) {
            ZStack {
                if isSyncing {
                    LiquidWave(color: accent)
                } else {
                    Circle().fill(accent.opacity(0.10))
                }

                VStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(isSyncing ? "Syncing…" : "Health data")
                        .font(.subheadline)
                    Text(isSyncing ? "Please wait" : "Sync & status")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSyncing ? "Sync in progress" : "Sync health data")
    }
}

// MARK: - BUILDING BLOCKS

struct CircleTileBase<Content: View>: View {
    @ScaledMetric private var pad: CGFloat = 14
    @ScaledMetric private var corner: CGFloat = 24
    var diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)

            content.padding(pad)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .scaleEffect(reduceMotion ? 1 : 1.0) // future micro-interactions here
    }
}

fileprivate struct Card<Inner: View>: View {
    @ScaledMetric private var corner: CGFloat = 16
    @ScaledMetric private var pad: CGFloat = 14
    @ViewBuilder var content: Inner

    var body: some View {
        VStack { content }
            .padding(pad)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner))
    }
}

private struct ActivityRow: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(spacing: 8) {
            Circle().frame(width: 6, height: 6).foregroundStyle(.secondary)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - BACKGROUND (breathing, subtle)
struct BreathingBackground: View {
    var theme: HomeTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hueShift: Double = 0

    var body: some View {
        LinearGradient(
            colors: [
                theme.bgStart.hueShifted(hueShift),
                theme.bgEnd.hueShifted(hueShift * 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                hueShift = 0.02 // ±2% hue drift
            }
        }
    }
}

// MARK: - LIQUID WAVE (inside the sync tile)

private struct LiquidWave: View {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))

                // Wave clipped to circle
                WaveShape(amplitude: size * 0.06, wavelength: size * 0.7, phase: phase)
                    .fill(color.opacity(0.35))
                    .clipShape(Circle())
                    .offset(y: size * 0.15)

                WaveShape(amplitude: size * 0.04, wavelength: size * 0.55, phase: phase * 1.3)
                    .fill(color.opacity(0.25))
                    .clipShape(Circle())
                    .offset(y: size * 0.12)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
    }
}

private struct WaveShape: Shape {
    var amplitude: CGFloat
    var wavelength: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: 0, y: midY))
        let step = max(1, wavelength / 20)
        for x in stride(from: 0, through: rect.width, by: step) {
            let relative = x / wavelength
            let y = midY + sin(relative * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        // close at bottom
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - UTILITIES

//private extension View {
//    /// Success notification haptic when `trigger` changes (iOS 17+).
//    @ViewBuilder
//    func applySuccessHaptic(trigger: Int) -> some View {
//        if #available(iOS 17.0, *) {
//            self.sensoryFeedback(.success, trigger: trigger)
//        } else {
//            self
//        }
//    }
//}

private extension Color {
    func hueShifted(_ delta: Double) -> Color {
        // super-lightweight approximation (good enough for tiny shifts)
        // for precise HSB math, keep your existing mapping utilities
        return self.opacity(1.0) // placeholder to avoid heavy conversions here
    }
}

struct Template: View {
    var body: some View {
        Text("Hello")
    }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    HomeScreen(showSignInView: .constant(false))
      .environmentObject(ThemeManager())
  }
}
