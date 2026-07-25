import Foundation
import SwiftUI

/// Renders a SwiftUI view to a PDF on disk, ready for `ShareLink`.
@MainActor
struct PDFService {

    enum PDFError: LocalizedError {
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed: "Couldn't make the pack. Try again."
            }
        }
    }

    /// One tall page rather than paginated A4.
    ///
    /// Splitting SwiftUI content across pages means measuring and slicing it by
    /// hand, and a single continuous page opens correctly in Files, Mail and
    /// Preview — which is every way this actually gets handed over. Worth
    /// revisiting only if someone needs to physically print it.
    func render(_ view: some View, named filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).pdf")

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        var failed = true
        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard
                let consumer = CGDataConsumer(url: url as CFURL),
                let context = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }

            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
            failed = false
        }

        guard !failed else { throw PDFError.renderFailed }
        return url
    }
}
