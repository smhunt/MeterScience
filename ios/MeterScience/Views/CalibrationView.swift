import SwiftUI

struct CalibrationView: View {
    @StateObject private var viewModel = CalibrationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Indicator
                ProgressBar(currentStep: viewModel.currentStep, totalSteps: 4)
                    .padding()

                // Content
                TabView(selection: $viewModel.currentStep) {
                    MeterTypeStep(viewModel: viewModel)
                        .tag(1)

                    MeterDetailsStep(viewModel: viewModel)
                        .tag(2)

                    SampleReadingStep(viewModel: viewModel)
                        .tag(3)

                    ConfirmationStep(viewModel: viewModel)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)

                // Navigation Buttons
                NavigationButtons(viewModel: viewModel, dismiss: dismiss)
                    .padding()
            }
            .navigationTitle("Add Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - View Model

@MainActor
class CalibrationViewModel: ObservableObject {
    @Published var currentStep = 1
    @Published var meterType: MeterType = .electric
    @Published var meterName = ""
    @Published var postalCode = ""
    @Published var digitCount = 6
    @Published var hasDecimalPoint = false
    @Published var sampleReading = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdMeter: MeterResponse?

    var canProceed: Bool {
        switch currentStep {
        case 1: return true
        case 2: return !meterName.isEmpty
        case 3: return !sampleReading.isEmpty && sampleReading.count >= 4
        case 4: return true
        default: return false
        }
    }

    var isLastStep: Bool { currentStep == 4 }

    func nextStep() {
        if currentStep < 4 {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }

    func createMeter() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let meter = try await APIService.shared.createMeter(
                name: meterName,
                meterType: meterType.rawValue,
                postalCode: postalCode.isEmpty ? nil : postalCode
            )
            createdMeter = meter

            // Create first reading if sample provided
            if !sampleReading.isEmpty {
                let normalizedValue = normalizeReading(sampleReading)
                _ = try await APIService.shared.createReading(
                    meterId: meter.id,
                    rawValue: sampleReading,
                    normalizedValue: normalizedValue,
                    confidence: 1.0,
                    source: "calibration"
                )
            }

            return true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func normalizeReading(_ reading: String) -> String {
        let digitsOnly = reading.filter { $0.isNumber || $0 == "." }
        return digitsOnly
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.blue : Color(.systemGray4))
                    .frame(width: 10, height: 10)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? Color.blue : Color(.systemGray4))
                        .frame(height: 2)
                }
            }
        }
    }
}

// MARK: - Step 1: Meter Type

struct MeterTypeStep: View {
    @ObservedObject var viewModel: CalibrationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gauge.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("What type of meter?")
                        .font(.title2.bold())

