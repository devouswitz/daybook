import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let onUnlocked: () -> Void

    @State private var passcode = ""
    @State private var failed = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            JournalTheme.canvas.ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(JournalTheme.accentSoft)
                        .frame(width: 64, height: 64)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(JournalTheme.accent)
                }
                VStack(spacing: 4) {
                    Text("Unlock your journal")
                        .font(.title3.weight(.bold))
                    Text("Enter your Daybook passcode to read private entries.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                SecureField("Passcode", text: $passcode)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 13)
                    .frame(height: 42)
                    .background(JournalTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(failed ? Color.red.opacity(0.65) : JournalTheme.stroke)
                    }
                    .focused($focused)
                    .onSubmit(attempt)

                if failed {
                    Label("That passcode did not match. Try again.", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Unlock", action: attempt)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(JournalTheme.accent)
                        .disabled(passcode.isEmpty)
                }
            }
            .padding(24)
            .journalCard(radius: 22, shadow: 0.08)
            .padding(22)
        }
        .frame(width: 380)
        .onAppear { focused = true }
    }

    private func attempt() {
        if store.unlock(passcode: passcode) {
            dismiss()
            onUnlocked()
        } else {
            failed = true
            passcode = ""
        }
    }
}

struct PasscodeSettingsView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            JournalTheme.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(JournalTheme.accentSoft)
                            .frame(width: 44, height: 44)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(JournalTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.hasPasscode ? "Change passcode" : "Protect your journal")
                            .font(.title3.weight(.bold))
                        Text("Private entries are encrypted on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("One passcode protects every private entry you choose to lock. If you forget it, those entries cannot be recovered.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    if store.hasPasscode {
                        secureField("Current passcode", text: $current)
                            .focused($focused)
                    }
                    secureField("New passcode", text: $new1)
                    secureField("Repeat new passcode", text: $new2)
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 10) {
                    if store.hasPasscode && store.isUnlocked {
                        Button("Lock now") {
                            store.relock()
                            dismiss()
                        }
                        .foregroundStyle(JournalTheme.accent)
                    }
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(JournalTheme.accent)
                        .disabled(new1.isEmpty)
                }
            }
            .padding(24)
            .journalCard(radius: 22, shadow: 0.08)
            .padding(22)
        }
        .frame(width: 460)
        .onAppear { focused = true }
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(JournalTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(JournalTheme.stroke)
            }
    }

    private func save() {
        guard new1 == new2 else {
            error = "The new passcodes do not match."
            return
        }
        guard new1.count >= 4 else {
            error = "Use at least 4 characters."
            return
        }
        if store.setPasscode(current: store.hasPasscode ? current : nil, new: new1) {
            dismiss()
        } else {
            error = "The current passcode is incorrect."
            current = ""
        }
    }
}
