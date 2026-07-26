import Foundation
import Supabase

/// The one Supabase client, and the errors talking to it can raise.
///
/// Optional on purpose: `Supabase.plist` is gitignored, so a fresh clone has no
/// credentials and the app still has to launch (CLAUDE.md §8 — the demo device
/// is never left staring at a crash).
nonisolated enum Backend {
    static let client: SupabaseClient? = makeClient()

    /// Throws rather than returning nil, so callers surface a real message.
    static func requireClient() throws -> SupabaseClient {
        guard let client else { throw BackendError.notConfigured }
        return client
    }

    private static func makeClient() -> SupabaseClient? {
        guard Config.isSupabaseConfigured, let url = Config.supabaseURL else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
    }
}

nonisolated enum BackendError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "No Supabase credentials. Copy Supabase.example.plist to Supabase.plist and fill it in."
        }
    }
}

extension PostgrestBuilder {
    /// Runs the query and decodes it with *our* decoder rather than the SDK's.
    ///
    /// Ours understands Postgres timestamps in both the fractional and plain
    /// forms, and leaves key names alone because every model spells its
    /// `CodingKeys` out explicitly.
    ///
    /// - Parameter retryOnDrop: whether it is safe to send this request twice.
    ///   **Inserts must pass `false`.** See `Backend.retryingTransient`.
    nonisolated func decoded<T: Decodable>(
        _ type: T.Type = T.self,
        retryOnDrop: Bool = true
    ) async throws -> T {
        let data = try await Backend.retryingTransient(enabled: retryOnDrop) {
            try await execute().data
        }
        return try JSONCoding.decoder.decode(T.self, from: data)
    }

    /// For requests whose response we don't read. Same retry rule.
    nonisolated func executed(retryOnDrop: Bool = true) async throws {
        _ = try await Backend.retryingTransient(enabled: retryOnDrop) {
            try await execute()
        }
    }
}

extension Backend {
    /// Runs a request, retrying once on the transient failures a pooled
    /// connection produces after an idle spell.
    ///
    /// `URLError.networkConnectionLost` (-1005) is the usual one: URLSession
    /// hands out a keep-alive socket the server has already closed, and the
    /// first request after a quiet couple of minutes dies on it. Observed on
    /// exactly the wrong request — approving the medication card, after the
    /// long pause while extraction ran — where it reads as a card that doesn't
    /// work. A second attempt succeeds immediately.
    ///
    /// Only for requests that are safe to send twice: every read, and the
    /// idempotent PATCHes (`artifact.status`, a `medication` field). Never for
    /// an insert — a dropped connection gives no answer either way, and two
    /// captures or two questions is worse than one visible failure.
    nonisolated static func retryingTransient<T>(
        enabled: Bool = true,
        _ operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch let error as URLError where enabled && Self.isTransient(error) {
            #if DEBUG
            print("[CareAid] \(error.code) talking to Supabase — retrying once.")
            #endif
            return try await operation()
        }
    }

    private nonisolated static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .networkConnectionLost, .timedOut, .cannotConnectToHost, .dnsLookupFailed:
            true
        default:
            false
        }
    }
}
