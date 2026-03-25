import SwiftUI

struct RecommendationTile: View {
    let status: GraduationStatus?
    let recommendation: RecommendationPackage?
    let accent: Color
    let isRefreshing: Bool
    let errorMessage: String?

    @ScaledMetric private var diameter: CGFloat = 140
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var hum = false

    private var isReady: Bool {
        (status?.graduated ?? false) && recommendation != nil
    }

    private var isUnavailable: Bool {
        errorMessage != nil && status == nil && recommendation == nil
    }

    private var progress: Double {
        guard let status else { return 0.08 }
        let dayProgress = Double(min(status.nDays, 21)) / 21.0
        let streakProgress = Double(min(status.consecutiveDays, 7)) / 7.0
        let winProgress = min(status.winRate / 0.6, 1.0)
        let safetyProgress = status.safetyViolations == 0 ? 1.0 : 0.0
        return min(1.0, max(0.08, (dayProgress + streakProgress + winProgress + safetyProgress) / 4.0))
    }

    private var readinessPercent: Int {
        Int((progress * 100).rounded())
    }

    private var tileState: TileState {
        if isUnavailable { return .unavailable }
        if isRefreshing && status == nil && recommendation == nil { return .syncing }
        if isReady { return .ready }
        if progress >= 0.82 { return .nearlyReady }
        return .learning
    }

    var body: some View {
        CircleTileBase(diameter: diameter) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: tileState.ringColors(accent: accent),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack {
                    BrainReadinessCore(
                        progress: progress,
                        readinessPercent: readinessPercent,
                        accent: accent,
                        state: tileState,
                        pulse: pulse,
                        hum: hum
                    )
                    stateCaption
                }
                .multilineTextAlignment(.center)
                .frame(width: diameter * 0.74, height: diameter * 0.62)
                .padding(.horizontal, 8)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                hum = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var stateCaption: some View {
        VStack(spacing: 6) {
            Text(tileState.eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(tileState.title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tileState.titleColor(accent: accent))
            Text(tileState.subtitle(status: status, errorMessage: errorMessage))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private var accessibilityLabel: String {
        switch tileState {
        case .ready:
            return "Chamelia ready. Recommendation available now."
        case .nearlyReady:
            return "Chamelia nearly ready. Readiness \(readinessPercent) percent."
        case .learning:
            if let status {
                return "Chamelia learning. \(status.nDays) days in shadow, win rate \(Int((status.winRate * 100).rounded())) percent, \(status.consecutiveDays) consecutive good days."
            }
            return "Chamelia learning. Sync to start building readiness."
        case .syncing:
            return "Chamelia syncing."
        case .unavailable:
            return "Chamelia temporarily unavailable."
        }
    }
}

private extension RecommendationTile {
    enum TileState {
        case ready
        case nearlyReady
        case learning
        case syncing
        case unavailable

        var eyebrow: String {
            switch self {
            case .ready: return "Chamelia"
            case .nearlyReady: return "Shadow"
            case .learning: return "Shadow"
            case .syncing: return "Chamelia"
            case .unavailable: return "Chamelia"
            }
        }

        var title: String {
            switch self {
            case .ready: return "Ready"
            case .nearlyReady: return "Nearly Ready"
            case .learning: return "Learning"
            case .syncing: return "Syncing"
            case .unavailable: return "Paused"
            }
        }

        func titleColor(accent: Color) -> Color {
            switch self {
            case .ready: return .green
            case .nearlyReady: return accent
            case .learning: return .primary
            case .syncing: return accent
            case .unavailable: return .orange
            }
        }

        func ringColors(accent: Color) -> [Color] {
            switch self {
            case .ready:
                return [Color.green.opacity(0.9), accent.opacity(0.7), Color.green.opacity(0.9)]
            case .nearlyReady:
                return [accent.opacity(0.95), Color.green.opacity(0.55), accent.opacity(0.95)]
            case .learning:
                return [accent.opacity(0.85), accent.opacity(0.28), accent.opacity(0.85)]
            case .syncing:
                return [accent.opacity(0.3), accent.opacity(0.85), accent.opacity(0.3)]
            case .unavailable:
                return [Color.orange.opacity(0.7), Color.red.opacity(0.45), Color.orange.opacity(0.7)]
            }
        }

        func subtitle(status: GraduationStatus?, errorMessage: String?) -> String {
            switch self {
            case .ready:
                return "Recommendation waiting"
            case .nearlyReady:
                if let status {
                    return "\(status.consecutiveDays)/7 strong days • almost there"
                }
                return "Shadow criteria nearly met"
            case .learning:
                if let status {
                    return "\(status.nDays)d tracked • \(Int((status.winRate * 100).rounded()))% win"
                }
                return "Sync to start learning your patterns"
            case .syncing:
                return "Refreshing state"
            case .unavailable:
                return errorMessage ?? "Temporarily unavailable"
            }
        }
    }
}

private struct BrainReadinessCore: View {
    let progress: Double
    let readinessPercent: Int
    let accent: Color
    let state: RecommendationTile.TileState
    let pulse: Bool
    let hum: Bool

    var body: some View {
        ZStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.12))

            GeometryReader { proxy in
                let fillHeight = max(8, proxy.size.height * progress)
                let glow = state == .ready ? Color.green : accent

                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            glow.opacity(state == .unavailable ? 0.35 : 0.92),
                            glow.opacity(state == .unavailable ? 0.18 : 0.45)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: fillHeight)
                    .overlay(
                        Capsule()
                            .fill(.white.opacity(0.18))
                            .frame(height: 5)
                            .offset(y: hum ? -2 : 2),
                        alignment: .top
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .mask(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 34, weight: .medium))
                )
                .shadow(color: glow.opacity(0.28), radius: pulse ? 12 : 6, x: 0, y: 0)
            }
            .frame(width: 48, height: 48)
            .scaleEffect(pulse ? 1.02 : 0.98)

            Text("\(readinessPercent)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.92))
                .offset(y: 36)
        }
        .frame(height: 60)
    }
}

#Preview {
    ZStack {
        BreathingBackground(theme: .defaultTeal).ignoresSafeArea()
        HStack(spacing: 20) {
            RecommendationTile(
                status: GraduationStatus(graduated: false, nDays: 10, winRate: 0.48, safetyViolations: 0, consecutiveDays: 3),
                recommendation: nil,
                accent: .teal,
                isRefreshing: false,
                errorMessage: nil
            )
            RecommendationTile(
                status: GraduationStatus(graduated: true, nDays: 23, winRate: 0.7, safetyViolations: 0, consecutiveDays: 9),
                recommendation: RecommendationPackage(
                    action: TherapyAction(kind: "therapy_adjustment", deltas: ["isf_delta": 0.05]),
                    predictedImprovement: 0.08,
                    confidence: 0.72,
                    effectSize: 0.11,
                    cvarValue: 0.2,
                    burnoutAttribution: nil
                ),
                accent: .teal,
                isRefreshing: false,
                errorMessage: nil
            )
        }
    }
}
