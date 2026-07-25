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
    nonisolated func decoded<T: Decodable>(_ type: T.Type = T.self) async throws -> T {
        let data = try await execute().data
        return try JSONCoding.decoder.decode(T.self, from: data)
    }
}
