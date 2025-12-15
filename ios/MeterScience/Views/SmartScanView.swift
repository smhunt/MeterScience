import SwiftUI
import AVFoundation
import Vision

struct SmartScanView: View {
    let meter: MeterResponse
    @StateObject private var viewModel: SmartScanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false

    init(meter: MeterResponse) {
        self.meter = meter
        _viewModel = StateObject(wrappedValue: SmartScanViewModel(meter: meter))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = viewModel.capturedImage {
                // Show captured photo
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // Prompt to take photo
                VStack(spacing: 24) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("Tap to capture your meter reading")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Overlay
            VStack {
                // Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(meter.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(meter.meterType.capitalized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding()

                Spacer()

                // Result Card (after capture + OCR)
                if viewModel.scanState == .detected || viewModel.scanState == .confirmed {
                    ResultCard(viewModel: viewModel, dismiss: dismiss)
                }

                // Capture Button
                if viewModel.scanState == .scanning {
                    Button {
                        showingCamera = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 82, height: 82)
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }

            // Loading Overlay
            if viewModel.isProcessing {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Processing...")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $viewModel.capturedImage) {
                // Photo was taken - run OCR
                viewModel.processCapture()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Image Picker (System Camera)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    var onCapture: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.dismiss()
                parent.onCapture()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - View Model

@MainActor
class SmartScanViewModel: NSObject, ObservableObject {
    let meter: MeterResponse

    @Published var scanState: ScanState = .scanning
    @Published var detectedReading = ""
    @Published var confidence: Float = 0
    @Published var allCandidates: [RecognizedReading] = []
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isSubmitting = false
    @Published var isProcessing = false
    @Published var capturedImage: UIImage?
    @Published var manualReading = ""

    private let textRecognizer = TextRecognizer()

    enum ScanState {
        case scanning
        case detected
        case confirmed
    }

    init(meter: MeterResponse) {
        self.meter = meter
        super.init()
        print("[SmartScanVM] init for meter: \(meter.name)")
    }

    func processCapture() {
        guard let image = capturedImage else { return }
        print("[SmartScanVM] processCapture called")

        isProcessing = true

        Task {
            if let cgImage = image.cgImage {
                let ciImage = CIImage(cgImage: cgImage)
                await processImageAsync(ciImage, fromCapture: true)
            }
            isProcessing = false
        }
    }

    func retryScanning() {
        detectedReading = ""
        confidence = 0
        allCandidates = []
        capturedImage = nil
        scanState = .scanning
    }

    func submitReading() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let normalizedValue = detectedReading.filter { $0.isNumber || $0 == "." }
            _ = try await APIService.shared.createReading(
                meterId: meter.id,
                rawValue: detectedReading,
                normalizedValue: normalizedValue,
                confidence: confidence,
                source: "ocr"
            )
            scanState = .confirmed
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func submitManualReading() async {
        guard !manualReading.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let normalizedValue = manualReading.filter { $0.isNumber || $0 == "." }
            _ = try await APIService.shared.createReading(
                meterId: meter.id,
                rawValue: manualReading,
                normalizedValue: normalizedValue,
                confidence: 1.0,
                source: "manual"
            )
            scanState = .confirmed
            detectedReading = manualReading
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func processImage(_ image: CIImage) {
        Task { @MainActor in
            await processImageAsync(image, fromCapture: false)
        }
    }

    func processImageAsync(_ image: CIImage, fromCapture: Bool) async {
        let results = await textRecognizer.recognizeText(in: image)
        print("[SmartScanVM] OCR found \(results.count) text regions")

        // Filter for digit sequences
        let digitReadings = results.compactMap { result -> RecognizedReading? in
            let digitsOnly = result.text.filter { $0.isNumber }
            guard digitsOnly.count >= 4 && digitsOnly.count <= 10 else { return nil }

            return RecognizedReading(
                text: result.text,
                digitsOnly: digitsOnly,
                confidence: result.confidence,
                boundingBox: result.boundingBox
            )
        }
        print("[SmartScanVM] Found \(digitReadings.count) potential readings, fromCapture: \(fromCapture)")

        if digitReadings.isEmpty {
            // If from capture button and no digits found, still show result card for manual entry
            if fromCapture {
                self.detectedReading = ""
                self.confidence = 0
                self.allCandidates = []
                self.scanState = .detected
            }
            return
        }

        // Sort by confidence and digit count matching expected
        let sorted = digitReadings.sorted { a, b in
            // Prefer readings closer to expected digit count
            let expectedDigits = meter.digitCount
            let aDiff = abs(a.digitsOnly.count - expectedDigits)
            let bDiff = abs(b.digitsOnly.count - expectedDigits)

            if aDiff != bDiff {
                return aDiff < bDiff
            }
            return a.confidence > b.confidence
        }

        if let best = sorted.first {
            print("[SmartScanVM] Best reading: \(best.digitsOnly) confidence: \(best.confidence)")

            // For auto-detection (not from capture button), require higher confidence and minimum scan time
            if !fromCapture {
                let timeSinceStart = Date().timeIntervalSince(sessionStartTime)
                let meetsTimeRequirement = timeSinceStart >= minimumScanTime
                let meetsConfidenceRequirement = best.confidence >= minimumAutoConfidence

                print("[SmartScanVM] Auto-detect check: time=\(timeSinceStart)s (need \(minimumScanTime)s), confidence=\(best.confidence) (need \(minimumAutoConfidence))")

                if !meetsTimeRequirement || !meetsConfidenceRequirement {
                    print("[SmartScanVM] Skipping auto-detect, requirements not met")
                    return
                }
            }

            self.detectedReading = best.digitsOnly
            self.confidence = best.confidence
            self.allCandidates = Array(sorted.prefix(5))
            self.scanState = .detected
            print("[SmartScanVM] Set scanState to .detected")
        }
    }
}

// MARK: - Text Recognizer

actor TextRecognizer {
    struct RecognitionResult {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    func recognizeText(in image: CIImage) async -> [RecognitionResult] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.compactMap { observation -> RecognitionResult? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognitionResult(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Supporting Types

struct RecognizedReading: Identifiable {
    let id = UUID()
    let text: String
    let digitsOnly: String
    let confidence: Float
    let boundingBox: CGRect
}

// MARK: - Top Bar (unused - kept for reference)

struct TopBar: View {
    @ObservedObject var viewModel: SmartScanViewModel
    let dismiss: DismissAction

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Meter Info
            VStack(spacing: 2) {
                Text(viewModel.meter.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.meter.meterType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            Button {
                viewModel.toggleFlash()
            } label: {
                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.title2)
                    .foregroundStyle(viewModel.isFlashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
    }
}

// MARK: - Scanning Guide

struct ScanningGuide: View {
    @ObservedObject var viewModel: SmartScanViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Guide Frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 280, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )

            // Instructions
            Text("Align meter display in frame")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            // Scanning Indicator
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Scanning...")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.5))
            .clipShape(Capsule())
        }
        .padding(.bottom, 100)
    }
}

// MARK: - Result Card

struct ResultCard: View {
    @ObservedObject var viewModel: SmartScanViewModel
    let dismiss: DismissAction

    @State private var editedReading: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(displayReading.isEmpty ? "Enter Reading" : "Reading Detected")
                    .font(.headline)

                Spacer()

                if viewModel.confidence > 0 {
                    ConfidenceBadge(confidence: viewModel.confidence)
                }
            }

            // Reading Display
            if !displayReading.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(displayReading.enumerated()), id: \.offset) { index, char in
                        Text(String(char))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .frame(width: 36, height: 48)
                            .background(meterColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(meterUnit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            } else {
                Text("No reading detected. Enter manually below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            // Edit Field
            if viewModel.scanState == .detected {
                TextField("Edit reading", text: $editedReading)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospacedDigit())
                    .onAppear {
                        editedReading = viewModel.detectedReading
                    }
                    .onChange(of: editedReading) { _, newValue in
                        viewModel.detectedReading = newValue.filter { $0.isNumber }
                    }
            }

            // Alternative Readings
            if !viewModel.allCandidates.isEmpty && viewModel.scanState == .detected {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alternatives")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.allCandidates) { candidate in
                                Button {
                                    viewModel.detectedReading = candidate.digitsOnly
                                    viewModel.confidence = candidate.confidence
                                    editedReading = candidate.digitsOnly
                                } label: {
                                    Text(candidate.digitsOnly)
                                        .font(.caption.monospacedDigit())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            candidate.digitsOnly == viewModel.detectedReading
                                                ? meterColor.opacity(0.2)
                                                : Color(.systemGray6)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Action Buttons
            if viewModel.scanState == .detected {
                HStack(spacing: 12) {
                    Button {
                        viewModel.retryScanning()
                    } label: {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.submitReading()
                        }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(meterColor)
                }
            }

            // Success State
            if viewModel.scanState == .confirmed {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("Reading Saved!")
                        .font(.headline)

                    Text("+10 XP")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .padding()
    }

    var displayReading: String {
        viewModel.detectedReading
    }

    var meterColor: Color {
        switch viewModel.meter.meterType.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        case "solar": return .green
        default: return .gray
        }
    }

    var meterUnit: String {
        switch viewModel.meter.meterType.lowercased() {
        case "electric", "solar": return "kWh"
        case "gas": return "m³"
        case "water": return "gal"
        default: return "units"
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Float

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            Text("\(Int(confidence * 100))%")
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.1))
        .clipShape(Capsule())
    }

    var confidenceColor: Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Bottom Controls

struct BottomControls: View {
    @ObservedObject var viewModel: SmartScanViewModel

    var body: some View {
        HStack(spacing: 32) {
            // Gallery Button
            Button {
                // TODO: Open photo picker
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            // Capture Button
            Button {
                viewModel.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)

                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 82, height: 82)
                }
            }

            // Manual Entry Button
            Button {
                // Show manual entry sheet
            } label: {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Camera Unavailable View

struct CameraUnavailableView: View {
    @ObservedObject var viewModel: SmartScanViewModel
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: viewModel.cameraPermissionDenied ? "camera.badge.ellipsis" : "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(viewModel.cameraPermissionDenied ? "Camera Access Required" : "Camera Not Available")
                .font(.title2.bold())

            if viewModel.cameraPermissionDenied {
                Text("Please allow camera access in Settings to scan your meter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Text("Or enter your meter reading manually below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Meter Info
            HStack(spacing: 8) {
                Image(systemName: meterIcon)
                    .foregroundStyle(meterColor)
                Text(viewModel.meter.name)
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(meterColor.opacity(0.1))
            .clipShape(Capsule())

            // Manual Entry
            VStack(spacing: 16) {
                TextField("Enter reading (e.g., 123456)", text: $viewModel.manualReading)
                    .keyboardType(.numberPad)
                    .font(.title2.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if viewModel.scanState == .confirmed {
                    // Success State
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("Reading Saved!")
                            .font(.headline)

                        Text("+10 XP")
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                    }
                    .padding()
                }

                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.submitManualReading()
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if viewModel.scanState == .confirmed {
                            Text("Done")
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Reading")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(meterColor)
                    .disabled(viewModel.manualReading.isEmpty || viewModel.isSubmitting)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10)

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    var meterIcon: String {
        switch viewModel.meter.meterType.lowercased() {
        case "electric": return "bolt.fill"
        case "gas": return "flame.fill"
        case "water": return "drop.fill"
        case "solar": return "sun.max.fill"
        default: return "gauge"
        }
    }

    var meterColor: Color {
        switch viewModel.meter.meterType.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        case "solar": return .green
        default: return .gray
        }
    }
}

#Preview {
    SmartScanView(meter: MeterResponse(
        id: UUID(),
        userId: UUID(),
        name: "Kitchen Electric",
        meterType: "electric",
        utilityProvider: nil,
        postalCode: "M5V",
        digitCount: 6,
        isActive: true,
        lastReadAt: nil,
        createdAt: Date()
    ))
}
