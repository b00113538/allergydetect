import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Native QR generation with CoreImage's `CIQRCodeGenerator` — no third-party dependency.
enum QRCodeService {
    private static let context = CIContext()

    /// Renders `payload` as a crisp QR image `size` points wide.
    static func image(for payload: String, size: CGFloat = 280, scale: CGFloat = 3) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        // Scale with nearest-neighbour-equivalent integer factors so modules stay sharp.
        let pixels = size * scale
        let factor = max(1, (pixels / output.extent.width).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
