import Foundation

/// Handles communication with the extraction Edge Function.
/// AI processing and database writes happen on the backend; this service manages request and response.
final class ExtractionService {

    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
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

        request.httpBody = try JSONEncoder().encode(
            ExtractRequest(captureID: captureID)
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExtractionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ExtractionError.requestFailed(
                statusCode: httpResponse.statusCode
            )
        }

        return try JSONDecoder().decode(
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

// MARK: - Errors

enum ExtractionError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."

        case .requestFailed(let statusCode):
            return "Extraction failed with status code \(statusCode)."
        }
    }
}
