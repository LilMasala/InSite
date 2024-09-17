//
//  Sleep_Data.swift
//  InSite
//
//  Created by Anand Parikh on 2/1/24.
//

import Foundation
import HealthKit

struct DailySleepDurations {
    let date: Date
    var awake: TimeInterval = 0
    var asleepCore: TimeInterval = 0
    var asleepDeep: TimeInterval = 0
    var asleepREM: TimeInterval = 0
    var asleepUnspecified: TimeInterval = 0

    mutating func addSleepState(state: HKCategoryValueSleepAnalysis, duration: TimeInterval) {
        switch state {
        case .awake:
            awake += duration
        case .asleepCore:
            asleepCore += duration
        case .asleepDeep:
            asleepDeep += duration
        case .asleepREM:
            asleepREM += duration
        case .asleepUnspecified:
            asleepUnspecified += duration
        default:
            break
        }
    }
}
extension HealthStore {
    func fetchSleepDurations(startDate: Date, endDate: Date, completion: @escaping ([Date: DailySleepDurations]) -> Void) {
        guard let healthStore = self.healthStore else { return completion([:]) }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKCategorySample], error == nil else {
                completion([:])
                return
            }

            var sleepDurations = [Date: DailySleepDurations]()
            let calendar = Calendar.current

            for sample in samples {
                let stateValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)!
                let startOfDay = calendar.startOfDay(for: sample.startDate)
                let endOfDay = calendar.startOfDay(for: sample.endDate)

                var day = startOfDay
                while day <= endOfDay, day <= endDate {
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
                    let overlapStart = max(sample.startDate, day)
                    let overlapEnd = min(sample.endDate, dayEnd)
                    let duration = overlapEnd.timeIntervalSince(overlapStart) / 60.0 // Duration in minutes

                    if duration > 0 {
                        sleepDurations[day, default: DailySleepDurations(date: day)].addSleepState(state: stateValue, duration: duration)
                    }

                    day = dayEnd
                }
            }

            // Ensure every day in the range has an entry
            var day = startDate
            while day <= endDate {
                sleepDurations[day, default: DailySleepDurations(date: day)]
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }

            completion(sleepDurations)
        }

        healthStore.execute(query)
    }
}
