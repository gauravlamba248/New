import SwiftUI

@MainActor
public final class AddMailFormState: ObservableObject {
    @Published public var selectedProvider: MailProvider = .gmail
    @Published public var emailText: String = ""
    @Published public var passwordText: String = ""
    @Published public var displayNameText: String = ""
    @Published public var is2StepAuthActive: Bool = false
    @Published public var appPasswordText: String = ""
    @Published public var isConnecting: Bool = false
    @Published public var errorMessage: String? = nil

    public init(initialProvider: MailProvider = .gmail) {
        self.selectedProvider = initialProvider
    }
}

public struct AddMailAccountView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var mailManager = MailManager.shared
    @ObservedObject var form: AddMailFormState

    public init(appState: AppState, form: AddMailFormState) {
        self.appState = appState
        self.form = form
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: form.selectedProvider.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(providerColor)

                Text("Add \(form.selectedProvider.rawValue) Account")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                Button(action: {
                    mailManager.isAddAccountPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Provider Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Email Provider")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(MailProvider.allCases) { prov in
                                Button(action: {
                                    self.form.selectedProvider = prov
                                    self.form.errorMessage = nil
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: prov.iconName)
                                        Text(prov.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity)
                                    .background(form.selectedProvider == prov ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                    .foregroundColor(form.selectedProvider == prov ? .accentColor : .primary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(form.selectedProvider == prov ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Step 1: Email Address
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2. Email Address")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField(emailPlaceholder, text: $form.emailText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                            .font(.system(size: 12))
                    }

                    // Step 2: Password
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3. Password")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        SecureField("Enter your account password", text: $form.passwordText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                            .font(.system(size: 12))

                        if form.selectedProvider == .gmail && !form.is2StepAuthActive {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("Note: Google requires a 16-character App Password for native desktop IMAP clients.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }

                    // Step 4: 2-Step Authentication Handling
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $form.is2StepAuthActive) {
                            HStack(spacing: 4) {
                                Text("Two-Step Authentication (2FA) is \(form.is2StepAuthActive ? "ON" : "OFF")")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: form.is2StepAuthActive ? "shield.lefthalf.filled" : "shield")
                                    .foregroundColor(form.is2StepAuthActive ? .green : .secondary)
                            }
                        }
                        .toggleStyle(.checkbox)

                        if form.is2StepAuthActive {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("When 2FA is active, \(form.selectedProvider.rawValue) requires an App-Specific Password for direct TLS connections.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    SecureField("16-character App Password (e.g. abcd efgh ijkl mnop)", text: $form.appPasswordText)
                                        .textFieldStyle(.plain)
                                        .padding(8)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
                                        .font(.system(size: 11, design: .monospaced))

                                    Button(action: {
                                        appState.openBrowser(mode: .secure)
                                        if let url = URL(string: form.selectedProvider.twoStepAuthDocUrl) {
                                            appState.browserVM.navigate(to: url)
                                        }
                                        mailManager.isAddAccountPresented = false
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.right.square")
                                            Text("Get App Password")
                                                .font(.system(size: 10, weight: .semibold))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open \(form.selectedProvider.twoStepAuthTitle) in browser")
                                }
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    // Error Banner
                    if let err = form.errorMessage {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(err)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)

                                    if form.selectedProvider == .gmail && (err.contains("AUTHENTICATIONFAILED") || err.contains("Invalid credentials") || err.contains("Google blocks")) {
                                        Text("Why this happens: Your email and password are correct for google.com, but Google blocked standard password login for IMAP in 2022. Google requires a 16-character App Password.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)

                                        Button(action: {
                                            form.is2StepAuthActive = true
                                            if let url = URL(string: "https://myaccount.google.com/apppasswords") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.up.right.square.fill")
                                                Text("Get 16-Character Google App Password")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.15))
                                            .foregroundColor(.red)
                                            .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.top, 2)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Action Buttons
                    HStack {
                        Button("Cancel") {
                            mailManager.isAddAccountPresented = false
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)

                        Spacer()

                        Button(action: {
                            Task {
                                await handleLogin()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if form.isConnecting {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                    Text("Verifying...")
                                        .font(.system(size: 12, weight: .bold))
                                } else {
                                    Image(systemName: "lock.shield.fill")
                                    Text("Log In & Connect")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(form.emailText.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(form.emailText.isEmpty || form.isConnecting)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .frame(width: 440, height: 430)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var providerColor: Color {
        switch form.selectedProvider {
        case .gmail: return .red
        case .outlook: return .blue
        case .apple: return .primary
        }
    }

    private var emailPlaceholder: String {
        switch form.selectedProvider {
        case .gmail: return "username@gmail.com"
        case .outlook: return "username@outlook.com or hotmail.com"
        case .apple: return "username@icloud.com or me.com"
        }
    }

    private func handleLogin() async {
        form.isConnecting = true
        form.errorMessage = nil

        let email = form.emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPass = form.is2StepAuthActive ? form.appPasswordText : form.passwordText
        let password = rawPass.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")

        guard !email.isEmpty else {
            form.errorMessage = "Please enter an email address."
            form.isConnecting = false
            return
        }

        guard !password.isEmpty else {
            form.errorMessage = form.is2StepAuthActive ? "Please enter your 16-character App Password." : "Please enter your password."
            form.isConnecting = false
            return
        }

        do {
            _ = try await mailManager.addAccount(
                provider: form.selectedProvider,
                email: email,
                displayName: form.displayNameText.isEmpty ? email : form.displayNameText,
                password: password,
                is2FA: form.is2StepAuthActive,
                twoFactorCode: form.is2StepAuthActive ? password : nil
            )
            mailManager.selectedProvider = form.selectedProvider
            mailManager.isAddAccountPresented = false
        } catch {
            if let imapErr = error as? IMAPError {
                switch imapErr {
                case .twoFactorRequired(let msg):
                    self.form.is2StepAuthActive = true
                    self.form.errorMessage = msg
                default:
                    if form.selectedProvider == .gmail && !form.is2StepAuthActive {
                        self.form.is2StepAuthActive = true
                        self.form.errorMessage = "Google blocks regular passwords for desktop IMAP clients. Please enter your 16-character Google App Password above."
                    } else {
                        self.form.errorMessage = error.localizedDescription
                    }
                }
            } else {
                self.form.errorMessage = error.localizedDescription
            }
        }
        form.isConnecting = false
    }
}
