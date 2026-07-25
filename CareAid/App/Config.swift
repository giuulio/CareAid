import Foundation

/// Static app configuration.
///
/// Supabase credentials are read from `Supabase.plist` in the app bundle so they
/// stay out of source. Third-party AI keys are never here — those live as
/// Supabase secrets and are only ever used inside Edge Functions.
enum Config {

    // MARK: - Supabase

    /// Project URL, e.g. `https://abcdefgh.supabase.co`. Empty until the plist is filled in.
    static let supabaseURL: URL? = plist["SUPABASE_URL"].flatMap(URL.init(string:))

    /// Anon/publishable key. Safe to ship; the service-role key is not.
    static let supabaseAnonKey: String = plist["SUPABASE_ANON_KEY"] ?? ""

    /// False until someone fills in `Supabase.plist`. Callers should degrade
    /// gracefully rather than crash — the app must always launch.
    static var isSupabaseConfigured: Bool {
        supabaseURL != nil && !supabaseAnonKey.isEmpty
    }

    // MARK: - Demo identities

    // No auth in V0. These UUIDs are hardcoded here and must match `002_seed.sql`.

    /// Margaret Ellis, 78 — the care recipient.
    static let recipientID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

    /// Sarah, 52 — her daughter, and the person holding the phone.
    static let caregiverID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

    // MARK: - Time

    /// Everything is stored UTC and shown in London.
    static let displayTimeZone = TimeZone(identifier: "Europe/London") ?? .gmt

    // MARK: - Plist loading

    private static let plist: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = raw as? [String: String]
        else {
            assertionFailure("Supabase.plist missing or malformed — check it is in the app bundle.")
            return [:]
        }
        return dict.compactMapValues { $0.isEmpty ? nil : $0 }
    }()
}
