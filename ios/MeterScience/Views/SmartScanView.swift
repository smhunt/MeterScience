import SwiftUI
import AVFoundation
import Vision

struct SmartScanView: View {
    @StateObject private var viewModel: SmartScanViewModel
    @Environment(\.dismiss) private var dismiss

    init(meter: MeterResponse) {
        _viewModel = StateObject(wrappedValue: SmartScanViewModel(meter: meter))
    }

    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Top Bar
                TopBar(viewModel: viewModel, dismiss: dismiss)

                Spacer()

                // Scanning Guide
                if viewModel.scanState == .scanning {
                    ScanningGuide(viewModel: viewModel)
                }

                // Result Card
                if viewModel.scanState == .detected || viewModel.scanState == .confirmed {
                    ResultCard(viewModel: viewModel, dismiss: dismiss)
                }

                // Bottom Controls
                if viewModel.scanState == .scanning {
                    BottomControls(viewModel: viewModel)
                }
            }

            // Loading Overlay
            if viewModel.isSubmitting {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

// MARK: - View Model

@MainActor
class SmartScanViewModel: NSObject, ObservableObject {
    let meter: MeterResponse
    let session = AVCaptureSession()

    @Published var scanState: ScanState = .scanning
    @Published var detectedReading = ""
    @Published var confidence: Float = 0
    @Published var allCandidates: [RecognizedReading] = []
    @Published var isFlashOn = false
    @Published var errorMessage: String?
    @Published var isSubmitting = false
    @Published var capturedImage: UIImage?

    private var captureOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let textRecognizer = TextRecognizer()

    private var processingFrame = false
    private var lastProcessedTime = Date()

    enum ScanState {
        case scanning
        case detected
        case confirmed
    }

    init(meter: MeterResponse) {
        self.meter = meter
        super.init()
    }

    func startSession() {
        Task {
            await setupCamera()
        }
    }

    func stopSession() {
        session.stopRunning()
    }

    private func setupCamera() async {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "Camera not available"
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            session.beginConfiguration()

            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Photo output for capturing
            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.captureOutput = photoOutput
            }

            // Video output for live OCR
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }

            session.commitConfiguration()

            Task {
                session.startRunning()
            }
        } catch {
            errorMessage = "Camera setup failed: \(error.localizedDescription)"
        }
    }

    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .off : .on
            isFlashOn.toggle()
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle failed: \(error)")
        }
    }

    func capturePhoto() {
        guard let captureOutput = captureOutput else { return }

        let settings = AVCapturePhotoSettings()
        if let photoOutputConnection = captureOutput.connection(with: .video) {
            photoOutputConnection.videoOrientation = .portrait
        }

        captureOutput.capturePhoto(with: settings, delegate: self)
    }

    func confirmReading() {
        scanState = .confirmed
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func processImage(_ image: CIImage) {
        Task { @MainActor in
            let results = await textRecognizer.recognizeText(in: image)

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

            guard !digitReadings.isEmpty else { return }

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
                self.detectedReading = best.digitsOnly
                self.confidence = best.confidence
                self.allCandidates = Array(sorted.prefix(5))
                self.scanState = .detected
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension SmartScanViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let now = Date()

        Task { @MainActor in
            // Throttle processing
            guard now.timeIntervalSince(lastProcessedTime) > 0.5 else { return }
            guard scanState == .scanning else { return }
            lastProcessedTime = now
            processImage(ciImage)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension SmartScanViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        Task { @MainActor in
            self.capturedImage = image
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

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Top Bar

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
                Text("Reading Detected")
                    .font(.headline)

                Spacer()

                ConfidenceBadge(confidence: viewModel.confidence)
            }

            // Reading Display
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
