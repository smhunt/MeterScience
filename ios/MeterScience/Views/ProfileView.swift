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
        }
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

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                icon: "camera.viewfinder",
                title: "Readings",
                value: "\(stats?.totalReadings ?? 0)",
                color: .blue
            )
            StatCard(
                icon: "checkmark.seal.fill",
                title: "Verified",
                value: "\(stats?.verifiedReadings ?? 0)",
                color: .green
            )
            StatCard(
                icon: "flame.fill",
                title: "Streak",
                value: "\(stats?.streakDays ?? 0) days",
                color: .orange
            )
            StatCard(
                icon: "hand.thumbsup.fill",
                title: "Verifications",
                value: "\(stats?.verificationsPerformed ?? 0)",
                color: .purple
            )
            StatCard(
                icon: "shield.fill",
                title: "Trust Score",
                value: "\(stats?.trustScore ?? 50)",
                color: .cyan
            )
            StatCard(
                icon: "gauge",
                title: "Meters",
                value: "\(stats?.metersCount ?? 0)",
                color: .indigo
            )
        }
    }
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
