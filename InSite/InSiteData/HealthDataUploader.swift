//
//  HealthDataUploader.swift
//  InSite
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Canonical cadences & kinds

enum Cadence: String { case hourly, daily, event }

enum DataKind: String {
    case bloodGlucose        = "blood_glucose"
    case heartRate           = "heart_rate"
    case energy              = "energy"
    case exercise            = "exercise"
    case sleep               = "sleep"
    case bodyMass            = "body_mass"
    case restingHeartRate    = "resting_heart_rate"
    case therapySettings     = "therapy_settings"
    case menstrual           = "menstrual"
    case siteChanges         = "site_changes"

    /// Default subpath per cadence (collections are always .../<subpath>/items)
    func defaultSubpath(for cadence: Cadence) -> String {
        switch (self, cadence) {
        case (.bloodGlucose, .hourly):      return "hourly"
        case (.bloodGlucose, .daily):       return "daily"
        case (.heartRate, .hourly):         return "hourly"
        case (.heartRate, .daily):          return "daily_average"
        case (.energy, .hourly):            return "hourly"
        case (.energy, .daily):             return "daily_average"
        case (.exercise, .hourly):          return "hourly"
        case (.exercise, .daily):           return "daily_average"
        case (.sleep, .daily):              return "daily"
        case (.bodyMass, .hourly):          return "hourly"
        case (.restingHeartRate, .daily):   return "daily"
        case (.therapySettings, .hourly):   return "hourly"
        case (.menstrual, .daily):          return "daily"
        case (.siteChanges, .daily):        return "daily"
        case (.siteChanges, .event):        return "events"
        default:                             return cadence.rawValue
        }
    }
}

// MARK: - Time helpers (UTC)

private let isoHour: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.formatOptions = [.withInternetDateTime] // no fractional seconds, stable doc IDs
    return f
}()

private let isoDay: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.formatOptions = [.withFullDate]
    return f
}()

private func floorToHourUTC(_ d: Date) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let c = cal.dateComponents([.year,.month,.day,.hour], from: d)
    return cal.date(from: c)!
}

func isoHourId(_ date: Date) -> String { isoHour.string(from: floorToHourUTC(date)) }
func isoDayId(_ date: Date)  -> String { isoDay.string(from: date) }
func uuidDocId()             -> String { UUID().uuidString }

// MARK: - TherapyHour (unchanged shape)

struct TherapyHour {
    let hourStartUtc: Date
    let profileId: String
    let profileName: String
    let snapshotTimestamp: Date
    let carbRatio: Double
    let basalRate: Double
    let insulinSensitivity: Double
    // optional: local tz info for convenience
    let localTz: TimeZone?
    let localHour: Int?
}

// MARK: - StreamRecord protocol (tiny mappers implement this)

protocol StreamRecord {
    static var kind: DataKind { get }
    static var cadence: Cadence { get }
    /// Override the subpath under the kind (e.g., "percent", "uROC", "average"). Default is kind.defaultSubpath.
    static var subpathOverride: String? { get }

    var documentId: String { get }         // deterministic ID (UTC hour/day) or UUID for events
    var payload: [String: Any] { get }     // merge-safe body (no giant blobs)
}

extension StreamRecord {
    static var subpathOverride: String? { nil }
}

// MARK: - Generic, idempotent uploader

final class FirestoreStreamUploader {
    private let db = Firestore.firestore()
    private let uid: String
    private let batchSize = 450

    init?(uid: String? = Auth.auth().currentUser?.uid) {
        guard let uid = uid else { return nil }
        self.uid = uid
    }

    private func itemsCollection<R: StreamRecord>(_: R.Type) -> CollectionReference {
        let sub = R.subpathOverride ?? R.kind.defaultSubpath(for: R.cadence)
        return db.collection("users")
                 .document(uid)
                 .collection(R.kind.rawValue)
                 .document(sub)
                 .collection("items")
    }

    /// Upsert records (merge) in chunks; replay-safe if documentId is stable.
    func upsert<R: StreamRecord>(_ records: [R], label: String) {
        guard !records.isEmpty else { return }
        let col = itemsCollection(R.self)

        var buf: [R] = []
        buf.reserveCapacity(batchSize)

        func flush(_ xs: [R]) {
            guard !xs.isEmpty else { return }
            let batch = db.batch()
            for r in xs {
                batch.setData(r.payload, forDocument: col.document(r.documentId), merge: true)
            }
            batch.commit { err in
                if let err = err {
                    print("[\(label)] commit error:", err)
                }
            }
        }

        for r in records {
            buf.append(r)
            if buf.count == batchSize {
                flush(buf)
                buf.removeAll(keepingCapacity: true)
            }
        }
        flush(buf)
    }
}

