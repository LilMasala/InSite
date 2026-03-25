import Foundation

enum ChameliaError: Error, LocalizedError {
    case networkError(Error)
    case serverError(Int, String)
    case notFound
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case let .networkError(error as URLError):
            switch error.code {
            case .timedOut:
                return "Chamelia took too long to respond. Try again in a moment."
            case .notConnectedToInternet:
                return "You're offline. Reconnect to the internet and try again."
            default:
                return "Chamelia couldn't be reached right now."
            }
        case let .networkError(error):
            return "Chamelia couldn't be reached right now. \(error.localizedDescription)"
        case let .serverError(status, message):
            if message.isEmpty {
                return "Chamelia returned a server error (\(status))."
            }
            return "Chamelia server error (\(status)): \(message)"
        case .notFound:
            return "No Chamelia state exists yet for this account."
        case let .decodingError(error):
            return "Chamelia returned data in an unexpected format. \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Try syncing again after your connection stabilizes."
        case .serverError:
            return "If this keeps happening, wait a minute and try again."
        case .notFound:
            return "This is normal for a first-time account."
        case .decodingError:
            return "Try again after the next app sync."
        }
    }
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
    let physicalPriors: [String: [Double]]

    enum CodingKeys: String, CodingKey {
        case aggressiveness
        case hypoglycemiaFear = "hypoglycemia_fear"
        case burdenSensitivity = "burden_sensitivity"
        case persona
        case physicalPriors = "physical_priors"
    }

    init(
        aggressiveness: Double,
        hypoglycemiaFear: Double,
        burdenSensitivity: Double,
        persona: String,
        physicalPriors: [String: [Double]] = [:]
    ) {
        self.aggressiveness = aggressiveness
        self.hypoglycemiaFear = hypoglycemiaFear
        self.burdenSensitivity = burdenSensitivity
        self.persona = persona
        self.physicalPriors = physicalPriors
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
    private let loggingEnabled = true

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func initialize(patientId: String, preferences: ChameliaPreferences) async throws {
        let request = InitializeRequest(patientId: patientId, preferences: preferences)
        log("initialize start patient=\(patientId)")
        let _: ChameliaResponse = try await post(path: "/chamelia_initialize_patient", body: request)
        log("initialize success patient=\(patientId)")
    }

    func observe(patientId: String, timestamp: Double, signals: [String: Double]) async throws {
        let request = SignalRequest(patientId: patientId, timestamp: timestamp, signals: signals)
        log("observe start patient=\(patientId) timestamp=\(timestamp) signals=\(signals.count)")
        let _: ChameliaResponse = try await post(path: "/chamelia_observe", body: request)
        log("observe success patient=\(patientId)")
    }

    func step(patientId: String, timestamp: Double, signals: [String: Double]) async throws -> RecommendationPackage? {
        let response = try await stepResult(patientId: patientId, timestamp: timestamp, signals: signals)
        return response.recommendation
    }

    func stepResult(patientId: String, timestamp: Double, signals: [String: Double]) async throws -> ChameliaResponse {
        let request = SignalRequest(patientId: patientId, timestamp: timestamp, signals: signals)
        log("step start patient=\(patientId) timestamp=\(timestamp) signals=\(signals.count)")
        let response: ChameliaResponse = try await post(path: "/chamelia_step", body: request)
        log("step success patient=\(patientId) recommendation=\(response.recommendation != nil)")
        return response
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
        log("recordOutcome start patient=\(patientId) recId=\(recId) response=\(response) signals=\(signals.count) cost=\(cost)")
        let _: ChameliaResponse = try await post(path: "/chamelia_record_outcome", body: request)
        log("recordOutcome success patient=\(patientId) recId=\(recId)")
    }

    func graduationStatus(patientId: String) async throws -> GraduationStatus {
        let request = PatientRequest(patientId: patientId)
        log("graduationStatus start patient=\(patientId)")
        let response: ChameliaResponse = try await post(path: "/chamelia_graduation_status", body: request)
        guard let status = response.status else {
            throw ChameliaError.serverError(200, "Missing graduation status in response")
        }
        log("graduationStatus success patient=\(patientId) nDays=\(status.nDays) graduated=\(status.graduated)")
        return status
    }

    func save(patientId: String) async throws {
        let request = PatientRequest(patientId: patientId)
        log("save start patient=\(patientId)")
        let _: ChameliaResponse = try await post(path: "/chamelia_save_patient", body: request)
        log("save success patient=\(patientId)")
    }

    func load(patientId: String) async throws {
        let request = PatientRequest(patientId: patientId)
        log("load start patient=\(patientId)")
        let _: ChameliaResponse = try await post(path: "/chamelia_load_patient", body: request)
        log("load success patient=\(patientId)")
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
            log("encode failure path=\(path) error=\(error)")
            throw ChameliaError.networkError(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log("network failure path=\(path) error=\(error)")
            throw ChameliaError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            log("invalid response path=\(path)")
            throw ChameliaError.serverError(-1, "Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            log("server error path=\(path) status=\(httpResponse.statusCode) message=\(message)")
            if httpResponse.statusCode == 404 {
                throw ChameliaError.notFound
            }
            throw ChameliaError.serverError(httpResponse.statusCode, message)
        }

        do {
            return try decoder.decode(ResponseBody.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            log("decode failure path=\(path) error=\(error) body=\(rawBody)")
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

    private func log(_ message: String) {
        guard loggingEnabled else { return }
        print("[ChameliaEngine] \(message)")
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
