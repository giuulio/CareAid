import SwiftUI

struct ReviewView: View {

    @State private var viewModel: ReviewViewModel

    init(response: ExtractionResponse) {
        _viewModel = State(
            initialValue: ReviewViewModel(
                response: response
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("What I heard")
                        .font(.title2)
                        .bold()

                    Text("Your recording will appear here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)


                if !viewModel.response.events.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(viewModel.response.events) { event in
                            // TimelinePreview doesn't exist; TimelineEventRow
                            // from C4 renders the same thing.
                            TimelineEventRow(event: event)
                        }
                    }
                }


                if !viewModel.visibleArtifacts.isEmpty {
                    VStack(spacing: 16) {
                        ForEach(viewModel.visibleArtifacts) { artifact in
                            ReviewCard(
                                artifact: artifact,
                                approveAction: {
                                    viewModel.approve(artifact)
                                },
                                dismissAction: {
                                    viewModel.dismiss(artifact)
                                }
                            )
                        }
                    }


                    Button {
                        viewModel.approveAll()
                    } label: {
                        Text("Approve all")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                } else {
                    Text("Nothing needs reviewing.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}
