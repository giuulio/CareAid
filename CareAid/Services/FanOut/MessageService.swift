import Foundation
import UIKit

/// Opens WhatsApp (or Messages) with the draft already written.
///
/// Deliberately stops at "composed and waiting to send" — CareAid never sends
/// anything itself (CLAUDE.md §2, rule 3). The last tap is always hers, and it
/// means she can edit the wording first, which matters because §10 rules out
/// editing cards in the app.
@MainActor
struct MessageService {

    enum MessageError: LocalizedError {
        case noHandle
        case cannotOpen

        var errorDescription: String? {
            switch self {
            case .noHandle: "There's no phone number saved for them."
            case .cannotOpen: "Couldn't open WhatsApp or Messages on this phone."
            }
        }
    }

    func compose(_ payload: FamilyUpdatePayload, handle: String?) async throws {
        guard let handle, !handle.isEmpty else { throw MessageError.noHandle }

        // WhatsApp first, Messages if it isn't installed. Either way she lands
        // on a composed message she still has to send.
        //
        // The install check has to go through the `whatsapp://` scheme, not the
        // wa.me link — canOpenURL says yes to any https URL, so testing the
        // link would always claim WhatsApp is present and the fallback below
        // would be dead code. This needs LSApplicationQueriesSchemes.
        if payload.channel == .whatsapp,
           isWhatsAppInstalled,
           let url = whatsAppURL(handle, payload.draftText) {
            await UIApplication.shared.open(url)
            return
        }

        if let url = smsURL(handle, payload.draftText), UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
            return
        }

        throw MessageError.cannotOpen
    }

    private var isWhatsAppInstalled: Bool {
        guard let probe = URL(string: "whatsapp://app") else { return false }
        return UIApplication.shared.canOpenURL(probe)
    }

    private func whatsAppURL(_ handle: String, _ text: String) -> URL? {
        let digits = handle.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        var components = URLComponents(string: "https://wa.me/\(digits)")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        return components?.url
    }

    private func smsURL(_ handle: String, _ text: String) -> URL? {
        // `sms:` takes the body as a query, and the number must keep its `+`.
        let number = handle.filter { $0.isNumber || $0 == "+" }
        guard !number.isEmpty else { return nil }
        var components = URLComponents(string: "sms:\(number)")
        components?.queryItems = [URLQueryItem(name: "body", value: text)]
        return components?.url
    }
}
