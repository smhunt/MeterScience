import SwiftUI

@main
struct MeterScienceApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Check subscription status on app launch
                    await subscriptionManager.checkSubscriptionStatus()
                }
        }
    }
}
