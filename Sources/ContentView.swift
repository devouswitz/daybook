import SwiftUI
import AppKit

enum EntryFilter: Hashable {
    case all
    case bookmarked
    case photos
    case locations
    case type(EntryType)

    var label: String {
        switch self {
        case .all: return "All Entries"
        case .bookmarked: return "Bookmarked"
        case .photos: return "Photos"
        case .locations: return "Places"
        case .type(let type): return type.label
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "line.3.horizontal.decrease"
        case .bookmarked: return "bookmark.fill"
        case .photos: return "photo.on.rectangle.angled"
        case .locations: return "mappin.and.ellipse"
        case .type(let type): return type.icon
        }
    }

    func matches(_ entry: JournalEntry) -> Bool {
        switch self {
        case .all: return true
        case .bookmarked: return entry.isBookmarked
        case .photos: return !entry.photos.isEmpty
        case .locations: return !(entry.location ?? "").isEmpty
        case .type(let type): return entry.type == type
        }
    }
}

struct EditorContext: Identifiable {
    let id = UUID()
    var entry: JournalEntry?
    var decrypted: (title: String, text: String)?
}

struct ContentView: View {
    @EnvironmentObject private var store: JournalStore

    @State private var searchText = ""
    @State private var filter: EntryFilter = .all
    @State private var selectedDay: Date?
    @State private var editorContext: EditorContext?
    @State private var pendingDelete: JournalEntry?
    @State private var unlockTarget: JournalEntry?
    @State private var showInsights = false
    @State private var showSettings = false
    @State private var showCalendar = false

    private let calendar = Calendar.current

    private var visibleEntries: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.entries.filter { entry in
            guard filter.matches(entry) else { return false }
            if let selectedDay, !calendar.isDate(entry.date, inSameDayAs: selectedDay) {
                return false
            }
            guard !query.isEmpty else { return true }
            guard !entry.isLocked else { return false }
            let haystack = [entry.title, entry.text, entry.location ?? "",
                            entry.workout ?? "", entry.book ?? ""]
                .joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
    }

