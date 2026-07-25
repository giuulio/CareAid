import SwiftUI

/// Every colour, size, space and type decision in the app.
///
/// Two rules keep the C13 design pass cheap:
///
/// 1. **Semantic names, not literal ones.** `ink`, not `nearBlack`. When the
///    palette moves, the name still describes the truth and nobody has to
///    rename call sites.
/// 2. **Nothing outside this file hardcodes a value.** No `.padding(16)`, no
///    `Color(red:...)`, no `.font(.system(size: 20))` in feature code. Ever.
///
/// The values here are provisional and get retuned in C13 — see `ThemeGallery`
/// to view them all on one page. The *accessibility floors* are not provisional:
/// body ≥ 19pt, touch targets ≥ 56pt, primary actions 72pt, body contrast ≥ 7:1.
enum Theme {

    // MARK: - Palette

    /// Warm paper and near-black ink, one accent. Contrast ratios below are
    /// against `surface` in light mode; recheck them if you change a value.
    enum Palette {
        /// App background. Warm paper, not clinical white.
        static let surface = Color(light: 0xFBF7F1, dark: 0x12100E)

        /// Content cards. Solid and opaque, always — never glass (CLAUDE.md §8).
        static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x1E1B18)

        /// Primary text. ~17:1.
        static let ink = Color(light: 0x14110E, dark: 0xF5F1EA)

        /// Supporting text and metadata. ~10:1 — still well past the 7:1 floor.
        static let inkSecondary = Color(light: 0x423C36, dark: 0xC3BBB1)

        /// The one accent. `onAccent` reads ~8:1 against it.
        static let accent = Color(light: 0x14594A, dark: 0x4FBFA3)

        /// Text and glyphs sitting on top of `accent`.
        static let onAccent = Color(light: 0xFFFFFF, dark: 0x0B1F1A)

        /// Tinted fill for banners and selected states. Text on this stays `ink`.
        static let accentSoft = Color(light: 0xE4EFEA, dark: 0x1B2E29)

        /// Borders and dividers. Decorative — never the only carrier of meaning.
        static let hairline = Color(light: 0xE6DFD5, dark: 0x2E2A26)
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
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Type scale

    /// A size at the default Dynamic Type setting, plus the text style it
    /// scales against.
    ///
    /// Not a `Font`: SwiftUI's `Font.system(size:)` is a *fixed* size and
    /// ignores Dynamic Type entirely (verified on device — the text does not
    /// move at accessibility sizes). Applying tokens through `.themeFont(_:)`
    /// runs them through `@ScaledMetric` instead, which does scale.
    struct TypeToken {
        let size: CGFloat
        let weight: Font.Weight
        let relativeTo: Font.TextStyle
        /// Serif is reserved for the brief and the appointment pack, so they
        /// read as a document you hand to a consultant rather than as app
        /// chrome (C10).
        var design: Font.Design = .default
    }

    /// Sizes sit above the 17pt system default throughout — CLAUDE.md §8.
    enum TypeScale {
        /// The brief's one-liner. The largest thing in the app.
        static let briefOneLiner = TypeToken(size: 30, weight: .semibold, relativeTo: .largeTitle, design: .serif)
        /// Body copy inside the brief and the printed pack.
        static let document = TypeToken(size: 20, weight: .regular, relativeTo: .body, design: .serif)
        /// Section headings in the printed pack.
        static let documentHeading = TypeToken(size: 22, weight: .semibold, relativeTo: .title3, design: .serif)
        /// Screen titles.
        static let screenTitle = TypeToken(size: 28, weight: .bold, relativeTo: .title)
        /// Card headlines.
        static let cardHeadline = TypeToken(size: 22, weight: .semibold, relativeTo: .title3)
        /// Button labels.
        static let button = TypeToken(size: 22, weight: .semibold, relativeTo: .title3)
        /// Body copy. The floor for anything the caregiver has to read properly.
        static let body = TypeToken(size: 20, weight: .regular, relativeTo: .body)
        /// Body copy that needs emphasis.
        static let bodyStrong = TypeToken(size: 20, weight: .semibold, relativeTo: .body)
        /// Metadata only — timestamps, captions. Never body copy.
        static let meta = TypeToken(size: 17, weight: .regular, relativeTo: .subheadline)
        /// Toolbar and inline SF Symbols. Glyph size follows the font.
        static let icon = TypeToken(size: 22, weight: .medium, relativeTo: .body)
    }

    // MARK: - Sizes

    enum Size {
        /// Nothing tappable is ever smaller than this.
        static let minTouchTarget: CGFloat = 56
        /// Primary actions — CLAUDE.md §8.
        static let primaryButtonHeight: CGFloat = 72
        /// Secondary actions.
        static let secondaryButtonHeight: CGFloat = 56
        /// The mic. Dominant by a wide margin; it is the whole point of Home.
        static let micDiameter: CGFloat = 168
        /// The mic glyph inside it. Fixed — the circle does not grow with type.
        static let micGlyph: CGFloat = 56
        /// Enough room to type a rambling paragraph without scrolling.
        static let textEditorMinHeight: CGFloat = 220
        /// The live waveform while she is speaking.
        static let waveformHeight: CGFloat = 120
        /// Hairline borders and dividers.
        static let hairline: CGFloat = 1
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
