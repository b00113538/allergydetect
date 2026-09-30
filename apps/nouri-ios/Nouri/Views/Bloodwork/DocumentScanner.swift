import SwiftUI
import UIKit
import VisionKit

/// VisionKit document camera: edge detection, perspective correction, multiple pages.
/// Unavailable in the simulator — callers fall back to `CameraPicker`.
struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan((0..<scan.pageCount).map(scan.imageOfPage(at:)))
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

enum ReportDocument {
    /// Largest accepted upload (matches the Storage rule and the Cloud Function limit).
    static let maxBytes = 10 * 1024 * 1024

    /// Scanned pages → one PDF, each page downscaled and JPEG-compressed to keep uploads small
    /// while staying legible (Claude reads images up to ~1568 px on the long edge at full detail).
    static func pdf(from pages: [UIImage]) -> Data {
        let compressed = pages.compactMap { $0.nouriJPEGData(maxDimension: 1568, quality: 0.8).flatMap(UIImage.init(data:)) }
        let first = compressed.first?.size ?? CGSize(width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: first))
        return renderer.pdfData { context in
            for page in compressed {
                context.beginPage(withBounds: CGRect(origin: .zero, size: page.size), pageInfo: [:])
                page.draw(in: CGRect(origin: .zero, size: page.size))
            }
        }
    }
}
