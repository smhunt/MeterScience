import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var currentSubscription: Product?
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var isProcessing = false

    private var updateListenerTask: Task<Void, Error>?
    private var entitlementTask: Task<Void, Never>?

    // Product IDs matching backend configuration
    private let productIDs = [
        "com.meterscience.neighbor",
        "com.meterscience.block",
        "com.meterscience.district"
    ]

    private init() {
        updateListenerTask = listenForTransactions()
        entitlementTask = Task {
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
        entitlementTask?.cancel()
    }

    // MARK: - Public Methods

    /// Check subscription status on app launch
    func checkSubscriptionStatus() async {
        do {
            // Check for active subscriptions
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    // Found an active subscription
                    if transaction.revocationDate == nil {
                        await handleActiveSubscription(transaction)
                        return
                    }
                }
            }

            // No active subscription found
            subscriptionStatus = .notSubscribed
            currentSubscription = nil

        } catch {
            print("Failed to check subscription status: \(error)")
            subscriptionStatus = .unknown
        }
    }

    /// Restore purchases and sync with backend
    func restorePurchases() async throws {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Check for active entitlements
            var foundSubscription = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.revocationDate == nil {
                        await handleActiveSubscription(transaction)
                        foundSubscription = true
                        break
                    }
                }
            }

            if !foundSubscription {
                subscriptionStatus = .notSubscribed
                currentSubscription = nil
            }

        } catch {
            print("Restore purchases failed: \(error)")
            throw SubscriptionError.restoreFailed
        }
    }

    /// Validate a transaction with the backend
    func validateTransaction(_ transaction: StoreKit.Transaction) async throws {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Call backend to validate receipt
            let response = try await APIService.shared.validateReceipt(
                transactionId: String(transaction.id),
                productId: transaction.productID
            )

            if response.success {
                // Update subscription status
                subscriptionStatus = .active(tier: response.subscriptionTier)

                // Update user profile with new tier
                await updateUserSubscriptionTier(response.subscriptionTier)

                print("✅ Subscription validated: \(response.subscriptionTier)")
            } else {
                throw SubscriptionError.validationFailed
            }

        } catch {
            print("❌ Receipt validation failed: \(error)")
            throw error
        }
    }

    // MARK: - Private Methods

    private func handleActiveSubscription(_ transaction: StoreKit.Transaction) async {
        // Update local state
        subscriptionStatus = .active(tier: tierFromProductID(transaction.productID))

        // Validate with backend
        do {
            try await validateTransaction(transaction)
        } catch {
            print("Failed to validate active subscription: \(error)")
            // Keep local state but log error
        }
    }

    private func updateUserSubscriptionTier(_ tier: String) async {
        // Refresh user from backend to get latest state
        // The backend will have updated the subscription tier
        await AuthManager.shared.refreshUser()
    }

    private func tierFromProductID(_ productID: String) -> String {
        switch productID {
        case "com.meterscience.neighbor":
            return "neighbor"
        case "com.meterscience.block":
            return "block"
        case "com.meterscience.district":
            return "district"
        default:
            return "free"
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                do {
                    let transaction = try self.checkVerified(result)

                    await MainActor.run {
                        Task {
                            // Validate new transaction with backend
                            do {
                                try await self.validateTransaction(transaction)
                                await transaction.finish()
                            } catch {
                                print("Failed to validate transaction update: \(error)")
                            }
                        }
                    }
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum SubscriptionStatus: Equatable {
    case unknown
    case notSubscribed
    case active(tier: String)

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var tierName: String? {
        if case .active(let tier) = self {
            return tier
        }
        return nil
    }
}

enum SubscriptionError: LocalizedError {
    case failedVerification
    case validationFailed
    case restoreFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Failed to verify purchase with App Store"
        case .validationFailed:
            return "Failed to validate subscription with server"
        case .restoreFailed:
            return "Failed to restore purchases"
        case .productNotFound:
            return "Subscription product not found"
        }
    }
}
