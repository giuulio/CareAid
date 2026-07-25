import SwiftUI

struct ReviewCard: View {

    let artifact: Artifact
    let approveAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(title)
                .font(.headline)

            Text(detail)
                .font(.body)

            HStack {
                Button {
                    approveAction()
                } label: {
                    Text("Approve")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    dismissAction()
                } label: {
                    Text("Not this")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var title: String {
        switch artifact.kind {
        case .task:
            return "Task"

        case .calendarEvent:
            return "Put it in the diary"

        case .familyUpdate:
            return "Tell family"

        case .question:
            return "Ask the doctor"

        case .timer:
            return "Reminder"

        case .medicationUpdate:
            return "Medication update"

        default:
            return "Care item"
        }
    }

    private var detail: String {
        artifact.payload.description
    }
}
