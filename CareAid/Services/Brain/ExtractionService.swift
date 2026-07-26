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

    func extract(captureID: UUID) async throws -> ExtractionResponse {
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
            ExtractRequest(captureID: captureID)
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

private struct ExtractRequest: Codable {
    let captureID: UUID

    enum CodingKeys: String, CodingKey {
        case captureID = "capture_id"
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
