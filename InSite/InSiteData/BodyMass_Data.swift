import Foundation
import HealthKit

struct HourlyBodyMassData {
    let hour: Date
    let weight: Double
}

extension HealthStore {
    
    func fetchHourlyMassData(start: Date, end: Date, dispatchGroup: DispatchGroup, completion: @escaping ([HourlyBodyMassData]) -> Void) {
        guard let healthStore = self.healthStore, let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            dispatchGroup.leave()
            return
        }
        
        var bodyMassData = [HourlyBodyMassData]()
        
        dispatchGroup.enter()
        fetchHourlyMassDataQuery(start: start, end: end, healthStore: healthStore, bodyMassType: bodyMassType) { results in
            for result in results {
                let date = result.startDate
                if let average = result.averageQuantity() {
                    let bodyMassValue = average.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    let dataPoint = HourlyBodyMassData(hour: date, weight: bodyMassValue)
                    bodyMassData.append(dataPoint)
                }
            }
            completion(bodyMassData)
            dispatchGroup.leave()
        }
    }

    
    private func fetchHourlyMassDataQuery(start: Date, end: Date, healthStore: HKHealthStore, bodyMassType: HKQuantityType, completion: @escaping ([HKStatistics]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        var dateComponents = DateComponents()
        dateComponents.hour = 1
        
        let query = HKStatisticsCollectionQuery(quantityType: bodyMassType, quantitySamplePredicate: predicate, options: [.discreteAverage], anchorDate: start, intervalComponents: dateComponents)
        
        query.initialResultsHandler = { query, results, error in
            guard let statsCollection = results else {
                print("Failed to fetch body mass data: \(error?.localizedDescription ?? "unknown error")")
                completion([])
                return
            }
            var statistics = [HKStatistics]()
            statsCollection.enumerateStatistics(from: start, to: end) { statistic, stop in
                statistics.append(statistic)
            }
            completion(statistics)
        }
        
        healthStore.execute(query)
    }
}
