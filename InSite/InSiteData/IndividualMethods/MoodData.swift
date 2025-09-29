//
//  MoodData.swift
//  InSite
//
//  Created by Anand Parikh on 10/8/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Mood event (what the UI saves)
struct MoodEventRecord: StreamRecord {
    static let kind: DataKind = .mood
    static let cadence: Cadence = .event

    let id: String              // UUID
    let timestamp: Date         // client timestamp
    let valence: Double         // [-1, 1]
    let arousal: Double         // [-1, 1]

    var documentId: String { id }
    var payload: [String: Any] {
        [
            "clientTs": Timestamp(date: timestamp),
            "serverTs": FieldValue.serverTimestamp(),
            "valence": valence,
            "arousal": arousal
        ]
    }
}

// OPTIONAL: if you want to persist hourly mood ctx to Firestore too
struct MoodHourlyCtxRecord: StreamRecord {
    static let kind: DataKind = .mood
    static let cadence: Cadence = .hourly

    let hour: Date
    let valence: Double?
    let arousal: Double?
    let quad_posPos: Int?
    let quad_posNeg: Int?
    let quad_negPos: Int?
    let quad_negNeg: Int?
    let hoursSinceMood: Double?

    var documentId: String { isoHourId(hour) }
    var payload: [String: Any] {
        var d: [String: Any] = ["hourUtc": isoHourId(hour)]
        func put(_ k: String, _ v: Any?) { if let v = v { d[k] = v } }
        put("valence", valence); put("arousal", arousal)
        put("quad_posPos", quad_posPos); put("quad_posNeg", quad_posNeg)
        put("quad_negPos", quad_negPos); put("quad_negNeg", quad_negNeg)
        put("hoursSinceMood", hoursSinceMood)
        return d
    }
}


final class MoodCache {
    static let shared = MoodCache()
    private let key = "mood_points_v1"
    private init() {}

    func add(_ m: MoodPoint) {
        var all = load()
        all.append(m)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> [MoodPoint] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([MoodPoint].self, from: data) else { return [] }
        return arr
    }
}
