import SwiftUI

extension Notification.Name {
    static let readingsDidChange = Notification.Name("readingsDidChange")
}

struct ContentView: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            if auth.isAuthenticated {
                await auth.refreshUser()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingAddMeter = false
    @State private var selectedMeter: MeterResponse?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Meters Tab
            MetersListView(
                onScan: { meter in
                    selectedMeter = meter
                },
                onAddMeter: {
                    showingAddMeter = true
                }
            )
            .tabItem {
                Label("Meters", systemImage: "gauge")
            }
            .tag(0)

            // Verify Tab
            VerifyView()
                .tabItem {
                    Label("Verify", systemImage: "checkmark.seal")
                }
                .tag(1)

            // Campaigns Tab
            CampaignsView()
                .tabItem {
                    Label("Campaigns", systemImage: "flag")
                }
                .tag(2)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(3)
        }
        .sheet(isPresented: $showingAddMeter) {
            CalibrationView()
        }
        .fullScreenCover(item: $selectedMeter) { meter in
            SmartScanView(meter: meter)
        }
        .onChange(of: selectedMeter) { oldValue, newValue in
            // When SmartScanView is dismissed (selectedMeter becomes nil), post notification to refresh
            if oldValue != nil && newValue == nil {
                NotificationCenter.default.post(name: .readingsDidChange, object: nil)
            }
        }
    }
}

// MARK: - Meters List View

struct MetersListView: View {
    let onScan: (MeterResponse) -> Void
    let onAddMeter: () -> Void

    @StateObject private var viewModel = MetersListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.meters.isEmpty {
                    ProgressView()
                } else if viewModel.meters.isEmpty {
                    EmptyMetersView(onAddMeter: onAddMeter)
                } else {
                    List {
                        ForEach(viewModel.meters) { meter in
                            NavigationLink(value: meter) {
                                MeterRow(meter: meter)
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                await viewModel.deleteMeter(at: indexSet)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadMeters()
                    }
                }
            }
            .navigationTitle("My Meters")
            .navigationDestination(for: MeterResponse.self) { meter in
                MeterDetailView(meter: meter) {
                    onScan(meter)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onAddMeter()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.loadMeters()
            }
        }
    }
}

