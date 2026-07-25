//
//  ImageCaptureService.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2026-05-05.
//

import Foundation
import UIKit
import ARKit
import CoreImage
import ImageIO

final class ImageCaptureService {
    private let ciContext = CIContext()

    func saveCurrentCameraImage(from session: ARSession,
                                named name: String,
                                in folder: URL,
                                overlayText: String? = nil) -> String? {
        guard AppConfiguration.shared.enablePeakFrameImageCapture else { return nil }
        guard let frame = session.currentFrame else { return nil }
        return saveCameraPixelBuffer(frame.capturedImage,
                                     named: name,
                                     in: folder,
                                     overlayText: overlayText)
    }

    func saveCameraPixelBuffer(_ pixelBuffer: CVPixelBuffer,
                               named name: String,
                               in folder: URL,
                               overlayText: String? = nil) -> String? {
        guard AppConfiguration.shared.enablePeakFrameImageCapture else { return nil }

        // ARKit camera frames usually arrive in a landscape sensor orientation.
        // .right gives a portrait-oriented image for normal iPhone portrait testing.
        // If your saved images look rotated, change this to .left or .rightMirrored.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        var image = UIImage(cgImage: cgImage)
        image = resized(image, maxDimension: 900)

        if let overlayText, !overlayText.isEmpty {
            image = drawOverlay(text: overlayText, on: image)
        }

        let safeName = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        let fileURL = folder.appendingPathComponent("\(safeName).jpg")
        guard let data = image.jpegData(compressionQuality: 0.72) else { return nil }

        do {
            try data.write(to: fileURL, options: [.atomic])
            return fileURL.path
        } catch {
            return nil
        }
    }

    func savePlaceholderImage(named name: String, in folder: URL) -> String? {
        guard AppConfiguration.shared.enablePeakFrameImageCapture else { return nil }
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 10)
            ]
            let text = NSString(string: name)
            text.draw(in: CGRect(x: 4, y: 24, width: 56, height: 20), withAttributes: attrs)
        }
        let fileURL = folder.appendingPathComponent("\(name).png")
        guard let data = image.pngData() else { return nil }
        try? data.write(to: fileURL)
        return fileURL.path
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largestDimension = max(image.size.width, image.size.height)
        guard largestDimension > maxDimension else { return image }

        let scale = maxDimension / largestDimension
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func drawOverlay(text: String, on image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            image.draw(at: .zero)

            let padding: CGFloat = 12
            let boxHeight: CGFloat = 64
            let boxRect = CGRect(x: padding,
                                 y: image.size.height - boxHeight - padding,
                                 width: image.size.width - padding * 2,
                                 height: boxHeight)

            UIColor.black.withAlphaComponent(0.62).setFill()
            UIBezierPath(roundedRect: boxRect, cornerRadius: 10).fill()

            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
            ]

            let textRect = boxRect.insetBy(dx: 10, dy: 8)
            NSString(string: text).draw(in: textRect, withAttributes: attrs)
        }
    }
}
