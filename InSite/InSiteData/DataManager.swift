import Foundation
import HealthKit

// Coordinator between HealthKit fetching and Firebase uploading

class DataManager {
    static let shared = DataManager()
    private let fetcher = HealthDataFetcher()
    private let uploader = HealthDataUploader()
    private let dispatchGroup = DispatchGroup()

    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        fetcher.requestAuthorization(completion: completion)
    }
    
    func syncHealthData(completion: @escaping () -> Void) {
        let lastSyncDateKey = "LastSyncDate"
        let startDate: Date = (UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date)
            ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let endDate = Date()
        
        // Before dispatchGroup.notify(...)
        self.backfillTherapySettingsByHour(from: startDate, to: endDate, tz: TimeZone(identifier: "America/Detroit") ?? .current)


        // ---- Blood Glucose (uses its own internal subtasks) ----
        dispatchGroup.enter()
        print("Fetching BG Data")
        let bgGroup = DispatchGroup()
        fetcher.fetchAllBgData(start: startDate, end: endDate, group: bgGroup) { result in
            print("BG fetch completed with result: \(result)")
            switch result {
            case .success(let (hourlyBgData, avgBgData, hourlyPercentages)):
                print("BG success, hourly=\(hourlyBgData.count) avg=\(avgBgData.count) pct=\(hourlyPercentages.count)")
                self.processHourlyBgData(hourlyBgData)
                self.processAvgBgData(avgBgData)
                self.processHourlyBgPercentages(hourlyPercentages)
                let uroc = BgAnalytics.computeHourlyURoc(hourlyBgData: hourlyBgData, targetBG: 110)
                self.processHourlyBgURoc(uroc)
            case .failure(let error):
                print("BG fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Heart Rate (has internal parallelization) ----
        dispatchGroup.enter()
        let hrGroup = DispatchGroup()
        fetcher.fetchHeartRateData(start: startDate, end: endDate, group: hrGroup) { result in
            switch result {
            case .success(let (hourlyData, dailyAverageData)):
                self.processHourlyHeartRateData(hourlyData)
                self.processDailyAverageHeartRateData(dailyAverageData)
            case .failure(let error):
                print("Heart rate fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Exercise (has internal parallelization) ----
        dispatchGroup.enter()
        let exGroup = DispatchGroup()
        fetcher.fetchExerciseData(start: startDate, end: endDate, group: exGroup) { result in
            switch result {
            case .success(let (hourlyData, dailyAverageData)):
                self.processHourlyExerciseData(hourlyData)
                self.processDailyAverageExerciseData(dailyAverageData)
            case .failure(let error):
                print("Exercise fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Menstrual ----
        dispatchGroup.enter()
        fetcher.fetchMenstrualData(start: startDate, end: endDate) { result in
            switch result {
            case .success(let data):
                self.processMenstrualData(data)
            case .failure(let error):
                print("Menstrual fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Body Mass ----
        dispatchGroup.enter()
        fetcher.fetchBodyMassData(start: startDate, end: endDate, group: DispatchGroup()) { result in
            switch result {
            case .success(let data):
                self.processBodyMassData(data)
            case .failure(let error):
                print("Body mass fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Resting HR ----
        dispatchGroup.enter()
        fetcher.fetchRestingHeartRate(start: startDate, end: endDate) { result in
            switch result {
            case .success(let data):
                self.processRestingHeartRateData(data)
            case .failure(let error):
                print("Resting heart rate fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Sleep ----
        dispatchGroup.enter()
        fetcher.fetchSleepDurations(start: startDate, end: endDate) { result in
            switch result {
            case .success(let data):
                self.processSleepDurations(data)
            case .failure(let error):
                print("Sleep fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // ---- Energy (has internal parallelization) ----
        dispatchGroup.enter()
        let energyGroup = DispatchGroup()
        fetcher.fetchEnergyData(start: startDate, end: endDate, group: energyGroup) { result in
            switch result {
            case .success(let (hourlyEnergyData, dailyAverageEnergyData)):
                self.processHourlyEnergyData(hourlyEnergyData)
                self.processDailyAverageEnergyData(dailyAverageEnergyData)
            case .failure(let error):
                print("Energy fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }

        // Final notify
        dispatchGroup.notify(queue: .main) {
            UserDefaults.standard.set(endDate, forKey: lastSyncDateKey)
            completion()
        }
    }

    
    private func processHourlyBgData(_ data: [HourlyBgData]) {
        print("Processed hourly blood glucose data")
        Task {
            var enriched: [(HourlyBgData, String?)] = []
            for entry in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: entry.startDate)
                enriched.append((entry, profile?.profileId))
            }
            uploader.uploadHourlyBgData(enriched)
        }
    }

    private func processAvgBgData(_ data: [HourlyAvgBgData]) {
        print("Processed average blood glucose data")
        Task {
            var enriched: [(HourlyAvgBgData, String?)] = []
            for entry in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: entry.startDate)
                enriched.append((entry, profile?.profileId))
            }
            uploader.uploadAverageBgData(enriched)
        }
    }

    private func processHourlyBgPercentages(_ data: [HourlyBgPercentages]) {
        print("Processed hourly blood glucose percentages")
        Task {
            var enriched: [(HourlyBgPercentages, String?)] = []
            for entry in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: entry.startDate)
                enriched.append((entry, profile?.profileId))
            }
            uploader.uploadHourlyBgPercentages(enriched)
        }
    }

    private func processHourlyHeartRateData(_ data: [Date: HourlyHeartRateData]) {
        print("Processed hourly heart rate data")
        Task {
            var enriched: [Date: (HourlyHeartRateData, String?)] = [:]
            for (date, entry) in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: date)
                enriched[date] = (entry, profile?.profileId)
            }
            uploader.uploadHourlyHeartRateData(enriched)
        }
    }
    
    private func processDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        print("Processed daily average heart rate data")
        uploader.uploadDailyAverageHeartRateData(data)
    }
    
    private func processHourlyBgURoc(_ data: [HourlyBgURoc]) {
        print("Processed hourly BG uROC")
        Task {
            var enriched: [(HourlyBgURoc, String?)] = []
            for entry in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: entry.startDate)
                enriched.append((entry, profile?.profileId))
            }
            uploader.uploadHourlyBgURoc(enriched) // add this method in HealthDataUploader
        }
    }

    
    private func processHourlyExerciseData(_ data: [Date: HourlyExerciseData]) {
        print("Processed hourly exercise data")
        Task {
            var enriched: [Date: (HourlyExerciseData, String?)] = [:]
            for (date, entry) in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: date)
                enriched[date] = (entry, profile?.profileId)
            }
            uploader.uploadHourlyExerciseData(enriched)
        }
    }

    private func processDailyAverageExerciseData(_ data: [Date: DailyAverageExerciseData]) {
        print("Processed daily average exercise data")
        uploader.uploadDailyAverageExerciseData(data)
    }
    
    private func processMenstrualData(_ data: [Date: DailyMenstrualData]) {
        print("Processed menstrual data")
        uploader.uploadMenstrualData(data)
    }
    
    private func processBodyMassData(_ data: [HourlyBodyMassData]) {
        print("Processed body mass data")

        var bodyMassDict = [Date: Double]()
        Task {
            var enriched: [(HourlyBodyMassData, String?)] = []
            for massData in data {
                bodyMassDict[massData.hour] = massData.weight
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: massData.hour)
                enriched.append((massData, profile?.profileId))
            }

            print("Body mass data dictionary: \(bodyMassDict)")
            uploader.uploadBodyMassData(enriched)
        }
    }

    
    private func processRestingHeartRateData(_ data: [DailyRestingHeartRateData]) {
        print("Processed resting heart rate data")
        
        var restingHeartRateDict = [Date: Double]()
        for heartRateData in data {
            restingHeartRateDict[heartRateData.date] = heartRateData.restingHeartRate
        }

        // Now you can save or process `restingHeartRateDict`
        print("Resting heart rate data dictionary: \(restingHeartRateDict)")
        uploader.uploadRestingHeartRateData(data)
    }

    
    private func processSleepDurations(_ data: [Date: DailySleepDurations]) {
        print("Processed sleep durations")
        uploader.uploadSleepDurations(data)
    }

    private func processHourlyEnergyData(_ data: [Date: HourlyEnergyData]) {
        print("Processed hourly energy data")
        Task {
            var enriched: [Date: (HourlyEnergyData, String?)] = [:]
            for (date, entry) in data {
                let profile = try? await TherapySettingsLogManager.shared.getActiveTherapyProfile(at: date)
                enriched[date] = (entry, profile?.profileId)
            }
            uploader.uploadHourlyEnergyData(enriched)
        }
    }

    private func processDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        print("Processed daily average energy data")
        uploader.uploadDailyAverageEnergyData(data)
    }

    func backfillTherapySettingsByHour(from startDate: Date, to endDate: Date, tz: TimeZone = .current) {
        Task {
            // 0) Decide window with a small buffer and last-backfill memory
            let key = "LastTherapyHourBackfill"
            let last = (UserDefaults.standard.object(forKey: key) as? Date)
            let windowStart = max(last ?? startDate, startDate).addingTimeInterval(-86_400) // -24h buffer
            let windowEnd = endDate

            // 1) Load snapshots once
            let snaps = (try? await TherapySettingsLogManager.shared.loadSnapshots(since: windowStart, until: windowEnd)) ?? []
            guard !snaps.isEmpty else {
                print("No therapy snapshots; skipping backfill")
                UserDefaults.standard.set(windowEnd, forKey: key)
                return
            }

            // 2) Build intervals: [snap[i].timestamp, snap[i+1].timestamp)
            struct Interval { let start: Date; let end: Date?; let snap: TherapySnapshot }
            var intervals: [Interval] = []
            for i in 0..<snaps.count {
                let startT = snaps[i].timestamp
                let endT = (i+1 < snaps.count) ? snaps[i+1].timestamp : nil
                intervals.append(Interval(start: startT, end: endT, snap: snaps[i]))
            }

            // 3) Walk each UTC hour in window and resolve settings
            var hours: [TherapyHour] = []
            for hourStart in eachHourUTC(from: windowStart, to: windowEnd) {
                // find interval covering hourStart
                guard let iv = intervals.last(where: { hourStart >= $0.start && ( $0.end == nil || hourStart < $0.end! ) }) else {
                    continue // before first snapshot; skip or choose policy
                }
                // map hourStart -> local hour to select HourRange
                let localHour = localHour(for: hourStart, tz: tz)
                guard let hr = rangeFor(localHour: localHour, in: iv.snap.hourRanges) else {
                    // if gap, you can choose to skip or fallback
                    continue
                }
                hours.append(
                    TherapyHour(
                        hourStartUtc: hourStart,
                        profileId: iv.snap.profileId,
                        profileName: iv.snap.profileName,
                        snapshotTimestamp: iv.snap.timestamp,
                        carbRatio: hr.carbRatio,
                        basalRate: hr.basalRate,
                        insulinSensitivity: hr.insulinSensitivity,
                        localTz: tz,
                        localHour: localHour
                    )
                )
            }

            // 4) Upload in batches (idempotent: doc id = hourStartUtc)
            uploader.uploadTherapySettingsByHour(hours)

            // 5) Advance checkpoint
            UserDefaults.standard.set(windowEnd, forKey: key)
        }
    }

    // --- helpers ---
    private func eachHourUTC(from start: Date, to end: Date) -> [Date] {
        var out: [Date] = []
        let cal = Calendar(identifier: .gregorian)
        var cur = floorToHourUTC(start)
        let stop = floorToHourUTC(end)
        while cur <= stop {
            out.append(cur)
            cur = cal.date(byAdding: .hour, value: 1, to: cur)!
        }
        return out
    }

    private func floorToHourUTC(_ d: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year,.month,.day,.hour], from: d)
        return cal.date(from: comps)!
    }

    private func localHour(for utcHourStart: Date, tz: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.component(.hour, from: utcHourStart) // using the same moment, just viewed in local tz
    }

    private func rangeFor(localHour: Int, in ranges: [HourRange]) -> HourRange? {
        // supports wraparound: e.g., 22..5 means 22,23,0,1,2,3,4,5
        func contains(_ r: HourRange, _ h: Int) -> Bool {
            if r.startHour <= r.endHour {
                return (r.startHour...r.endHour).contains(h)
            } else {
                return h >= r.startHour || h <= r.endHour
            }
        }
        // If multiple match, prefer the most specific (shortest span)
        return ranges
            .filter { contains($0, localHour) }
            .sorted { span($0) < span($1) }
            .first
    }

    private func span(_ r: HourRange) -> Int {
        r.startHour <= r.endHour
            ? (r.endHour - r.startHour + 1)
            : (24 - r.startHour + r.endHour + 1)
    }
}
