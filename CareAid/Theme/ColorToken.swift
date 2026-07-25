import SwiftUI
import UIKit

extension Color {
    /// One token, both appearances, declared in a single place.
    ///
    /// Keeping light and dark adjacent is deliberate: a palette change that
    /// only lands in one of them is the easiest way to ship an unreadable
    /// screen, and our user cannot afford a low-contrast surprise at 3am.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            .fromHex(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    /// `0xRRGGBB` → colour. Isolation-free so it can be called from the
    /// trait-change closure above, which runs off the main actor.
    nonisolated static func fromHex(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
