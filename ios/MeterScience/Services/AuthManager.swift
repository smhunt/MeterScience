import Foundation
import SwiftUI

/// Manages authentication state and token storage
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: UserResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let tokenKey = "meterscience_auth_token"
    private let userKey = "meterscience_user"

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    private init() {
        // Check for existing token on init
        if token != nil {
            isAuthenticated = true
            loadCachedUser()
        }
    }

    // MARK: - Auth Actions

    func register(email: String?, displayName: String, password: String?) async {
        isLoading = true
        error = nil

        do {
            let response = try await APIService.shared.register(
                email: email,
                displayName: displayName,
                password: password
            )
            handleAuthSuccess(response)
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Registration failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await APIService.shared.login(email: email, password: password)
            handleAuthSuccess(response)
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() {
        token = nil
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    func refreshUser() async {
        guard isAuthenticated else { return }

        do {
            let user = try await APIService.shared.getCurrentUser()
            currentUser = user
            cacheUser(user)
        } catch APIError.unauthorized {
            logout()
        } catch {
            print("Failed to refresh user: \(error)")
        }
    }

    // MARK: - Helpers

    private func handleAuthSuccess(_ response: AuthResponse) {
        token = response.accessToken
        currentUser = response.user
        isAuthenticated = true
        cacheUser(response.user)
    }

    private func cacheUser(_ user: UserResponse) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func loadCachedUser() {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(UserResponse.self, from: data) else {
            return
        }
        currentUser = user
    }
}

// MARK: - Auth Views

struct LoginView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo
                VStack(spacing: 8) {
                    Text("📊")
                        .font(.system(size: 64))
                    Text("MeterScience")
                        .font(.largeTitle.bold())
                    Text("Citizen Science for Utility Monitoring")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                Spacer()

                // Form
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)

                    if let error = auth.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            if isSignUp {
                                await auth.register(email: email, displayName: displayName, password: password)
                            } else {
                                await auth.login(email: email, password: password)
                            }
                        }
                    } label: {
                        if auth.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isLoading || email.isEmpty || password.isEmpty || (isSignUp && displayName.isEmpty))

                    Button {
                        withAnimation {
                            isSignUp.toggle()
                            auth.error = nil
                        }
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Skip for now
                Button {
                    Task {
                        await auth.register(email: nil, displayName: "Guest", password: nil)
                    }
                } label: {
                    Text("Continue as Guest")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

#Preview {
    LoginView()
}
