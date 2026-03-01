import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var loading = false
    @State private var errorMsg: String? = nil
    @State private var showEmailForm = false

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 160)
                    Text("bet that.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                VStack(spacing: 14) {

                    // ── Email Auth Form (expandable) ──────────────────
                    if showEmailForm {
                        VStack(spacing: 10) {

                            // Toggle sign up / sign in
                            HStack {
                                Button { withAnimation { isSignUp = false } } label: {
                                    Text("Sign In")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(!isSignUp ? .black : theme.textSecondary)
                                        .frame(maxWidth: .infinity).frame(height: 36)
                                        .background(!isSignUp ? Color.snapsGreen : Color.clear,
                                                    in: RoundedRectangle(cornerRadius: 10))
                                }
                                Button { withAnimation { isSignUp = true } } label: {
                                    Text("Create Account")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(isSignUp ? .black : theme.textSecondary)
                                        .frame(maxWidth: .infinity).frame(height: 36)
                                        .background(isSignUp ? Color.snapsGreen : Color.clear,
                                                    in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(4)
                            .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))

                            if isSignUp {
                                SnapTextField(placeholder: "Display Name", text: $displayName)
                            }
                            SnapTextField(placeholder: "Email", text: $email, keyboard: .emailAddress)
                            SnapTextField(placeholder: "Password", text: $password, secure: true)

                            if let err = errorMsg {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.snapsDanger)
                                    .multilineTextAlignment(.center)
                            }

                            Button { Task { await submit() } } label: {
                                Group {
                                    if loading {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text(isSignUp ? "Create Account →" : "Sign In →")
                                            .font(.system(size: 17, weight: .black))
                                            .foregroundStyle(.black)
                                    }
                                }
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(Color.snapsGreen, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(SnapsButtonStyle())
                            .disabled(loading)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Email button ──────────────────────────────────
                    if !showEmailForm {
                        Button { withAnimation(.spring(duration: 0.3)) { showEmailForm = true } } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Continue with Email")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(white: 0.25), lineWidth: 1))
                        }
                        .buttonStyle(SnapsButtonStyle())
                    }

                    // ── Divider ───────────────────────────────────────
                    HStack {
                        Rectangle().fill(theme.border).frame(height: 1)
                        Text("or").font(.system(size: 13)).foregroundStyle(theme.textMuted).padding(.horizontal, 12)
                        Rectangle().fill(theme.border).frame(height: 1)
                    }

                    // ── Guest ─────────────────────────────────────────
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { isLoggedIn = true }
                    } label: {
                        Text("Continue as Guest →")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color.snapsGreen, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.snapsGreen.opacity(0.35), radius: 12, y: 4)
                    }
                    .buttonStyle(SnapsButtonStyle())

                    Text("Your data stays on this device as a guest.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    // ── Submit ────────────────────────────────────────────────────────

    func submit() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMsg = "Please fill in all fields."; return
        }
        loading = true
        errorMsg = nil
        do {
            let user: UserProfile
            if isSignUp {
                let name = displayName.isEmpty ? email.components(separatedBy: "@").first ?? "Player" : displayName
                user = try await appState.repo.signUp(email: email, password: password,
                                                       username: name.lowercased().replacingOccurrences(of: " ", with: ""),
                                                       displayName: name)
            } else {
                user = try await appState.repo.signIn(email: email, password: password)
            }
            appState.currentUser = user
            withAnimation(.easeInOut(duration: 0.3)) { isLoggedIn = true }
        } catch {
            errorMsg = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Text Field Component

struct SnapTextField: View {
    @Environment(\.colorScheme) private var colorScheme
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border, lineWidth: 1))
    }
}
