import Foundation
import SwiftUI

/// Manages subscription tier enforcement and feature access
@MainActor
class TierEnforcement: ObservableObject {
    static let shared = TierEnforcement()

    @Published var showUpgradePrompt = false
    @Published var blockedFeature: Feature?

    private init() {}

    // MARK: - Feature Definition

    enum Feature {
        case neighborhoodStats
        case blockStats
        case districtStats
        case apiAccess
        case advancedAnalytics

        var requiredTier: SubscriptionTier {
            switch self {
            case .neighborhoodStats:
                return .neighbor
            case .blockStats:
                return .block
            case .districtStats, .apiAccess, .advancedAnalytics:
                return .district
            }
        }

        var displayName: String {
            switch self {
            case .neighborhoodStats:
                return "Neighborhood Statistics"
            case .blockStats:
                return "Block Statistics"
            case .districtStats:
                return "District Statistics"
            case .apiAccess:
                return "API Access"
            case .advancedAnalytics:
                return "Advanced Analytics"
            }
        }

        var description: String {
            switch self {
            case .neighborhoodStats:
                return "View aggregated data from meters in your postal code"
            case .blockStats:
                return "Access statistics from meters within 5km radius"
            case .districtStats:
                return "Explore data from meters within 25km radius"
            case .apiAccess:
                return "Programmatic access to your meter data"
            case .advancedAnalytics:
                return "Deep insights and trend analysis"
            }
        }

        var icon: String {
            switch self {
            case .neighborhoodStats:
                return "map"
            case .blockStats:
                return "map.circle"
            case .districtStats:
                return "map.circle.fill"
            case .apiAccess:
                return "chevron.left.forwardslash.chevron.right"
            case .advancedAnalytics:
                return "chart.xyaxis.line"
            }
        }
    }

    // MARK: - Access Control

    /// Check if user has access to a feature based on their subscription tier
    func hasAccess(to feature: Feature) -> Bool {
        guard let user = AuthManager.shared.currentUser else {
            return false
        }

        let userTier = parseTier(user.subscriptionTier)
        return userTier.rawValue >= feature.requiredTier.rawValue
    }

    /// Check access before executing an action, showing upgrade prompt if needed
    func checkAccess(to feature: Feature) -> Bool {
        if hasAccess(to: feature) {
            return true
        } else {
            blockedFeature = feature
            showUpgradePrompt = true
            return false
        }
    }

    /// Get the appropriate tier for accessing neighborhood stats based on scope
    func requiredTierForScope(_ scope: StatsScope) -> SubscriptionTier {
        switch scope {
        case .own:
            return .free
        case .postalCode:
            return .neighbor
        case .radius5km:
            return .block
        case .radius25km:
            return .district
        }
    }

    /// Check if user can access a specific stats scope
    func canAccessScope(_ scope: StatsScope) -> Bool {
        guard let user = AuthManager.shared.currentUser else {
            return false
        }

        let userTier = parseTier(user.subscriptionTier)
        let requiredTier = requiredTierForScope(scope)
        return userTier.rawValue >= requiredTier.rawValue
    }

    // MARK: - Helpers

    private func parseTier(_ tierString: String) -> SubscriptionTier {
        SubscriptionTier(rawValue: tierString.lowercased()) ?? .free
    }

    /// Get all available tiers with their benefits
    static func tierBenefits() -> [(tier: SubscriptionTier, benefits: [String])] {
        [
            (.free, [
                "Your own meter data",
                "Basic statistics",
                "Community verification",
                "Gamification & XP"
            ]),
            (.neighbor, [
                "All Free features",
                "Postal code aggregates",
                "Compare with neighbors",
                "Early access to features"
            ]),
            (.block, [
                "All Neighbor features",
                "5km radius statistics",
                "Advanced analytics",
                "Priority support"
            ]),
            (.district, [
                "All Block features",
                "25km radius statistics",
                "Full API access",
                "Custom exports",
                "Enterprise webhooks"
            ])
        ]
    }
}

// MARK: - Stats Scope

enum StatsScope: String, CaseIterable {
    case own = "own"
    case postalCode = "postal_code"
    case radius5km = "radius_5km"
    case radius25km = "radius_25km"

    var displayName: String {
        switch self {
        case .own:
            return "Your Data"
        case .postalCode:
            return "Your Postal Code"
        case .radius5km:
            return "5km Radius"
        case .radius25km:
            return "25km Radius"
        }
    }

    var icon: String {
        switch self {
        case .own:
            return "person.fill"
        case .postalCode:
            return "map"
        case .radius5km:
            return "map.circle"
        case .radius25km:
            return "map.circle.fill"
        }
    }

    var requiredTier: SubscriptionTier {
        TierEnforcement.shared.requiredTierForScope(self)
    }
}

// MARK: - Upgrade Prompt View

struct UpgradePromptView: View {
    let feature: TierEnforcement.Feature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Feature Icon
                Image(systemName: feature.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)

                // Feature Info
                VStack(spacing: 12) {
                    Text(feature.displayName)
                        .font(.title2.bold())

                    Text(feature.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Required Tier
                VStack(spacing: 16) {
                    Text("Requires")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.requiredTier.rawValue.capitalized)
                                .font(.headline)

                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: feature.requiredTier.monthlyPrice).doubleValue))/month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer()

                // Tier Benefits
                VStack(spacing: 16) {
                    Text("What's Included")
                        .font(.headline)

                    ForEach(benefitsForTier(feature.requiredTier), id: \.self) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            Text(benefit)
                                .font(.subheadline)

                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                // CTA Buttons
                VStack(spacing: 12) {
                    Button {
                        // Navigate to subscription view
                        dismiss()
                    } label: {
                        Text("Upgrade to \(feature.requiredTier.rawValue.capitalized)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func benefitsForTier(_ tier: SubscriptionTier) -> [String] {
        let allBenefits = TierEnforcement.tierBenefits()
        guard let tierBenefits = allBenefits.first(where: { $0.tier == tier }) else {
            return []
        }
        return tierBenefits.benefits
    }
}

// MARK: - Tier Badge

struct TierBadge: View {
    let tier: SubscriptionTier

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tierIcon)
                .font(.caption2)

            Text(tier.rawValue.capitalized)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tierColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tierColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var tierIcon: String {
        switch tier {
        case .free:
            return "star"
        case .neighbor:
            return "star.fill"
        case .block:
            return "crown"
        case .district:
            return "crown.fill"
        }
    }

    private var tierColor: Color {
        switch tier {
        case .free:
            return .gray
        case .neighbor:
            return .blue
        case .block:
            return .purple
        case .district:
            return .orange
        }
    }
}

#Preview("Upgrade Prompt") {
    UpgradePromptView(feature: .neighborhoodStats)
}

#Preview("Tier Badge") {
    VStack(spacing: 12) {
        TierBadge(tier: .free)
        TierBadge(tier: .neighbor)
        TierBadge(tier: .block)
        TierBadge(tier: .district)
    }
}
