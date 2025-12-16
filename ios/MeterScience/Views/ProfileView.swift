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
                MeterRowSimple(meter: meter)
            }
        }
        .navigationTitle("My Meters")
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
                ReadingRowFull(reading: reading)
            }
        }
        .navigationTitle(filterVerified ? "Verified Readings" : "All Readings")
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

// MARK: - My Verifications View

struct MyVerificationsView: View {
    var body: some View {
        ContentUnavailableView("Coming Soon", systemImage: "hand.thumbsup.fill", description: Text("Your verification history will appear here"))
            .navigationTitle("My Verifications")
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

#Preview {
    ProfileView()
}
