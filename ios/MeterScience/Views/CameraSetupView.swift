import SwiftUI
import AVFoundation

struct CameraSetupView: View {
    @StateObject private var viewModel = CameraSetupViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Steps
                ProgressSteps(currentStep: viewModel.currentStep)
                    .padding()

                // Content based on step
                Group {
                    switch viewModel.currentStep {
                    case .permission:
                        PermissionStep(viewModel: viewModel)
                    case .preview:
                        PreviewStep(viewModel: viewModel)
                    case .test:
                        TestStep(viewModel: viewModel)
                    case .complete:
                        CompleteStep(viewModel: viewModel, dismiss: dismiss)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Camera Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.stopCamera()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }
}

// MARK: - View Model

@MainActor
class CameraSetupViewModel: NSObject, ObservableObject {
    enum SetupStep {
        case permission
        case preview
        case test
        case complete
    }

    @Published var currentStep: SetupStep = .permission
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var cameraError: String?
    @Published var isPreviewRunning = false
    @Published var capturedImage: UIImage?
    @Published var testPassed = false

    let session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?

    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if permissionStatus == .authorized {
            currentStep = .preview
            startCamera()
        }
    }

    func requestPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        permissionStatus = granted ? .authorized : .denied

        if granted {
            currentStep = .preview
            startCamera()
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func startCamera() {
        guard permissionStatus == .authorized else { return }

        Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    await MainActor.run {
                        self.cameraError = "No camera found on this device"
                    }
                    return
                }

                let input = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let photoOutput = AVCapturePhotoOutput()
                if self.session.canAddOutput(photoOutput) {
                    self.session.addOutput(photoOutput)
                    await MainActor.run {
                        self.photoOutput = photoOutput
                    }
                }

                self.session.commitConfiguration()
                self.session.startRunning()

                await MainActor.run {
                    self.isPreviewRunning = true
                    self.cameraError = nil
                }
            } catch {
                await MainActor.run {
                    self.cameraError = "Camera error: \(error.localizedDescription)"
                }
            }
        }
    }

    func stopCamera() {
        session.stopRunning()
        isPreviewRunning = false
    }

    func proceedToTest() {
        currentStep = .test
    }

    func captureTestPhoto() {
        guard let photoOutput = photoOutput else {
            cameraError = "Photo capture not available"
            return
        }

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func completeSetup() {
        UserDefaults.standard.set(true, forKey: "cameraSetupComplete")
        currentStep = .complete
    }

    func retrySetup() {
        capturedImage = nil
        testPassed = false
        cameraError = nil
        currentStep = .preview
        startCamera()
    }
}

extension CameraSetupViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.cameraError = "Capture failed: \(error.localizedDescription)"
                self.testPassed = false
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                self.cameraError = "Failed to process captured image"
                self.testPassed = false
                return
            }

            self.capturedImage = image
            self.testPassed = true
            self.cameraError = nil
        }
    }
}

// MARK: - Progress Steps

struct ProgressSteps: View {
    let currentStep: CameraSetupViewModel.SetupStep

    var body: some View {
        HStack(spacing: 0) {
            StepIndicator(number: 1, title: "Permission", isActive: currentStep == .permission, isComplete: stepIndex > 0)
            StepConnector(isComplete: stepIndex > 0)
            StepIndicator(number: 2, title: "Preview", isActive: currentStep == .preview, isComplete: stepIndex > 1)
            StepConnector(isComplete: stepIndex > 1)
            StepIndicator(number: 3, title: "Test", isActive: currentStep == .test, isComplete: stepIndex > 2)
            StepConnector(isComplete: stepIndex > 2)
            StepIndicator(number: 4, title: "Done", isActive: currentStep == .complete, isComplete: stepIndex > 3)
        }
    }

    var stepIndex: Int {
        switch currentStep {
        case .permission: return 0
        case .preview: return 1
        case .test: return 2
        case .complete: return 3
        }
    }
}

struct StepIndicator: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isComplete ? .green : (isActive ? .blue : Color(.systemGray4)))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }
}

struct StepConnector: View {
    let isComplete: Bool

    var body: some View {
        Rectangle()
            .fill(isComplete ? .green : Color(.systemGray4))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
    }
}

// MARK: - Permission Step

struct PermissionStep: View {
    @ObservedObject var viewModel: CameraSetupViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Camera Access Required")
                .font(.title2.bold())

            Text("MeterScience needs camera access to scan your utility meters using OCR.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if viewModel.permissionStatus == .denied {
                VStack(spacing: 12) {
                    Text("Camera access was denied")
                        .foregroundStyle(.red)

                    Button {
                        viewModel.openSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 48)
                }
            } else {
                Button {
                    Task {
                        await viewModel.requestPermission()
                    }
                } label: {
                    Text("Allow Camera Access")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 48)
            }

            Spacer()
        }
    }
}

// MARK: - Preview Step

struct PreviewStep: View {
    @ObservedObject var viewModel: CameraSetupViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Camera Preview")
                .font(.headline)

            Text("Verify the camera is working properly")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Camera Preview
            ZStack {
                if viewModel.isPreviewRunning {
                    CameraPreviewView(session: viewModel.session)
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(height: 350)
                        .overlay {
                            if let error = viewModel.cameraError {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.title)
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                            } else {
                                ProgressView("Starting camera...")
                            }
                        }
                }
            }
            .padding(.horizontal)

            if viewModel.isPreviewRunning {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Camera is working!")
                    }
                    .font(.subheadline)

                    Button {
                        viewModel.proceedToTest()
                    } label: {
                        Text("Continue to Test")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 48)
                }
            }

            Spacer()
        }
        .padding(.top)
    }
}

// MARK: - Test Step

struct TestStep: View {
    @ObservedObject var viewModel: CameraSetupViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Test Photo Capture")
                .font(.headline)

            Text("Take a test photo to verify capture works")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Preview or Captured Image
            ZStack {
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    CameraPreviewView(session: viewModel.session)
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)

            if let error = viewModel.cameraError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.testPassed {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Photo captured successfully!")
                    }
                    .font(.subheadline)

                    Button {
                        viewModel.completeSetup()
                    } label: {
                        Text("Complete Setup")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 48)

                    Button("Retake Photo") {
                        viewModel.capturedImage = nil
                        viewModel.testPassed = false
                    }
                    .font(.subheadline)
                }
            } else {
                Button {
                    viewModel.captureTestPhoto()
                } label: {
                    Label("Capture Test Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 48)
            }

            Spacer()
        }
        .padding(.top)
    }
}

// MARK: - Complete Step

struct CompleteStep: View {
    @ObservedObject var viewModel: CameraSetupViewModel
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Camera Setup Complete!")
                .font(.title2.bold())

            Text("Your camera is configured and ready to scan meter readings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Preview

#Preview {
    CameraSetupView()
}