    private var monthGroups: [(month: Date, label: String, entries: [JournalEntry])] {
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
        GeometryReader { proxy in
            let compact = proxy.size.width < 560
            ZStack(alignment: compact ? .bottom : .bottomTrailing) {
                backgroundLayer
                VStack(spacing: 0) {
                    header
                    if visibleEntries.isEmpty {
                        emptyState
                    } else {
                        feed
                    }
                }
                newEntryButton(compact: compact)
            }
        }
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
                if let entry = pendingDelete { store.delete(id: entry.id) }
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

    private var backgroundLayer: some View {
        ZStack {
            JournalTheme.canvas
            RadialGradient(
                colors: [JournalTheme.accent.opacity(0.075), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 440
            )
        }
        .ignoresSafeArea()
    }

    private func openLocked(_ entry: JournalEntry) {
        guard let content = store.decryptedContent(of: entry) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            editorContext = EditorContext(entry: entry, decrypted: content)
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daybook")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                habitBadge
            }

            HStack(spacing: 8) {
                searchField
                filterMenu
                calendarButton
                toolbarButton("chart.bar.fill", help: "Insights") {
                    showInsights = true
                }
                if store.hasPasscode && store.isUnlocked {
                    toolbarButton("lock.open.fill", help: "Lock journal now") {
                        store.relock()
                    }
                }
                toolbarButton("gearshape.fill", help: store.hasPasscode ? "Change passcode" : "Set a passcode") {
                    showSettings = true
                }
            }

            if let selectedDay {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .foregroundStyle(JournalTheme.accent)
                    Text("Showing \(selectedDay.formatted(date: .long, time: .omitted))")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button {
                        self.selectedDay = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show all dates")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(JournalTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(JournalTheme.accent.opacity(0.15))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 38)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(JournalTheme.stroke).frame(height: 1)
        }
    }

    private var habitBadge: some View {
        HStack(spacing: 8) {
            if store.streak > 0 {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(store.streak) day\(store.streak == 1 ? "" : "s")")
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(JournalTheme.accent)
                Text("\(store.entryCount)")
            }
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(JournalTheme.surfaceRaised)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(JournalTheme.stroke) }
        .help("\(store.entryCount) total entries")
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search your journal", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(JournalTheme.surfaceRaised)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(JournalTheme.stroke) }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                Label("All Entries", systemImage: "tray.full").tag(EntryFilter.all)
                Label("Bookmarked", systemImage: "bookmark.fill").tag(EntryFilter.bookmarked)
                Label("Photos", systemImage: "photo.on.rectangle.angled").tag(EntryFilter.photos)
                Label("Places", systemImage: "mappin.and.ellipse").tag(EntryFilter.locations)
                Divider()
                ForEach(EntryType.allCases) { type in
                    Label(type.label, systemImage: type.icon).tag(EntryFilter.type(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: filter == .all ? "line.3.horizontal.decrease" : filter.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(filter == .all ? Color.primary : JournalTheme.accent)
                .frame(width: 36, height: 36)
                .background(filter == .all ? JournalTheme.surfaceRaised : JournalTheme.accentSoft)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(filter == .all ? JournalTheme.stroke : JournalTheme.accent.opacity(0.22))
                }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(filter == .all ? "Filter entries" : "Filtered by \(filter.label)")
    }

    private var calendarButton: some View {
        toolbarButton(selectedDay == nil ? "calendar" : "calendar.badge.checkmark", help: "Choose a date",
                      isSelected: selectedDay != nil) {
            showCalendar.toggle()
        }
        .popover(isPresented: $showCalendar, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse by date")
                    .font(.headline)
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { selectedDay ?? Date() },
                        set: { selectedDay = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                if selectedDay != nil {
                    Button("Show all dates") {
                        selectedDay = nil
                        showCalendar = false
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .frame(width: 280)
        }
    }

    private func toolbarButton(_ systemName: String, help: String, isSelected: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(JournalIconButtonStyle(isSelected: isSelected))
        .help(help)
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(monthGroups, id: \.month) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.label.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(0.9)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(group.entries.count)")
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 4)

                        ForEach(group.entries) { entry in
                            EntryCard(
                                entry: entry,
                                onOpen: { open(entry) },
                                onBookmark: { store.toggleBookmark(id: entry.id) },
                                onDelete: { pendingDelete = entry }
                            )
                            .environmentObject(store)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 106)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(JournalTheme.accentSoft)
                    .frame(width: 82, height: 82)
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(JournalTheme.accent)
            }
            Text(emptyStateTitle)
                .font(.title2.weight(.bold))
            Text(emptyStateMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if searchText.isEmpty && filter == .all && selectedDay == nil {
                Button("Write your first entry") {
                    editorContext = EditorContext(entry: nil, decrypted: nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(JournalTheme.accent)
                .controlSize(.large)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var emptyStateIcon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        if selectedDay != nil { return "calendar" }
        if filter == .bookmarked { return "bookmark" }
        return "book.closed"
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty { return "No matching entries" }
        if selectedDay != nil { return "Nothing written that day" }
        if filter == .bookmarked { return "No bookmarks yet" }
        if filter != .all { return "No entries in this view" }
        return "Start your journal"
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty { return "Try a different word or clear your filters." }
        if selectedDay != nil { return "Choose another date or return to all entries." }
        if filter == .bookmarked { return "Bookmark the moments you want to revisit." }
        if filter != .all { return "Choose a different filter to keep browsing." }
        return "A few honest lines are enough. Capture one detail you want to remember."
    }

    private func newEntryButton(compact: Bool) -> some View {
        Button {
            editorContext = EditorContext(entry: nil, decrypted: nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(JournalTheme.accent)
                .clipShape(Circle())
                .overlay { Circle().stroke(.white.opacity(0.22), lineWidth: 1) }
                .shadow(color: JournalTheme.accent.opacity(0.38), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.trailing, compact ? 0 : 25)
        .padding(.bottom, compact ? 8 : 24)
        .help("New Entry (Cmd+N)")
        .accessibilityLabel("New entry")
    }
}

struct EntryCard: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let entry: JournalEntry
    let onOpen: () -> Void
    let onBookmark: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var previewText: String {
        entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !entry.photos.isEmpty && !entry.isLocked {
                JournalPhotoCollage(names: entry.photos, height: entry.photos.count == 1 ? 210 : 220)
                    .environmentObject(store)
            }

            VStack(alignment: .leading, spacing: 10) {
                if entry.isLocked {
                    HStack(spacing: 9) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(JournalTheme.accent)
                        Text("Private entry")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(entry.displayTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(entry.isLocked ? Color.secondary : Color.primary)
                    .lineLimit(2)

                if entry.isLocked {
                    Text("Unlock your journal to read this entry.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if !previewText.isEmpty && previewText != entry.displayTitle {
                    Text(previewText)
                        .font(.system(size: 14.5))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .lineLimit(entry.photos.isEmpty ? 4 : 3)
                }

                detailChipsRow

                HStack(spacing: 7) {
                    Label(entry.type.label, systemImage: entry.type.icon)
                        .foregroundStyle(entry.type.color)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(Self.dateFormatter.string(from: entry.date))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(Self.timeFormatter.string(from: entry.date))
                    Spacer(minLength: 4)
                    Button(action: onBookmark) {
                        Image(systemName: entry.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(entry.isBookmarked ? JournalTheme.accent : Color.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(entry.isBookmarked ? "Remove bookmark" : "Bookmark entry")

                    Menu {
                        Button("Edit", systemImage: "pencil", action: onOpen)
                        Button(entry.isBookmarked ? "Remove Bookmark" : "Bookmark",
                               systemImage: entry.isBookmarked ? "bookmark.slash" : "bookmark",
                               action: onBookmark)
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 25, height: 24)
                            .background(JournalTheme.surfaceMuted)
                            .clipShape(Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Entry actions")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(JournalTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isHovering ? JournalTheme.accent.opacity(0.24) : JournalTheme.stroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0.09), radius: isHovering ? 18 : 12, y: isHovering ? 9 : 5)
        .offset(y: isHovering && !reduceMotion ? -2 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onOpen)
        .onHover { hovering in isHovering = hovering }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .contextMenu {
            Button("Edit", action: onOpen)
            Button(entry.isBookmarked ? "Remove Bookmark" : "Bookmark", action: onBookmark)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open entry", onOpen)
    }

    @ViewBuilder
    private var detailChipsRow: some View {
        let chips = Array(detailChips.prefix(3))
        if !chips.isEmpty {
            HStack(spacing: 6) {
                ForEach(chips, id: \.1) { icon, label in
                    Label(label, systemImage: icon)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(JournalTheme.surfaceMuted)
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detailChips: [(String, String)] {
        var chips: [(String, String)] = []
        if let location = entry.location, !location.isEmpty {
            chips.append(("mappin.and.ellipse", location))
        }
        if let workout = entry.workout, !workout.isEmpty {
            chips.append(("figure.run", workout))
        }
        if let book = entry.book, !book.isEmpty {
            chips.append(("book", book))
        }
        if let mood = entry.mood {
            chips.append(("face.smiling", Mood.label(for: mood)))
        }
        return chips
    }
}
