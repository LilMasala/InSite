import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChameliaInsightsSnapshot {
    struct CountBreakdown: Equatable {
        let accepted: Int
        let partial: Int
        let rejected: Int
    }

    struct TrendSeries: Equatable {
        let dates: [String]
        let tirRolling14d: [Double]
        let bgAvgRolling14d: [Double]
        let pctLowRolling14d: [Double]
        let pctHighRolling14d: [Double]
        let moodValenceDaily: [Double?]
        let moodArousalDaily: [Double?]
        let stressAcuteDaily: [Double?]
    }

    struct RecommendationHistoryItem: Identifiable, Equatable {
        let day: Int
        let dateText: String
        let actionKind: String
        let actionLevel: Int?
        let actionFamily: String?
        let response: String?
        let scheduleChanged: Bool
        let realizedCost: Double?
        let outcomeSummary: OutcomeSummary?

        var id: String { "\(day)-\(dateText)-\(actionKind)" }
    }

    struct OutcomeSummary: Equatable {
        let tirDelta: Double
        let costDelta: Double
        let positive: Bool
    }

    let status: GraduationStatus?
    let recommendationCount: Int
    let graduatedDay: Int?
    let acceptOrPartialRate: Double?
    let realizedPositiveOutcomeRate: Double?
    let counts: CountBreakdown
    let tirMean: Double?
    let tirBaseline14dMean: Double?
    let tirFinal14dMean: Double?
    let tirDeltaBaselineVsFinal14d: Double?
    let pctLowMean: Double?
    let pctHighMean: Double?
    let postGraduationSurfaceDays: Int?
    let postGraduationNoSurfaceDays: Int?
    let topBlockReasons: [(reason: String, count: Int)]
    let trendSeries: TrendSeries?
    let history: [RecommendationHistoryItem]
    let latestProfileName: String?
    let latestTherapyUpdate: Date?
    let lastDecisionReason: String?
    let jepaStatus: String?
    let jepaActiveDays: Int?
    let configuratorModeSummary: String?

    var isGraduated: Bool {
        status?.graduated == true || graduatedDay != nil
    }
}

@MainActor
final class ChameliaInsightsStore: ObservableObject {
    @Published private(set) var snapshot: ChameliaInsightsSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()

    func refresh(userId: String?, fallbackStatus: GraduationStatus? = nil) async {
        guard let userId, !userId.isEmpty else {
            snapshot = nil
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let reportDocument = db.collection("users")
                .document(userId)
                .collection("sim_reports")
                .document("latest")
                .getDocument()

            async let simLogDocuments = db.collection("users")
                .document(userId)
                .collection("sim_log")
                .document("entries")
                .collection("items")
                .order(by: "day", descending: true)
                .limit(to: 1)
                .getDocuments()

            let latestTherapySnapshot = try? await TherapySettingsLogManager.shared.getLatestValidTherapySnapshot(limit: 12)
            let (reportSnapshot, logSnapshot) = try await (reportDocument, simLogDocuments)

            let parsed = try parseSnapshot(
                reportData: reportSnapshot.data(),
                latestLogData: logSnapshot.documents.first?.data(),
                fallbackStatus: fallbackStatus,
                latestTherapySnapshot: latestTherapySnapshot
            )

            snapshot = parsed
            errorMessage = nil
        } catch {
            snapshot = nil
            errorMessage = readableMessage(for: error)
            print("[ChameliaInsights] failed to load insights for \(userId): \(error)")
        }
    }

