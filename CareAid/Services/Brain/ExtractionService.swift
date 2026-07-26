import Foundation

/// Handles communication with the extraction Edge Function.
/// AI processing and database writes happen on the backend; this service manages request and response.
final class ExtractionService {

    private let baseURL: URL
    private let session: URLSession

    /// Defaults to the configured project's Edge Function root, so callers
    /// don't each have to rebuild it.
    init(baseURL: URL? = nil, session: URLSession = .shared) throws {
        guard
            let root = baseURL ?? Config.supabaseURL?.appendingPathComponent("functions/v1"),
            Config.isSupabaseConfigured
        else {
            throw BackendError.notConfigured
        }
        self.baseURL = root
        self.session = session
    }

    /// - Parameter correcting: set when this capture is her re-recording
    ///   because a card was wrong. The function reads the earlier capture and
    ///   its proposals itself — we only name them.
    func extract(
        captureID: UUID,
        correcting: Correction? = nil
    ) async throws -> ExtractionResponse {
        let url = baseURL.appendingPathComponent("extract")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        // Supabase's gateway rejects an unauthenticated call before the
        // function ever runs, so both of these are required.
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue(
            "Bearer \(Config.supabaseAnonKey)",
            forHTTPHeaderField: "Authorization"
        )
        // One LLM call plus the database writes; the default 60s is not enough.
        request.timeoutInterval = 90

        request.httpBody = try JSONEncoder().encode(
            ExtractRequest(
                captureID: captureID,
                correctsCaptureID: correcting?.captureID,
                rejectedArtifactIDs: correcting?.rejectedArtifactIDs
            )
        )

        // Safe to send twice: the function keys its writes on `capture_id` and
        // replaces that capture's rows, so a retry cannot double-write. Worth
        // it — this call follows a long pause, which is exactly when a pooled
        // connection turns out to be dead.
        let (data, response) = try await Backend.retryingTransient {
            try await session.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExtractionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // The function explains itself in the body. Surfacing that instead
            // of a bare status code is the difference between "Extraction
            // failed with status code 500" and "OPENAI_API_KEY is not set".
            let reason = try? JSONDecoder().decode(ServerError.self, from: data)
            throw ExtractionError.requestFailed(
                statusCode: httpResponse.statusCode,
                reason: reason?.error
            )
        }

        // Our decoder, not a plain one: the response carries Postgres
        // timestamps, which JSONDecoder's default strategy cannot read.
        return try JSONCoding.decoder.decode(
            ExtractionResponse.self,
            from: data
        )
    }
}

// MARK: - Request

/// The earlier capture this one is putting right, and which of its proposals
/// she said were wrong.
nonisolated struct Correction: Sendable {
    let captureID: UUID
    let rejectedArtifactIDs: [UUID]
}

private struct ExtractRequest: Codable {
    let captureID: UUID
    let correctsCaptureID: UUID?
    let rejectedArtifactIDs: [UUID]?

    enum CodingKeys: String, CodingKey {
        case captureID = "capture_id"
        case correctsCaptureID = "corrects_capture_id"
        case rejectedArtifactIDs = "rejected_artifact_ids"
    }
}

private struct ServerError: Decodable {
    let error: String
}

// MARK: - Errors

enum ExtractionError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, reason: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."

        case .requestFailed(let statusCode, let reason):
            return reason ?? "Extraction failed with status code \(statusCode)."
        }
    }
}
