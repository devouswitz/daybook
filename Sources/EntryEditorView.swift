import SwiftUI
import AppKit

struct EntryEditorView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss

    let existing: JournalEntry?

    @State private var type: EntryType
    @State private var date: Date
    @State private var title: String
    @State private var text: String
    @State private var location: String
    @State private var workout: String
    @State private var book: String
    @State private var mood: Int?
    @State private var photos: [String]
    @State private var wantsLock: Bool

    @State private var prompt: String
    @State private var showLocation: Bool
    @State private var showWorkout: Bool
    @State private var showBook: Bool
    @State private var showMood: Bool
    @State private var confirmingDelete = false
    @State private var passcodeSetup = false
    @State private var unlockPrompt = false
    @State private var newlyImported: [String] = []
    @FocusState private var bodyFocused: Bool

    /// For a locked entry, pass the decrypted content in; fields stay empty otherwise.
    init(entry: JournalEntry?, decrypted: (title: String, text: String)? = nil) {
        self.existing = entry
        let t = entry?.type ?? .general
        _type = State(initialValue: t)
        _date = State(initialValue: entry?.date ?? Date())
        _title = State(initialValue: decrypted?.title ?? entry?.title ?? "")
        _text = State(initialValue: decrypted?.text ?? entry?.text ?? "")
        _location = State(initialValue: entry?.location ?? "")
        _workout = State(initialValue: entry?.workout ?? "")
        _book = State(initialValue: entry?.book ?? "")
        _mood = State(initialValue: entry?.mood)
        _photos = State(initialValue: entry?.photos ?? [])
        _wantsLock = State(initialValue: entry?.isLocked ?? false)
        _prompt = State(initialValue: WritingPrompts.random(for: t))
        _showLocation = State(initialValue: !(entry?.location ?? "").isEmpty)
        _showWorkout = State(initialValue: !(entry?.workout ?? "").isEmpty)
        _showBook = State(initialValue: !(entry?.book ?? "").isEmpty)
        _showMood = State(initialValue: entry?.mood != nil)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            typeChips
            promptBar
            TextField("Title (optional)", text: $title)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(fieldBackground)
            editorBody
            detailChips
            detailFields
            photoStrip
            footer
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 620)
        .onAppear { bodyFocused = true }
        .onChange(of: type) { newType in
            prompt = WritingPrompts.random(for: newType)
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                if let existing { store.delete(id: existing.id) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $passcodeSetup) {
            PasscodeSettingsView()
                .onDisappear { wantsLock = store.hasPasscode && store.isUnlocked && wantsLock }
        }
        .sheet(isPresented: $unlockPrompt) {
            UnlockView { }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text(existing == nil ? "New Entry" : "Edit Entry")
                .font(.title3.weight(.semibold))
            Spacer()
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EntryType.allCases) { t in
                    Button {
                        type = t
                    } label: {
                        Label(t.label, systemImage: t.icon)
                            .font(.callout.weight(type == t ? .bold : .regular))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(type == t ? t.color.opacity(0.2) : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(type == t ? t.color : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promptBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .foregroundStyle(type.color)
            Text(prompt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Use") {
                title = prompt
                bodyFocused = true
            }
            .font(.callout)
            Button {
                prompt = WritingPrompts.random(for: type, excluding: prompt)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Another prompt")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(type.color.opacity(0.08))
        )
    }

    private var editorBody: some View {
        TextEditor(text: $text)
            .font(.system(size: 15))
            .lineSpacing(3)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(fieldBackground)
            .frame(minHeight: 220)
            .focused($bodyFocused)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    // Match the caret's real origin: the 8pt wrapper padding plus
                    // NSTextView's 5pt line fragment padding, no extra vertical.
                    Text(type.placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8).padding(.leading, 13)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if wordCount > 0 {
                    Text("\(wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(6)
                }
            }
    }

    private var detailChips: some View {
        HStack(spacing: 6) {
            detailChip("mappin.and.ellipse", "Location", $showLocation) { location = "" }
            detailChip("figure.run", "Workout", $showWorkout) { workout = "" }
            detailChip("book", "Book", $showBook) { book = "" }
            detailChip("face.smiling", "Mood", $showMood) { mood = nil }
            Button {
                importPhotos()
            } label: {
                Label("Photos", systemImage: "photo.on.rectangle.angled")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func detailChip(_ icon: String, _ label: String, _ flag: Binding<Bool>,
                            onDisable: @escaping () -> Void) -> some View {
        Button {
            flag.wrappedValue.toggle()
            if !flag.wrappedValue { onDisable() }
        } label: {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(flag.wrappedValue ? Color.teal.opacity(0.18) : Color.primary.opacity(0.05))
                )
                .foregroundStyle(flag.wrappedValue ? .teal : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailFields: some View {
        if showLocation || showWorkout || showBook || showMood {
            VStack(spacing: 6) {
                if showLocation {
                    detailField("mappin.and.ellipse", "Where are you? (city, place)", $location)
                }
                if showWorkout {
                    detailField("figure.run", "Workout (e.g. Badminton, 90 min)", $workout)
                }
                if showBook {
                    detailField("book", "Book (title, author, pages)", $book)
                }
                if showMood {
                    HStack(spacing: 8) {
                        Image(systemName: "face.smiling").foregroundStyle(.secondary).frame(width: 18)
                        ForEach(Mood.range, id: \.self) { v in
                            Button {
                                mood = v
                            } label: {
                                Text(Mood.emoji(for: v))
                                    .font(.system(size: mood == v ? 24 : 18))
                                    .opacity(mood == v || mood == nil ? 1 : 0.4)
                            }
                            .buttonStyle(.plain)
                            .help(Mood.label(for: v))
                        }
                        if let mood {
                            Text(Mood.label(for: mood))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(fieldBackground)
                }
            }
        }
    }

    private func detailField(_ icon: String, _ placeholder: String, _ value: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 18)
            TextField(placeholder, text: value)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(fieldBackground)
    }

    @ViewBuilder
    private var photoStrip: some View {
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos, id: \.self) { name in
                        ZStack(alignment: .topTrailing) {
                            if let img = NSImage(contentsOf: store.photoURL(name)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            Button {
                                photos.removeAll { $0 == name }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(2)
                        }
                    }
                }
            }
            .frame(height: 68)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                toggleLockIntent()
            } label: {
                Label(wantsLock ? "Locked" : "Lock",
                      systemImage: wantsLock ? "lock.fill" : "lock.open")
                    .foregroundStyle(wantsLock ? .indigo : .secondary)
            }
            .help(wantsLock
                  ? "This entry will be encrypted with your journal passcode. Photos stay unencrypted."
                  : "Encrypt this entry with your journal passcode")

            if existing != nil {
                Button("Delete", role: .destructive) { confirmingDelete = true }
            }
            Spacer()
            Button("Cancel") { cancel() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: Actions

    private func importPhotos() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic, .webP, .tiff, .bmp]
        if panel.runModal() == .OK {
            let names = store.importPhotos(from: panel.urls)
            photos.append(contentsOf: names)
            newlyImported.append(contentsOf: names)
        }
    }

    private func toggleLockIntent() {
        if wantsLock {
            wantsLock = false
            return
        }
        if !store.hasPasscode {
            passcodeSetup = true
            wantsLock = true
        } else if !store.isUnlocked {
            unlockPrompt = true
            wantsLock = true
        } else {
            wantsLock = true
        }
    }

    private func cancel() {
        for name in newlyImported { store.removePhotoFile(name) }
        dismiss()
    }

    private func save() {
        // Locking needs a live key; fall back to saving unlocked if the
        // passcode flow was dismissed without finishing.
        let lockable = wantsLock && store.hasPasscode && store.isUnlocked

        var entry = existing ?? JournalEntry()
        entry.type = type
        entry.date = date
        entry.location = location.isEmpty ? nil : location
        entry.workout = workout.isEmpty ? nil : workout
        entry.book = book.isEmpty ? nil : book
        entry.mood = showMood ? mood : nil

        // Photo files removed in this session get cleaned off disk.
        let removed = Set(existing?.photos ?? []).subtracting(photos)
        for name in removed { store.removePhotoFile(name) }
        entry.photos = photos

        if let existing, existing.isLocked {
            if lockable {
                entry.title = ""
                entry.text = ""
                store.update(entry)          // persist details first
                store.updateLocked(entry, title: title, text: text)
            } else if store.isUnlocked {
                // Lock switched off: restore plaintext.
                entry.title = title
                entry.text = text
                entry.isLocked = false
                entry.cipher = nil
                store.update(entry)
            }
        } else {
            entry.title = title
            entry.text = text
            entry.isLocked = false
            entry.cipher = nil
            if existing == nil {
                store.add(entry)
            } else {
                store.update(entry)
            }
            if lockable {
                store.lockEntry(id: entry.id)
            }
        }
        dismiss()
    }
}