// MARK: - Mappers (1 small struct per logical stream)

// --- Blood Glucose (hourly raw) ---
struct BGHourlyRecord: StreamRecord {
    static let kind: DataKind = .bloodGlucose
    static let cadence: Cadence = .hourly

    let start: Date
    let end: Date
    let startBg: Double?
    let endBg: Double?
    let therapyProfileId: String?

    var documentId: String { isoHourId(start) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "startUtc": isoHourId(start),
            "endUtc": isoHour.string(from: end)
        ]
        if let v = startBg { d["startBg"] = v }
        if let v = endBg   { d["endBg"]   = v }
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

// --- Blood Glucose (hourly average) ---
struct BGAverageHourlyRecord: StreamRecord {
    static let kind: DataKind = .bloodGlucose
    static let cadence: Cadence = .hourly
    static let subpathOverride: String? = "average"   // goes to blood_glucose/average/items

    let start: Date
    let end: Date
    let averageBg: Double?
    let therapyProfileId: String?

    var documentId: String { isoHourId(start) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "startUtc": isoHourId(start),
            "endUtc": isoHour.string(from: end)
        ]
        if let v = averageBg { d["averageBg"] = v }
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

// --- Blood Glucose (hourly %low/%high) ---
struct BGPercentHourlyRecord: StreamRecord {
    static let kind: DataKind = .bloodGlucose
    static let cadence: Cadence = .hourly
    static let subpathOverride: String? = "percent"

    let start: Date
    let end: Date
    let percentLow: Double
    let percentHigh: Double
    let therapyProfileId: String?

    var documentId: String { isoHourId(start) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "startUtc": isoHourId(start),
            "endUtc": isoHour.string(from: end),
            "percentLow": percentLow,
            "percentHigh": percentHigh
        ]
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

// --- Blood Glucose (hourly uROC) ---
struct BGURocHourlyRecord: StreamRecord {
    static let kind: DataKind = .bloodGlucose
    static let cadence: Cadence = .hourly
    static let subpathOverride: String? = "uROC"

    let start: Date
    let end: Date
    let uRoc: Double?              // mg/dL per sec
    let expectedEndBg: Double?
    let therapyProfileId: String?

    var documentId: String { isoHourId(start) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "startUtc": isoHourId(start),
            "endUtc": isoHour.string(from: end)
        ]
        if let u = uRoc           { d["uRoc"] = u }
        if let e = expectedEndBg  { d["expectedEndBg"] = e }
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

// --- Heart Rate ---
struct HRHourlyRecord: StreamRecord {
    static let kind: DataKind = .heartRate
    static let cadence: Cadence = .hourly

    let hour: Date
    let heartRate: Double
    let therapyProfileId: String?

    var documentId: String { isoHourId(hour) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "hourUtc": isoHourId(hour),
            "heartRate": heartRate
        ]
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

struct HRDailyAverageRecord: StreamRecord {
    static let kind: DataKind = .heartRate
    static let cadence: Cadence = .daily   // goes to heart_rate/daily_average/items

    let date: Date
    let averageHeartRate: Double

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "averageHeartRate": averageHeartRate
        ]
    }
}

// --- Exercise ---
struct ExerciseHourlyRecord: StreamRecord {
    static let kind: DataKind = .exercise
    static let cadence: Cadence = .hourly

    let hour: Date
    let moveMinutes: Double
    let exerciseMinutes: Double
    let totalMinutes: Double
    let therapyProfileId: String?

    var documentId: String { isoHourId(hour) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "hourUtc": isoHourId(hour),
            "moveMinutes": moveMinutes,
            "exerciseMinutes": exerciseMinutes,
            "totalMinutes": totalMinutes
        ]
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

struct ExerciseDailyAverageRecord: StreamRecord {
    static let kind: DataKind = .exercise
    static let cadence: Cadence = .daily  // exercise/daily_average/items

