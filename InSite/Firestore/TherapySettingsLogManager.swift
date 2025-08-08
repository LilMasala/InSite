import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct TherapySnapshot: Codable, Identifiable {
    @DocumentID var id: String?
    var timestamp: Date
    var profileId: String
    var profileName: String
    var hourRanges: [HourRange]
}

final class TherapySettingsLogManager {
    static let shared = TherapySettingsLogManager()
    private init() {}

    private func logCollection(for uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("therapy_settings_log")
    }

    private var cache: [TherapySnapshot] = []

    func logTherapySettingsChange(profile: DiabeticProfile, timestamp: Date = Date()) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let snapshot = TherapySnapshot(timestamp: timestamp, profileId: profile.id, profileName: profile.name, hourRanges: profile.hourRanges)
        try logCollection(for: uid).addDocument(from: snapshot)
        cache.append(snapshot)
        cache.sort { $0.timestamp < $1.timestamp }
    }

    func getActiveTherapyProfile(at date: Date) async throws -> TherapySnapshot? {
        if let cached = cache.last(where: { $0.timestamp <= date }) {
            return cached
        }
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let query = logCollection(for: uid)
            .order(by: "timestamp", descending: true)
            .whereField("timestamp", isLessThanOrEqualTo: date)
            .limit(to: 1)
        let snapshot = try await query.getDocuments().documents.first
        if let snapshot = snapshot {
            let snap = try snapshot.data(as: TherapySnapshot.self)
            cache.append(snap)
            cache.sort { $0.timestamp < $1.timestamp }
            return snap
        }
        return nil
    }
}
