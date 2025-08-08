//
//  Menstrual_Data.swift
//  InSite
//
//  Created by Anand Parikh on 12/19/23.
//

import Foundation
import HealthKit


struct DailyMenstrualData {
    let date: Date
    let daysSincePeriodStart: Int
}
extension HealthStore {
    func fetchMenstrualData(startDate: Date, endDate: Date, completion: @escaping (Result<[Date: DailyMenstrualData], Error>) -> Void) {
        guard let healthStore = self.healthStore else {
            completion(.failure(HealthStoreError.notAvailable))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: menstrualType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKCategorySample], error == nil else {
                completion(.failure(error ?? HealthStoreError.dataUnavailable("menstrual")))
                return
            }

            var lastPeriodStart: Date? = nil
            var menstrualData = [Date: DailyMenstrualData]()

            let calendar = Calendar.current
            var currentDate = startDate

            // Pre-process the samples into a dictionary keyed by the start date
            let periodStartDates: [Date: Date] = samples.reduce(into: [Date: Date]()) { result, sample in
                let startDay = calendar.startOfDay(for: sample.startDate)
                result[startDay] = sample.startDate
            }

            // Loop through each day in the range and calculate the days since the last period start
            while currentDate <= endDate {
                let dayStart = calendar.startOfDay(for: currentDate)

                // First, check if there's a new period start today
                if let periodStart = periodStartDates[dayStart] {
                    lastPeriodStart = periodStart
                }

                // Now calculate days since period start
                if let lastStart = lastPeriodStart {
                    let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastStart), to: dayStart).day ?? 0
                    menstrualData[dayStart] = DailyMenstrualData(date: dayStart, daysSincePeriodStart: daysSinceStart)
                } else {
                    menstrualData[dayStart] = DailyMenstrualData(date: dayStart, daysSincePeriodStart: -1)  // No period recorded yet
                }

                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }


            completion(.success(menstrualData))
        }

        healthStore.execute(query)
    }
}
