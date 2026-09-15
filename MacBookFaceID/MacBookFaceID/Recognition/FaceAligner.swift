import CoreGraphics
import Foundation
import Vision

/// Crops a detected face with padding and scales to 112×112. Enrollment and
/// matching share this path so embeddings stay comparable.
enum FaceAligner {
    static let outputSize = 112

    static func alignedFace(from image: CGImage, observation: VNFaceObservation) -> CGImage? {
        guard let cropped = crop(image, boundingBox: observation.boundingBox, pad: 0.28) else {
            return nil
        }
        return resize(cropped, to: outputSize)
    }

    static func crop(_ image: CGImage, boundingBox: CGRect, pad: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        var rect = CGRect(
            x: boundingBox.minX * width,
            y: (1 - boundingBox.maxY) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )
        rect = rect.insetBy(dx: -rect.width * pad, dy: -rect.height * pad)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !rect.isNull, rect.width > 8, rect.height > 8 else { return nil }
        return image.cropping(to: rect.integral)
    }

    private static func resize(_ image: CGImage, to size: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()
    }
}