    let date: Date
    let averageMoveMinutes: Double
    let averageExerciseMinutes: Double
    let averageTotalMinutes: Double

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "averageMoveMinutes": averageMoveMinutes,
            "averageExerciseMinutes": averageExerciseMinutes,
            "averageTotalMinutes": averageTotalMinutes
        ]
    }
}

// --- Menstrual ---
struct MenstrualDailyRecord: StreamRecord {
    static let kind: DataKind = .menstrual
    static let cadence: Cadence = .daily

    let date: Date
    let daysSincePeriodStart: Int

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "daysSincePeriodStart": daysSincePeriodStart
        ]
    }
}

// --- Body Mass ---
struct BodyMassHourlyRecord: StreamRecord {
    static let kind: DataKind = .bodyMass
    static let cadence: Cadence = .hourly

    let hour: Date
    let weight: Double
    let therapyProfileId: String?

    var documentId: String { isoHourId(hour) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "hourUtc": isoHourId(hour),
            "weight": weight
        ]
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

// --- Resting HR ---
struct RestingHRDailyRecord: StreamRecord {
    static let kind: DataKind = .restingHeartRate
    static let cadence: Cadence = .daily

    let date: Date
    let restingHeartRate: Double

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "restingHeartRate": restingHeartRate
        ]
    }
}

// --- Sleep ---
struct SleepDailyRecord: StreamRecord {
    static let kind: DataKind = .sleep
    static let cadence: Cadence = .daily

    let date: Date
    let awake: Double
    let asleepCore: Double
    let asleepDeep: Double
    let asleepREM: Double
    let asleepUnspecified: Double

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "awake": awake,
            "asleepCore": asleepCore,
            "asleepDeep": asleepDeep,
            "asleepREM": asleepREM,
            "asleepUnspecified": asleepUnspecified
        ]
    }
}

// --- Energy ---
struct EnergyHourlyRecord: StreamRecord {
    static let kind: DataKind = .energy
    static let cadence: Cadence = .hourly

    let hour: Date
    let basalEnergy: Double
    let activeEnergy: Double
    let totalEnergy: Double
    let therapyProfileId: String?

    var documentId: String { isoHourId(hour) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "hourUtc": isoHourId(hour),
            "basalEnergy": basalEnergy,
            "activeEnergy": activeEnergy,
            "totalEnergy": totalEnergy
        ]
        if let p = therapyProfileId { d["therapyProfileId"] = p }
        return d
    }
}

struct EnergyDailyAverageRecord: StreamRecord {
    static let kind: DataKind = .energy
    static let cadence: Cadence = .daily

    let date: Date
    let averageActiveEnergy: Double

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "averageActiveEnergy": averageActiveEnergy
        ]
    }
}

// --- Therapy Settings (hourly projection of snapshot to UTC hour) ---
struct TherapySettingsHourlyRecord: StreamRecord {
    static let kind: DataKind = .therapySettings
    static let cadence: Cadence = .hourly

    let hourStartUtc: Date
    let profileId: String
    let profileName: String
    let snapshotTimestamp: Date
    let carbRatio: Double
    let basalRate: Double
    let insulinSensitivity: Double
    let localTzId: String?
    let localHour: Int?

    var documentId: String { isoHourId(hourStartUtc) }
    var payload: [String: Any] {
        var d: [String: Any] = [
            "hourStartUtc": isoHourId(hourStartUtc),
            "profileId": profileId,
            "profileName": profileName,
            "snapshotTimestamp": isoHour.string(from: snapshotTimestamp),
            "carbRatio": carbRatio,
            "basalRate": basalRate,
            "insulinSensitivity": insulinSensitivity
        ]
        if let tz = localTzId { d["localTz"] = tz }
        if let lh = localHour { d["localHour"] = lh }
        return d
    }
}

// --- Site change (event + derived daily) ---
struct SiteChangeEventRecord: StreamRecord {
    static let kind: DataKind = .siteChanges
    static let cadence: Cadence = .event

    let id: String       // use UUID
    let location: String
    let localTzId: String
    let timestamp: Date  // client-side timestamp as hint

    var documentId: String { id }
    var payload: [String: Any] {
        [
            "location": location,
            "localTz": localTzId,
            "clientTimestamp": isoHour.string(from: timestamp),
            "createdAt": FieldValue.serverTimestamp(),
            "timestamp": FieldValue.serverTimestamp() // authoritative
        ]
    }
}

