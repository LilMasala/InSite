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
#if DEBUG
        MockHealthDataSeeder.seed()
#endif
        
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
        fetcher.fetchAllBgData(start: startDate, end: endDate, group: dispatchGroup) { result in
            switch result {
            case .success(let (hourlyBgData, avgBgData, hourlyPercentages)):
                self.processHourlyBgData(hourlyBgData)
                self.processAvgBgData(avgBgData)
                self.processHourlyBgPercentages(hourlyPercentages)
            case .failure(let error):
                print("BG fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }
        
        // Fetch Heart Rate Data
        dispatchGroup.enter()
        fetcher.fetchHeartRateData(start: startDate, end: endDate, group: dispatchGroup) { result in
            switch result {
            case .success(let (hourlyData, dailyAverageData)):
                self.processHourlyHeartRateData(hourlyData)
                self.processDailyAverageHeartRateData(dailyAverageData)
            case .failure(let error):
                print("Heart rate fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }
        
        // Fetch Exercise Data
        dispatchGroup.enter()
        fetcher.fetchExerciseData(start: startDate, end: endDate, group: dispatchGroup) { result in
            switch result {
            case .success(let (hourlyData, dailyAverageData)):
                self.processHourlyExerciseData(hourlyData)
                self.processDailyAverageExerciseData(dailyAverageData)
            case .failure(let error):
                print("Exercise fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }
        
        // Fetch Menstrual Data
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
        
        // Fetch Body Mass Data
        dispatchGroup.enter()
        fetcher.fetchBodyMassData(start: startDate, end: endDate, group: dispatchGroup) { result in
            switch result {
            case .success(let data):
                self.processBodyMassData(data)
            case .failure(let error):
                print("Body mass fetch error: \(error)")
            }
            self.dispatchGroup.leave()
        }
        
        // Fetch Resting Heart Rate Data
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
        
        // Fetch Sleep Durations
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
        
        // Fetch Energy Data
        dispatchGroup.enter()
        fetcher.fetchEnergyData(start: startDate, end: endDate, group: dispatchGroup) { result in
            switch result {
            case .success(let (hourlyEnergyData, dailyAverageEnergyData)):
                self.processHourlyEnergyData(hourlyEnergyData)
                self.processDailyAverageEnergyData(dailyAverageEnergyData)
            case .failure(let error):
                print("Energy fetch error: \(error)")
            }
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
        uploader.uploadHourlyBgData(data)
    }
    
    private func processAvgBgData(_ data: [HourlyAvgBgData]) {
        print("Processed average blood glucose data")
        uploader.uploadAverageBgData(data)
    }
    
    private func processHourlyBgPercentages(_ data: [HourlyBgPercentages]) {
        print("Processed hourly blood glucose percentages")
        uploader.uploadHourlyBgPercentages(data)
    }
    
    private func processHourlyHeartRateData(_ data: [Date: HourlyHeartRateData]) {
        print("Processed hourly heart rate data")
        uploader.uploadHourlyHeartRateData(data)
    }
    
    private func processDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        print("Processed daily average heart rate data")
        uploader.uploadDailyAverageHeartRateData(data)
    }
    
    private func processHourlyExerciseData(_ data: [Date: HourlyExerciseData]) {
        print("Processed hourly exercise data")
        uploader.uploadHourlyExerciseData(data)
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
        for massData in data {
            bodyMassDict[massData.hour] = massData.weight
        }
        
        print("Body mass data dictionary: \(bodyMassDict)")
        uploader.uploadBodyMassData(data)
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
        uploader.uploadHourlyEnergyData(data)
    }

    private func processDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        print("Processed daily average energy data")
        uploader.uploadDailyAverageEnergyData(data)
    }

}
