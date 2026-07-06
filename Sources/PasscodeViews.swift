import SwiftUI

// MARK: - Unlock prompt

struct UnlockView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let onUnlocked: () -> Void

    @State private var passcode = ""
    @State private var failed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(.indigo)
            Text("Enter your journal passcode")
                .font(.headline)
            SecureField("Passcode", text: $passcode)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($focused)
                .onSubmit(attempt)
            if failed {
                Text("That's not it. Try again.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Unlock") { attempt() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(passcode.isEmpty)
            }
        }
        .padding(26)
        .frame(width: 320)
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

// MARK: - Set / change passcode

struct PasscodeSettingsView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(store.hasPasscode ? "Change passcode" : "Set a journal passcode",
                  systemImage: "lock.shield")
                .font(.headline)
            Text("One passcode covers the journal; you choose which entries it locks. Locked entries are encrypted on disk. If you forget the passcode, locked entries cannot be recovered.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.hasPasscode {
                SecureField("Current passcode", text: $current)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
            }
            SecureField("New passcode", text: $new1)
                .textFieldStyle(.roundedBorder)
            SecureField("Repeat new passcode", text: $new2)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                if store.hasPasscode && store.isUnlocked {
                    Button("Lock journal now") {
                        store.relock()
                        dismiss()
                    }
                    .font(.callout)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(new1.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 380)
        .onAppear { focused = true }
    }

    private func save() {
        guard new1 == new2 else {
            error = "The new passcodes don't match."
            return
        }
        guard new1.count >= 4 else {
            error = "Use at least 4 characters."
            return
        }
        if store.setPasscode(current: store.hasPasscode ? current : nil, new: new1) {
            dismiss()
        } else {
            error = "Current passcode is wrong."
            current = ""
        }
    }
}