                    Text("Select the utility type you want to track")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Meter Type Options
                VStack(spacing: 12) {
                    ForEach(MeterType.allCases, id: \.self) { type in
                        MeterTypeCard(
                            type: type,
                            isSelected: viewModel.meterType == type,
                            onSelect: { viewModel.meterType = type }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }
}

struct MeterTypeCard: View {
    let type: MeterType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(type.color)
                    .frame(width: 44, height: 44)
                    .background(type.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue.capitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Measured in \(type.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Meter Details

struct MeterDetailsStep: View {
    @ObservedObject var viewModel: CalibrationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: viewModel.meterType.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(viewModel.meterType.color)

                    Text("Meter Details")
                        .font(.title2.bold())

                    Text("Give your meter a name and location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Form Fields
                VStack(spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meter Name")
                            .font(.subheadline.weight(.medium))

                        TextField("e.g., Kitchen Electric, Main Gas", text: $viewModel.meterName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Postal Code
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Postal Code")
                                .font(.subheadline.weight(.medium))
                            Text("(Optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TextField("e.g., M5V 1K4", text: $viewModel.postalCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)

                        Text("Used for neighborhood comparisons. Only the first 3 characters are shared.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Divider()

                    // Digit Count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Digits")
                            .font(.subheadline.weight(.medium))

                        Stepper(value: $viewModel.digitCount, in: viewModel.meterType.expectedDigitRange) {
                            HStack {
                                Text("\(viewModel.digitCount) digits")
                                    .font(.body.monospacedDigit())

                                Spacer()

                                // Preview
                                HStack(spacing: 2) {
                                    ForEach(0..<viewModel.digitCount, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 16, height: 24)
                                    }
                                }
                            }
                        }
                    }

                    // Decimal Point
                    Toggle(isOn: $viewModel.hasDecimalPoint) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Has Decimal Point")
                                .font(.subheadline.weight(.medium))
                            Text("Does your meter show partial units?")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Step 3: Sample Reading

struct SampleReadingStep: View {
    @ObservedObject var viewModel: CalibrationViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("First Reading")
                        .font(.title2.bold())

                    Text("Enter your current meter reading to calibrate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Reading Input
                VStack(spacing: 16) {
                    // Visual Input
                    HStack(spacing: 4) {
                        ForEach(0..<viewModel.digitCount, id: \.self) { index in
                            let char = getCharacter(at: index)
                            DigitBox(character: char, meterType: viewModel.meterType)

                            if viewModel.hasDecimalPoint && index == viewModel.digitCount - 2 {
                                Text(".")
                                    .font(.title.bold())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Hidden Text Field
                    TextField("Enter reading", text: $viewModel.sampleReading)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .onChange(of: viewModel.sampleReading) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > viewModel.digitCount {
                                viewModel.sampleReading = String(filtered.prefix(viewModel.digitCount))
                            } else {
                                viewModel.sampleReading = filtered
                            }
                        }

                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(
                            icon: "info.circle",
                            text: "Read all \(viewModel.digitCount) digits from left to right"
                        )
                        InstructionRow(
                            icon: "eye",
                            text: "Ignore any red or highlighted numbers"
                        )
                        InstructionRow(
                            icon: "arrow.up.circle",
                            text: "Round down if a digit is between numbers"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .onTapGesture {
            isInputFocused = true
        }
    }

    func getCharacter(at index: Int) -> String {
        let reading = viewModel.sampleReading
        if index < reading.count {
            let stringIndex = reading.index(reading.startIndex, offsetBy: index)
            return String(reading[stringIndex])
        }
        return ""
    }
}

struct DigitBox: View {
    let character: String
    let meterType: MeterType

    var body: some View {
        Text(character.isEmpty ? "_" : character)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .frame(width: 36, height: 48)
            .background(character.isEmpty ? Color(.systemGray5) : meterType.color.opacity(0.1))
            .foregroundStyle(character.isEmpty ? .secondary : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(character.isEmpty ? Color.clear : meterType.color, lineWidth: 2)
            )
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step 4: Confirmation

struct ConfirmationStep: View {
    @ObservedObject var viewModel: CalibrationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if viewModel.createdMeter != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)

                        Text("Meter Created!")
                            .font(.title2.bold())

                        Text("Your meter is ready to track readings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)

                        Text("Ready to Go!")
                            .font(.title2.bold())

                        Text("Review your meter configuration")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                // Summary Card
                VStack(spacing: 16) {
                    SummaryRow(
                        icon: viewModel.meterType.icon,
                        iconColor: viewModel.meterType.color,
                        label: "Type",
                        value: viewModel.meterType.rawValue.capitalized
                    )

                    Divider()

                    SummaryRow(
                        icon: "textformat",
                        iconColor: .blue,
                        label: "Name",
                        value: viewModel.meterName
                    )

                    if !viewModel.postalCode.isEmpty {
                        Divider()

                        SummaryRow(
                            icon: "mappin.circle",
                            iconColor: .orange,
                            label: "Postal Code",
                            value: viewModel.postalCode
                        )
                    }

                    Divider()

                    SummaryRow(
                        icon: "number",
                        iconColor: .purple,
                        label: "Digits",
                        value: "\(viewModel.digitCount)\(viewModel.hasDecimalPoint ? " with decimal" : "")"
                    )

                    Divider()

                    SummaryRow(
                        icon: "camera.viewfinder",
                        iconColor: .green,
                        label: "First Reading",
                        value: formatReading()
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)
                .padding(.horizontal)

                // Tips
                if viewModel.createdMeter == nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Accurate Tracking")
                            .font(.headline)

                        TipRow(
                            icon: "clock",
                            text: "Read your meter at the same time each day"
                        )
                        TipRow(
                            icon: "sun.max",
                            text: "Good lighting helps OCR accuracy"
                        )
                        TipRow(
                            icon: "checkmark.circle",
                            text: "Verify readings for bonus XP"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
    }

    func formatReading() -> String {
        var reading = viewModel.sampleReading
        if viewModel.hasDecimalPoint && reading.count > 1 {
            let insertIndex = reading.index(reading.endIndex, offsetBy: -1)
            reading.insert(".", at: insertIndex)
        }
        return "\(reading) \(viewModel.meterType.unit)"
    }
}

struct SummaryRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Navigation Buttons

struct NavigationButtons: View {
    @ObservedObject var viewModel: CalibrationViewModel
    let dismiss: DismissAction

    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            if viewModel.currentStep > 1 && viewModel.createdMeter == nil {
                Button {
                    viewModel.previousStep()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // Next/Create/Done Button
            Button {
                if viewModel.createdMeter != nil {
                    dismiss()
                } else if viewModel.isLastStep {
                    Task {
                        let success = await viewModel.createMeter()
                        if success {
                            // Stay on step 4 to show success
                        }
                    }
                } else {
                    viewModel.nextStep()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonTitle)
                        if viewModel.createdMeter == nil && !viewModel.isLastStep {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceed || viewModel.isLoading)
        }
    }

    var buttonTitle: String {
        if viewModel.createdMeter != nil {
            return "Done"
        } else if viewModel.isLastStep {
            return "Create Meter"
        } else {
            return "Continue"
        }
    }
}

#Preview {
    CalibrationView()
}
