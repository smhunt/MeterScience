import SwiftUI

struct ActivityLogView: View {
    @StateObject private var viewModel = ActivityLogViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.activities.isEmpty {
                ProgressView()
            } else if viewModel.activities.isEmpty {
                EmptyActivityView()
            } else {
                List {
                    ForEach(viewModel.groupedActivities.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(viewModel.groupedActivities[date] ?? []) { activity in
                                ActivityRow(activity: activity)
                            }
                        } header: {
                            Text(formatSectionDate(date))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadActivities()
                }
            }
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadActivities()
        }
        .overlay {
            if viewModel.isLoading && !viewModel.activities.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 5)
                        .padding()
                }
            }
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month().day())
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: ActivityItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundStyle(activity.color)
                .frame(width: 40, height: 40)
                .background(activity.color.opacity(0.1))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline.weight(.medium))

                if let subtitle = activity.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Additional metadata display
                if let metadata = activity.metadata {
                    HStack(spacing: 8) {
                        if let value = metadata.readingValue {
                            Label(value, systemImage: "gauge")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let xp = metadata.xpAmount {
                            Label("+\(xp) XP", systemImage: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                        if let badge = metadata.badgeIcon {
                            Text(badge)
                                .font(.caption)
                        }
                        if let level = metadata.newLevel {
                            Label("Level \(level)", systemImage: "arrow.up")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                        if let streak = metadata.streakDays {
                            Label("\(streak) days", systemImage: "flame")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Timestamp
            Text(activity.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Activity Yet")
                    .font(.title2.bold())

                Text("Your recent actions will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("Start by:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    EmptyActivitySuggestion(
                        icon: "camera.viewfinder",
                        label: "Take a reading",
                        color: .blue
                    )
                    EmptyActivitySuggestion(
                        icon: "checkmark.seal",
                        label: "Verify readings",
                        color: .green
                    )
                    EmptyActivitySuggestion(
                        icon: "flag",
                        label: "Join a campaign",
                        color: .indigo
                    )
                }
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

struct EmptyActivitySuggestion: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - View Model

@MainActor
class ActivityLogViewModel: ObservableObject {
    @Published var activities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var error: String?

    var groupedActivities: [Date: [ActivityItem]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.timestamp)
        }
        return grouped
    }

    func loadActivities() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load data from multiple sources
            async let readingsTask = APIService.shared.getReadings()
            async let statsTask = APIService.shared.getMyStats()
            async let verificationHistoryTask = getVerificationHistory()

            let (readingsResponse, stats, verificationHistory) = try await (readingsTask, statsTask, verificationHistoryTask)

            var newActivities: [ActivityItem] = []

            // Add reading activities
            for reading in readingsResponse.readings.prefix(20) {
                newActivities.append(ActivityItem(
                    id: reading.id,
                    type: .readingSubmitted,
                    timestamp: reading.createdAt,
                    title: "Reading Submitted",
                    subtitle: "Captured meter reading",
                    metadata: ActivityMetadata(
                        readingValue: reading.normalizedValue,
                        xpAmount: 10 // Base XP for reading
                    )
                ))
            }

            // Add verification activities
            for vote in verificationHistory {
                let voteType = vote.vote.capitalized
                newActivities.append(ActivityItem(
                    id: vote.id,
                    type: .verificationPerformed,
                    timestamp: vote.createdAt,
                    title: "Verification: \(voteType)",
                    subtitle: "Helped verify a reading",
                    metadata: ActivityMetadata(
                        xpAmount: 5 // XP for verification
                    )
                ))
            }

            // Add badge activities
            for badge in stats.badges.prefix(10) {
                newActivities.append(ActivityItem(
                    type: .badgeEarned,
                    timestamp: badge.earnedAt,
                    title: "Badge Earned: \(badge.name)",
                    subtitle: badge.description,
                    metadata: ActivityMetadata(
                        badgeIcon: badge.icon
                    )
                ))
            }

            // Add level up activity (simulated based on current level)
            if stats.level > 1 {
                // Estimate when they leveled up (this is approximate)
                let daysAgo = Double(stats.level * 3) // Rough estimate
                let levelUpDate = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()
                newActivities.append(ActivityItem(
                    type: .levelUp,
                    timestamp: levelUpDate,
                    title: "Level Up!",
                    subtitle: "Reached level \(stats.level)",
                    metadata: ActivityMetadata(
                        xpAmount: 50,
                        newLevel: stats.level
                    )
                ))
            }

            // Add streak milestone (if applicable)
            if stats.streakDays > 0 && stats.streakDays % 7 == 0 {
                let streakDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                newActivities.append(ActivityItem(
                    type: .streakMilestone,
                    timestamp: streakDate,
                    title: "Streak Milestone!",
                    subtitle: "Maintained your reading streak",
                    metadata: ActivityMetadata(
                        xpAmount: 25,
                        streakDays: stats.streakDays
                    )
                ))
            }

            // Sort by timestamp (newest first)
            activities = newActivities.sorted { $0.timestamp > $1.timestamp }

        } catch {
            self.error = error.localizedDescription
            print("Failed to load activities: \(error)")
        }
    }

    private func getVerificationHistory() async throws -> [VoteResponse] {
        do {
            let history = try await APIService.shared.getVerificationHistory()
            return history.recentVotes
        } catch {
            // If verification history endpoint fails, return empty array
            print("Failed to load verification history: \(error)")
            return []
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActivityLogView()
    }
}
