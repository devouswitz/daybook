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

    init(entry: JournalEntry?, decrypted: (title: String, text: String)? = nil) {
        self.existing = entry
        let initialType = entry?.type ?? .general
        _type = State(initialValue: initialType)
        _date = State(initialValue: entry?.date ?? Date())
        _title = State(initialValue: decrypted?.title ?? entry?.title ?? "")
        _text = State(initialValue: decrypted?.text ?? entry?.text ?? "")
        _location = State(initialValue: entry?.location ?? "")
        _workout = State(initialValue: entry?.workout ?? "")
        _book = State(initialValue: entry?.book ?? "")
        _mood = State(initialValue: entry?.mood)
        _photos = State(initialValue: entry?.photos ?? [])
        _wantsLock = State(initialValue: entry?.isLocked ?? false)
        _prompt = State(initialValue: WritingPrompts.random(for: initialType))
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
        ZStack {
            JournalTheme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                editorHeader
                ScrollView {
                    VStack(spacing: 14) {
                        typeSelector
                        promptCard
                        writingPaper
                        attachmentBar
                        detailsCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(minWidth: 700, minHeight: 690)
        .onAppear { bodyFocused = true }
        .onChange(of: type) { _, newType in
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
                .environmentObject(store)
                .onDisappear { wantsLock = store.hasPasscode && store.isUnlocked && wantsLock }
        }
        .sheet(isPresented: $unlockPrompt) {
            UnlockView { }
                .environmentObject(store)
        }
    }

    // MARK: - Header

    private var editorHeader: some View {
        HStack(spacing: 12) {
            Button(action: cancel) {
                Image(systemName: "xmark")
            }
            .buttonStyle(JournalIconButtonStyle(size: 34))
            .keyboardShortcut(.cancelAction)
            .help("Cancel")

            VStack(alignment: .leading, spacing: 1) {
                Text(existing == nil ? "New Entry" : "Edit Entry")
                    .font(.headline)
                Text(type.label)
                    .font(.caption)
                    .foregroundStyle(type.color)
            }

            Spacer()

            DatePicker("Entry date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()

            Button {
                toggleLockIntent()
            } label: {
                Image(systemName: wantsLock ? "lock.fill" : "lock.open")
            }
            .buttonStyle(JournalIconButtonStyle(isSelected: wantsLock, size: 34))
            .help(wantsLock ? "This entry will stay private" : "Lock this entry")

            if existing != nil {
                Menu {
                    Button("Delete Entry", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(JournalTheme.surfaceRaised)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(JournalTheme.stroke) }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More actions")
            }

            Button("Done", action: save)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(JournalTheme.accent)
                .controlSize(.large)
                .disabled(!canSave)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(JournalTheme.stroke).frame(height: 1)
        }
    }

    // MARK: - Writing surface

    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(EntryType.allCases) { candidate in
                    Button {
                        type = candidate
                    } label: {
                        Label(candidate.label, systemImage: candidate.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .foregroundStyle(type == candidate ? candidate.color : Color.secondary)
                            .background(type == candidate ? candidate.color.opacity(0.14) : JournalTheme.surfaceRaised)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(type == candidate ? candidate.color.opacity(0.24) : JournalTheme.stroke)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promptCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(type.color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("REFLECTION PROMPT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Text(prompt)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("Use") {
                title = prompt
                bodyFocused = true
            }
            .buttonStyle(.borderless)
            Button {
                prompt = WritingPrompts.random(for: type, excluding: prompt)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(JournalIconButtonStyle(size: 30))
            .help("Another prompt")
        }
        .padding(11)
        .background(type.color.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(type.color.opacity(0.13))
        }
    }

    private var writingPaper: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, photos.isEmpty ? 2 : 12)

            if !photos.isEmpty {
                editorPhotoGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
            }

            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            Rectangle()
                .fill(JournalTheme.stroke)
                .frame(height: 1)
                .padding(.horizontal, 18)

            TextEditor(text: $text)
                .font(.system(size: 16))
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(minHeight: 285)
                .focused($bodyFocused)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(type.placeholder)
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 18)
                            .padding(.leading, 18)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                if wantsLock {
                    Label("Private entry", systemImage: "lock.fill")
                        .foregroundStyle(JournalTheme.accent)
                }
                Spacer()
                Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .journalCard(radius: 22, shadow: 0.08)
    }

    @ViewBuilder
    private var editorPhotoGrid: some View {
        if photos.count == 1 {
            editorPhoto(photos[0])
                .frame(maxWidth: .infinity)
                .frame(height: 235)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            let columns = [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
            ]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(photos, id: \.self) { name in
                    editorPhoto(name)
                        .frame(height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func editorPhoto(_ name: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = NSImage(contentsOf: store.photoURL(name)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        JournalTheme.surfaceMuted
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .clipped()

            Button {
                photos.removeAll { $0 == name }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(7)
            .help("Remove photo")
        }
    }

    // MARK: - Attachments

    private var attachmentBar: some View {
        HStack(spacing: 8) {
            attachmentButton("mappin.and.ellipse", "Location", isOn: showLocation) {
                showLocation.toggle()
                if !showLocation { location = "" }
            }
            attachmentButton("figure.run", "Workout", isOn: showWorkout) {
                showWorkout.toggle()
                if !showWorkout { workout = "" }
            }
            attachmentButton("book", "Book", isOn: showBook) {
                showBook.toggle()
                if !showBook { book = "" }
            }
            attachmentButton("face.smiling", "Mood", isOn: showMood) {
                showMood.toggle()
                if !showMood { mood = nil }
            }
            attachmentButton("photo.on.rectangle.angled", "Photos", isOn: !photos.isEmpty) {
                importPhotos()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(JournalTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(JournalTheme.stroke)
        }
    }

    private func attachmentButton(_ icon: String, _ label: String, isOn: Bool,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? JournalTheme.accent : Color.secondary)
                .background(isOn ? JournalTheme.accentSoft : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailsCard: some View {
        if showLocation || showWorkout || showBook || showMood {
            VStack(spacing: 10) {
                if showLocation {
                    detailField("mappin.and.ellipse", "Where are you?", $location)
                }
                if showWorkout {
                    detailField("figure.run", "Workout details", $workout)
                }
                if showBook {
                    detailField("book", "Book title, author, or pages", $book)
                }
                if showMood {
                    moodPicker
                }
            }
            .padding(14)
            .journalCard(radius: 18, shadow: 0.035)
        }
    }

    private func detailField(_ icon: String, _ placeholder: String, _ value: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(JournalTheme.accent)
                .frame(width: 20)
            TextField(placeholder, text: value)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(JournalTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(JournalTheme.stroke)
        }
    }

    private var moodPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "face.smiling")
                .foregroundStyle(JournalTheme.accent)
                .frame(width: 20)
            ForEach(Mood.range, id: \.self) { value in
                Button {
                    mood = value
                } label: {
                    Text(Mood.emoji(for: value))
                        .font(.system(size: mood == value ? 23 : 18))
                        .opacity(mood == nil || mood == value ? 1 : 0.4)
                        .frame(width: 30, height: 30)
                        .background(mood == value ? JournalTheme.accentSoft : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(Mood.label(for: value))
                .accessibilityLabel(Mood.label(for: value))
            }
            if let mood {
                Text(Mood.label(for: mood))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(JournalTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(JournalTheme.stroke)
        }
    }

    // MARK: - Actions

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
        let lockable = wantsLock && store.hasPasscode && store.isUnlocked

        var entry = existing ?? JournalEntry()
        entry.type = type
        entry.date = date
        entry.location = location.isEmpty ? nil : location
        entry.workout = workout.isEmpty ? nil : workout
        entry.book = book.isEmpty ? nil : book
        entry.mood = showMood ? mood : nil

        let removed = Set(existing?.photos ?? []).subtracting(photos)
        for name in removed { store.removePhotoFile(name) }
        entry.photos = photos

        if let existing, existing.isLocked {
            if lockable {
                entry.title = ""
                entry.text = ""
                store.update(entry)
                store.updateLocked(entry, title: title, text: text)
            } else if store.isUnlocked {
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
            if lockable { store.lockEntry(id: entry.id) }
        }
        dismiss()
    }
}
