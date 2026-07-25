import SwiftUI

/// What gets printed. Rendered off-screen to PDF, never shown in the app.
///
/// Written for Dr Okafor to read in the two minutes before he calls her in:
/// the one-liner, what changed, what Sarah wants to ask, and the medication
/// list — in that order, because that is the order he needs them.
struct PackDocument: View {
    let recipient: Recipient?
    let brief: Brief?
    let questions: [String]
    let medications: [Medication]
    let events: [TimelineEvent]

    static let pageWidth: CGFloat = 595 // A4 at 72dpi

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            header

            if let brief {
                section("Where things are") {
                    Text(brief.content.oneLiner)
                        .themeFont(Theme.TypeScale.briefOneLiner)
                        .foregroundStyle(Theme.Palette.ink)
                }

                if !brief.content.currentConcerns.isEmpty {
                    section("What we're worried about") {
                        ForEach(Array(brief.content.currentConcerns.enumerated()), id: \.offset) { _, concern in
                            bullet("\(concern.text)\(trend(concern))")
                        }
                    }
                }
            }

            if !questions.isEmpty {
                section("What Sarah would like to ask") {
                    ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                        bullet("\(index + 1). \(question)")
                    }
                }
            }

            if !medications.isEmpty {
                section("Current medication") {
                    ForEach(medications) { medication in
                        bullet([medication.name, medication.dose, medication.schedule]
                            .compactMap(\.self).joined(separator: " · "))
                    }
                }
            }

            if !events.isEmpty {
                section("The last 30 days") {
                    ForEach(events) { event in
                        bullet("\(DisplayDate.dayLabel(for: event.occurredAt)) — \(event.headline)")
                    }
                }
            }

            Text("Prepared by CareAid from notes recorded by Sarah. Not a medical record.")
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .padding(.top, Theme.Space.l)
        }
        .padding(Theme.Space.xxl)
        .frame(width: Self.pageWidth, alignment: .leading)
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(recipient?.legalName ?? recipient?.displayName ?? "Care recipient")
                .themeFont(Theme.TypeScale.documentHeading)
                .foregroundStyle(Theme.Palette.ink)
            Text(subtitle)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Divider()
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let year = recipient?.yearOfBirth { parts.append("born \(year)") }
        if let conditions = recipient?.conditions, !conditions.isEmpty {
            parts.append(conditions.joined(separator: ", "))
        }
        parts.append("prepared \(DisplayDate.dayLabel(for: .now))")
        return parts.joined(separator: " · ")
    }

    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(title)
                .themeFont(Theme.TypeScale.documentHeading)
                .foregroundStyle(Theme.Palette.ink)
            content()
        }
    }

    private func bullet(_ text: String) -> some View {
        Text("•  \(text)")
            .themeFont(Theme.TypeScale.document)
            .foregroundStyle(Theme.Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Direction only — never a judgement about severity (rule 1).
    private func trend(_ concern: Concern) -> String {
        switch concern.trend {
        case .worsening: " (getting worse)"
        case .improving: " (easing)"
        case .stable, nil: ""
        }
    }
}