    private func parseSnapshot(
        reportData: [String: Any]?,
        latestLogData: [String: Any]?,
        fallbackStatus: GraduationStatus?,
        latestTherapySnapshot: TherapySnapshot?
    ) throws -> ChameliaInsightsSnapshot {
        guard let reportData else {
            if let fallbackStatus {
                return ChameliaInsightsSnapshot(
                    status: fallbackStatus,
                    recommendationCount: 0,
                    graduatedDay: nil,
                    acceptOrPartialRate: nil,
                    realizedPositiveOutcomeRate: nil,
                    counts: .init(accepted: 0, partial: 0, rejected: 0),
                    tirMean: nil,
                    tirBaseline14dMean: nil,
                    tirFinal14dMean: nil,
                    tirDeltaBaselineVsFinal14d: nil,
                    pctLowMean: nil,
                    pctHighMean: nil,
                    postGraduationSurfaceDays: nil,
                    postGraduationNoSurfaceDays: nil,
                    topBlockReasons: [],
                    trendSeries: nil,
                    history: [],
                    latestProfileName: latestTherapySnapshot?.profileName,
                    latestTherapyUpdate: latestTherapySnapshot?.timestamp,
                    lastDecisionReason: latestLogData.flatMap(decisionReason(from:)),
                    jepaStatus: fallbackStatus.beliefMode,
                    jepaActiveDays: nil,
                    configuratorModeSummary: fallbackStatus.configuratorMode
                )
            }
            throw NSError(domain: "ChameliaInsights", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No mature-account Chamelia report exists yet for this user."
            ])
        }

        let finalStatus = graduationStatus(from: reportData["final_status"] as? [String: Any]) ?? fallbackStatus
        let trendSeries = trendSeries(from: reportData["trend_series"] as? [String: Any])
        let outcomesByDay = Dictionary(uniqueKeysWithValues: outcomeTimeline(from: reportData["realized_outcome_timeline"] as? [[String: Any]]).map { ($0.day, $0) })
        let history = recommendationHistory(
            from: reportData["recommendation_timeline"] as? [[String: Any]],
            outcomesByDay: outcomesByDay
        )

