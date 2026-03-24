import Foundation

enum ChameliaError: Error {
    case networkError(Error)
    case serverError(Int, String)
    case notFound
    case decodingError(Error)
}

struct GraduationStatus: Codable, Equatable {
    let graduated: Bool
    let nDays: Int
    let winRate: Double
    let safetyViolations: Int
    let consecutiveDays: Int

    enum CodingKeys: String, CodingKey {
        case graduated
        case nDays = "n_days"
        case winRate = "win_rate"
        case safetyViolations = "safety_violations"
        case consecutiveDays = "consecutive_days"
    }
}

struct TherapyAction: Codable, Equatable {
    let kind: String
    let deltas: [String: Double]
}

struct BurnoutAttribution: Codable, Equatable {
    let deltaHat: Double
    let pTreated: Double
    let pBaseline: Double
    let upperCI: Double
    let horizon: Int

    enum CodingKeys: String, CodingKey {
        case deltaHat = "delta_hat"
        case pTreated = "p_treated"
        case pBaseline = "p_baseline"
        case upperCI = "upper_ci"
        case horizon
    }
}

struct RecommendationPackage: Codable, Equatable {
    let action: TherapyAction
    let predictedImprovement: Double
    let confidence: Double
    let effectSize: Double
    let cvarValue: Double
    let burnoutAttribution: BurnoutAttribution?

    enum CodingKeys: String, CodingKey {
        case action
        case predictedImprovement = "predicted_improvement"
        case confidence
        case effectSize = "effect_size"
        case cvarValue = "cvar_value"
        case burnoutAttribution = "burnout_attribution"
    }
}

struct ChameliaPreferences: Codable, Equatable {
    let aggressiveness: Double
    let hypoglycemiaFear: Double
    let burdenSensitivity: Double
    let persona: String

    enum CodingKeys: String, CodingKey {
        case aggressiveness
        case hypoglycemiaFear = "hypoglycemia_fear"
        case burdenSensitivity = "burden_sensitivity"
        case persona
    }
}

struct ChameliaResponse: Codable, Equatable {
    let ok: Bool
    let patientId: String
    let status: GraduationStatus?
    let recId: Int64?
    let recommendation: RecommendationPackage?

    enum CodingKeys: String, CodingKey {
        case ok
        case patientId = "patient_id"
        case status
        case recId = "rec_id"
        case recommendation
    }
}

actor ChameliaEngine {
    static let shared = ChameliaEngine()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func initialize(patientId: String, preferences: ChameliaPreferences) async throws {
        let request = InitializeRequest(patientId: patientId, preferences: preferences)
        let _: ChameliaResponse = try await post(path: "/chamelia_initialize_patient", body: request)
    }

    func observe(patientId: String, timestamp: Double, signals: [String: Double]) async throws {
        let request = SignalRequest(patientId: patientId, timestamp: timestamp, signals: signals)
        let _: ChameliaResponse = try await post(path: "/chamelia_observe", body: request)
    }

    func step(patientId: String, timestamp: Double, signals: [String: Double]) async throws -> RecommendationPackage? {
        let request = SignalRequest(patientId: patientId, timestamp: timestamp, signals: signals)
        let response: ChameliaResponse = try await post(path: "/chamelia_step", body: request)
        return response.recommendation
    }

    func recordOutcome(patientId: String, recId: Int, response: String, signals: [String: Double], cost: Double) async throws {
        guard ["reject", "partial", "accept"].contains(response) else {
            throw ChameliaError.serverError(0, "Invalid outcome response: \(response)")
        }

        let request = RecordOutcomeRequest(
            patientId: patientId,
            recId: recId,
            response: response,
            signals: signals,
            cost: cost
        )
        let _: ChameliaResponse = try await post(path: "/chamelia_record_outcome", body: request)
    }

    func graduationStatus(patientId: String) async throws -> GraduationStatus {
        let request = PatientRequest(patientId: patientId)
        let response: ChameliaResponse = try await post(path: "/chamelia_graduation_status", body: request)
        guard let status = response.status else {
            throw ChameliaError.serverError(200, "Missing graduation status in response")
        }
        return status
    }

    func save(patientId: String) async throws {
        let request = PatientRequest(patientId: patientId)
        let _: ChameliaResponse = try await post(path: "/chamelia_save_patient", body: request)
    }

    func load(patientId: String) async throws {
        let request = PatientRequest(patientId: patientId)
        let _: ChameliaResponse = try await post(path: "/chamelia_load_patient", body: request)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: ChameliaConfig.baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = ChameliaConfig.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw ChameliaError.networkError(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ChameliaError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChameliaError.serverError(-1, "Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            if httpResponse.statusCode == 404 {
                throw ChameliaError.notFound
            }
            throw ChameliaError.serverError(httpResponse.statusCode, message)
        }

        do {
            return try decoder.decode(ResponseBody.self, from: data)
        } catch {
            throw ChameliaError.decodingError(error)
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let payload = try? decoder.decode(ErrorResponse.self, from: data) {
            return payload.error
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct PatientRequest: Encodable {
    let patientId: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
    }
}

private struct InitializeRequest: Encodable {
    let patientId: String
    let preferences: ChameliaPreferences

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case preferences
    }
}

private struct SignalRequest: Encodable {
    let patientId: String
    let timestamp: Double
    let signals: [String: Double]

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case timestamp
        case signals
    }
}

private struct RecordOutcomeRequest: Encodable {
    let patientId: String
    let recId: Int
    let response: String
    let signals: [String: Double]
    let cost: Double

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case recId = "rec_id"
        case response
        case signals
        case cost
    }
}

private struct ErrorResponse: Decodable {
    let ok: Bool?
    let error: String
}
