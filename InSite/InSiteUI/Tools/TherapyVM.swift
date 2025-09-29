// TherapyVM.swift
import SwiftUI
import Combine

@MainActor
final class TherapyVM: ObservableObject {
    // Inputs/state
    @Published private(set) var profiles: [DiabeticProfile] = []
    @Published private(set) var activeProfile: DiabeticProfile?
    @Published private(set) var currentHourRange: HourRange?

    // Outputs for UI
    @Published private(set) var summaryText: String = "—"
    @Published private(set) var currentBasal: Double = 0
    @Published private(set) var currentISF: Double = 0
    @Published private(set) var currentCarbRatio: Double = 0
    @Published private(set) var currentProfileName: String = "—"
    
    @Published private(set) var sparklineBasal: [Double]? = nil
    @Published private(set) var sparklineISF:   [Double]? = nil
    @Published private(set) var sparklineCR:    [Double]? = nil

    private let store = ProfileDataStore()
    private var timerCancellable: AnyCancellable?
    private var fgObserver: Any?

    init() {
        reload()

        // Recompute “now” every minute (cheap)…
        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.recompute() }

        // …and when app returns to foreground (hour may have rolled over)
        fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.recompute() }
    }

    deinit {
        timerCancellable?.cancel()
        if let fgObserver { NotificationCenter.default.removeObserver(fgObserver) }
    }

    
    private func updateSparklines() {
        guard let p = activeProfile else {
            sparklineBasal = nil; sparklineISF = nil; sparklineCR = nil
            return
        }
        // Sort by start hour so the sparkline flows left→right in time
        let ranges = p.hourRanges.sorted { $0.startHour < $1.startHour }

        // Use the range values directly (the tile normalizes them)
        sparklineBasal = ranges.map { $0.basalRate }
        sparklineISF   = ranges.map { $0.insulinSensitivity }
        sparklineCR    = ranges.map { $0.carbRatio }
    }

    func reload() {
        profiles = store.loadProfiles()
        if let id = store.loadActiveProfileID(),
           let p = profiles.first(where: { $0.id == id }) {
            activeProfile = p
            recompute() // your existing method that sets currentHourRange, currentBasal, etc.
        } else {
            activeProfile = nil
        }
        updateSparklines()
    }

    func selectProfile(id: String) {
        guard let p = profiles.first(where: { $0.id == id }) else { return }
        activeProfile = p
        store.saveActiveProfileID(id)   // persist selection
        recompute()
    }

    // MARK: - Core compute
    func recompute(reference date: Date = Date()) {
        guard let p = activeProfile else {
            summaryText       = "—"
            currentHourRange  = nil
            currentBasal      = 0
            currentISF        = 0
            currentCarbRatio  = 0
            currentProfileName = "—"
            return
        }

        currentProfileName = p.name

        let hour = Calendar.current.component(.hour, from: date)
        currentHourRange = Self.range(for: hour, in: p.hourRanges)

        if let r = currentHourRange {
            currentBasal      = r.basalRate
            currentISF        = r.insulinSensitivity
            currentCarbRatio  = r.carbRatio
            summaryText = "\(p.name) · \(Self.h12(r.startHour))–\(Self.h12(r.endHour))"
        } else {
            currentBasal = 0; currentISF = 0; currentCarbRatio = 0
            summaryText = "\(p.name) · No active range"
        }
    }

    // MARK: - Helpers (same logic you used elsewhere)
    static func range(for hour: Int, in ranges: [HourRange]) -> HourRange? {
        func contains(_ r: HourRange, _ h: Int) -> Bool {
            if r.startHour <= r.endHour {
                return (r.startHour...r.endHour).contains(h)
            } else {
                return h >= r.startHour || h <= r.endHour
            }
        }
        return ranges
            .filter { contains($0, hour) }
            .sorted { span($0) < span($1) }
            .first
    }

    private static func span(_ r: HourRange) -> Int {
        r.startHour <= r.endHour
            ? (r.endHour - r.startHour + 1)
            : (24 - r.startHour + r.endHour + 1)
    }

    private static func h12(_ hour: Int) -> String {
        let h = max(0, min(23, hour))
        var dc = DateComponents(); dc.hour = h
        let date = Calendar.current.date(from: dc) ?? Date()
        let df = DateFormatter(); df.dateFormat = "ha"
        return df.string(from: date)
    }
}
