import Foundation
import HealthKit
import FirebaseFirestore
import FirebaseAuth

class DataManager {
    static let shared = DataManager()
    private var healthStore: HealthStore?
    private let dispatchGroup = DispatchGroup()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    private func userCollection(_ name: String) -> CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return Firestore.firestore().collection("users").document(uid).collection(name)
    }
    
    private init() {
        healthStore = HealthStore()
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        healthStore?.requestAuthorization { success in
            completion(success)
        }
    }
    
    func syncHealthData(completion: @escaping () -> Void) {
        guard let healthStore = healthStore else { return }
        
        // Retrieve last sync date from UserDefaults or set a default date
        let lastSyncDateKey = "LastSyncDate"
        let startDate: Date
        if let savedDate = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date {
            startDate = savedDate
        } else {
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        }
        let endDate = Date()
        
        // Fetch Blood Glucose Data
        dispatchGroup.enter()
        healthStore.fetchAllBgData(start: startDate, end: endDate, dispatchGroup: dispatchGroup) { hourlyBgData, avgBgData, hourlyPercentages in
            self.processHourlyBgData(hourlyBgData)
            self.processAvgBgData(avgBgData)
            self.processHourlyBgPercentages(hourlyPercentages)
            self.dispatchGroup.leave()
        }
        
        // Fetch Heart Rate Data
        dispatchGroup.enter()
        healthStore.fetchAndCombineHourlyHeartRateData(start: startDate, end: endDate, dispatchGroup: dispatchGroup) { hourlyData, dailyAverageData in
            self.processHourlyHeartRateData(hourlyData)
            self.processDailyAverageHeartRateData(dailyAverageData)
            self.dispatchGroup.leave()
        }
        
        // Fetch Exercise Data
        dispatchGroup.enter()
        healthStore.fetchAndCombineExerciseData(start: startDate, end: endDate, dispatchGroup: dispatchGroup) { hourlyData, dailyAverageData in
            self.processHourlyExerciseData(hourlyData)
            self.processDailyAverageExerciseData(dailyAverageData)
            self.dispatchGroup.leave()
        }
        
        // Fetch Menstrual Data
        dispatchGroup.enter()
        healthStore.fetchMenstrualData(startDate: startDate, endDate: endDate) { menstrualData in
            self.processMenstrualData(menstrualData)
            self.dispatchGroup.leave()
        }
        
        // Fetch Body Mass Data
        dispatchGroup.enter()
        healthStore.fetchHourlyMassData(start: startDate, end: endDate, dispatchGroup: dispatchGroup) { bodyMassData in
            self.processBodyMassData(bodyMassData)
            self.dispatchGroup.leave()
        }
        
        // Fetch Resting Heart Rate Data
        dispatchGroup.enter()
        healthStore.fetchDailyRestingHeartRate(startDate: startDate, endDate: endDate) { restingHeartRateData in
            self.processRestingHeartRateData(restingHeartRateData)
            self.dispatchGroup.leave()
        }
        
        // Fetch Sleep Durations
        dispatchGroup.enter()
        healthStore.fetchSleepDurations(startDate: startDate, endDate: endDate) { sleepDurations in
            self.processSleepDurations(sleepDurations)
            self.dispatchGroup.leave()
        }
        
        // Fetch Energy Data
        dispatchGroup.enter()
        healthStore.fetchAndCombineHourlyEnergyData(start: startDate, end: endDate, dispatchGroup: dispatchGroup) { hourlyEnergyData, dailyAverageEnergyData in
            self.processHourlyEnergyData(hourlyEnergyData)
            self.processDailyAverageEnergyData(dailyAverageEnergyData)
            self.dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            // Save the end date as the last sync date
            UserDefaults.standard.set(endDate, forKey: lastSyncDateKey)
            completion()
        }
    }
    
    private func processHourlyBgData(_ data: [HourlyBgData]) {
        print("Processed hourly blood glucose data")
        uploadHourlyBgData(data)
    }
    
    private func processAvgBgData(_ data: [HourlyAvgBgData]) {
        print("Processed average blood glucose data")
        uploadAverageBgData(data)
    }
    
    private func processHourlyBgPercentages(_ data: [HourlyBgPercentages]) {
        print("Processed hourly blood glucose percentages")
        uploadHourlyBgPercentages(data)
    }
    
    private func processHourlyHeartRateData(_ data: [Date: HourlyHeartRateData]) {
        print("Processed hourly heart rate data")
        uploadHourlyHeartRateData(data)
    }
    
    private func processDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        print("Processed daily average heart rate data")
        uploadDailyAverageHeartRateData(data)
    }
    
    private func processHourlyExerciseData(_ data: [Date: HourlyExerciseData]) {
        print("Processed hourly exercise data")
        uploadHourlyExerciseData(data)
    }

    private func processDailyAverageExerciseData(_ data: [Date: DailyAverageExerciseData]) {
        print("Processed daily average exercise data")
        uploadDailyAverageExerciseData(data)
    }
    
    private func processMenstrualData(_ data: [Date: DailyMenstrualData]) {
        print("Processed menstrual data")
        uploadMenstrualData(data)
    }
    
    private func processBodyMassData(_ data: [HourlyBodyMassData]) {
        print("Processed body mass data")
        
        var bodyMassDict = [Date: Double]()
        for massData in data {
            bodyMassDict[massData.hour] = massData.weight
        }
        
        print("Body mass data dictionary: \(bodyMassDict)")
        uploadBodyMassData(data)
    }

    
    private func processRestingHeartRateData(_ data: [DailyRestingHeartRateData]) {
        print("Processed resting heart rate data")
        
        var restingHeartRateDict = [Date: Double]()
        for heartRateData in data {
            restingHeartRateDict[heartRateData.date] = heartRateData.restingHeartRate
        }

        // Now you can save or process `restingHeartRateDict`
        print("Resting heart rate data dictionary: \(restingHeartRateDict)")
        uploadRestingHeartRateData(data)
    }

    
    private func processSleepDurations(_ data: [Date: DailySleepDurations]) {
        print("Processed sleep durations")
        uploadSleepDurations(data)
    }

    private func processHourlyEnergyData(_ data: [Date: HourlyEnergyData]) {
        print("Processed hourly energy data")
        uploadHourlyEnergyData(data)
    }

    private func processDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        print("Processed daily average energy data")
        uploadDailyAverageEnergyData(data)
    }

    // MARK: - Firebase Upload Helpers

    private func uploadHourlyBgData(_ data: [HourlyBgData]) {
        guard let collection = userCollection("blood_glucose") else { return }
        for entry in data {
            var dict: [String: Any] = [
                "startDate": isoString(from: entry.startDate),
                "endDate": isoString(from: entry.endDate),
                "type": "hourly"
            ]
            if let start = entry.startBg { dict["startBg"] = start }
            if let end = entry.endBg { dict["endBg"] = end }
            collection.document("hourly-\(isoString(from: entry.startDate))").setData(dict)
        }
    }

    private func uploadAverageBgData(_ data: [HourlyAvgBgData]) {
        guard let collection = userCollection("blood_glucose") else { return }
        for entry in data {
            var dict: [String: Any] = [
                "startDate": isoString(from: entry.startDate),
                "endDate": isoString(from: entry.endDate),
                "type": "average"
            ]
            if let avg = entry.averageBg { dict["averageBg"] = avg }
            collection.document("average-\(isoString(from: entry.startDate))").setData(dict)
        }
    }

    private func uploadHourlyBgPercentages(_ data: [HourlyBgPercentages]) {
        guard let collection = userCollection("blood_glucose") else { return }
        for entry in data {
            let dict: [String: Any] = [
                "startDate": isoString(from: entry.startDate),
                "endDate": isoString(from: entry.endDate),
                "percentLow": entry.percentLow,
                "percentHigh": entry.percentHigh,
                "type": "percent"
            ]
            collection.document("percent-\(isoString(from: entry.startDate))").setData(dict)
        }
    }

    private func uploadHourlyHeartRateData(_ data: [Date: HourlyHeartRateData]) {
        guard let collection = userCollection("heart_rate") else { return }
        for (date, entry) in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "heartRate": entry.heartRate,
                "type": "hourly"
            ]
            collection.document("hourly-\(isoString(from: date))").setData(dict)
        }
    }

    private func uploadDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        guard let collection = userCollection("heart_rate") else { return }
        for entry in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "averageHeartRate": entry.averageHeartRate,
                "type": "daily_average"
            ]
            collection.document("average-\(isoString(from: entry.date))").setData(dict)
        }
    }

    private func uploadHourlyExerciseData(_ data: [Date: HourlyExerciseData]) {
        guard let collection = userCollection("exercise") else { return }
        for (date, entry) in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "moveMinutes": entry.moveMinutes,
                "exerciseMinutes": entry.exerciseMinutes,
                "totalMinutes": entry.totalMinutes,
                "type": "hourly"
            ]
            collection.document("hourly-\(isoString(from: date))").setData(dict)
        }
    }

    private func uploadDailyAverageExerciseData(_ data: [Date: DailyAverageExerciseData]) {
        guard let collection = userCollection("exercise") else { return }
        for (date, entry) in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "averageMoveMinutes": entry.averageMoveMinutes,
                "averageExerciseMinutes": entry.averageExerciseMinutes,
                "averageTotalMinutes": entry.averageTotalMinutes,
                "type": "daily_average"
            ]
            collection.document("average-\(isoString(from: date))").setData(dict)
        }
    }

    private func uploadMenstrualData(_ data: [Date: DailyMenstrualData]) {
        guard let collection = userCollection("menstrual") else { return }
        for (date, entry) in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "daysSincePeriodStart": entry.daysSincePeriodStart
            ]
            collection.document(isoString(from: date)).setData(dict)
        }
    }

    private func uploadBodyMassData(_ data: [HourlyBodyMassData]) {
        guard let collection = userCollection("body_mass") else { return }
        for entry in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "weight": entry.weight
            ]
            collection.document(isoString(from: entry.hour)).setData(dict)
        }
    }

    private func uploadRestingHeartRateData(_ data: [DailyRestingHeartRateData]) {
        guard let collection = userCollection("resting_heart_rate") else { return }
        for entry in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "restingHeartRate": entry.restingHeartRate
            ]
            collection.document(isoString(from: entry.date)).setData(dict)
        }
    }

    private func uploadSleepDurations(_ data: [Date: DailySleepDurations]) {
        guard let collection = userCollection("sleep") else { return }
        for (date, entry) in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "awake": entry.awake,
                "asleepCore": entry.asleepCore,
                "asleepDeep": entry.asleepDeep,
                "asleepREM": entry.asleepREM,
                "asleepUnspecified": entry.asleepUnspecified
            ]
            collection.document(isoString(from: date)).setData(dict)
        }
    }

    private func uploadHourlyEnergyData(_ data: [Date: HourlyEnergyData]) {
        guard let collection = userCollection("energy") else { return }
        for (date, entry) in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "basalEnergy": entry.basalEnergy,
                "activeEnergy": entry.activeEnergy,
                "totalEnergy": entry.totalEnergy,
                "type": "hourly"
            ]
            collection.document("hourly-\(isoString(from: date))").setData(dict)
        }
    }

    private func uploadDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        guard let collection = userCollection("energy") else { return }
        for entry in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "averageActiveEnergy": entry.averageActiveEnergy,
                "type": "daily_average"
            ]
            collection.document("average-\(isoString(from: entry.date))").setData(dict)
        }
    }
}
