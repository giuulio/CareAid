import Observation
import SwiftUI

/// Where the app can navigate to from Home.
///
/// CLAUDE.md §8 caps navigation at two levels, so this is a flat list of
/// destinations pushed onto a single stack — no nesting, no modals.
enum Route: Hashable {
    case voiceCapture
    case textCapture
    case timeline
    case schedule
    case appointmentPack
    #if DEBUG
    case themeGallery
    #endif
}

/// App-wide state. Deliberately thin for now — real data arrives with the
/// repositories in C4.
@Observable
final class AppState {
    /// Navigation stack behind Home.
    var path: [Route] = []

    /// What the caregiver calls the person they look after.
    let recipientDisplayName = "Mum"
}
