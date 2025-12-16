import SwiftUI

struct VersionNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Section = .whatsNew

    enum Section: String, CaseIterable {
        case whatsNew = "What's New"
        case howItWorks = "How It Works"
        case roadmap = "Roadmap"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // App Version Header
                VStack(spacing: 8) {
                    Image(systemName: "app.badge.checkmark.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("MeterScience")
                        .font(.title2.bold())

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))

                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(Section.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemBackground))

                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedSection {
                        case .whatsNew:
                            WhatsNewContent()
                        case .howItWorks:
                            HowItWorksContent()
                        case .roadmap:
                            RoadmapContent()
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - What's New Content

struct WhatsNewContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recent Updates")
                .font(.title2.bold())
                .padding(.bottom, 8)

            FeatureItem(
                icon: "123.rectangle",
                iconColor: .blue,
                title: "Strict OCR Filtering",
                description: "Readings now filtered by expected digit count for better accuracy"
            )

            FeatureItem(
                icon: "wand.and.stars",
                iconColor: .purple,
                title: "Image Preprocessing",
                description: "Enhanced image processing for clearer meter readings"
            )

            FeatureItem(
                icon: "location.fill",
                iconColor: .green,
                title: "GPS Location Capture",
                description: "Automatic location tagging with every reading for better tracking"
            )

            FeatureItem(
                icon: "doc.text.magnifyingglass",
                iconColor: .orange,
                title: "Reading Detail Pages",
                description: "View comprehensive details about each reading including confidence and verification status"
            )

            FeatureItem(
                icon: "checkmark.seal.fill",
                iconColor: .cyan,
                title: "Verification History",
                description: "Track your community verification contributions with detailed history"
            )

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - How It Works Content

struct HowItWorksContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How It Works")
                .font(.title2.bold())
                .padding(.bottom, 8)

            StepItem(
                number: 1,
                title: "Add Your Meters",
                description: "Configure each meter with type and expected digit count for accurate readings",
                icon: "gauge.with.dots.needle.67percent",
                color: .indigo
            )

            StepItem(
                number: 2,
                title: "Take Photos",
                description: "Capture clear photos of your meter displays - our OCR technology extracts the reading",
                icon: "camera.fill",
                color: .blue
            )

            StepItem(
                number: 3,
                title: "Community Verification",
                description: "Help verify other readings to improve data accuracy and earn XP",
                icon: "hand.thumbsup.fill",
                color: .purple
            )

            StepItem(
                number: 4,
                title: "Earn Rewards",
                description: "Gain XP, unlock badges, and level up as you contribute to the community",
                icon: "star.fill",
                color: .yellow
            )

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Privacy First")
                        .font(.subheadline.bold())
                }

                Text("Your data is private by default. Aggregated neighborhood statistics are only shown when there are at least 5 participating homes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Roadmap Content

struct RoadmapContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Coming Soon")
                .font(.title2.bold())
                .padding(.bottom, 8)

            RoadmapItem(
                icon: "brain.head.profile",
                iconColor: .purple,
                title: "Reference Image Learning",
                description: "Train OCR on your specific meter for even better accuracy",
                status: .inProgress
            )

            RoadmapItem(
                icon: "arrow.up.right.circle.fill",
                iconColor: .green,
                title: "Batch Accuracy Improvement",
                description: "Bulk editing and correction tools for historical readings",
                status: .planned
            )

            RoadmapItem(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .blue,
                title: "Usage Charts & Graphs",
                description: "Visualize your consumption patterns over time",
                status: .planned
            )

            RoadmapItem(
                icon: "map.fill",
                iconColor: .orange,
                title: "Neighborhood Comparisons",
                description: "See how your usage compares to similar homes nearby",
                status: .planned
            )

            RoadmapItem(
                icon: "cpu.fill",
                iconColor: .cyan,
                title: "MeterPi Integration",
                description: "Connect automated Raspberry Pi hardware for 24/7 monitoring",
                status: .planned
            )

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Have a Suggestion?")
                        .font(.subheadline.bold())
                }

                Text("We'd love to hear your ideas! Share feedback through the app or join our community forums.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Supporting Views

struct FeatureItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StepItem: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)

                Text("\(number)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.bold())
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RoadmapItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: RoadmapStatus

    enum RoadmapStatus {
        case inProgress
        case planned

        var label: String {
            switch self {
            case .inProgress: return "In Progress"
            case .planned: return "Planned"
            }
        }

        var color: Color {
            switch self {
            case .inProgress: return .orange
            case .planned: return .gray
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text(status.label)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.color.opacity(0.2))
                        .foregroundStyle(status.color)
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VersionNotesView()
}
