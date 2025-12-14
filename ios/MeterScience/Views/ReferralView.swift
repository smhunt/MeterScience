import SwiftUI

struct ReferralView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var showShareSheet = false
    @State private var copiedToClipboard = false
    @State private var referralCodeInput = ""
    @State private var applyingCode = false
    @State private var applyError: String?
    @State private var applySuccess = false

    var referralCode: String {
        auth.currentUser?.referralCode ?? "------"
    }

    var referralCount: Int {
        auth.currentUser?.referralCount ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                ReferralHeaderView(referralCount: referralCount)

                // Your Code Section
                YourCodeSection(
                    code: referralCode,
                    copiedToClipboard: $copiedToClipboard,
                    showShareSheet: $showShareSheet
                )

                // Rewards Ladder
                RewardsLadderView(currentReferrals: referralCount)

                // Apply a Code
                ApplyCodeSection(
                    codeInput: $referralCodeInput,
                    isLoading: $applyingCode,
                    error: $applyError,
                    success: $applySuccess,
                    onApply: applyReferralCode
                )
            }
            .padding()
        }
        .navigationTitle("Referrals")
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareMessage])
        }
    }

    var shareMessage: String {
        """
        Join me on MeterScience! 📊

        Track your utility meters, earn XP, and help citizen science.

        Use my referral code: \(referralCode)

        Download: https://meterscience.app
        """
    }

    func applyReferralCode() {
        guard !referralCodeInput.isEmpty else { return }

        applyingCode = true
        applyError = nil
        applySuccess = false

        Task {
            do {
                _ = try await APIService.shared.applyReferral(code: referralCodeInput.uppercased())
                await auth.refreshUser()
                applySuccess = true
                referralCodeInput = ""
            } catch let error as APIError {
                applyError = error.localizedDescription
            } catch {
                applyError = error.localizedDescription
            }
            applyingCode = false
        }
    }
}

// MARK: - Referral Header

struct ReferralHeaderView: View {
    let referralCount: Int

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Invite Friends, Earn Rewards")
                .font(.title2.bold())

            Text("Share your code and unlock free premium features when friends join!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Current Progress
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.pink)
                Text("\(referralCount) friends joined")
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.pink.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Your Code Section

struct YourCodeSection: View {
    let code: String
    @Binding var copiedToClipboard: Bool
    @Binding var showShareSheet: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Your Referral Code")
                .font(.headline)

            // Code Display
            HStack(spacing: 4) {
                ForEach(Array(code), id: \.self) { char in
                    Text(String(char))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .frame(width: 36, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = code
                    copiedToClipboard = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedToClipboard = false
                    }
                } label: {
                    Label(copiedToClipboard ? "Copied!" : "Copy", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Rewards Ladder

struct RewardsLadderView: View {
    let currentReferrals: Int

    let rewards: [(count: Int, reward: String, icon: String)] = [
        (1, "1 month Neighbor tier free", "gift"),
        (5, "25% off forever", "percent"),
        (10, "Block tier for life", "building.2"),
        (25, "District tier for life", "map")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rewards Ladder")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(rewards, id: \.count) { reward in
                    RewardRow(
                        count: reward.count,
                        reward: reward.reward,
                        icon: reward.icon,
                        isUnlocked: currentReferrals >= reward.count,
                        currentProgress: currentReferrals
                    )

                    if reward.count != rewards.last?.count {
                        Rectangle()
                            .fill(currentReferrals >= reward.count ? Color.green : Color(.systemGray4))
                            .frame(width: 2, height: 20)
                            .padding(.leading, 19)
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

struct RewardRow: View {
    let count: Int
    let reward: String
    let icon: String
    let isUnlocked: Bool
    let currentProgress: Int

    var body: some View {
        HStack(spacing: 12) {
            // Progress Circle
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.green : Color(.systemGray5))
                    .frame(width: 40, height: 40)

                if isUnlocked {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                } else {
                    Text("\(count)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(reward)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)

                if !isUnlocked {
                    Text("\(count - currentProgress) more to go")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isUnlocked ? .green : .secondary)
        }
    }
}

// MARK: - Apply Code Section

struct ApplyCodeSection: View {
    @Binding var codeInput: String
    @Binding var isLoading: Bool
    @Binding var error: String?
    @Binding var success: Bool

    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Have a referral code?")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("Enter code", text: $codeInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button {
                    onApply()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Apply")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(codeInput.isEmpty || isLoading)
            }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if success {
                Label("Code applied successfully!", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ReferralView()
    }
}
