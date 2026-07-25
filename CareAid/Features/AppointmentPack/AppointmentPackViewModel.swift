import Foundation
import Observation
import SwiftUI

/// The question bank, and the pack built from it.
@Observable
final class AppointmentPackViewModel {

    enum State {
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var recipient: Recipient?
    private(set) var brief: Brief?
    private(set) var questions: [Artifact] = []
    private(set) var medications: [Medication] = []
    private(set) var recentEvents: [TimelineEvent] = []
    private(set) var nextAppointment: TimelineEvent?

    private(set) var packURL: URL?
    private(set) var buildingPack = false

    func load() async {
        state = .loading
        do {
            async let recipientTask = RecipientRepository().current()
            async let briefTask = BriefRepository().current()
            async let questionsTask = ArtifactRepository().questions()
            async let medicationsTask = MedicationRepository().active()
            async let recentTask = TimelineRepository().recent(limit: 200)
            async let upcomingTask = TimelineRepository().upcoming()

            recipient = try await recipientTask
            brief = try await briefTask
            questions = try await questionsTask
            medications = try await medicationsTask

            // The pack is for the appointment, so only the recent run-up is
            // relevant — 90 days of history would bury it.
            let cutoff = Date.now.addingTimeInterval(-30 * 86_400)
            recentEvents = try await recentTask
                .filter { $0.occurredAt >= cutoff && $0.severity != .none }

            nextAppointment = try await upcomingTask.first { $0.kind == .appointment }
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    var questionTexts: [String] {
        questions.compactMap { artifact in
            if case .question(let payload) = artifact.payload { payload.question } else { nil }
        }
    }

    @MainActor
    func makePack() async {
        buildingPack = true
        defer { buildingPack = false }
        do {
            let document = PackDocument(
                recipient: recipient,
                brief: brief,
                questions: questionTexts,
                medications: medications,
                events: recentEvents
            )
            packURL = try PDFService().render(document, named: "CareAid-appointment-pack")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