struct SiteChangeDailyRecord: StreamRecord {
    static let kind: DataKind = .siteChanges
    static let cadence: Cadence = .daily

    let date: Date
    let daysSince: Int
    let location: String

    var documentId: String { isoDayId(date) }
    var payload: [String: Any] {
        [
            "dateUtc": isoDayId(date),
            "daysSinceChange": daysSince,
            "location": location,
            "computedAt": FieldValue.serverTimestamp()
        ]
    }
}

// MARK: - Convenience façade (optionally keep this name for call sites)

final class HealthDataUploader {
    private var uploader: FirestoreStreamUploader?
    private var cachedUid: String?
    var skipWrites: Bool = false

    init() {
        refresh(for: Auth.auth().currentUser?.uid)
    }

    func refresh(for uid: String?) {
        guard cachedUid != uid else { return }
        cachedUid = uid
        if let uid = uid, !uid.isEmpty {
            uploader = FirestoreStreamUploader(uid: uid)
        } else {
            uploader = nil
        }
    }

    func clear() {
        cachedUid = nil
        uploader = nil
    }

    private func currentUploader(function: String = #function) -> FirestoreStreamUploader? {
        if uploader == nil {
            refresh(for: Auth.auth().currentUser?.uid)
        }
        guard let uploader else {
            print("[HealthDataUploader] Missing uploader for \(function); ensure user is authenticated before syncing.")
            return nil
        }
        return uploader
    }

