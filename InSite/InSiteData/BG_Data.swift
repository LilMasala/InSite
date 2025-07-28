import Foundation
import HealthKit

struct HourlyBgPercentages {
    let startDate: Date
    let endDate: Date
    let percentLow: Double
    let percentHigh: Double
}

struct HourlyBgData {
    let startDate: Date
    let endDate: Date
    let startBg: Double?
    let endBg: Double?
}

struct HourlyBgValues {
    let startDate: Date
    let endDate: Date
    let values: [Double]
}

struct HourlyAvgBgData {
    let startDate: Date
    let endDate: Date
    let averageBg: Double?
}

extension HealthStore {
    public func fetchAllBgData(start: Date, end: Date, dispatchGroup: DispatchGroup, completion: @escaping (Result<([HourlyBgData], [HourlyAvgBgData], [HourlyBgPercentages]), Error>) -> Void) {
        guard let healthStore = self.healthStore else {
            completion(.failure(HealthStoreError.notAvailable))
            return
        }
        var hourlyBgData: [HourlyBgData] = []
        var avgBgData: [HourlyAvgBgData] = []
        var hourlyPercentages: [HourlyBgPercentages] = []

        dispatchGroup.enter()
        fetchBgAtStartandEnd(start: start, end: end, healthStore: healthStore, bloodGlucoseType: bloodGlucoseType) { result in
            switch result {
            case .success(let data):
                hourlyBgData = data
            case .failure(let error):
                print("Error fetching BG start/end: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        fetchAvgBg(start: start, end: end, healthStore: healthStore, bloodGlucoseType: bloodGlucoseType) { result in
            switch result {
            case .success(let data):
                avgBgData = data
            case .failure(let error):
                print("Error fetching BG average: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        calculatePercentLowAndHigh(start: start, end: end, healthStore: healthStore, dispatchGroup: dispatchGroup, bloodGlucoseType: bloodGlucoseType) { result in
            switch result {
            case .success(let data):
                hourlyPercentages = data
            case .failure(let error):
                print("Error calculating BG percentages: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            completion(.success((hourlyBgData, avgBgData, hourlyPercentages)))
        }
    }

    private func fetchBgAtStartandEnd(start: Date, end: Date, healthStore: HKHealthStore, bloodGlucoseType: HKQuantityType, completion: @escaping (Result<[HourlyBgData], Error>) -> Void) {
        let calendar = Calendar.current

        // Create an hourly interval
        var dateComponents = DateComponents()
        dateComponents.hour = 1

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: bloodGlucoseType, quantitySamplePredicate: predicate, options: [.discreteAverage], anchorDate: start, intervalComponents: dateComponents)

        query.initialResultsHandler = { _, result, error in
            guard let result = result else {
                completion(.failure(error ?? HealthStoreError.dataUnavailable("bg-start-end")))
                return
            }

            var bgData: [HourlyBgData] = []

            result.enumerateStatistics(from: start, to: end) { statistic, _ in
                let startDate = statistic.startDate
                let endDate = statistic.endDate
                let startBg = statistic.averageQuantity()?.doubleValue(for: HKUnit(from: "mg/dL"))
                let endBg = statistic.averageQuantity()?.doubleValue(for: HKUnit(from: "mg/dL"))

                let hourlyData = HourlyBgData(startDate: startDate, endDate: endDate, startBg: startBg, endBg: endBg)
                bgData.append(hourlyData)
            }

            completion(.success(bgData))
        }

        healthStore.execute(query)
    }

    private func fetchAllBgPerHour(start: Date, end: Date, healthStore: HKHealthStore, bloodGlucoseType: HKQuantityType, dispatchGroup: DispatchGroup, completion: @escaping (Result<[HourlyBgValues], Error>) -> Void) {
        let calendar = Calendar.current
        var date = start
        var hourlyBgValues: [HourlyBgValues] = []
        let unit = HKUnit(from: "mg/dL")

        while date < end {
            let nextDate = calendar.date(byAdding: .hour, value: 1, to: date)!
            let predicate = HKQuery.predicateForSamples(withStart: date, end: nextDate, options: .strictStartDate)

            dispatchGroup.enter()
            let query = HKSampleQuery(sampleType: bloodGlucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                defer { dispatchGroup.leave() }
                guard error == nil else {
                    completion(.failure(error!))
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    completion(.failure(HealthStoreError.dataUnavailable("bg-hour-values")))
                    return
                }

                var values: [Double] = []
                for sample in samples {
                    let value = sample.quantity.doubleValue(for: unit)
                    values.append(value)
                }

                let hourlyData = HourlyBgValues(startDate: date, endDate: nextDate, values: values)
                hourlyBgValues.append(hourlyData)
            }

            healthStore.execute(query)
            date = nextDate
        }

        dispatchGroup.notify(queue: .main) {
            completion(.success(hourlyBgValues))
        }
    }

    private func fetchAvgBg(start: Date, end: Date, healthStore: HKHealthStore, bloodGlucoseType: HKQuantityType, completion: @escaping (Result<[HourlyAvgBgData], Error>) -> Void) {
        let calendar = Calendar.current

        // Create an hourly interval
        var dateComponents = DateComponents()
        dateComponents.hour = 1

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: bloodGlucoseType, quantitySamplePredicate: predicate, options: [.discreteAverage], anchorDate: start, intervalComponents: dateComponents)

        query.initialResultsHandler = { _, result, error in
            guard let result = result else {
                completion(.failure(error ?? HealthStoreError.dataUnavailable("bg-avg")))
                return
            }

            var avgBgData: [HourlyAvgBgData] = []

            result.enumerateStatistics(from: start, to: end) { statistic, _ in
                let startDate = statistic.startDate
                let endDate = statistic.endDate
                let averageBg = statistic.averageQuantity()?.doubleValue(for: HKUnit(from: "mg/dL"))

                let hourlyData = HourlyAvgBgData(startDate: startDate, endDate: endDate, averageBg: averageBg)
                avgBgData.append(hourlyData)
            }

            completion(.success(avgBgData))
        }

        healthStore.execute(query)
    }

    private func calculatePercentLowAndHigh(start: Date, end: Date, healthStore: HKHealthStore, dispatchGroup: DispatchGroup, bloodGlucoseType: HKQuantityType, completion: @escaping (Result<[HourlyBgPercentages], Error>) -> Void) {
        let lowBg = 80.0
        let highBg = 180.0

        fetchAllBgPerHour(start: start, end: end, healthStore: healthStore, bloodGlucoseType: bloodGlucoseType, dispatchGroup: dispatchGroup) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let hourlyBgValues):
            var hourlyPercentages: [HourlyBgPercentages] = []

            for hourlyBg in hourlyBgValues {
                let totalCount = hourlyBg.values.count
                guard totalCount > 0 else {
                    let hourlyData = HourlyBgPercentages(startDate: hourlyBg.startDate, endDate: hourlyBg.endDate, percentLow: 0, percentHigh: 0)
                    hourlyPercentages.append(hourlyData)
                    continue
                }

                let lowCount = hourlyBg.values.filter { $0 < lowBg }.count
                let highCount = hourlyBg.values.filter { $0 > highBg }.count

                let percentLow = (Double(lowCount) / Double(totalCount)) * 100
                let percentHigh = (Double(highCount) / Double(totalCount)) * 100

                let hourlyData = HourlyBgPercentages(startDate: hourlyBg.startDate, endDate: hourlyBg.endDate, percentLow: percentLow, percentHigh: percentHigh)
                hourlyPercentages.append(hourlyData)
            }

            completion(.success(hourlyPercentages))
            }
        }
    }
}