        return ChameliaInsightsSnapshot(
            status: finalStatus,
            recommendationCount: intValue(reportData["recommendation_count"]) ?? history.count,
            graduatedDay: intValue(reportData["graduated_day"]),
            acceptOrPartialRate: doubleValue(reportData["accept_or_partial_rate"]),
            realizedPositiveOutcomeRate: doubleValue(reportData["realized_positive_outcome_rate"]),
            counts: .init(
                accepted: intValue(reportData["accepted_count"]) ?? 0,
                partial: intValue(reportData["partial_count"]) ?? 0,
                rejected: intValue(reportData["rejected_count"]) ?? 0
            ),
            tirMean: doubleValue(reportData["tir_mean"]),
            tirBaseline14dMean: doubleValue(reportData["tir_baseline_14d_mean"]),
            tirFinal14dMean: doubleValue(reportData["tir_final_14d_mean"]),
            tirDeltaBaselineVsFinal14d: doubleValue(reportData["tir_delta_baseline_vs_final_14d"]),
            pctLowMean: doubleValue(reportData["pct_low_mean"]),
            pctHighMean: doubleValue(reportData["pct_high_mean"]),
            postGraduationSurfaceDays: intValue(reportData["post_graduation_surface_days"]),
            postGraduationNoSurfaceDays: intValue(reportData["post_graduation_no_surface_days"]),
            topBlockReasons: sortedCounts(from: reportData["block_reasons"]).prefix(3).map { $0 },
            trendSeries: trendSeries,
            history: history,
            latestProfileName: latestTherapySnapshot?.profileName,
            latestTherapyUpdate: latestTherapySnapshot?.timestamp,
            lastDecisionReason: latestLogData.flatMap(decisionReason(from:)),
            jepaStatus: stringValue(reportData["jepa_status"]) ?? finalStatus?.beliefMode,
            jepaActiveDays: intValue(reportData["jepa_active_days"]),
            configuratorModeSummary: configuratorModeSummary(from: reportData["configurator_mode_counts"]) ?? finalStatus?.configuratorMode
        )
    }

    private func recommendationHistory(
        from raw: [[String: Any]]?,
        outcomesByDay: [Int: ChameliaInsightsSnapshot.OutcomeSummary]
    ) -> [ChameliaInsightsSnapshot.RecommendationHistoryItem] {
        (raw ?? []).compactMap { item in
            guard let day = intValue(item["day"]) else { return nil }
            return .init(
                day: day,
                dateText: stringValue(item["date"]) ?? "Day \(day)",
                actionKind: stringValue(item["action_kind"]) ?? "Recommendation",
                actionLevel: intValue(item["action_level"]),
                actionFamily: stringValue(item["action_family"]),
                response: stringValue(item["patient_response"]),
                scheduleChanged: boolValue(item["schedule_changed"]) ?? false,
                realizedCost: doubleValue(item["realized_cost"]),
                outcomeSummary: outcomesByDay[day]
            )
        }
        .sorted { $0.day > $1.day }
    }

    private func outcomeTimeline(from raw: [[String: Any]]?) -> [ChameliaInsightsSnapshot.OutcomeSummaryWithDay] {
        (raw ?? []).compactMap { item in
            guard let day = intValue(item["day"]) else { return nil }
            return .init(
                day: day,
                tirDelta: doubleValue(item["tir_delta"]) ?? 0,
                costDelta: doubleValue(item["cost_delta"]) ?? 0,
                positive: boolValue(item["positive"]) ?? false
            )
        }
    }

    private func trendSeries(from raw: [String: Any]?) -> ChameliaInsightsSnapshot.TrendSeries? {
        guard let raw else { return nil }
        return .init(
            dates: stringArray(raw["dates"]),
            tirRolling14d: doubleArray(raw["tir_rolling_14d"]),
            bgAvgRolling14d: doubleArray(raw["bg_avg_rolling_14d"]),
            pctLowRolling14d: doubleArray(raw["pct_low_rolling_14d"]),
            pctHighRolling14d: doubleArray(raw["pct_high_rolling_14d"]),
            moodValenceDaily: optionalDoubleArray(raw["mood_valence_daily"]),
            moodArousalDaily: optionalDoubleArray(raw["mood_arousal_daily"]),
            stressAcuteDaily: optionalDoubleArray(raw["stress_acute_daily"])
        )
    }

    private func graduationStatus(from raw: [String: Any]?) -> GraduationStatus? {
        guard let raw else { return nil }
        return GraduationStatus(
            graduated: boolValue(raw["graduated"]) ?? false,
            nDays: intValue(raw["n_days"]) ?? 0,
            winRate: doubleValue(raw["win_rate"]) ?? 0,
            safetyViolations: intValue(raw["safety_violations"]) ?? 0,
            consecutiveDays: intValue(raw["consecutive_days"]) ?? 0,
            beliefMode: stringValue(raw["belief_mode"]),
            jepaActive: boolValue(raw["jepa_active"]),
            configuratorMode: stringValue(raw["configurator_mode"]),
            lastDecisionReason: stringValue(raw["last_decision_reason"])
        )
    }

    private func decisionReason(from raw: [String: Any]) -> String? {
        stringValue(raw["last_decision_reason"])
            ?? stringValue(raw["decision_block_reason"])
            ?? {
                if raw["recommendation"] != nil { return "Recommendation surfaced" }
                return nil
            }()
    }

    private func configuratorModeSummary(from raw: Any?) -> String? {
        guard let rawCounts = raw as? [String: Any] else { return nil }
        let sorted = rawCounts.compactMap { key, value -> (String, Int)? in
            guard let count = intValue(value), count > 0 else { return nil }
            return (key, count)
        }
        .sorted { $0.1 > $1.1 }

        guard let first = sorted.first else { return nil }
        return "\(first.0.replacingOccurrences(of: "_", with: " ").capitalized) · \(first.1)d"
    }

    private func sortedCounts(from raw: Any?) -> [(reason: String, count: Int)] {
        guard let rawCounts = raw as? [String: Any] else { return [] }
        return rawCounts.compactMap { key, value -> (String, Int)? in
            guard let count = intValue(value), count > 0 else { return nil }
            return (key.replacingOccurrences(of: "_", with: " ").capitalized, count)
        }
        .sorted { $0.1 > $1.1 }
    }

    private func stringArray(_ raw: Any?) -> [String] {
        (raw as? [Any])?.compactMap(stringValue) ?? []
    }

    private func doubleArray(_ raw: Any?) -> [Double] {
        (raw as? [Any])?.compactMap(doubleValue) ?? []
    }

    private func optionalDoubleArray(_ raw: Any?) -> [Double?] {
        (raw as? [Any])?.map { value in
            if value is NSNull { return nil }
            return doubleValue(value)
        } ?? []
    }

    private func intValue(_ raw: Any?) -> Int? {
        if let int = raw as? Int { return int }
        if let number = raw as? NSNumber { return number.intValue }
        if let string = raw as? String { return Int(string) }
        return nil
    }

    private func doubleValue(_ raw: Any?) -> Double? {
        if let double = raw as? Double { return double }
        if let number = raw as? NSNumber { return number.doubleValue }
        if let string = raw as? String { return Double(string) }
        return nil
    }

    private func boolValue(_ raw: Any?) -> Bool? {
        if let bool = raw as? Bool { return bool }
        if let number = raw as? NSNumber { return number.boolValue }
        if let string = raw as? String { return Bool(string) }
        return nil
    }

    private func stringValue(_ raw: Any?) -> String? {
        if let string = raw as? String, !string.isEmpty { return string }
        if let number = raw as? NSNumber { return number.stringValue }
        return nil
    }

    private func readableMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

