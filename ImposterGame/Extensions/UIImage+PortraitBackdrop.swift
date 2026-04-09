import SwiftUI
import UIKit

extension UIImage {
    /// Estimates the flat backdrop color by averaging inset corner samples (typical for portrait cards).
    func portraitBackdropColor() -> Color? {
        guard let ui = averageCornerUIColor() else { return nil }
        return Color(uiColor: ui)
    }

    private func averageCornerUIColor() -> UIColor? {
        let maxSide: CGFloat = 96
        let w = size.width
        let h = size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(maxSide / w, maxSide / h, 1)
        let rw = Int(max(4, w * scale))
        let rh = Int(max(4, h * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: rw, height: rh), format: format)
        let scaled = renderer.image { _ in
            draw(in: CGRect(x: 0, y: 0, width: rw, height: rh))
        }
        guard let cgImage = scaled.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapSize = height * bytesPerRow
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let raw = malloc(bitmapSize)
        else { return nil }
        defer { free(raw) }

        guard let context = CGContext(
            data: raw,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let buf = raw.assumingMemoryBound(to: UInt8.self)
        let inset = max(1, min(width, height) / 24)

        func unpremultipliedRGB(at x: Int, y: Int) -> (CGFloat, CGFloat, CGFloat) {
            let o = (y * width + x) * bytesPerPixel
            let r = CGFloat(buf[o]) / 255
            let g = CGFloat(buf[o + 1]) / 255
            let b = CGFloat(buf[o + 2]) / 255
            let a = CGFloat(buf[o + 3]) / 255
            if a < 0.001 { return (r, g, b) }
            return (r / a, g / a, b / a)
        }

        let corners = [
            unpremultipliedRGB(at: inset, y: inset),
            unpremultipliedRGB(at: width - 1 - inset, y: inset),
            unpremultipliedRGB(at: inset, y: height - 1 - inset),
            unpremultipliedRGB(at: width - 1 - inset, y: height - 1 - inset)
        ]

        let n = CGFloat(corners.count)
        let sr = corners.map(\.0).reduce(0, +) / n
        let sg = corners.map(\.1).reduce(0, +) / n
        let sb = corners.map(\.2).reduce(0, +) / n

        return UIColor(red: sr, green: sg, blue: sb, alpha: 1)
    }
}
