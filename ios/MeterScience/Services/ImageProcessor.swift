import UIKit
import Vision
import CoreImage

/// Service for pre-processing images to improve OCR accuracy
/// Handles orientation correction, text angle detection, and contrast enhancement
class ImageProcessor {

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Orientation Normalization

    /// Normalizes image orientation by applying EXIF orientation data
    /// Ensures image is displayed upright regardless of how it was captured
    /// - Parameter image: The input UIImage with potential orientation issues
    /// - Returns: A UIImage with normalized orientation
    func normalizeOrientation(_ image: UIImage) -> UIImage {
        // If already in up orientation, return as-is
        guard image.imageOrientation != .up else {
            return image
        }

        // Redraw image in correct orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: image.size))

        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("[ImageProcessor] Failed to normalize orientation, returning original")
            return image
        }

        print("[ImageProcessor] Normalized orientation from \(image.imageOrientation.rawValue) to .up")
        return normalizedImage
    }

    // MARK: - Text Angle Detection

    /// Detects the angle of text in the image using Vision framework
    /// Returns angle in radians, or nil if no text detected
    /// - Parameter image: The CIImage to analyze
    /// - Returns: Angle in radians (positive = clockwise rotation needed), or nil if no text found
    func detectTextAngle(_ image: CIImage) async -> Float? {
        await withCheckedContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNTextObservation],
                      !observations.isEmpty else {
                    print("[ImageProcessor] No text rectangles detected")
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate average angle from all text observations
                var angles: [Float] = []

                for observation in observations {
                    // Get the bounding box corners
                    let topLeft = observation.topLeft
                    let topRight = observation.topRight

                    // Calculate angle of text baseline (top edge of bounding box)
                    let dx = Float(topRight.x - topLeft.x)
                    let dy = Float(topRight.y - topLeft.y)
                    let angle = atan2(dy, dx)

                    angles.append(angle)
                }

                // Use median angle to avoid outliers
                let sortedAngles = angles.sorted()
                let medianAngle = sortedAngles[sortedAngles.count / 2]

                print("[ImageProcessor] Detected text angle: \(medianAngle) radians (\(medianAngle * 180 / .pi) degrees)")
                continuation.resume(returning: medianAngle)
            }

            request.reportCharacterBoxes = false

            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[ImageProcessor] Text angle detection failed: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Image Rotation

    /// Rotates image to horizontal orientation based on detected angle
    /// - Parameters:
    ///   - image: The CIImage to rotate
    ///   - angle: Angle in radians (positive = clockwise rotation needed)
    /// - Returns: Rotated CIImage with text horizontal
    func rotateToHorizontal(_ image: CIImage, angle: Float) -> CIImage {
        // Only rotate if angle is significant (> 2 degrees)
        let threshold: Float = 2.0 * .pi / 180.0
        guard abs(angle) > threshold else {
            print("[ImageProcessor] Angle \(angle) below threshold, skipping rotation")
            return image
        }

        // Convert angle to degrees for better logging
        let degrees = angle * 180.0 / .pi
        print("[ImageProcessor] Rotating image by \(degrees) degrees")

        // Apply rotation transform
        // Note: Negative angle because CIImage rotation is counterclockwise
        let transform = CGAffineTransform(rotationAngle: CGFloat(-angle))
        let rotatedImage = image.transformed(by: transform)

        return rotatedImage
    }

    // MARK: - Contrast Enhancement

    /// Enhances image contrast to improve OCR readability
    /// Applies automatic color adjustments and sharpening
    /// - Parameter image: The CIImage to enhance
    /// - Returns: Enhanced CIImage with better contrast
    func enhanceContrast(_ image: CIImage) -> CIImage {
        var enhancedImage = image

        // 1. Auto-adjust exposure and contrast
        if let autoFilter = CIFilter(name: "CIColorControls") {
            autoFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            autoFilter.setValue(1.2, forKey: kCIInputContrastKey) // Boost contrast
            autoFilter.setValue(0.0, forKey: kCIInputBrightnessKey) // Keep brightness neutral
            autoFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color (grayscale)

            if let output = autoFilter.outputImage {
                enhancedImage = output
                print("[ImageProcessor] Applied contrast boost and grayscale conversion")
            }
        }

        // 2. Sharpen edges for better digit recognition
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.8, forKey: kCIInputSharpnessKey) // Moderate sharpening

            if let output = sharpenFilter.outputImage {
                enhancedImage = output
                print("[ImageProcessor] Applied sharpening filter")
            }
        }

        // 3. Apply unsharp mask for additional clarity
        if let unsharpFilter = CIFilter(name: "CIUnsharpMask") {
            unsharpFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            unsharpFilter.setValue(2.5, forKey: kCIInputRadiusKey)
            unsharpFilter.setValue(0.5, forKey: kCIInputIntensityKey)

            if let output = unsharpFilter.outputImage {
                enhancedImage = output
                print("[ImageProcessor] Applied unsharp mask")
            }
        }

        return enhancedImage
    }

    // MARK: - Complete Pipeline

    /// Runs complete preprocessing pipeline on a UIImage
    /// - Parameter image: Input UIImage from camera
    /// - Returns: Preprocessed CIImage ready for OCR
    func preprocessForOCR(_ image: UIImage) async -> CIImage? {
        print("[ImageProcessor] Starting preprocessing pipeline")

        // Step 1: Normalize orientation
        let normalizedImage = normalizeOrientation(image)

        // Step 2: Convert to CIImage
        guard let cgImage = normalizedImage.cgImage else {
            print("[ImageProcessor] Failed to get CGImage")
            return nil
        }
        var ciImage = CIImage(cgImage: cgImage)

        // Step 3: Detect and correct text angle
        if let angle = await detectTextAngle(ciImage) {
            ciImage = rotateToHorizontal(ciImage, angle: angle)
        }

        // Step 4: Enhance contrast
        ciImage = enhanceContrast(ciImage)

        print("[ImageProcessor] Preprocessing complete")
        return ciImage
    }

    // MARK: - Helper Methods

    /// Converts CIImage back to UIImage for display purposes
    /// - Parameter ciImage: The CIImage to convert
    /// - Returns: UIImage or nil if conversion fails
    func convertToUIImage(_ ciImage: CIImage) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