private extension ChameliaInsightsSnapshot {
    struct OutcomeSummaryWithDay {
        let day: Int
        let tirDelta: Double
        let costDelta: Double
        let positive: Bool

        var asOutcome: OutcomeSummary {
            .init(tirDelta: tirDelta, costDelta: costDelta, positive: positive)
        }
    }
}

private extension Array where Element == ChameliaInsightsSnapshot.OutcomeSummaryWithDay {
    func mapToDictionary() -> [Int: ChameliaInsightsSnapshot.OutcomeSummary] {
        Dictionary(uniqueKeysWithValues: map { ($0.day, $0.asOutcome) })
    }
}

struct ChameliaInsightsEntryCard: View {
    let snapshot: ChameliaInsightsSnapshot?
    let fallbackStatus: GraduationStatus?
    let accent: Color
    let isLoading: Bool
    let errorMessage: String?

    private var status: GraduationStatus? {
        snapshot?.status ?? fallbackStatus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status?.graduated == true ? "Chamelia is live" : "Chamelia progress")
                        .font(.title3.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            if let snapshot {
                HStack(spacing: 10) {
                    insightPill(title: "Recs", value: "\(snapshot.recommendationCount)")
                    insightPill(title: "Accept+", value: snapshot.acceptOrPartialRate.percentString)
                    insightPill(title: "TIR Δ", value: snapshot.tirDeltaBaselineVsFinal14d.signedPercentString)
                }
            } else if let status {
                HStack(spacing: 10) {
                    insightPill(title: "Days", value: "\(status.nDays)")
                    insightPill(title: "Win", value: (status.winRate).percentString)
                    insightPill(title: "Streak", value: "\(status.consecutiveDays)")
                }
            }

            if let message = errorMessage, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView()
                    .padding(16)
                    .tint(accent)
            }
        }
    }

    private var subtitle: String {
        if let snapshot, snapshot.isGraduated {
            return "Recommendations, outcomes, and health trends are synced to this account."
        }
        if let status, status.graduated {
            return "This account has already graduated out of pure shadow mode."
        }
        return "See shadow progress, recommendation history, and recent health trends."
    }

    private var statusBadge: some View {
        Text((status?.graduated ?? false) ? "Live" : "Shadow")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(((status?.graduated ?? false) ? Color.green : accent).opacity(0.16), in: Capsule())
            .foregroundStyle((status?.graduated ?? false) ? Color.green : accent)
    }

    private func insightPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ChameliaStatusSummaryCard: View {
    let status: GraduationStatus
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(status.graduated ? "Chamelia live" : "Shadow progress", systemImage: status.graduated ? "bolt.heart.fill" : "hourglass.bottomhalf.filled")
                    .font(.headline)
                    .foregroundStyle(status.graduated ? Color.green : accent)
                Spacer()
                Text(status.graduated ? "Live" : "Shadow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((status.graduated ? Color.green : accent).opacity(0.16), in: Capsule())
                    .foregroundStyle(status.graduated ? Color.green : accent)
            }

            if status.graduated {
                Text("Chamelia is actively evaluating recommendations on top of your current schedule.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Chamelia is still building evidence before surfacing recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricChip(title: "Observed days", value: "\(status.nDays)")
                metricChip(title: "Win rate", value: status.winRate.percentString)
                metricChip(title: "Streak", value: "\(status.consecutiveDays)")
                metricChip(title: "Safety", value: "\(status.safetyViolations)")
            }
        }
        .insightCardStyle()
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ChameliaInsightsView: View {
    @ObservedObject var store: ChameliaInsightsStore
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var siteChange = SiteChangeData.shared

    private var accent: Color { themeManager.theme.accent }

    var body: some View {
        ZStack {
            BreathingBackground(theme: themeManager.theme)
                .ignoresSafeArea()

            if store.isLoading && store.snapshot == nil {
                ProgressView("Loading Chamelia insights…")
                    .tint(accent)
            } else if let errorMessage = store.errorMessage, store.snapshot == nil {
                ScrollView {
                    VStack(spacing: 16) {
                        errorCard(message: errorMessage)
                    }
                    .padding(16)
                }
            } else if let snapshot = store.snapshot {
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard(snapshot: snapshot)
                        if let status = snapshot.status {
                            ChameliaStatusSummaryCard(status: status, accent: accent)
                        }
                        healthCard(snapshot: snapshot)
                        operationalCard(snapshot: snapshot)
                        recommendationHistoryCard(snapshot: snapshot)
                    }
                    .padding(16)
                }
                .refreshable {
                    await store.refresh(userId: Auth.auth().currentUser?.uid, fallbackStatus: ChameliaDashboardStore.shared.state.status)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        emptyCard
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Chamelia & Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(snapshot: ChameliaInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.isGraduated ? "Chamelia is live" : "Chamelia is learning")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text(snapshot.isGraduated
                         ? "This account has already graduated out of shadow mode. The recommendation engine is active."
                         : "This account is still accumulating shadow evidence before surfacing recommendations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(snapshot.isGraduated ? "Live" : "Shadow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background((snapshot.isGraduated ? Color.green : accent).opacity(0.16), in: Capsule())
                    .foregroundStyle(snapshot.isGraduated ? Color.green : accent)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                dashboardMetric(title: "Recommendations", value: "\(snapshot.recommendationCount)", tint: accent)
                dashboardMetric(title: "Accept + partial", value: snapshot.acceptOrPartialRate.percentString, tint: .green)
                dashboardMetric(title: "Positive outcomes", value: snapshot.realizedPositiveOutcomeRate.percentString, tint: .green)
                dashboardMetric(title: "Graduated day", value: snapshot.graduatedDay.map(String.init) ?? "—", tint: accent)
                dashboardMetric(title: "Observed days", value: snapshot.status.map { "\($0.nDays)" } ?? "—", tint: accent)
                dashboardMetric(title: "Win rate", value: snapshot.status?.winRate.percentString ?? "—", tint: snapshot.status?.winRate ?? 0 >= 0.6 ? .green : .orange)
                dashboardMetric(title: "Safety violations", value: snapshot.status.map { "\($0.safetyViolations)" } ?? "—", tint: (snapshot.status?.safetyViolations ?? 0) == 0 ? .green : .red)
                dashboardMetric(title: "Consecutive good days", value: snapshot.status.map { "\($0.consecutiveDays)" } ?? "—", tint: accent)
            }

            HStack(spacing: 10) {
                infoTag(title: "Belief", value: snapshot.jepaStatus ?? snapshot.status?.beliefMode ?? "Unknown")
                if let configuratorModeSummary = snapshot.configuratorModeSummary {
                    infoTag(title: "Mode", value: configuratorModeSummary)
                }
                if let jepaActiveDays = snapshot.jepaActiveDays, jepaActiveDays > 0 {
                    infoTag(title: "JEPA", value: "\(jepaActiveDays)d active")
                }
            }

            if let lastDecisionReason = snapshot.lastDecisionReason, !lastDecisionReason.isEmpty {
                Label(lastDecisionReason, systemImage: "text.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .insightCardStyle()
    }

    private func healthCard(snapshot: ChameliaInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Health trends")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                trendMetricCard(
                    title: "TIR",
                    current: snapshot.trendSeries?.tirRolling14d.last ?? snapshot.tirFinal14dMean,
                    delta: rollingDelta(snapshot.trendSeries?.tirRolling14d),
                    data: snapshot.trendSeries?.tirRolling14d,
                    tint: .green,
                    format: .percent
                )
                trendMetricCard(
                    title: "Average BG",
                    current: snapshot.trendSeries?.bgAvgRolling14d.last,
                    delta: rollingDelta(snapshot.trendSeries?.bgAvgRolling14d),
                    data: snapshot.trendSeries?.bgAvgRolling14d,
                    tint: accent,
                    format: .number
                )
                trendMetricCard(
                    title: "% Low",
                    current: snapshot.trendSeries?.pctLowRolling14d.last ?? snapshot.pctLowMean,
                    delta: rollingDelta(snapshot.trendSeries?.pctLowRolling14d),
                    data: snapshot.trendSeries?.pctLowRolling14d,
                    tint: .orange,
                    format: .percent
                )
                trendMetricCard(
                    title: "% High",
                    current: snapshot.trendSeries?.pctHighRolling14d.last ?? snapshot.pctHighMean,
                    delta: rollingDelta(snapshot.trendSeries?.pctHighRolling14d),
                    data: snapshot.trendSeries?.pctHighRolling14d,
                    tint: .pink,
                    format: .percent
                )
            }

            if let tirDelta = snapshot.tirDeltaBaselineVsFinal14d {
                HStack(spacing: 10) {
                    infoTag(title: "Baseline 14d", value: snapshot.tirBaseline14dMean.percentString)
                    infoTag(title: "Final 14d", value: snapshot.tirFinal14dMean.percentString)
                    infoTag(title: "Δ TIR", value: tirDelta.signedPercentString)
                }
            }
        }
        .insightCardStyle()
    }

    private func operationalCard(snapshot: ChameliaInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Operational context")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                dashboardMetric(title: "Current profile", value: snapshot.latestProfileName ?? "—", tint: accent)
                dashboardMetric(title: "Last therapy update", value: snapshot.latestTherapyUpdate.map(relativeDateString) ?? "—", tint: accent)
                dashboardMetric(title: "Site age", value: "\(siteChange.daysSinceSiteChange) days", tint: accent)
                dashboardMetric(title: "Post-grad surfaced", value: snapshot.postGraduationSurfaceDays.map(String.init) ?? "—", tint: .green)
                dashboardMetric(title: "Post-grad withheld", value: snapshot.postGraduationNoSurfaceDays.map(String.init) ?? "—", tint: .secondary)
                dashboardMetric(title: "Recent block reason", value: snapshot.topBlockReasons.first?.reason ?? "None", tint: .orange)
            }
        }
        .insightCardStyle()
    }

    private func recommendationHistoryCard(snapshot: ChameliaInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recommendation history")
                .font(.headline)

            if snapshot.history.isEmpty {
                Text("No surfaced recommendations are stored for this account yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.history.prefix(10)) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.actionKind.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.dateText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.response?.capitalized ?? "Pending")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(responseTint(for: item).opacity(0.14), in: Capsule())
                                .foregroundStyle(responseTint(for: item))
                        }

                        HStack(spacing: 8) {
                            infoTag(title: "Level", value: item.actionLevel.map(String.init) ?? "—")
                            if let family = item.actionFamily {
                                infoTag(title: "Family", value: family.replacingOccurrences(of: "_", with: " ").capitalized)
                            }
                            infoTag(title: "Changed", value: item.scheduleChanged ? "Yes" : "No")
                        }

                        if let outcome = item.outcomeSummary {
                            Text(outcomeText(for: outcome))
                                .font(.caption)
                                .foregroundStyle(outcome.positive ? Color.green : .secondary)
                        } else if let realizedCost = item.realizedCost {
                            Text("Realized cost \(realizedCost.formatted(.number.precision(.fractionLength(2))))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .insightCardStyle()
    }

    private func dashboardMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func trendMetricCard(
        title: String,
        current: Double?,
        delta: Double?,
        data: [Double]?,
        tint: Color,
        format: InsightNumberFormat
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let delta {
                    Text(formatDelta(delta, format: format))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(delta >= 0 ? tint : .orange)
                }
            }

            Text(formatValue(current, format: format))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            TrendSparkline(values: data ?? [], tint: tint)
                .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoTag(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Unable to load Chamelia insights", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .insightCardStyle()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No Chamelia insight data yet")
                .font(.headline)
            Text("Sync the account or wait for seeded report artifacts before this screen can show trends and recommendation history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .insightCardStyle()
    }

    private func responseTint(for item: ChameliaInsightsSnapshot.RecommendationHistoryItem) -> Color {
        switch item.response?.lowercased() {
        case "accept":
            return .green
        case "partial":
            return accent
        case "reject":
            return .orange
        default:
            return .secondary
        }
    }

    private func outcomeText(for outcome: ChameliaInsightsSnapshot.OutcomeSummary) -> String {
        let tirText = outcome.tirDelta.signedPercentString
        let costText = outcome.costDelta.formatted(.number.precision(.fractionLength(2)))
        if outcome.positive {
            return "Positive follow-up outcome · TIR \(tirText) · cost \(costText)"
        }
        return "Follow-up mixed/neutral · TIR \(tirText) · cost \(costText)"
    }

    private func rollingDelta(_ values: [Double]?) -> Double? {
        guard let values, values.count >= 2 else { return nil }
        let current = values[values.count - 1]
        let priorIndex = max(0, values.count - 15)
        return current - values[priorIndex]
    }

    private func formatValue(_ value: Double?, format: InsightNumberFormat) -> String {
        guard let value else { return "—" }
        switch format {
        case .percent:
            return value.percentString
        case .number:
            return value.formatted(.number.precision(.fractionLength(0)))
        }
    }

    private func formatDelta(_ value: Double, format: InsightNumberFormat) -> String {
        switch format {
        case .percent:
            return value.signedPercentString
        case .number:
            let rounded = Int(value.rounded())
            return rounded > 0 ? "+\(rounded)" : "\(rounded)"
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

private enum InsightNumberFormat {
    case percent
    case number
}

private struct TrendSparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            if values.count < 2 {
                Capsule()
                    .fill(tint.opacity(0.14))
                    .frame(height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                let trimmed = Array(values.suffix(21))
                let minValue = trimmed.min() ?? 0
                let maxValue = trimmed.max() ?? 1
                let span = max(maxValue - minValue, 0.0001)
                Path { path in
                    for (index, value) in trimmed.enumerated() {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(max(trimmed.count - 1, 1))
                        let y = proxy.size.height * (1 - CGFloat((value - minValue) / span))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private extension View {
    func insightCardStyle() -> some View {
        self
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private extension Optional where Wrapped == Double {
    var percentString: String {
        guard let value = self else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    var signedPercentString: String {
        guard let value = self else { return "—" }
        let percent = Int((value * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }
}

private extension Double {
    var percentString: String {
        self.formatted(.percent.precision(.fractionLength(0)))
    }

    var signedPercentString: String {
        let percent = Int((self * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }
}
