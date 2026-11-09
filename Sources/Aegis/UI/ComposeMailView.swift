import SwiftUI

@MainActor
public final class ComposeMailFormState: ObservableObject {
    @Published public var selectedAccountId: UUID
    @Published public var toText: String = ""
    @Published public var ccText: String = ""
    @Published public var subjectText: String = ""
    @Published public var bodyText: String = ""
    @Published public var isSending: Bool = false
    @Published public var errorMessage: String? = nil

    public init(initialAccountId: UUID, initialTo: String = "", initialSubject: String = "", initialBody: String = "") {
        self.selectedAccountId = initialAccountId
        self.toText = initialTo
        self.subjectText = initialSubject
        self.bodyText = initialBody
    }
}

public struct ComposeMailView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var mailManager = MailManager.shared
    @ObservedObject var form: ComposeMailFormState

    public init(appState: AppState, form: ComposeMailFormState) {
        self.appState = appState
        self.form = form
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.accentColor)
                    Text("New Message")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button(action: {
                    mailManager.isComposePresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            VStack(spacing: 0) {
                // From field
                HStack {
                    Text("From:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)

                    Picker("", selection: $form.selectedAccountId) {
                        ForEach(mailManager.providerAccounts) { acc in
                            Text("\(acc.displayName) <\(acc.email)>").tag(acc.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                Divider()

                // To field
                HStack {
                    Text("To:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)

                    TextField("Recipient email address", text: $form.toText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Subject field
                HStack {
                    Text("Subject:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)

                    TextField("Subject", text: $form.subjectText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Message Body
                TextEditor(text: $form.bodyText)
                    .font(.system(size: 13))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let err = form.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                }

                Divider()

                // Bottom Action Bar
                HStack {
                    Button(action: {
                        Task {
                            await handleSend()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if form.isSending {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                Text("Sending...")
                                    .font(.system(size: 12, weight: .bold))
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 11))
                                Text("Send Immediately")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(form.toText.isEmpty ? Color.secondary.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(form.toText.isEmpty || form.isSending)

                    Spacer()

                    Button(action: {
                        mailManager.isComposePresented = false
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Discard Draft")
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 520, height: 480)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 12)
    }

    private func handleSend() async {
        guard let account = mailManager.accounts.first(where: { $0.id == form.selectedAccountId }) else {
            form.errorMessage = "Please select a valid sender account."
            return
        }

        form.isSending = true
        form.errorMessage = nil

        let recipients = form.toText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        do {
            try await mailManager.sendEmail(
                fromAccount: account,
                to: recipients,
                subject: form.subjectText.isEmpty ? "(No Subject)" : form.subjectText,
                body: form.bodyText
            )
            mailManager.isComposePresented = false
        } catch {
            form.errorMessage = error.localizedDescription
        }
        form.isSending = false
    }
}
