import SwiftUI

/// One question, two answers, side by side and the same size.
///
/// For decisions where *no* is a real answer rather than a way of getting out of
/// the way — putting something in her actual calendar is the case this was built
/// for. A big primary action with a small "Not this" underneath reads as one
/// thing to do plus an escape hatch; a pair reads as a question, which is what
/// this is. Both are 72pt: the same decision, so the same weight.
///
/// The question itself belongs above the buttons — "Yes" and "No" only mean
/// something next to it.
struct YesNoButtons: View {
    private let yes: String
    private let no: String
    private let yesSymbol: String?
    private let noSymbol: String?
    private let yesAction: () -> Void
    private let noAction: () -> Void

    init(
        yes: String = "Yes",
        no: String = "No",
        yesSymbol: String? = nil,
        noSymbol: String? = nil,
        yesAction: @escaping () -> Void,
        noAction: @escaping () -> Void
    ) {
        self.yes = yes
        self.no = no
        self.yesSymbol = yesSymbol
        self.noSymbol = noSymbol
        self.yesAction = yesAction
        self.noAction = noAction
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            PrimaryButton(yes, systemImage: yesSymbol, action: yesAction)
            SecondaryButton(no, systemImage: noSymbol, height: Theme.Size.primaryButtonHeight, action: noAction)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Space.m) {
        Text("Put it in the diary?")
            .themeFont(Theme.TypeScale.bodyStrong)
        YesNoButtons(yesSymbol: "calendar", noSymbol: "mic", yesAction: {}, noAction: {})
    }
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
