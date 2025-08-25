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

}