@MainActor
class MetersListViewModel: ObservableObject {
    @Published var meters: [MeterResponse] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadMeters() async {
        isLoading = true
        do {
            meters = try await APIService.shared.getMeters()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteMeter(at indexSet: IndexSet) async {
        for index in indexSet {
            let meter = meters[index]
            do {
                try await APIService.shared.deleteMeter(id: meter.id)
                meters.remove(at: index)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct MeterRow: View {
    let meter: MeterResponse

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: meterIcon)
                .font(.title2)
                .foregroundStyle(meterColor)
                .frame(width: 44, height: 44)
                .background(meterColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(meter.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(meter.meterType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastRead = meter.lastReadAt {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(lastRead, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    var meterIcon: String {
        switch meter.meterType.lowercased() {
        case "electric": return "bolt.fill"
        case "gas": return "flame.fill"
        case "water": return "drop.fill"
        case "solar": return "sun.max.fill"
        default: return "gauge"
        }
    }

    var meterColor: Color {
        switch meter.meterType.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        case "solar": return .green
        default: return .gray
        }
    }
}

// MARK: - Meter Detail View

struct MeterDetailView: View {
    let meter: MeterResponse
    let onScan: () -> Void

    @StateObject private var viewModel = MeterDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Meter Header Card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: meterIcon)
                            .font(.system(size: 36))
                            .foregroundStyle(meterColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.meterName.isEmpty ? meter.name : viewModel.meterName)
                                .font(.title2.bold())
                            Text(meter.meterType.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(meterColor)
                        }
                    }

                    // Quick stats
                    HStack(spacing: 20) {
                        StatBox(
                            value: "\(viewModel.readings.count)",
                            label: "Readings"
                        )

                        if let latest = viewModel.readings.first {
                            StatBox(
                                value: latest.normalizedValue,
                                label: "Latest"
                            )
                        }

                        if let postal = meter.postalCode {
                            StatBox(
                                value: postal,
                                label: "Location"
                            )
                        }
                    }

                    // Take Reading Button
                    Button {
                        onScan()
                    } label: {
                        Label("Take New Reading", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(meterColor)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)

                // Readings History
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Reading History")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.readings.count) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if viewModel.readings.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No readings yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Take your first reading to start tracking")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.readings) { reading in
                                ReadingRow(reading: reading, meterColor: meterColor)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Meter Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadReadings(meterId: meter.id)
        }
        .refreshable {
            await viewModel.loadReadings(meterId: meter.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingsDidChange)) { _ in
            Task {
                await viewModel.loadReadings(meterId: meter.id)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMeterView(meter: meter, viewModel: viewModel)
        }
        .onAppear {
            viewModel.meterName = meter.name
            viewModel.meterType = meter.meterType
            viewModel.digitCount = meter.digitCount
            viewModel.postalCode = meter.postalCode ?? ""
        }
    }

    var meterIcon: String {
        switch meter.meterType.lowercased() {
        case "electric": return "bolt.fill"
        case "gas": return "flame.fill"
        case "water": return "drop.fill"
        case "solar": return "sun.max.fill"
        default: return "gauge"
        }
    }

    var meterColor: Color {
        switch meter.meterType.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        case "solar": return .green
        default: return .gray
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ReadingRow: View {
    let reading: ReadingResponse
    let meterColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Reading value
            Text(reading.normalizedValue)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(meterColor)

            Spacer()

            // Metadata
            VStack(alignment: .trailing, spacing: 2) {
                Text(reading.createdAt, style: .date)
                    .font(.caption)
                Text(reading.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var statusColor: Color {
        switch reading.verificationStatus?.lowercased() {
        case "verified": return .green
        case "rejected": return .red
        case "pending": return .orange
        default: return .gray
        }
    }
}

@MainActor
class MeterDetailViewModel: ObservableObject {
    @Published var readings: [ReadingResponse] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var meterName = ""
    @Published var meterType = "electric"
    @Published var digitCount = 6
    @Published var postalCode = ""
    @Published var isSaving = false

    func loadReadings(meterId: UUID) async {
        isLoading = true
        do {
            let response = try await APIService.shared.getReadings(meterId: meterId)
            readings = response.readings
        } catch {
            self.error = error.localizedDescription
            print("Failed to load readings: \(error)")
        }
        isLoading = false
    }

    func updateMeter(meterId: UUID) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await APIService.shared.updateMeter(
                id: meterId,
                name: meterName,
                meterType: meterType,
                digitCount: digitCount,
                postalCode: postalCode.isEmpty ? nil : postalCode
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

// MARK: - Edit Meter View

struct EditMeterView: View {
    let meter: MeterResponse
    @ObservedObject var viewModel: MeterDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let meterTypes = ["electric", "gas", "water", "solar", "other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Meter Details") {
                    TextField("Meter Name", text: $viewModel.meterName)

                    Picker("Type", selection: $viewModel.meterType) {
                        ForEach(meterTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }

                    Stepper("Digits: \(viewModel.digitCount)", value: $viewModel.digitCount, in: 4...8)
                }

                Section("Location") {
                    TextField("Postal Code (A1A 1A1)", text: $viewModel.postalCode)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: viewModel.postalCode) { _, newValue in
                            viewModel.postalCode = formatPostalCode(newValue)
                        }
                }

                Section {
                    Button {
                        Task {
                            if await viewModel.updateMeter(meterId: meter.id) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.meterName.isEmpty || viewModel.isSaving)
                }
            }
            .navigationTitle("Edit Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatPostalCode(_ input: String) -> String {
        let clean = input.replacingOccurrences(of: " ", with: "").uppercased()
        let filtered = clean.filter { $0.isLetter || $0.isNumber }
        let limited = String(filtered.prefix(6))

        if limited.count > 3 {
            let index = limited.index(limited.startIndex, offsetBy: 3)
            return String(limited[..<index]) + " " + String(limited[index...])
        }
        return limited
    }
}

struct EmptyMetersView: View {
    let onAddMeter: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gauge.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("No Meters Yet")
                    .font(.title2.bold())

                Text("Add your first meter to start tracking your utility usage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                onAddMeter()
            } label: {
                Label("Add Meter", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Verify View

struct VerifyView: View {
    @StateObject private var viewModel = VerifyViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.queue.isEmpty {
                    ProgressView()
                } else if viewModel.queue.isEmpty {
                    EmptyVerifyView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.queue) { reading in
                                VerificationCard(
                                    reading: reading,
                                    onVote: { vote, suggested in
                                        Task {
                                            await viewModel.vote(
                                                readingId: reading.id,
                                                vote: vote,
                                                suggestedValue: suggested
                                            )
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadQueue()
                    }
                }
            }
            .navigationTitle("Verify")
            .task {
                await viewModel.loadQueue()
            }
        }
    }
}

@MainActor
class VerifyViewModel: ObservableObject {
    @Published var queue: [VerificationReadingResponse] = []
    @Published var isLoading = false

    func loadQueue() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getVerificationQueue()
            queue = response.readings
        } catch {
            print("Failed to load queue: \(error)")
        }
        isLoading = false
    }

    func vote(readingId: UUID, vote: String, suggestedValue: String?) async {
        do {
            _ = try await APIService.shared.voteOnReading(
                readingId: readingId,
                vote: vote,
                suggestedValue: suggestedValue
            )
            queue.removeAll { $0.id == readingId }
        } catch {
            print("Vote failed: \(error)")
        }
    }
}

struct VerificationCard: View {
    let reading: VerificationReadingResponse
    let onVote: (String, String?) -> Void

    @State private var suggestedValue = ""

    var body: some View {
        VStack(spacing: 16) {
            // Meter Type Badge
            HStack {
                Image(systemName: meterIcon)
                    .foregroundStyle(meterColor)
                Text(reading.meterType.capitalized)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(Int(reading.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Reading Display
            Text(reading.normalizedValue)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Correction Field
            HStack {
                TextField("Correct value (if different)", text: $suggestedValue)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }

            // Vote Buttons
            HStack(spacing: 12) {
                Button {
                    onVote("incorrect", suggestedValue.isEmpty ? nil : suggestedValue)
                } label: {
                    Label("Wrong", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    onVote("unclear", nil)
                } label: {
                    Label("Unclear", systemImage: "questionmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onVote("correct", nil)
                } label: {
                    Label("Correct", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    var meterIcon: String {
        switch reading.meterType.lowercased() {
        case "electric": return "bolt.fill"
        case "gas": return "flame.fill"
        case "water": return "drop.fill"
        default: return "gauge"
        }
    }

    var meterColor: Color {
        switch reading.meterType.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        default: return .gray
        }
    }
}

struct EmptyVerifyView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("All Caught Up!")
                    .font(.title2.bold())

                Text("No readings need verification right now. Check back later!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Campaigns View

struct CampaignsView: View {
    @StateObject private var viewModel = CampaignsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.campaigns.isEmpty {
                    ProgressView()
                } else if viewModel.campaigns.isEmpty {
                    EmptyCampaignsView()
                } else {
                    List(viewModel.campaigns) { campaign in
                        CampaignRow(campaign: campaign) {
                            Task {
                                await viewModel.toggleParticipation(campaign: campaign)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadCampaigns()
                    }
                }
            }
            .navigationTitle("Campaigns")
            .task {
                await viewModel.loadCampaigns()
            }
        }
    }
}

@MainActor
class CampaignsViewModel: ObservableObject {
    @Published var campaigns: [CampaignResponse] = []
    @Published var isLoading = false

    func loadCampaigns() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getCampaigns()
            campaigns = response.campaigns
        } catch {
            print("Failed to load campaigns: \(error)")
        }
        isLoading = false
    }

    func toggleParticipation(campaign: CampaignResponse) async {
        do {
            if campaign.isParticipant {
                try await APIService.shared.leaveCampaign(id: campaign.id)
            } else {
                _ = try await APIService.shared.joinCampaign(id: campaign.id)
            }
            await loadCampaigns()
        } catch {
            print("Toggle failed: \(error)")
        }
    }
}

struct CampaignRow: View {
    let campaign: CampaignResponse
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.name)
                        .font(.headline)

                    if let description = campaign.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if campaign.isParticipant {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Progress
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(campaign.progressPercent) / 100)
                    .tint(.blue)

                HStack {
                    Text("\(campaign.participantCount) participants")
                    Spacer()
                    Text("\(campaign.totalReadings) readings")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Join/Leave Button
            Button {
                onToggle()
            } label: {
                Text(campaign.isParticipant ? "Leave" : "Join")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(campaign.isParticipant ? .red : .blue)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyCampaignsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "flag.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("No Active Campaigns")
                    .font(.title2.bold())

                Text("Join a campaign to contribute readings with your community")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
