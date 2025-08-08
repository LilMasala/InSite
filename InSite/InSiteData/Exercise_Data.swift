import Foundation
import HealthKit

enum DataType {
    case move
    case exercise
}

struct HourlyExerciseData {
    let hour: Date
    var moveMinutes: Double
    var exerciseMinutes: Double
    var totalMinutes: Double {
        moveMinutes + exerciseMinutes
    }
}

struct DailyAverageExerciseData {
    let date: Date
    var averageMoveMinutes: Double
    var averageExerciseMinutes: Double
    var averageTotalMinutes: Double {
        (averageMoveMinutes + averageExerciseMinutes) / 2
    }
}

struct LastExerciseData {
    var hoursSinceLightExercise: Double?
    var hoursSinceIntenseExercise: Double?
}

extension HealthStore {
    
    func fetchAndCombineExerciseData(start: Date, end: Date, dispatchGroup: DispatchGroup, completion: @escaping (Result<([Date: HourlyExerciseData], [Date: DailyAverageExerciseData]), Error>) -> Void) {
        var hourlyExerciseData = [Date: HourlyExerciseData]()
        var dailyAverageExerciseData = [Date: DailyAverageExerciseData]()
        let queue = DispatchQueue(label: "com.yourapp.hourlyExerciseDataQueue")
        
        // Hourly data for Move Time
        dispatchGroup.enter()
        fetchHourlyExerciseData(for: appleMoveTimeType, dataType: .move, start: start, end: end) { result in
            switch result {
            case .success(let results):
                for (hour, newData) in results {
                    guard let hourDate = hour as? Date else {
                        print("Invalid date in results: \(hour)")
                        continue
                    }
                    
                    queue.sync {
                        print("hourDate: \(hourDate)")
                        print("newData.totalMinutes: \(newData.totalMinutes)")
                        
                        if var existingData = hourlyExerciseData[hourDate] {
                            print("hourlyExerciseData[hourDate] exists")
                            existingData.moveMinutes += newData.totalMinutes
                            hourlyExerciseData[hourDate] = existingData
                        } else {
                            print("hourlyExerciseData[hourDate] does not exist")
                            let defaultData = HourlyExerciseData(hour: hourDate, moveMinutes: 0, exerciseMinutes: 0)
                            var newEntry = defaultData
                            newEntry.moveMinutes += newData.totalMinutes
                            hourlyExerciseData[hourDate] = newEntry
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching move data: \(error)")
            }
            dispatchGroup.leave()
        }
        
        // Hourly data for Exercise Time
        dispatchGroup.enter()
        fetchHourlyExerciseData(for: appleExerciseTimeType, dataType: .exercise, start: start, end: end) { result in
            switch result {
            case .success(let results):
                for (hour, newData) in results {
                    guard let hourDate = hour as? Date else {
                        print("Invalid date in results: \(hour)")
                        continue
                    }
                    
                    queue.sync {
                        print("hourDate: \(hourDate)")
                        print("newData.totalMinutes: \(newData.totalMinutes)")
                        
                        if var existingData = hourlyExerciseData[hourDate] {
                            print("hourlyExerciseData[hourDate] exists")
                            existingData.exerciseMinutes += newData.totalMinutes
                            hourlyExerciseData[hourDate] = existingData
                        } else {
                            print("hourlyExerciseData[hourDate] does not exist")
                            let defaultData = HourlyExerciseData(hour: hourDate, moveMinutes: 0, exerciseMinutes: 0)
                            var newEntry = defaultData
                            newEntry.exerciseMinutes += newData.totalMinutes
                            hourlyExerciseData[hourDate] = newEntry
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching exercise minutes: \(error)")
                
                dispatchGroup.leave()
            }
            
            // Calculate daily averages post-fetch
            dispatchGroup.notify(queue: .main) {
                for (hour, data) in hourlyExerciseData {
                    let dayStart = Calendar.current.startOfDay(for: hour)
                    let existingData = dailyAverageExerciseData[dayStart, default: DailyAverageExerciseData(date: dayStart, averageMoveMinutes: 0, averageExerciseMinutes: 0)]
                    dailyAverageExerciseData[dayStart] = DailyAverageExerciseData(
                        date: dayStart,
                        averageMoveMinutes: existingData.averageMoveMinutes + data.moveMinutes / 24,  // Assuming average over possible 24 data points
                        averageExerciseMinutes: existingData.averageExerciseMinutes + data.exerciseMinutes / 24
                    )
                }
                completion(.success((hourlyExerciseData, dailyAverageExerciseData)))
            }
        }
        
        func fetchHourlyExerciseData(for quantityType: HKQuantityType, dataType: DataType, start: Date, end: Date, completion: @escaping (Result<[Date: HourlyExerciseData], Error>) -> Void) {
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            var interval = DateComponents()
            interval.hour = 1
            
            let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: [.cumulativeSum], anchorDate: start, intervalComponents: interval)
            query.initialResultsHandler = { _, results, error in
                guard let results = results else {
                    completion(.failure(error ?? HealthStoreError.dataUnavailable("exercise")))
                    return
                }
                
                var data: [Date: HourlyExerciseData] = [:]
                results.enumerateStatistics(from: start, to: end) { statistic, _ in
                    let hour = statistic.startDate
                    let totalMinutes = statistic.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                    var existingData = data[hour, default: HourlyExerciseData(hour: hour, moveMinutes: 0, exerciseMinutes: 0)]
                    
                    switch dataType {
                    case .move:
                        existingData.moveMinutes += totalMinutes
                    case .exercise:
                        existingData.exerciseMinutes += totalMinutes
                    }
                    
                    data[hour] = existingData
                }
                completion(.success(data))
            }
            HKHealthStore().execute(query)
        }
        
        func fetchDailyAverageExerciseData(start: Date, end: Date, healthStore: HKHealthStore, completion: @escaping (Result<[Date: DailyAverageExerciseData], Error>) -> Void) {
            var dailyAverageExerciseData = [Date: DailyAverageExerciseData]()
            
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            var interval = DateComponents()
            interval.day = 1
            
            let query = HKStatisticsCollectionQuery(quantityType: appleMoveTimeType, quantitySamplePredicate: predicate, options: [.cumulativeSum], anchorDate: start, intervalComponents: interval)
            query.initialResultsHandler = { _, results, error in
                guard let results = results else {
                    completion(.failure(error ?? HealthStoreError.dataUnavailable("exercise-move")))
                    return
                }
                
                var moveData: [Date: Double] = [:]
                results.enumerateStatistics(from: start, to: end) { statistic, _ in
                    let date = Calendar.current.startOfDay(for: statistic.startDate)
                    let moveMinutes = statistic.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                    moveData[date] = moveMinutes
                }
                
                let exerciseQuery = HKStatisticsCollectionQuery(quantityType: self.appleExerciseTimeType, quantitySamplePredicate: predicate, options: [.cumulativeSum], anchorDate: start, intervalComponents: interval)
                exerciseQuery.initialResultsHandler = { _, exerciseResults, error in
                    guard let exerciseResults = exerciseResults else {
                        completion(.failure(error ?? HealthStoreError.dataUnavailable("exercise")))
                        return
                    }
                    
                    var exerciseData: [Date: Double] = [:]
                    exerciseResults.enumerateStatistics(from: start, to: end) { statistic, _ in
                        let date = Calendar.current.startOfDay(for: statistic.startDate)
                        let exerciseMinutes = statistic.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                        exerciseData[date] = exerciseMinutes
                    }
                    
                    let allDates = Set(moveData.keys).union(exerciseData.keys)
                    for date in allDates {
                        let moveMinutes = moveData[date, default: 0]
                        let exerciseMinutes = exerciseData[date, default: 0]
                        dailyAverageExerciseData[date] = DailyAverageExerciseData(date: date, averageMoveMinutes: moveMinutes, averageExerciseMinutes: exerciseMinutes)
                    }
                    
                    completion(.success(dailyAverageExerciseData))
                }
                
                healthStore.execute(exerciseQuery)
            }
            
            healthStore.execute(query)
        }
        
        func determineLastExerciseData(healthStore: HKHealthStore, completion: @escaping (LastExerciseData) -> Void) {
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { query, results, error in
                guard let workouts = results as? [HKWorkout], let lastWorkout = workouts.first else {
                    if let error = error {
                        print("Error fetching the last workout: \(error.localizedDescription)")
                    }
                    completion(LastExerciseData(hoursSinceLightExercise: nil, hoursSinceIntenseExercise: nil))
                    return
                }
                
                let now = Date()
                let hoursSinceLastExercise = now.timeIntervalSince(lastWorkout.endDate) / 3600 // Convert seconds to hours
                
                let intensity = lastWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                let isIntense = intensity > 500 // Example threshold for intense exercise
                
                let lastExerciseData = LastExerciseData(
                    hoursSinceLightExercise: isIntense ? nil : hoursSinceLastExercise,
                    hoursSinceIntenseExercise: isIntense ? hoursSinceLastExercise : nil
                )
                
                completion(lastExerciseData)
            }
            
            healthStore.execute(query)
        }
    }
}
