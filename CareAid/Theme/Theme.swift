import SwiftUI

/// Every colour, size, space, type and motion decision in the app.
///
/// Two rules keep a design pass cheap:
///
/// 1. **Semantic names, not literal ones.** `ink`, not `nearBlack`. When the
///    palette moves, the name still describes the truth and nobody has to
///    rename call sites.
/// 2. **Nothing outside this file hardcodes a value.** No `.padding(16)`, no
///    `Color(red:...)`, no `.font(.system(size: 20))` in feature code. Ever.
///
/// The *accessibility floors* are not negotiable and every value below was
/// checked against them: body ≥ 19pt, touch targets ≥ 56pt, primary actions
/// 72pt, body contrast ≥ 7:1. Research on older adults pushes past several of
/// them — 60pt targets measurably beat 48pt for arthritic and tremoring hands,
/// and 7:1 (WCAG AAA) is the recommendation for ageing eyes rather than the
/// 4.5:1 floor — so the sizes here sit above the minimums, not on them.
enum Theme {

    // MARK: - Palette

    /// Soft sage paper, deep navy ink, one sky-blue accent.
    ///
    /// Contrast ratios below are measured against `surface` in light mode.
    /// **Recheck them if you change a value** — they are the reason the screen
    /// works at 3am for someone with presbyopia, not decoration.
    enum Palette {
        /// App background. Warm paper, not clinical white — glare off a
        /// pure-white screen is the single most common complaint from older
        /// readers.
        static let surface = Color(light: 0xFBF7F1, dark: 0x121820)

        /// Content cards. Solid and opaque, always — never glass (CLAUDE.md §8).
        /// Only a shade off `surface` in light mode, so the shadow does the
        /// lifting rather than the fill.
        static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x1C242F)

        /// A recessed well — text editors, inset fields, an entry already
        /// written. Reads as *into* the page where `surfaceRaised` reads as
        /// *out of* it.
        static let surfaceSunken = Color(light: 0xF0EAE1, dark: 0x0D1219)

        /// Primary text. 12.7:1 on `surface`.
        static let ink = Color(light: 0x1C3041, dark: 0xEBEDE9)

        /// Supporting text and metadata. 8.2:1 — clears the AAA floor, so it is
        /// safe for real sentences and not only for timestamps.
        static let inkSecondary = Color(light: 0x3A4D5F, dark: 0xA9B6C2)

        /// The one accent. Carries `onAccent` at 4.9:1 — fine for the 22pt+
        /// semibold labels it actually holds (WCAG large-text is 3:1), and
        /// never used behind body copy.
        static let accent = Color(light: 0x4DA5D1, dark: 0x5FB4DE)

        /// The top of the accent where the light lands. Paired with `accent` in
        /// a two-stop gradient, this is what gives a button a curved face
        /// instead of a flat one. Kept within a few steps of `accent` — a wide
        /// gradient would drop the label's contrast at one end.
        static let accentLit = Color(light: 0x69B7E0, dark: 0x74C0E6)

        /// Text and glyphs sitting on top of `accent`. Navy, not white: white
        /// on this blue is 2.75:1, which fails even the AA floor and is exactly
        /// the kind of "looks fine in the mockup" choice our reader pays for.
        static let onAccent = Color(light: 0x14283A, dark: 0x0B1722)

        /// Tinted fill for banners and selected states. Text on this stays
        /// `ink` — 10.8:1.
        static let accentSoft = Color(light: 0xD6E8F2, dark: 0x1B3040)

        /// Borders and dividers. Decorative — never the only carrier of meaning.
        static let hairline = Color(light: 0xE6DFD5, dark: 0x2C3744)

        /// The light that makes a raised surface look raised. Modern
        /// skeuomorphism, so: a top edge catching light, not a bevel. Muted in
        /// dark mode — a white edge at 21:00 is a glare source, not a highlight.
        static let highlight = Color(light: 0xFFFFFF, dark: 0x7C93A8).opacity(0.5)

