import Foundation
import HealthKit

class DataManager {
    static let shared = DataManager()
    private var healthStore: HealthStore?
    private let dispatchGroup = DispatchGroup()
    
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
        // Process and save the hourly blood glucose data
    }
    
    private func processAvgBgData(_ data: [HourlyAvgBgData]) {
        print("Processed average blood glucose data")
        // Process and save the average blood glucose data
    }
    
    private func processHourlyBgPercentages(_ data: [HourlyBgPercentages]) {
        print("Processed hourly blood glucose percentages")
        // Process and save the hourly blood glucose percentages data
    }
    
    private func processHourlyHeartRateData(_ data: [Date: HourlyHeartRateData]) {
        print("Processed hourly heart rate data")
        // Process and save the hourly heart rate data
    }
    
    private func processDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        print("Processed daily average heart rate data")
        // Process and save the daily average heart rate data
    }
    
    private func processHourlyExerciseData(_ data: [Date: HourlyExerciseData]) {
        print("Processed hourly exercise data")
        // Process and save the hourly exercise data
    }
    
    private func processDailyAverageExerciseData(_ data: [Date: DailyAverageExerciseData]) {
        print("Processed daily average exercise data")
        // Process and save the daily average exercise data
    }
    
    private func processMenstrualData(_ data: [Date: DailyMenstrualData]) {
        print("Processed menstrual data")
        // Process and save the menstrual data
    }
    
    private func processBodyMassData(_ data: [HourlyBodyMassData]) {
        print("Processed body mass data")
        
        var bodyMassDict = [Date: Double]()
        for massData in data {
            bodyMassDict[massData.hour] = massData.weight
        }
        
        // Now you can save or process `bodyMassDict`
        print("Body mass data dictionary: \(bodyMassDict)")
    }

    
    private func processRestingHeartRateData(_ data: [DailyRestingHeartRateData]) {
        print("Processed resting heart rate data")
        
        var restingHeartRateDict = [Date: Double]()
        for heartRateData in data {
            restingHeartRateDict[heartRateData.date] = heartRateData.restingHeartRate
        }
        
        // Now you can save or process `restingHeartRateDict`
        print("Resting heart rate data dictionary: \(restingHeartRateDict)")
    }

    
    private func processSleepDurations(_ data: [Date: DailySleepDurations]) {
        print("Processed sleep durations")
        // Process and save the sleep durations
    }
    
    private func processHourlyEnergyData(_ data: [Date: HourlyEnergyData]) {
        print("Processed hourly energy data")
        // Process and save the hourly energy data
    }
    
    private func processDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        print("Processed daily average energy data")
        // Process and save the daily average energy data
    }
}
