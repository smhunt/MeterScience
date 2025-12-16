import SwiftUI
import AVFoundation
import Vision
import CoreLocation

struct SmartScanView: View {
    let meter: MeterResponse
    @StateObject private var viewModel: SmartScanViewModel
    @StateObject private var locationManager = LocationManager.shared
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
            ImagePicker(
                image: $viewModel.capturedImage,
                onCapture: {
                    // Photo was taken - run OCR
                    viewModel.processCapture()
                },
                meterName: meter.name,
                digitCount: meter.digitCount
            )
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            // Request location permission when scanner opens
            locationManager.requestPermission()

            // Attempt to get current location
            Task {
                if let location = await locationManager.getCurrentLocation() {
                    viewModel.capturedLocation = location
                    print("[SmartScanView] Location captured: \(location.latitude), \(location.longitude)")
                }
            }
        }
    }
}

// MARK: - Camera Guide Overlay

class CameraGuideOverlay: UIView {
    private let digitCount: Int
    private let guideView = UIView()
    private let hintLabel = UILabel()
    private let digitLabel = UILabel()
    private var guideLayer: CAShapeLayer?

    init(digitCount: Int) {
        self.digitCount = digitCount
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        self.digitCount = 6
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear

        // Guide container
        guideView.backgroundColor = .clear
        guideView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(guideView)

        // Hint label
        hintLabel.text = "Align meter reading in box"
        hintLabel.textColor = .white
        hintLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        hintLabel.textAlignment = .center
        hintLabel.layer.shadowColor = UIColor.black.cgColor
        hintLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        hintLabel.layer.shadowOpacity = 0.8
        hintLabel.layer.shadowRadius = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        // Digit label
        digitLabel.text = "\(digitCount) digits"
        digitLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        digitLabel.font = .systemFont(ofSize: 13)
        digitLabel.textAlignment = .center
        digitLabel.layer.shadowColor = UIColor.black.cgColor
        digitLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        digitLabel.layer.shadowOpacity = 0.8
        digitLabel.layer.shadowRadius = 2
        digitLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(digitLabel)

        // Constraints
        NSLayoutConstraint.activate([
            // Guide view - centered, fixed size
            guideView.centerXAnchor.constraint(equalTo: centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -80),
            guideView.widthAnchor.constraint(equalToConstant: 260),
            guideView.heightAnchor.constraint(equalToConstant: 70),

            // Hint label - below guide
            hintLabel.topAnchor.constraint(equalTo: guideView.bottomAnchor, constant: 16),
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            // Digit label - below hint
            digitLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            digitLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGuideLayer()
    }

    private func updateGuideLayer() {
        guideLayer?.removeFromSuperlayer()

        let layer = CAShapeLayer()
        let rect = guideView.bounds
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        layer.path = path.cgPath
        layer.strokeColor = UIColor.white.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2
        layer.lineDashPattern = [8, 4]
        guideView.layer.addSublayer(layer)
        guideLayer = layer

        // Add corner brackets
        addCornerBrackets()
    }

    private func addCornerBrackets() {
        // Remove old brackets
        guideView.subviews.forEach { $0.removeFromSuperview() }

        let rect = guideView.bounds
        let bracketLength: CGFloat = 25
        let bracketWidth: CGFloat = 3

        let corners: [(CGFloat, CGFloat, Bool, Bool)] = [
            (0, 0, true, true),
            (rect.width, 0, false, true),
            (0, rect.height, true, false),
            (rect.width, rect.height, false, false)
        ]

        for (x, y, isLeft, isTop) in corners {
            let hBar = UIView()
            hBar.backgroundColor = .white
            hBar.frame = CGRect(
                x: isLeft ? x : x - bracketLength,
                y: y - bracketWidth / 2,
                width: bracketLength,
                height: bracketWidth
            )
            guideView.addSubview(hBar)

            let vBar = UIView()
            vBar.backgroundColor = .white
            vBar.frame = CGRect(
                x: x - bracketWidth / 2,
                y: isTop ? y : y - bracketLength,
                width: bracketWidth,
                height: bracketLength
            )
            guideView.addSubview(vBar)
        }
    }
}

// MARK: - Image Picker (System Camera)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    var onCapture: () -> Void
    var meterName: String = "Meter"
    var digitCount: Int = 6

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator

        // Add custom overlay with guide markings
        let overlayView = createOverlayView(for: picker)
        picker.cameraOverlayView = overlayView

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func createOverlayView(for picker: UIImagePickerController) -> UIView {
        let overlay = CameraGuideOverlay(digitCount: digitCount)
        overlay.isUserInteractionEnabled = false
        return overlay
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

    // Historical readings for validation
    @Published var historicalReadings: [ReadingResponse] = []
    @Published var lastReadingValue: Double?

    // GPS location
    var capturedLocation: CLLocationCoordinate2D?

    private let textRecognizer = TextRecognizer()
    private let imageProcessor = ImageProcessor()

    enum ScanState {
        case scanning
        case detected
        case confirmed
    }

    init(meter: MeterResponse) {
        self.meter = meter
        super.init()
        print("[SmartScanVM] init for meter: \(meter.name)")

        // Load historical readings on init
        Task {
            await loadHistoricalReadings()
        }
    }

    func loadHistoricalReadings() async {
        do {
            let response = try await APIService.shared.getReadings(meterId: meter.id)
            historicalReadings = response.readings

            // Get most recent reading value for comparison
            if let lastReading = response.readings.first,
               let numericValue = lastReading.numericValue {
                lastReadingValue = numericValue
                print("[SmartScanVM] Last reading: \(numericValue)")
            }
        } catch {
            print("[SmartScanVM] Failed to load history: \(error)")
        }
    }

    func processCapture() {
        guard let image = capturedImage else { return }
        print("[SmartScanVM] processCapture called")

        isProcessing = true

        Task {
            // Preprocess image before OCR
            if let preprocessedImage = await imageProcessor.preprocessForOCR(image) {
                await processImageAsync(preprocessedImage, fromCapture: true)
            } else {
                // Fallback to original image if preprocessing fails
                print("[SmartScanVM] Preprocessing failed, using original image")
                if let cgImage = image.cgImage {
                    let ciImage = CIImage(cgImage: cgImage)
                    await processImageAsync(ciImage, fromCapture: true)
                }
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
                source: "ocr",
                latitude: capturedLocation?.latitude,
                longitude: capturedLocation?.longitude
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
                source: "manual",
                latitude: capturedLocation?.latitude,
                longitude: capturedLocation?.longitude
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

        let expectedDigits = meter.digitCount

        // STRICT FILTER: Only accept readings matching exact digit count
        let digitReadings = results.compactMap { result -> RecognizedReading? in
            let digitsOnly = result.text.filter { $0.isNumber }

            // STRICT: Must match exact digit count configured for meter
            guard digitsOnly.count == expectedDigits else {
                print("[SmartScanVM] Rejected '\(digitsOnly)' - wrong digit count (\(digitsOnly.count) != \(expectedDigits))")
                return nil
            }

            return RecognizedReading(
                text: result.text,
                digitsOnly: digitsOnly,
                confidence: result.confidence,
                boundingBox: result.boundingBox
            )
        }
        print("[SmartScanVM] Found \(digitReadings.count) readings with exact \(expectedDigits) digits")

        // Filter by historical plausibility if we have past readings
        var plausibleReadings = digitReadings
        if let lastValue = lastReadingValue, lastValue > 0 {
            plausibleReadings = digitReadings.filter { reading in
                guard let numericValue = Double(reading.digitsOnly) else { return true }

                // Meters only go up (or reset). Reject if much lower than last reading.
                // Allow some tolerance for misreads (5% below last reading)
                let minAcceptable = lastValue * 0.95

                // Reject if more than 50% higher than last reading (unusual spike)
                // This is a loose check - meters can have variable usage
                let maxAcceptable = lastValue * 1.5

                let isPlausible = numericValue >= minAcceptable && numericValue <= maxAcceptable

                if !isPlausible {
                    print("[SmartScanVM] Rejected '\(reading.digitsOnly)' - implausible vs last (\(lastValue)): value=\(numericValue)")
                }
                return isPlausible
            }
            print("[SmartScanVM] After plausibility filter: \(plausibleReadings.count) readings")
        }

        if plausibleReadings.isEmpty && !digitReadings.isEmpty {
            // If we filtered everything out, show all digit-correct readings
            // but let user know they may be suspicious
            print("[SmartScanVM] All readings filtered as implausible - showing all \(expectedDigits)-digit candidates")
            plausibleReadings = digitReadings
        }

        if plausibleReadings.isEmpty {
            // If from capture and no digits found, still show result card for manual entry
            if fromCapture {
                self.detectedReading = ""
                self.confidence = 0
                self.allCandidates = []
                self.scanState = .detected
                print("[SmartScanVM] No \(expectedDigits)-digit readings found - prompting manual entry")
            }
            return
        }

        // Sort by confidence (all are now correct digit count)
        let sorted = plausibleReadings.sorted { $0.confidence > $1.confidence }

        if let best = sorted.first {
            print("[SmartScanVM] Best reading: \(best.digitsOnly) confidence: \(best.confidence)")
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