        /// The colour every shadow is cut from. Navy rather than black — a
        /// black shadow on a sage ground goes muddy and grey.
        static let shade = Color(light: 0x1C3041, dark: 0x000000)
    }

    // MARK: - Spacing

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 26
        static let pill: CGFloat = 999
    }

    // MARK: - Type

    /// A size at the default Dynamic Type setting, the face it is set in, and
    /// the text style it scales against.
    ///
    /// Not a `Font`: a bare `Font.custom(_:size:)` is *fixed* and ignores
    /// Dynamic Type entirely, which would quietly break CLAUDE.md §8 for
    /// exactly the reader we are building for. `.themeFont(_:)` routes every
    /// token through the `relativeTo:` overload, which scales.
    struct TypeToken {
        /// PostScript name of a bundled face, or `nil` for the system font.
        ///
        /// SF Symbols must stay on the system font — a symbol inherits its
        /// glyph metrics from the font it is set in, and Inter has no opinion
        /// about how big `pills` should be. Icon tokens leave this `nil`.
        var face: String?
        let size: CGFloat
        /// Only consulted when `face` is `nil`; the bundled faces carry their
        /// weight in the file, because SwiftUI's `.weight()` does not drive
        /// OpenType variation axes.
        var weight: Font.Weight = .regular
        let relativeTo: Font.TextStyle
    }

    /// The two families, by role.
    ///
    /// Nunito Sans is the brand voice — rounded terminals and a tall x-height,
    /// which is the reason it was picked and also, conveniently, what ageing
    /// eyes resolve most easily. Inter is the workhorse: a UI face drawn for
    /// screens, with unambiguous `1/l/I` and `0/O` shapes that matter when the
    /// text is a dose.
    enum Face {
        static let brandRegular = "NunitoSans-Regular"
        static let brandSemibold = "NunitoSans-SemiBold"
        static let brandBold = "NunitoSans-Bold"
        static let brandExtraBold = "NunitoSans-ExtraBold"

        static let textRegular = "Inter-Regular"
        static let textMedium = "Inter-Medium"
        static let textSemibold = "Inter-SemiBold"
        static let textBold = "Inter-Bold"
    }

    /// Sizes sit well above the 17pt system default throughout — CLAUDE.md §8,
    /// and the literature is blunter still: 16pt is the floor, 18–20pt is where
    /// older readers stop struggling.
    enum TypeScale {
        /// The wordmark on the splash.
        static let splashTitle = TypeToken(face: Face.brandBold, size: 44, relativeTo: .largeTitle)
        /// The wordmark in Home's header. Sized against the 48pt icons either
        /// side of it — at the old 22pt it read as a caption between two large
        /// glyphs rather than as the thing they flank.
        static let brandTitle = TypeToken(face: Face.brandBold, size: 34, relativeTo: .title)
        /// The greeting on Home, and nothing else. Deliberately *not* bold: at
        /// this size the scale is already the emphasis, and weight on top of it
        /// turns a question into a banner. 30pt rather than 40 because the
        /// question got longer — "How are we helping Mum today?" sets to two
        /// comfortable lines here, and to four cramped ones at 40.
        static let hero = TypeToken(face: Face.brandRegular, size: 30, relativeTo: .largeTitle)
        /// The brief's one-liner.
        static let briefOneLiner = TypeToken(face: Face.brandBold, size: 32, relativeTo: .largeTitle)
        /// Screen titles.
        static let screenTitle = TypeToken(face: Face.brandBold, size: 30, relativeTo: .title)
        /// Card headlines.
        static let cardHeadline = TypeToken(face: Face.brandBold, size: 24, relativeTo: .title3)
        /// Section headings in the printed pack.
        static let documentHeading = TypeToken(face: Face.brandSemibold, size: 23, relativeTo: .title3)
        /// Body copy inside the brief and the printed pack.
        static let document = TypeToken(face: Face.textRegular, size: 21, relativeTo: .body)
        /// Button labels.
        static let button = TypeToken(face: Face.textSemibold, size: 22, relativeTo: .title3)
        /// Body copy. The floor for anything the caregiver has to read properly.
        static let body = TypeToken(face: Face.textRegular, size: 21, relativeTo: .body)
        /// Body copy that needs emphasis.
        static let bodyStrong = TypeToken(face: Face.textSemibold, size: 21, relativeTo: .body)
        /// Metadata only — timestamps, captions. Never body copy.
        static let meta = TypeToken(face: Face.textMedium, size: 18, relativeTo: .subheadline)

        /// Inline SF Symbols. System font on purpose — see `TypeToken.face`.
        static let icon = TypeToken(face: nil, size: 24, weight: .medium, relativeTo: .body)
        /// Home's two destination icons, at double `icon`. They are the only
        /// way off this screen other than the mic, and they sit in a custom
        /// header rather than a `.toolbar` for exactly this reason: a 48pt
        /// glyph does not fit a 44pt system navigation bar, it gets clipped.
        static let navIcon = TypeToken(face: nil, size: 48, weight: .medium, relativeTo: .title)
        /// The larger glyph that leads a card or a row.
        static let iconLarge = TypeToken(face: nil, size: 30, weight: .medium, relativeTo: .title3)
    }

    // MARK: - Sizes

    enum Size {
        /// Nothing tappable is ever smaller than this. Apple says 44; the
        /// research on older hands says 48 is the bare minimum and 60 is where
        /// error rates actually collapse, so 60 it is.
        static let minTouchTarget: CGFloat = 60
        /// Primary actions — CLAUDE.md §8.
        static let primaryButtonHeight: CGFloat = 72
        /// Secondary actions.
        static let secondaryButtonHeight: CGFloat = 60
        /// Tap target around each of Home's two header icons. Bigger than
        /// `minTouchTarget` because the 48pt glyph inside needs the room.
        static let headerIcon: CGFloat = 64
        /// The brand mark on the splash.
        static let brandMark: CGFloat = 132
        /// The mic. Dominant by a wide margin; it is the whole point of Home.
        static let micDiameter: CGFloat = 200
        /// The mic glyph inside it. Fixed — the circle does not grow with type.
        static let micGlyph: CGFloat = 68
        /// How far the mic's halo breathes out at rest.
        static let micHalo: CGFloat = 28
        /// Enough room to type a rambling paragraph without scrolling.
        static let textEditorMinHeight: CGFloat = 220
        /// The live waveform while she is speaking.
        static let waveformHeight: CGFloat = 132
        /// One bar of it.
        static let waveformBar: CGFloat = 6
        /// Hairline borders and dividers.
        static let hairline: CGFloat = 1
        /// The lit top edge on a raised surface.
        static let highlightEdge: CGFloat = 1.5
    }

    // MARK: - Depth

    /// Modern skeuomorphism: surfaces that look like they have a thickness and
    /// respond when pressed.
    ///
    /// Deliberately *not* neumorphism. The 2020 style extrudes a control from
    /// the background in the same colour, and the well-documented consequence
    /// is a control nobody can see — the exact failure mode our reader cannot
    /// absorb. So the depth here is additive: a card is still white on sage and
    /// still passes 7:1 with every shadow switched off. Take the shadows away
    /// and the screen is merely flat, never ambiguous.
    enum Depth {
        struct ShadowToken {
            let opacity: Double
            let radius: CGFloat
            let y: CGFloat
        }

        /// Contact shadow — tight, sits directly under the edge.
        static let restingContact = ShadowToken(opacity: 0.07, radius: 2, y: 1)
        /// Ambient shadow — wide and soft, the light in the room.
        static let restingAmbient = ShadowToken(opacity: 0.09, radius: 20, y: 8)

        /// A control that is asking to be pressed sits higher than a card.
        static let raisedContact = ShadowToken(opacity: 0.10, radius: 3, y: 2)
        static let raisedAmbient = ShadowToken(opacity: 0.22, radius: 18, y: 10)

        /// Under the thumb: the control drops towards the page. This is the
        /// *whole* press effect — nothing scales, because scaling a button
        /// moves its label, and text that jumps under a tap is the single
        /// worst thing you can do to a reader who is tired or presbyopic.
        static let pressedContact = ShadowToken(opacity: 0.09, radius: 2, y: 1)
        static let pressedAmbient = ShadowToken(opacity: 0.12, radius: 6, y: 2)
    }

    // MARK: - Motion

    /// Motion is feedback, never decoration.
    ///
    /// **Text never moves.** Not on press, not on arrival, not ever. Type that
    /// slides, scales or jumps is the fastest way to make a screen unreadable
    /// for someone tired, presbyopic, or holding the phone one-handed at 3am —
    /// they lose their place and start the sentence again. Every animation
    /// below therefore acts on a shadow, a shape or an opacity, and the words
    /// stay exactly where they were put.
    ///
    /// What is left that moves at all, in the whole app:
    ///
    /// - the **waveform**, while she is speaking — it exists to prove the phone
    ///   is hearing her, and it is the reason she knows to keep talking;
    /// - one **ring** on `ThinkingIndicator`, during the ~13s extraction —
    ///   it exists to prove the app has not frozen;
    /// - a **shadow** collapsing under a press, which is how a button says
    ///   "yes, that registered" without touching its own label;
    /// - the Review **stagger**, a pure cross-fade, CLAUDE.md §8's one
    ///   sanctioned animation;
    /// - the **splash** handing over to Home, also a pure cross-fade.
    ///
    /// Everything else is static, and adding to this list needs a reason that
    /// survives the question *what does the reader lose if it doesn't move?*
    enum Motion {
        /// Press and release. Critically damped-ish; no overshoot.
        static let press = Animation.spring(response: 0.28, dampingFraction: 0.78)
        /// The splash dissolving into Home. Slightly longer than the stagger so
        /// the handover reads as one screen becoming another rather than as a
        /// flicker at launch.
        static let splashOut = Animation.easeOut(duration: 0.25)
        /// The Review stagger — CLAUDE.md §8's one animation, still 200ms.
        static let stagger = Animation.easeOut(duration: 0.2)
        /// Per-card delay in that stagger.
        static let staggerStep = 0.05
        /// One waveform bar easing to its new height. The samples arrive in
        /// steps; her voice does not.
        static let waveform = Animation.easeOut(duration: 0.12)

        /// Returns `animation` unless the reader has asked the system for less
        /// motion, in which case nothing moves.
        static func respectful(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }
    }

    // MARK: - Appearance

    /// Auto dark after 21:00, in London, with no toggle — CLAUDE.md §8 and §10.
    ///
    /// Evaluated when the root view renders rather than on a timer; a demo does
    /// not run long enough to cross the boundary mid-session.
    static func preferredColorScheme(at date: Date = .now) -> ColorScheme {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let hour = calendar.component(.hour, from: date)
        return (hour >= 21 || hour < 6) ? .dark : .light
    }
}
