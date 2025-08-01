import Foundation
import FirebaseFirestore
import FirebaseAuth

class HealthDataUploader {
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    #if DEBUG
    var skipWrites: Bool = true
    #else
    var skipWrites: Bool = false
    #endif

    private func isoString(from date: Date) -> String { isoFormatter.string(from: date) }

    private func userCollection(_ name: String) -> CollectionReference? {
        guard !skipWrites, let uid = Auth.auth().currentUser?.uid else { return nil }
        return Firestore.firestore().collection("users").document(uid).collection(name)
    }

    private func commit(_ batch: WriteBatch, label: String) {
        batch.commit { error in
            if let error = error { print("\(label) upload error: \(error)") }
        }
    }

    func uploadHourlyBgData(_ data: [HourlyBgData]) {
        guard let collection = userCollection("blood_glucose") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            var dict: [String: Any] = [
                "startDate": isoString(from: entry.startDate),
                "endDate": isoString(from: entry.endDate),
                "type": "hourly"
            ]
            if let start = entry.startBg { dict["startBg"] = start }
            if let end = entry.endBg { dict["endBg"] = end }
            batch.setData(dict, forDocument: collection.document("hourly-\(isoString(from: entry.startDate))"))
        }
        commit(batch, label: "hourly BG")
    }

    func uploadAverageBgData(_ data: [HourlyAvgBgData]) {
        guard let collection = userCollection("blood_glucose") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            var dict: [String: Any] = [
                "startDate": isoString(from: entry.startDate),
                "endDate": isoString(from: entry.endDate),
                "type": "average"
            ]
            if let avg = entry.averageBg { dict["averageBg"] = avg }
            batch.setData(dict, forDocument: collection.document("average-\(isoString(from: entry.startDate))"))
        }
        commit(batch, label: "avg BG")
    }

    func uploadHourlyBgPercentages(_ data: [HourlyBgPercentages]) {
        guard let collection = userCollection("blood_glucose") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            let dict: [String: Any] = [
                "startDate": isoString(from: entry.startDate),
                "endDate": isoString(from: entry.endDate),
                "percentLow": entry.percentLow,
                "percentHigh": entry.percentHigh,
                "type": "percent"
            ]
            batch.setData(dict, forDocument: collection.document("percent-\(isoString(from: entry.startDate))"))
        }
        commit(batch, label: "bg percent")
    }

    func uploadHourlyHeartRateData(_ data: [Date: HourlyHeartRateData]) {
        guard let collection = userCollection("heart_rate") else { return }
        let batch = Firestore.firestore().batch()
        for (date, entry) in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "heartRate": entry.heartRate,
                "type": "hourly"
            ]
            batch.setData(dict, forDocument: collection.document("hourly-\(isoString(from: date))"))
        }
        commit(batch, label: "hourly HR")
    }

    func uploadDailyAverageHeartRateData(_ data: [DailyAverageHeartRateData]) {
        guard let collection = userCollection("heart_rate") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "averageHeartRate": entry.averageHeartRate,
                "type": "daily_average"
            ]
            batch.setData(dict, forDocument: collection.document("average-\(isoString(from: entry.date))"))
        }
        commit(batch, label: "avg HR")
    }

    func uploadHourlyExerciseData(_ data: [Date: HourlyExerciseData]) {
        guard let collection = userCollection("exercise") else { return }
        let batch = Firestore.firestore().batch()
        for (date, entry) in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "moveMinutes": entry.moveMinutes,
                "exerciseMinutes": entry.exerciseMinutes,
                "totalMinutes": entry.totalMinutes,
                "type": "hourly"
            ]
            batch.setData(dict, forDocument: collection.document("hourly-\(isoString(from: date))"))
        }
        commit(batch, label: "hourly exercise")
    }

    func uploadDailyAverageExerciseData(_ data: [Date: DailyAverageExerciseData]) {
        guard let collection = userCollection("exercise") else { return }
        let batch = Firestore.firestore().batch()
        for (date, entry) in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "averageMoveMinutes": entry.averageMoveMinutes,
                "averageExerciseMinutes": entry.averageExerciseMinutes,
                "averageTotalMinutes": entry.averageTotalMinutes,
                "type": "daily_average"
            ]
            batch.setData(dict, forDocument: collection.document("average-\(isoString(from: date))"))
        }
        commit(batch, label: "avg exercise")
    }

    func uploadMenstrualData(_ data: [Date: DailyMenstrualData]) {
        guard let collection = userCollection("menstrual") else { return }
        let batch = Firestore.firestore().batch()
        for (date, entry) in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "daysSincePeriodStart": entry.daysSincePeriodStart
            ]
            batch.setData(dict, forDocument: collection.document(isoString(from: date)))
        }
        commit(batch, label: "menstrual")
    }

    func uploadBodyMassData(_ data: [HourlyBodyMassData]) {
        guard let collection = userCollection("body_mass") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "weight": entry.weight
            ]
            batch.setData(dict, forDocument: collection.document(isoString(from: entry.hour)))
        }
        commit(batch, label: "body mass")
    }

    func uploadRestingHeartRateData(_ data: [DailyRestingHeartRateData]) {
        guard let collection = userCollection("resting_heart_rate") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "restingHeartRate": entry.restingHeartRate
            ]
            batch.setData(dict, forDocument: collection.document(isoString(from: entry.date)))
        }
        commit(batch, label: "resting HR")
    }

    func uploadSleepDurations(_ data: [Date: DailySleepDurations]) {
        guard let collection = userCollection("sleep") else { return }
        let batch = Firestore.firestore().batch()
        for (date, entry) in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "awake": entry.awake,
                "asleepCore": entry.asleepCore,
                "asleepDeep": entry.asleepDeep,
                "asleepREM": entry.asleepREM,
                "asleepUnspecified": entry.asleepUnspecified
            ]
            batch.setData(dict, forDocument: collection.document(isoString(from: date)))
        }
        commit(batch, label: "sleep")
    }

    func uploadHourlyEnergyData(_ data: [Date: HourlyEnergyData]) {
        guard let collection = userCollection("energy") else { return }
        let batch = Firestore.firestore().batch()
        for (date, entry) in data {
            let dict: [String: Any] = [
                "hour": isoString(from: entry.hour),
                "basalEnergy": entry.basalEnergy,
                "activeEnergy": entry.activeEnergy,
                "totalEnergy": entry.totalEnergy,
                "type": "hourly"
            ]
            batch.setData(dict, forDocument: collection.document("hourly-\(isoString(from: date))"))
        }
        commit(batch, label: "energy")
    }

    func uploadDailyAverageEnergyData(_ data: [DailyAverageEnergyData]) {
        guard let collection = userCollection("energy") else { return }
        let batch = Firestore.firestore().batch()
        for entry in data {
            let dict: [String: Any] = [
                "date": isoString(from: entry.date),
                "averageActiveEnergy": entry.averageActiveEnergy,
                "type": "daily_average"
            ]
            batch.setData(dict, forDocument: collection.document("average-\(isoString(from: entry.date))"))
        }
        commit(batch, label: "avg energy")
    }
}
