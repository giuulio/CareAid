import Observation
import SwiftUI

/// Where the app can navigate to from Home.
///
/// CLAUDE.md §8 caps navigation at two levels, so this is a flat list of
/// destinations pushed onto a single stack — no nesting, no modals.
enum Route: Hashable {
    case voiceCapture
    case textCapture
    /// What happened, what's coming and when her tablets are due — one screen.
    /// Timeline, Schedule and Appointments were three answers to "what about
    /// this day?", so they are one destination now.
    case calendar
    case medications
    #if DEBUG
    /// The Review sheet, filled from `DemoData`. Rehearsal and screenshots
    /// without spending forty seconds and an LLM call each time.
    case demoReview
    #endif

    #if DEBUG
    /// The name used by `-openScreen`, below.
    init?(argumentName: String) {
        switch argumentName {
        case "voice": self = .voiceCapture
        case "text": self = .textCapture
        case "calendar": self = .calendar
        case "meds": self = .medications
        case "review": self = .demoReview
        default: return nil
        }
    }
    #endif
}

/// App-wide state.
@Observable
final class AppState {
    /// Navigation stack behind Home.
    var path: [Route] = []

    /// What the caregiver calls the person they look after.
    let recipientDisplayName = "Mum"

    init() {
        #if DEBUG
        // `simctl launch booted com.giulio.CareAid -openScreen schedule` opens
        // straight onto a screen. There is no way to tap the simulator from a
        // script, so without this every check of a screen behind Home needs a
        // human with a mouse — which is how a crash on the voice path survives
        // to the morning of the demo.
        if let name = UserDefaults.standard.string(forKey: "openScreen"),
           let route = Route(argumentName: name) {
            path = [route]
        }
        #endif
    }
}
