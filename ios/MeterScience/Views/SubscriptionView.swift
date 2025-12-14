import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var store = SubscriptionStore()
    @StateObject private var auth = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                SubscriptionHeaderView(currentTier: auth.currentUser?.subscriptionTier ?? "free")

                // Tier Cards
                ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                    TierCard(
                        tier: tier,
                        isCurrentTier: auth.currentUser?.subscriptionTier.lowercased() == tier.rawValue,
                        product: store.product(for: tier),
                        onSubscribe: { await store.purchase(tier) }
                    )
                }

                // Restore Purchases
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Legal Text
                Text("Subscriptions auto-renew monthly. Cancel anytime in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .alert("Purchase Error", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .overlay {
            if store.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .task {
            await store.loadProducts()
        }
    }
}

// MARK: - Subscription Store

@MainActor
class SubscriptionStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let productIDs = [
        "com.meterscience.neighbor.monthly",
        "com.meterscience.block.monthly",
        "com.meterscience.district.monthly"
    ]

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func product(for tier: SubscriptionTier) -> Product? {
        let productID: String
        switch tier {
        case .free: return nil
        case .neighbor: productID = "com.meterscience.neighbor.monthly"
        case .block: productID = "com.meterscience.block.monthly"
        case .district: productID = "com.meterscience.district.monthly"
        }
        return products.first { $0.id == productID }
    }

    func purchase(_ tier: SubscriptionTier) async {
        guard let product = product(for: tier) else {
            errorMessage = "Product not available"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()

            case .userCancelled:
                break

            case .pending:
                errorMessage = "Purchase pending approval"

            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                continue
            }
        }

        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

// MARK: - Subscription Header

struct SubscriptionHeaderView: View {
    let currentTier: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock More Data")
                .font(.title2.bold())

            Text("Your personal data is always free. Upgrade to compare with your neighborhood.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Current Tier Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(tierColor(currentTier))
                    .frame(width: 8, height: 8)
                Text("Current: \(currentTier.capitalized)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tierColor(currentTier).opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    func tierColor(_ tier: String) -> Color {
        switch tier.lowercased() {
        case "neighbor": return .blue
        case "block": return .purple
        case "district": return .orange
        default: return .gray
        }
    }
}

// MARK: - Tier Card

struct TierCard: View {
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    let product: Product?
    let onSubscribe: () async -> Void

    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tier.displayName)
                            .font(.title3.bold())

                        if isCurrentTier {
                            Text("CURRENT")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }

                        if tier == .block {
                            Text("POPULAR")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(tier.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    if tier == .free {
                        Text("$0")
                            .font(.title2.bold())
                    } else if let product = product {
                        Text(product.displayPrice)
                            .font(.title2.bold())
                        Text("/month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("$\(tier.monthlyPrice, specifier: "%.2f")")
                            .font(.title2.bold())
                        Text("/month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(tier.color)
                            .font(.subheadline)
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }

            // Action Button
            if tier != .free {
                Button {
                    Task {
                        isLoading = true
                        await onSubscribe()
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isCurrentTier ? "Manage" : "Subscribe")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(tier.color)
                .disabled(isLoading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentTier ? tier.color : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Subscription Tier Extensions

extension SubscriptionTier {
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .neighbor: return "Neighbor"
        case .block: return "Block"
        case .district: return "District"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Your data, always free"
        case .neighbor: return "Same postal code comparisons"
        case .block: return "5km radius data access"
        case .district: return "25km radius + API access"
        }
    }

    var color: Color {
        switch self {
        case .free: return .gray
        case .neighbor: return .blue
        case .block: return .purple
        case .district: return .orange
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Track your own meters",
                "Manual OCR scanning",
                "Basic usage charts",
                "XP, badges, streaks",
                "Data export (CSV/JSON)"
            ]
        case .neighbor:
            return [
                "Everything in Free",
                "Neighborhood comparisons",
                "Bill predictions",
                "Anomaly alerts",
                "Usage percentiles"
            ]
        case .block:
            return [
                "Everything in Neighbor",
                "5km radius data",
                "Advanced analytics",
                "Priority verification",
                "Time-of-use insights"
            ]
        case .district:
            return [
                "Everything in Block",
                "25km radius data",
                "REST API access",
                "Custom webhooks",
                "Research datasets"
            ]
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
