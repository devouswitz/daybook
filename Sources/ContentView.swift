import SwiftUI
import AppKit

// MARK: - Type styling

extension EntryType {
    var color: Color {
        switch self {
        case .general: return .teal
        case .reflection: return .orange
        case .dream: return .indigo
        case .fitness: return .green
        case .travel: return .blue
        case .reading: return .brown
        }
    }
}

// MARK: - Filter

enum EntryFilter: Hashable {
    case all
    case type(EntryType)

    var label: String {
        switch self {
        case .all: return "All Entries"
        case .type(let t): return t.label
        }
    }

    func matches(_ entry: JournalEntry) -> Bool {
        switch self {
        case .all: return true
        case .type(let t): return entry.type == t
        }
    }
}

// MARK: - Editor routing

struct EditorContext: Identifiable {
    let id = UUID()
    var entry: JournalEntry?
    var decrypted: (title: String, text: String)?
}

// MARK: - Content view

struct ContentView: View {
    @EnvironmentObject private var store: JournalStore

    @State private var searchText = ""
    @State private var filter: EntryFilter = .all
    @State private var editorContext: EditorContext?
    @State private var pendingDelete: JournalEntry?
    @State private var unlockTarget: JournalEntry?
    @State private var showInsights = false
    @State private var showSettings = false

    private var visibleEntries: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.entries.filter { entry in
            guard filter.matches(entry) else { return false }
            guard !query.isEmpty else { return true }
            guard !entry.isLocked else { return false }
            let haystack = [entry.title, entry.text, entry.location ?? "",
                            entry.workout ?? "", entry.book ?? ""]
                .joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
    }

    private var monthGroups: [(month: Date, label: String, entries: [JournalEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleEntries) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.date
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return grouped.keys.sorted(by: >).map { month in
            (month, formatter.string(from: month), grouped[month] ?? [])
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.4)
                if visibleEntries.isEmpty {
                    emptyState
                } else {
                    feed
                }
            }
            newEntryButton
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editorContext) { context in
            EntryEditorView(entry: context.entry, decrypted: context.decrypted)
                .environmentObject(store)
        }
        .sheet(isPresented: $showInsights) {
            InsightsView().environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            PasscodeSettingsView().environmentObject(store)
        }
        .sheet(item: $unlockTarget) { entry in
            UnlockView {
                openLocked(entry)
            }
            .environmentObject(store)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let entry = pendingDelete {
                    store.delete(id: entry.id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("\"\(pendingDelete?.displayTitle ?? "")\" will be removed. This cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .daybookNewEntry)) { _ in
            editorContext = EditorContext(entry: nil, decrypted: nil)
        }
    }

    private func openLocked(_ entry: JournalEntry) {
        guard let content = store.decryptedContent(of: entry) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            editorContext = EditorContext(entry: entry, decrypted: content)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daybook")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                statsBadge
            }
            HStack(spacing: 8) {
                searchField
                filterMenu
                iconButton("chart.bar.fill", help: "Insights") { showInsights = true }
                if store.hasPasscode && store.isUnlocked {
                    iconButton("lock.open.fill", help: "Lock journal now") { store.relock() }
                }
                iconButton("gearshape.fill", help: store.hasPasscode ? "Change passcode" : "Set a passcode") {
                    showSettings = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 38)
        .padding(.bottom, 14)
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var statsBadge: some View {
        HStack(spacing: 10) {
            if store.streak >= 2 {
                Label("\(store.streak) day streak", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
            }
            Text("\(store.entryCount) \(store.entryCount == 1 ? "entry" : "entries")")
                .foregroundStyle(.secondary)
        }
        .font(.callout.weight(.medium))
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                Label("All Entries", systemImage: "tray.full").tag(EntryFilter.all)
                Divider()
                ForEach(EntryType.allCases) { type in
                    Label(type.label, systemImage: type.icon).tag(EntryFilter.type(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle\(filter == .all ? "" : ".fill")")
                Text(filter.label)
            }
            .font(.callout.weight(.medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: Feed

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(monthGroups, id: \.month) { group in
                    Text(group.label)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .padding(.leading, 4)
                    ForEach(group.entries) { entry in
                        EntryCard(entry: entry)
                            .environmentObject(store)
                            .onTapGesture { open(entry) }
                            .contextMenu {
                                Button("Edit") { open(entry) }
                                Button("Delete", role: .destructive) {
                                    pendingDelete = entry
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 90)
        }
    }

    private func open(_ entry: JournalEntry) {
        if entry.isLocked {
            if store.isUnlocked, let content = store.decryptedContent(of: entry) {
                editorContext = EditorContext(entry: entry, decrypted: content)
            } else {
                unlockTarget = entry
            }
        } else {
            editorContext = EditorContext(entry: entry, decrypted: nil)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "book.closed.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty && filter == .all ? "Start your first entry" : "No matching entries")
                .font(.title3.weight(.semibold))
            Text(searchText.isEmpty && filter == .all
                 ? "A few honest lines a day is plenty."
                 : "Try a different search or filter.")
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: New entry button

    private var newEntryButton: some View {
        Button {
            editorContext = EditorContext(entry: nil, decrypted: nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: .indigo.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 22)
        .help("New Entry (Cmd+N)")
    }
}

// MARK: - Entry card

struct EntryCard: View {
    @EnvironmentObject private var store: JournalStore
    let entry: JournalEntry

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var previewText: String {
        entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.isLocked ? "lock.fill" : entry.type.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(entry.isLocked ? Color.secondary : entry.type.color)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(entry.isLocked
                                  ? Color.primary.opacity(0.08)
                                  : entry.type.color.opacity(0.14))
                )
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.displayTitle)
                    .font(.headline)
                    .foregroundStyle(entry.isLocked ? .secondary : .primary)
                    .lineLimit(1)

                if entry.isLocked {
                    Text("Enter your passcode to read this entry.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else if !previewText.isEmpty && previewText != entry.displayTitle {
                    Text(previewText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if !entry.photos.isEmpty && !entry.isLocked {
                    HStack(spacing: 6) {
                        ForEach(entry.photos.prefix(3), id: \.self) { name in
                            if let img = NSImage(contentsOf: store.photoURL(name)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 46, height: 46)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                        if entry.photos.count > 3 {
                            Text("+\(entry.photos.count - 3)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 46, height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                    }
                    .padding(.top, 2)
                }

                detailChipsRow

                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: entry.date))
                    Text("·")
                    Text(Self.timeFormatter.string(from: entry.date))
                    Text("·")
                    Text(entry.type.label)
                        .foregroundStyle(entry.type.color)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var detailChipsRow: some View {
        let chips = detailChips
        if !chips.isEmpty {
            HStack(spacing: 6) {
                ForEach(chips, id: \.1) { icon, label in
                    HStack(spacing: 3) {
                        if icon.isEmpty {
                            Text(label).font(.caption)
                        } else {
                            Image(systemName: icon).font(.caption2)
                            Text(label).font(.caption)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
    }

    private var detailChips: [(String, String)] {
        var chips: [(String, String)] = []
        if let l = entry.location, !l.isEmpty { chips.append(("mappin.and.ellipse", l)) }
        if let w = entry.workout, !w.isEmpty { chips.append(("figure.run", w)) }
        if let b = entry.book, !b.isEmpty { chips.append(("book", b)) }
        if let m = entry.mood { chips.append(("", "\(Mood.emoji(for: m)) \(Mood.label(for: m))")) }
        return chips
    }
}
