import SwiftUI
import UIKit

// MARK: - Depth

extension View {
    /// Gives a surface a thickness: a tight contact shadow plus a wide ambient
    /// one.
    ///
    /// Two shadows rather than one is the whole trick. A single blurred shadow
    /// reads as a sticker floating over the page; the tight one anchors the
    /// edge to the surface below it and the wide one places it in the room.
    func depth(
        contact: Theme.Depth.ShadowToken,
        ambient: Theme.Depth.ShadowToken
    ) -> some View {
        shadow(
            color: Theme.Palette.shade.opacity(contact.opacity),
            radius: contact.radius, x: 0, y: contact.y
        )
        .shadow(
            color: Theme.Palette.shade.opacity(ambient.opacity),
            radius: ambient.radius, x: 0, y: ambient.y
        )
    }

    /// The lit top edge of a raised surface.
    ///
    /// Modern skeuomorphism, so this is one light source from above catching a
    /// rounded edge — not a 2010 bevel, and not a neumorphic double-emboss.
    /// It fades out by the middle of the shape, which is what keeps it reading
    /// as a curved edge rather than as a border.
    func litEdge(radius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Theme.Palette.highlight, .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: Theme.Size.highlightEdge
                )
        }
    }
}

// MARK: - Press feedback

/// A control that visibly and physically answers a tap.
///
/// The research on older users is consistent that the failure is rarely the
/// aim — it is not knowing whether the tap registered, so the button gets
/// pressed twice. This answers that in the two ways that cost the reader
/// nothing: the shadow collapses, so the button visibly sinks towards the page,
/// and a haptic ticks under the thumb.
///
/// **The label does not move.** Scaling the button scales its text with it, and
/// type that jumps under a tap is exactly the "everything is moving" feel this
/// audience is worst served by. Depth alone carries the press; the words stay
/// where they were put.
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Corner radius of the shape being pressed, so the shadow follows the
    /// silhouette rather than a guess at it.
    var radius: CGFloat = Theme.Radius.medium
    /// `false` for flat surfaces like a glance card, which should still sink
    /// and still tick, but not cast a button's shadow at rest.
    var raised: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .depth(
                contact: pressed ? Theme.Depth.pressedContact
                    : (raised ? Theme.Depth.raisedContact : Theme.Depth.restingContact),
                ambient: pressed ? Theme.Depth.pressedAmbient
                    : (raised ? Theme.Depth.raisedAmbient : Theme.Depth.restingAmbient)
            )
            .animation(Theme.Motion.respectful(Theme.Motion.press, reduceMotion: reduceMotion),
                       value: pressed)
            .onChange(of: pressed) { _, isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}

// MARK: - Haptics

/// The physical half of "modern skeuomorphism" — a surface you can feel is a
/// surface you trust.
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .soft)

    /// A control going down under the thumb.
    static func tap() {
        impact.impactOccurred()
    }

    /// Something committed — a card approved, a message handed off.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
