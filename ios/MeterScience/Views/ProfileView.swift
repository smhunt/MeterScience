import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView(stats: viewModel.stats)

                    // XP Progress
                    if let stats = viewModel.stats {
                        XPProgressView(
                            level: stats.level,
                            xp: stats.xp,
                            xpToNext: stats.xpToNextLevel
                        )
                    }

                    // Stats Grid
                    StatsGridView(stats: viewModel.stats)

                    // Badges Section
                    BadgesSection(badges: viewModel.stats?.badges ?? [])

                    // Account Actions
                    AccountActionsView()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .refreshable {
                await viewModel.loadStats()
            }
            .task {
                await viewModel.loadStats()
            }
            .overlay {
                if viewModel.isLoading && viewModel.stats == nil {
                    ProgressView()
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .meters:
                    AllMetersView()
                case .readings:
                    AllReadingsView()
                case .verified:
                    AllReadingsView(filterVerified: true)
                case .verifications:
                    MyVerificationsView()
                case .activityLog:
                    ActivityLogView()
                }
            }
        }
    }
}

// MARK: - All Meters View

struct AllMetersView: View {
    @StateObject private var viewModel = MetersListViewModel()

    var body: some View {
        List {
            ForEach(viewModel.meters) { meter in
                NavigationLink(value: MeterDestination.detail(meter)) {
                    MeterRowSimple(meter: meter)
                }
            }
        }
        .navigationTitle("My Meters")
        .navigationDestination(for: MeterDestination.self) { destination in
            switch destination {
            case .detail(let meter):
                MeterDetailViewWrapper(meter: meter)
            }
        }
        .task {
            await viewModel.loadMeters()
        }
        .refreshable {
            await viewModel.loadMeters()
        }
        .overlay {
            if viewModel.meters.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Meters", systemImage: "gauge", description: Text("Add a meter to get started"))
            }
        }
    }
}

enum MeterDestination: Hashable {
    case detail(MeterResponse)
}

