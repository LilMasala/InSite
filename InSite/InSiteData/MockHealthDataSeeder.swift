#if DEBUG
import Foundation

struct MockHealthDataSeeder {
    static func seed() {
        print("Seeding mock HealthKit data (debug mode)")

        let uploader = HealthDataUploader()
        uploader.skipWrites = true

        let calendar = Calendar.current
        let now = Date()
        guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return }

        var hourlyBgData: [HourlyBgData] = []
        var avgBgData: [HourlyAvgBgData] = []
        var bgPercentages: [HourlyBgPercentages] = []

        var hourlyHeartRates: [Date: HourlyHeartRateData] = [:]
        var dailyAvgHeartRates: [DailyAverageHeartRateData] = []

        var hourlyExercise: [Date: HourlyExerciseData] = [:]
        var dailyAvgExercise: [Date: DailyAverageExerciseData] = [:]

        var menstrualData: [Date: DailyMenstrualData] = [:]

        var bodyMassData: [HourlyBodyMassData] = []

        var restingHeartRates: [DailyRestingHeartRateData] = []

        var sleepDurations: [Date: DailySleepDurations] = [:]

        var hourlyEnergy: [Date: HourlyEnergyData] = [:]
        var dailyAvgEnergy: [DailyAverageEnergyData] = []

        for dayOffset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            // Hourly data for each day
            for hour in 0..<24 {
                guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                      let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { continue }

                // Blood Glucose
                let startBg = Double.random(in: 80...120)
                let endBg = Double.random(in: 80...120)
                hourlyBgData.append(HourlyBgData(startDate: hourStart, endDate: hourEnd, startBg: startBg, endBg: endBg))
                let avgBg = (startBg + endBg) / 2
                avgBgData.append(HourlyAvgBgData(startDate: hourStart, endDate: hourEnd, averageBg: avgBg))
                let percentLow = Double.random(in: 0...10)
                let percentHigh = Double.random(in: 0...10)
                bgPercentages.append(HourlyBgPercentages(startDate: hourStart, endDate: hourEnd, percentLow: percentLow, percentHigh: percentHigh))

                // Heart Rate
                let hr = Double.random(in: 60...100)
                hourlyHeartRates[hourStart] = HourlyHeartRateData(hour: hourStart, heartRate: hr)

                // Exercise
                let move = Double.random(in: 0...30)
                let exercise = Double.random(in: 0...30)
                hourlyExercise[hourStart] = HourlyExerciseData(hour: hourStart, moveMinutes: move, exerciseMinutes: exercise)

                // Body Mass
                let weight = Double.random(in: 60...100)
                bodyMassData.append(HourlyBodyMassData(hour: hourStart, weight: weight))

                // Energy
                let basal = Double.random(in: 40...80)
                let active = Double.random(in: 0...100)
                hourlyEnergy[hourStart] = HourlyEnergyData(hour: hourStart, basalEnergy: basal, activeEnergy: active)
            }

            // Daily averages
            let avgHeartRate = Double.random(in: 60...80)
            dailyAvgHeartRates.append(DailyAverageHeartRateData(date: dayStart, averageHeartRate: avgHeartRate))

            let avgMove = Double.random(in: 20...60)
            let avgExercise = Double.random(in: 10...40)
            dailyAvgExercise[dayStart] = DailyAverageExerciseData(date: dayStart, averageMoveMinutes: avgMove, averageExerciseMinutes: avgExercise)

            let daysSince = calendar.dateComponents([.day], from: start, to: dayStart).day! % 28
            menstrualData[dayStart] = DailyMenstrualData(date: dayStart, daysSincePeriodStart: daysSince)

            let restingHR = Double.random(in: 55...75)
            restingHeartRates.append(DailyRestingHeartRateData(date: dayStart, restingHeartRate: restingHR))

            var sleepEntry = DailySleepDurations(date: dayStart)
            sleepEntry.awake = Double.random(in: 20...60)
            sleepEntry.asleepCore = Double.random(in: 180...300)
            sleepEntry.asleepDeep = Double.random(in: 60...120)
            sleepEntry.asleepREM = Double.random(in: 60...120)
            sleepEntry.asleepUnspecified = Double.random(in: 0...30)
            sleepDurations[dayStart] = sleepEntry

            let avgActiveEnergy = Double.random(in: 200...800)
            dailyAvgEnergy.append(DailyAverageEnergyData(date: dayStart, averageActiveEnergy: avgActiveEnergy))
        }

        uploader.uploadHourlyBgData(hourlyBgData)
        uploader.uploadAverageBgData(avgBgData)
        uploader.uploadHourlyBgPercentages(bgPercentages)
        uploader.uploadHourlyHeartRateData(hourlyHeartRates)
        uploader.uploadDailyAverageHeartRateData(dailyAvgHeartRates)
        uploader.uploadHourlyExerciseData(hourlyExercise)
        uploader.uploadDailyAverageExerciseData(dailyAvgExercise)
        uploader.uploadMenstrualData(menstrualData)
        uploader.uploadBodyMassData(bodyMassData)
        uploader.uploadRestingHeartRateData(restingHeartRates)
        uploader.uploadSleepDurations(sleepDurations)
        uploader.uploadHourlyEnergyData(hourlyEnergy)
        uploader.uploadDailyAverageEnergyData(dailyAvgEnergy)
    }
}
#endif