    // ---- BG ----
    func uploadHourlyBgData(_ data: [(HourlyBgData, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [BGHourlyRecord] = data.map { (e, pid) in
            BGHourlyRecord(start: e.startDate, end: e.endDate, startBg: e.startBg, endBg: e.endBg, therapyProfileId: pid)
        }
        up.upsert(recs, label: "bg hourly")
    }

    func uploadAverageBgData(_ data: [(HourlyAvgBgData, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [BGAverageHourlyRecord] = data.map { (e, pid) in
            BGAverageHourlyRecord(start: e.startDate, end: e.endDate, averageBg: e.averageBg, therapyProfileId: pid)
        }
        up.upsert(recs, label: "bg hourly average")
    }

    func uploadHourlyBgPercentages(_ data: [(HourlyBgPercentages, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [BGPercentHourlyRecord] = data.map { (e, pid) in
            BGPercentHourlyRecord(start: e.startDate, end: e.endDate, percentLow: e.percentLow, percentHigh: e.percentHigh, therapyProfileId: pid)
        }
        up.upsert(recs, label: "bg hourly percent")
    }

    func uploadHourlyBgURoc(_ data: [(HourlyBgURoc, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [BGURocHourlyRecord] = data.map { (e, pid) in
            BGURocHourlyRecord(start: e.startDate, end: e.endDate, uRoc: e.uRoc, expectedEndBg: e.expectedEndBg, therapyProfileId: pid)
        }
        up.upsert(recs, label: "bg hourly uROC")
    }

    // ---- HR ----
    func uploadHourlyHeartRateData(_ data: [Date: (HourlyHeartRateData, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [HRHourlyRecord] = data.values.map { (entry, pid) in
            HRHourlyRecord(hour: entry.hour, heartRate: entry.heartRate, therapyProfileId: pid)
        }
        up.upsert(recs, label: "hr hourly")
    }

    func uploadDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = data.map { HRDailyAverageRecord(date: $0.date, averageHeartRate: $0.averageHeartRate) }
        up.upsert(recs, label: "hr daily avg")
    }

    // ---- Exercise ----
    func uploadHourlyExerciseData(_ data: [Date: (HourlyExerciseData, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [ExerciseHourlyRecord] = data.values.map { (e, pid) in
            ExerciseHourlyRecord(hour: e.hour, moveMinutes: e.moveMinutes, exerciseMinutes: e.exerciseMinutes, totalMinutes: e.totalMinutes, therapyProfileId: pid)
        }
        up.upsert(recs, label: "exercise hourly")
    }

    func uploadDailyAverageExerciseData(_ data: [Date: DailyAverageExerciseData]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = data.values.map {
            ExerciseDailyAverageRecord(date: $0.date, averageMoveMinutes: $0.averageMoveMinutes, averageExerciseMinutes: $0.averageExerciseMinutes, averageTotalMinutes: $0.averageTotalMinutes)
        }
        up.upsert(recs, label: "exercise daily avg")
    }

    // ---- Menstrual ----
    func uploadMenstrualData(_ data: [Date: DailyMenstrualData]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = data.values.map { MenstrualDailyRecord(date: $0.date, daysSincePeriodStart: $0.daysSincePeriodStart) }
        up.upsert(recs, label: "menstrual daily")
    }

    // ---- Body mass ----
    func uploadBodyMassData(_ data: [(HourlyBodyMassData, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [BodyMassHourlyRecord] = data.map { (e, pid) in
            BodyMassHourlyRecord(hour: e.hour, weight: e.weight, therapyProfileId: pid)
        }
        up.upsert(recs, label: "body mass hourly")
    }

    // ---- Resting HR ----
    func uploadRestingHeartRateData(_ data: [DailyRestingHeartRateData]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = data.map { RestingHRDailyRecord(date: $0.date, restingHeartRate: $0.restingHeartRate) }
        up.upsert(recs, label: "resting hr daily")
    }

    // ---- Sleep ----
    func uploadSleepDurations(_ data: [Date: DailySleepDurations]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = data.values.map {
            SleepDailyRecord(date: $0.date, awake: $0.awake, asleepCore: $0.asleepCore, asleepDeep: $0.asleepDeep, asleepREM: $0.asleepREM, asleepUnspecified: $0.asleepUnspecified)
        }
        up.upsert(recs, label: "sleep daily")
    }

    // ---- Energy ----
    func uploadHourlyEnergyData(_ data: [Date: (HourlyEnergyData, String?)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [EnergyHourlyRecord] = data.values.map { (e, pid) in
            EnergyHourlyRecord(hour: e.hour, basalEnergy: e.basalEnergy, activeEnergy: e.activeEnergy, totalEnergy: e.totalEnergy, therapyProfileId: pid)
        }
        up.upsert(recs, label: "energy hourly")
    }

    func uploadDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = data.map { EnergyDailyAverageRecord(date: $0.date, averageActiveEnergy: $0.averageActiveEnergy) }
        up.upsert(recs, label: "energy daily avg")
    }

    // ---- Therapy settings (hourly) ----
    func uploadTherapySettingsByHour(_ hours: [TherapyHour]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs: [TherapySettingsHourlyRecord] = hours.map { h in
            TherapySettingsHourlyRecord(
                hourStartUtc: h.hourStartUtc,
                profileId: h.profileId,
                profileName: h.profileName,
                snapshotTimestamp: h.snapshotTimestamp,
                carbRatio: h.carbRatio,
                basalRate: h.basalRate,
                insulinSensitivity: h.insulinSensitivity,
                localTzId: h.localTz?.identifier,
                localHour: h.localHour
            )
        }
        up.upsert(recs, label: "therapy settings hourly")
    }
}

// MARK: - Site change convenience (event write + same-tick daily seed + backfill)

extension HealthDataUploader {
    /// Record a site change (event), seed today's daily=0, then backfill recent days (idempotent).
    func recordSiteChange(location: String,
                          localTz: TimeZone = .current,
                          backfillDays: Int = 14) {
        guard !skipWrites, let up = currentUploader() else { return }

        // 1) Event (UUID doc id; serverTimestamp for authoritative time)
        let ev = SiteChangeEventRecord(
            id: uuidDocId(),
            location: location,
            localTzId: localTz.identifier,
            timestamp: Date()
        )
        up.upsert([ev], label: "site change event")

        // 2) Seed today's derived daily doc for instant UX
        let today = Date()
        let seed = SiteChangeDailyRecord(date: today, daysSince: 0, location: location)
        up.upsert([seed], label: "site change daily seed")

        // 3) Backfill last N days with authoritative event timestamp
        let end = today
        let start = Calendar.current.date(byAdding: .day, value: -backfillDays, to: end) ?? end
        DataManager.shared.backfillSiteChangeDaily(from: start, to: end, tz: localTz)
    }
}

extension HealthDataUploader {
    func upsertDailySiteStatus(_ days: [(date: Date, daysSince: Int, location: String)]) {
        guard !skipWrites, let up = currentUploader() else { return }
        let recs = days.map { SiteChangeDailyRecord(date: $0.date, daysSince: $0.daysSince, location: $0.location) }
        up.upsert(recs, label: "site daily status")
    }
}