// Wrapper to use MeterDetailView from ContentView without the scan callback
struct MeterDetailViewWrapper: View {
    let meter: MeterResponse

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
                            Text(meter.name)
                                .font(.title2.bold())
                            Text(meter.meterType.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Quick stats
                    HStack(spacing: 20) {
                        if let lastRead = meter.lastReadAt {
                            VStack(spacing: 4) {
                                Text(lastRead, style: .relative)
                                    .font(.headline.monospacedDigit())
                                Text("Last Read")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if let postal = meter.postalCode {
                            VStack(spacing: 4) {
                                Text(postal)
                                    .font(.headline.monospacedDigit())
                                Text("Location")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)

                Text("Open this meter from the Meters tab to take readings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Meter Details")
        .navigationBarTitleDisplayMode(.inline)
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

struct MeterRowSimple: View {
    let meter: MeterResponse

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meterIcon)
                .font(.title3)
                .foregroundStyle(meterColor)
                .frame(width: 36, height: 36)
                .background(meterColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(meter.name)
                    .font(.subheadline.weight(.medium))
                Text(meter.meterType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let lastRead = meter.lastReadAt {
                Text(lastRead, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

// MARK: - All Readings View

struct AllReadingsView: View {
    var filterVerified: Bool = false
    @StateObject private var viewModel = AllReadingsViewModel()

    var body: some View {
        List {
            ForEach(filteredReadings) { reading in
                NavigationLink(value: ReadingDestination.detail(reading)) {
                    ReadingRowFull(reading: reading)
                }
            }
        }
        .navigationTitle(filterVerified ? "Verified Readings" : "All Readings")
        .navigationDestination(for: ReadingDestination.self) { destination in
            switch destination {
            case .detail(let reading):
                ReadingDetailView(reading: reading, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadReadings()
        }
        .refreshable {
            await viewModel.loadReadings()
        }
        .overlay {
            if filteredReadings.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Readings", systemImage: "camera.viewfinder", description: Text("Take some meter readings"))
            }
        }
    }

    var filteredReadings: [ReadingResponse] {
        if filterVerified {
            return viewModel.readings.filter { $0.verificationStatus?.lowercased() == "verified" }
        }
        return viewModel.readings
    }
}

enum ReadingDestination: Hashable {
    case detail(ReadingResponse)
}

@MainActor
class AllReadingsViewModel: ObservableObject {
    @Published var readings: [ReadingResponse] = []
    @Published var isLoading = false

    func loadReadings() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getReadings()
            readings = response.readings
        } catch {
            print("Failed to load readings: \(error)")
        }
        isLoading = false
    }
}

struct ReadingRowFull: View {
    let reading: ReadingResponse

    var body: some View {
        HStack(spacing: 12) {
            Text(reading.normalizedValue)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(reading.createdAt, style: .date)
                    .font(.caption)
                Text(reading.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
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

// MARK: - Reading Detail View

struct ReadingDetailView: View {
    let reading: ReadingResponse
    @ObservedObject var viewModel: AllReadingsViewModel
    @StateObject private var detailViewModel = ReadingDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Reading Value Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reading Value")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(reading.normalizedValue)
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                        }

                        Spacer()

                        // Verification Status Badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(reading.verificationStatus?.capitalized ?? "Unverified")
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    // Confidence
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(reading.confidence * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(confidenceColor)
                                    .frame(width: geo.size.width * CGFloat(reading.confidence), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)

                // Details Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)

                    DetailRow(label: "Captured", value: reading.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    DetailRow(label: "Created", value: reading.createdAt.formatted(date: .abbreviated, time: .shortened))
                    DetailRow(label: "Raw Value", value: reading.rawValue)

                    if let numeric = reading.numericValue {
                        DetailRow(label: "Numeric Value", value: String(format: "%.2f", numeric))
                    }

                    if let usage = reading.usageSinceLast {
                        DetailRow(label: "Usage Since Last", value: String(format: "%.2f units", usage))
                    }

                    if let days = reading.daysSinceLast {
                        DetailRow(label: "Days Since Last", value: String(format: "%.1f days", days))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)

                // Meter Info Card
                if let meter = detailViewModel.meter {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meter Information")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Image(systemName: meterIcon(for: meter.meterType))
                                .font(.title2)
                                .foregroundStyle(meterColor(for: meter.meterType))
                                .frame(width: 44, height: 44)
                                .background(meterColor(for: meter.meterType).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(meter.name)
                                    .font(.subheadline.weight(.medium))
                                Text(meter.meterType.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 10)
                }

                // Request Verification Button (if not verified)
                if reading.verificationStatus?.lowercased() != "verified" {
                    Button {
                        // TODO: Implement request verification
                        detailViewModel.showingRequestVerification = true
                    } label: {
                        Label("Request Verification", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reading Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await detailViewModel.loadMeter(id: reading.meterId)
        }
        .alert("Request Verification", isPresented: $detailViewModel.showingRequestVerification) {
            Button("OK") {
                detailViewModel.showingRequestVerification = false
            }
        } message: {
            Text("This reading will be added to the verification queue for community review.")
        }
    }

    var statusColor: Color {
        switch reading.verificationStatus?.lowercased() {
        case "verified": return .green
        case "rejected": return .red
        case "pending": return .orange
        default: return .gray
        }
    }

    var confidenceColor: Color {
        if reading.confidence >= 0.9 {
            return .green
        } else if reading.confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    func meterIcon(for type: String) -> String {
        switch type.lowercased() {
        case "electric": return "bolt.fill"
        case "gas": return "flame.fill"
        case "water": return "drop.fill"
        case "solar": return "sun.max.fill"
        default: return "gauge"
        }
    }

    func meterColor(for type: String) -> Color {
        switch type.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        case "solar": return .green
        default: return .gray
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
}

@MainActor
class ReadingDetailViewModel: ObservableObject {
    @Published var meter: MeterResponse?
    @Published var isLoading = false
    @Published var showingRequestVerification = false

    func loadMeter(id: UUID) async {
        isLoading = true
        do {
            meter = try await APIService.shared.getMeter(id: id)
        } catch {
            print("Failed to load meter: \(error)")
        }
        isLoading = false
    }
}

// MARK: - My Verifications View

struct MyVerificationsView: View {
    @StateObject private var viewModel = MyVerificationsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.history == nil {
                ProgressView()
            } else if let history = viewModel.history, !history.recentVotes.isEmpty {
                List {
                    // Summary Section
                    Section {
                        VStack(spacing: 16) {
                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(history.totalVerifications)")
                                        .font(.title.bold())
                                    Text("Total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)

                                VStack {
                                    Text("\(history.verificationsThisWeek)")
                                        .font(.title.bold())
                                    Text("This Week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)

                                VStack {
                                    Text("\(history.xpEarned)")
                                        .font(.title.bold())
                                    Text("XP Earned")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Consensus Rate
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Consensus Rate")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(history.consensusRate * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(history.consensusRate >= 0.8 ? Color.green : Color.orange)
                                            .frame(width: geo.size.width * CGFloat(history.consensusRate), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                Text("\(history.consensusMatches) of \(history.totalVerifications) matched community consensus")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Recent Verifications
                    Section("Recent Verifications") {
                        ForEach(history.recentVotes) { vote in
                            NavigationLink(value: VerificationDestination.detail(vote)) {
                                VerificationRowView(vote: vote)
                            }
                        }
                    }
                }
                .navigationDestination(for: VerificationDestination.self) { destination in
                    switch destination {
                    case .detail(let vote):
                        VerificationDetailView(vote: vote)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Verifications Yet",
                    systemImage: "hand.thumbsup",
                    description: Text("Visit the Verify tab to start helping the community")
                )
            }
        }
        .navigationTitle("My Verifications")
        .task {
            await viewModel.loadHistory()
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }
}

enum VerificationDestination: Hashable {
    case detail(VoteResponse)
}

struct VerificationRowView: View {
    let vote: VoteResponse

    var body: some View {
        HStack(spacing: 12) {
            // Vote icon
            Image(systemName: voteIcon)
                .font(.title3)
                .foregroundStyle(voteColor)
                .frame(width: 32, height: 32)
                .background(voteColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(vote.vote.capitalized)
                    .font(.subheadline.weight(.medium))

                if let suggested = vote.suggestedValue {
                    Text("Suggested: \(suggested)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(vote.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(vote.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(vote.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    var voteIcon: String {
        switch vote.vote.lowercased() {
        case "correct": return "checkmark.circle.fill"
        case "incorrect": return "xmark.circle.fill"
        case "unclear": return "questionmark.circle.fill"
        default: return "circle"
        }
    }

    var voteColor: Color {
        switch vote.vote.lowercased() {
        case "correct": return .green
        case "incorrect": return .red
        case "unclear": return .orange
        default: return .gray
        }
    }
}

@MainActor
class MyVerificationsViewModel: ObservableObject {
    @Published var history: VerificationHistoryResponse?
    @Published var isLoading = false

    func loadHistory() async {
        isLoading = true
        do {
            history = try await APIService.shared.getVerificationHistory()
        } catch {
            print("Failed to load verification history: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Verification Detail View

struct VerificationDetailView: View {
    let vote: VoteResponse
    @StateObject private var viewModel = VerificationDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vote Summary Card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: voteIcon)
                            .font(.system(size: 40))
                            .foregroundStyle(voteColor)
                            .frame(width: 60, height: 60)
                            .background(voteColor.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("You voted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vote.vote.capitalized)
                                .font(.title2.bold())
                                .foregroundStyle(voteColor)
                        }

                        Spacer()
                    }

                    if let suggested = vote.suggestedValue {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Value")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(suggested)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    DetailRow(label: "Voted At", value: vote.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10)

                // Reading Details Card
                if let reading = viewModel.reading {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reading Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original Value")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(reading.normalizedValue)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        DetailRow(label: "Confidence", value: "\(Int(reading.confidence * 100))%")
                        DetailRow(label: "Captured", value: reading.capturedAt.formatted(date: .abbreviated, time: .shortened))

                        if let status = reading.verificationStatus {
                            HStack {
                                Text("Status")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(statusColor(for: status))
                                        .frame(width: 8, height: 8)
                                    Text(status.capitalized)
                                        .font(.subheadline.weight(.medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(statusColor(for: status).opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 10)

                    // Meter Info Card
                    if let meter = viewModel.meter {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Meter Information")
                                .font(.headline)

                            HStack(spacing: 12) {
                                Image(systemName: meterIcon(for: meter.meterType))
                                    .font(.title2)
                                    .foregroundStyle(meterColor(for: meter.meterType))
                                    .frame(width: 44, height: 44)
                                    .background(meterColor(for: meter.meterType).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meter.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(meter.meterType.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 10)
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Verification Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadReading(id: vote.readingId)
        }
    }

    var voteIcon: String {
        switch vote.vote.lowercased() {
        case "correct": return "checkmark.circle.fill"
        case "incorrect": return "xmark.circle.fill"
        case "unclear": return "questionmark.circle.fill"
        default: return "circle"
        }
    }

    var voteColor: Color {
        switch vote.vote.lowercased() {
        case "correct": return .green
        case "incorrect": return .red
        case "unclear": return .orange
        default: return .gray
        }
    }

    func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "verified": return .green
        case "rejected": return .red
        case "pending": return .orange
        default: return .gray
        }
    }

    func meterIcon(for type: String) -> String {
        switch type.lowercased() {
        case "electric": return "bolt.fill"
        case "gas": return "flame.fill"
        case "water": return "drop.fill"
        case "solar": return "sun.max.fill"
        default: return "gauge"
        }
    }

    func meterColor(for type: String) -> Color {
        switch type.lowercased() {
        case "electric": return .yellow
        case "gas": return .orange
        case "water": return .blue
        case "solar": return .green
        default: return .gray
        }
    }
}

@MainActor
class VerificationDetailViewModel: ObservableObject {
    @Published var reading: ReadingResponse?
    @Published var meter: MeterResponse?
    @Published var isLoading = false

    func loadReading(id: UUID) async {
        isLoading = true
        do {
            reading = try await APIService.shared.getReading(id: id)
            if let meterId = reading?.meterId {
                meter = try await APIService.shared.getMeter(id: meterId)
            }
        } catch {
            print("Failed to load reading details: \(error)")
        }
        isLoading = false
    }
}

// MARK: - View Model

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var stats: UserStatsResponse?
    @Published var isLoading = false
    @Published var error: String?

    func loadStats() async {
        isLoading = true
        do {
            stats = try await APIService.shared.getMyStats()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let stats: UserStatsResponse?

    var body: some View {
        VStack(spacing: 12) {
            // Avatar
            Text(stats?.displayName.first.map { String($0).uppercased() } ?? "?")
                .font(.system(size: 40, weight: .bold))
                .frame(width: 80, height: 80)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Circle())

            // Name & Level
            VStack(spacing: 4) {
                Text(stats?.displayName ?? "Loading...")
                    .font(.title2.bold())

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Level \(stats?.level ?? 1)")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            // Rank Badge
            if let rank = stats?.rank {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)
                    Text("Rank #\(rank)")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - XP Progress

struct XPProgressView: View {
    let level: Int
    let xp: Int
    let xpToNext: Int

    var progress: Double {
        guard xpToNext > 0 else { return 0 }
        return Double(xp) / Double(xpToNext)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(level)")
                    .font(.headline)
                Spacer()
                Text("\(xp) / \(xpToNext) XP")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)

            Text("Level \(level + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Stats Grid

struct StatsGridView: View {
    let stats: UserStatsResponse?
    @State private var selectedTab: Int?

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            NavigationLink(value: ProfileDestination.meters) {
                StatCard(
                    icon: "gauge",
                    title: "Meters",
                    value: "\(stats?.metersCount ?? 0)",
                    color: .indigo
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileDestination.readings) {
                StatCard(
                    icon: "camera.viewfinder",
                    title: "Readings",
                    value: "\(stats?.totalReadings ?? 0)",
                    color: .blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileDestination.verified) {
                StatCard(
                    icon: "checkmark.seal.fill",
                    title: "Verified",
                    value: "\(stats?.verifiedReadings ?? 0)",
                    color: .green
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileDestination.verifications) {
                StatCard(
                    icon: "hand.thumbsup.fill",
                    title: "Verifications",
                    value: "\(stats?.verificationsPerformed ?? 0)",
                    color: .purple
                )
            }
            .buttonStyle(.plain)

            StatCard(
                icon: "flame.fill",
                title: "Streak",
                value: "\(stats?.streakDays ?? 0) days",
                color: .orange
            )

            StatCard(
                icon: "shield.fill",
                title: "Trust Score",
                value: "\(stats?.trustScore ?? 50)",
                color: .cyan
            )
        }
    }
}

enum ProfileDestination: Hashable {
    case meters
    case readings
    case verified
    case verifications
    case activityLog
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Badges Section

struct BadgesSection: View {
    let badges: [BadgeResponse]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Badges")
                    .font(.headline)
                Spacer()
                Text("\(badges.count) earned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if badges.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No badges yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Keep reading meters to earn badges!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(badges, id: \.id) { badge in
                            BadgeView(badge: badge)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct BadgeView: View {
    let badge: BadgeResponse

    var body: some View {
        VStack(spacing: 6) {
            Text(badge.icon)
                .font(.system(size: 32))
            Text(badge.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Account Actions

struct AccountActionsView: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(value: ProfileDestination.activityLog) {
                AccountActionRow(
                    icon: "clock.arrow.circlepath",
                    title: "Activity Log",
                    subtitle: "View your recent activity",
                    color: .cyan
                )
            }

            NavigationLink {
                ReferralView()
            } label: {
                AccountActionRow(
                    icon: "gift.fill",
                    title: "Referrals",
                    subtitle: "Invite friends, earn rewards",
                    color: .pink
                )
            }

            NavigationLink {
                SubscriptionView()
            } label: {
                AccountActionRow(
                    icon: "crown.fill",
                    title: "Subscription",
                    subtitle: auth.currentUser?.subscriptionTier.capitalized ?? "Free",
                    color: .yellow
                )
            }

            Button {
                auth.logout()
            } label: {
                AccountActionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    subtitle: auth.currentUser?.email ?? "Guest account",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct AccountActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity Log View

struct ActivityLogView: View {
    var body: some View {
        ContentUnavailableView(
            "Activity Log",
            systemImage: "list.bullet.clipboard",
            description: Text("Your activity history will appear here")
        )
        .navigationTitle("Activity Log")
    }
}

#Preview {
    ProfileView()
}
