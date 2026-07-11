import Foundation
import CryptoKit

// MARK: - Entry type

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case general
    case reflection
    case dream
    case fitness
    case travel
    case reading

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .reflection: return "Reflection"
        case .dream: return "Dream"
        case .fitness: return "Fitness"
        case .travel: return "Travel"
        case .reading: return "Reading"
        }
    }

    var icon: String {
        switch self {
        case .general: return "square.and.pencil"
        case .reflection: return "sparkles"
        case .dream: return "moon.stars.fill"
        case .fitness: return "figure.run"
        case .travel: return "airplane"
        case .reading: return "book.fill"
        }
    }

    var placeholder: String {
        switch self {
        case .general: return "What happened today?"
        case .reflection: return "Be honest. No one is grading this."
        case .dream: return "Get it down before it fades."
        case .fitness: return "How did it feel? What's improving?"
        case .travel: return "Where are you? What's different about it?"
        case .reading: return "What stuck with you? Any lines worth keeping?"
        }
    }
}

// MARK: - Mood (state of mind, 1 to 7)

enum Mood {
    static let range = 1...7
    static let emoji = ["😖", "😞", "😕", "😐", "🙂", "😊", "😄"]
    static let labels = [
        "Very unpleasant", "Unpleasant", "Slightly unpleasant", "Neutral",
        "Slightly pleasant", "Pleasant", "Very pleasant",
    ]
    static func emoji(for value: Int) -> String { emoji[max(1, min(7, value)) - 1] }
    static func label(for value: Int) -> String { labels[max(1, min(7, value)) - 1] }
}

// MARK: - Entry

struct JournalEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var type: EntryType
    var title: String
    var text: String
    var createdAt: Date
    var modifiedAt: Date
    // v2 details
    var location: String?
    var workout: String?
    var book: String?
    var mood: Int?
    var photos: [String]
    var isBookmarked: Bool
    // v2 lock: when locked, title/text are emptied and cipher holds the
    // AES-GCM sealed JSON of {title, text}. Photos stay unencrypted (noted
    // in the UI); their file names remain listed.
    var isLocked: Bool
    var cipher: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: EntryType = .general,
        title: String = "",
        text: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        location: String? = nil,
        workout: String? = nil,
        book: String? = nil,
        mood: Int? = nil,
        photos: [String] = [],
        isBookmarked: Bool = false,
        isLocked: Bool = false,
        cipher: String? = nil
    ) {
        self.id = id
        self.date = date.roundedToSecond
        self.type = type
        self.title = title
        self.text = text
        self.createdAt = createdAt.roundedToSecond
        self.modifiedAt = modifiedAt.roundedToSecond
        self.location = location
        self.workout = workout
        self.book = book
        self.mood = mood
        self.photos = photos
        self.isBookmarked = isBookmarked
        self.isLocked = isLocked
        self.cipher = cipher
    }

    // Custom decoding so version 1 files (no v2 keys) load with defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        type = try c.decode(EntryType.self, forKey: .type)
        title = try c.decode(String.self, forKey: .title)
        text = try c.decode(String.self, forKey: .text)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        workout = try c.decodeIfPresent(String.self, forKey: .workout)
        book = try c.decodeIfPresent(String.self, forKey: .book)
        mood = try c.decodeIfPresent(Int.self, forKey: .mood)
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        isBookmarked = try c.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        cipher = try c.decodeIfPresent(String.self, forKey: .cipher)
    }

    /// Title if present, otherwise the first non-blank line of the body.
    var displayTitle: String {
        if isLocked { return "Locked entry" }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
    }

    var isEmpty: Bool {
        !isLocked
            && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

extension Date {
    /// ISO8601 on disk has whole-second precision, so entries hold
    /// whole-second dates in memory too. Keeps save/load round-trips exact.
    var roundedToSecond: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded())
    }
}

// MARK: - On-disk formats

private struct StoreFile: Codable {
    var version: Int
    var entries: [JournalEntry]
}

private struct SettingsFile: Codable {
    var version: Int
    var salt: String        // base64
    var verifier: String    // base64 SHA-256 of derived key
}

private struct LockedPayload: Codable {
    var title: String
    var text: String
}

// MARK: - Store

final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var isUnlocked = false

    let fileURL: URL
    let settingsURL: URL
    let photosDir: URL
    private let calendar = Calendar.current
    private var key: SymmetricKey?
    private var settings: SettingsFile?

    init(directory: URL? = nil) {
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0]
            dir = appSupport.appendingPathComponent("Daybook", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("entries.json")
        settingsURL = dir.appendingPathComponent("settings.json")
        photosDir = dir.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        load()
        loadSettings()
    }

    // MARK: Mutations

    func add(_ entry: JournalEntry) {
        entries.append(entry)
        sortAndSave()
    }

    func update(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.date = entry.date.roundedToSecond
        updated.modifiedAt = Date().roundedToSecond
        entries[index] = updated
        sortAndSave()
    }

    func delete(id: UUID) {
        if let entry = entries.first(where: { $0.id == id }) {
            for name in entry.photos {
                try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(name))
            }
        }
        entries.removeAll { $0.id == id }
        sortAndSave()
    }

    func toggleBookmark(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isBookmarked.toggle()
        entries[index].modifiedAt = Date().roundedToSecond
        sortAndSave()
    }

    // MARK: Photos

    /// Copy image files into the store's photos directory; returns stored names.
    func importPhotos(from urls: [URL]) -> [String] {
        var names: [String] = []
        for url in urls {
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
            let name = UUID().uuidString + "." + ext
            do {
                try FileManager.default.copyItem(at: url, to: photosDir.appendingPathComponent(name))
                names.append(name)
            } catch {
                NSLog("Daybook: photo import failed: \(error)")
            }
        }
        return names
    }

    func photoURL(_ name: String) -> URL { photosDir.appendingPathComponent(name) }

    func removePhotoFile(_ name: String) {
        try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(name))
    }

    // MARK: Passcode & lock

    var hasPasscode: Bool { settings != nil }

    /// Create or change the journal passcode. Changing requires the current
    /// one (locked entries get re-encrypted with the new key).
    @discardableResult
    func setPasscode(current: String?, new: String) -> Bool {
        if let existing = settings {
            guard let cur = current,
                  let saltData = Data(base64Encoded: existing.salt) else { return false }
            let oldKey = Crypto.deriveKey(passcode: cur, salt: saltData)
            guard Crypto.verifier(for: oldKey).base64EncodedString() == existing.verifier else {
                return false
            }
            // Re-encrypt every locked entry under the new key.
            let salt = Crypto.randomSalt()
            let newKey = Crypto.deriveKey(passcode: new, salt: salt)
            for i in entries.indices where entries[i].isLocked {
                guard let payload = decryptPayload(entries[i], key: oldKey),
                      let sealed = try? Crypto.seal(JSONEncoder().encode(payload), key: newKey)
                else { return false }
                entries[i].cipher = sealed.base64EncodedString()
            }
            settings = SettingsFile(version: 1, salt: salt.base64EncodedString(),
                                    verifier: Crypto.verifier(for: newKey).base64EncodedString())
            key = newKey
            isUnlocked = true
            saveSettings()
            sortAndSave()
            return true
        }
        let salt = Crypto.randomSalt()
        let newKey = Crypto.deriveKey(passcode: new, salt: salt)
        settings = SettingsFile(version: 1, salt: salt.base64EncodedString(),
                                verifier: Crypto.verifier(for: newKey).base64EncodedString())
        key = newKey
        isUnlocked = true
        saveSettings()
        return true
    }

    /// Verify the passcode and keep the derived key for this session.
    @discardableResult
    func unlock(passcode: String) -> Bool {
        guard let s = settings, let saltData = Data(base64Encoded: s.salt) else { return false }
        let candidate = Crypto.deriveKey(passcode: passcode, salt: saltData)
        guard Crypto.verifier(for: candidate).base64EncodedString() == s.verifier else {
            return false
        }
        key = candidate
        isUnlocked = true
        return true
    }

    /// Forget the session key; locked entries need the passcode again.
    func relock() {
        key = nil
        isUnlocked = false
    }

    /// Encrypt an entry's title and body in place. Requires an unlocked key.
    @discardableResult
    func lockEntry(id: UUID) -> Bool {
        guard let key, let idx = entries.firstIndex(where: { $0.id == id }) else { return false }
        var e = entries[idx]
        guard !e.isLocked else { return true }
        let payload = LockedPayload(title: e.title, text: e.text)
        guard let sealed = try? Crypto.seal(JSONEncoder().encode(payload), key: key) else {
            return false
        }
        e.cipher = sealed.base64EncodedString()
        e.title = ""
        e.text = ""
        e.isLocked = true
        entries[idx] = e
        sortAndSave()
        return true
    }

    /// Remove the lock and restore plaintext. Requires an unlocked key.
    @discardableResult
    func unlockEntryPermanently(id: UUID) -> Bool {
        guard let key, let idx = entries.firstIndex(where: { $0.id == id }) else { return false }
        var e = entries[idx]
        guard e.isLocked, let payload = decryptPayload(e, key: key) else { return false }
        e.title = payload.title
        e.text = payload.text
        e.isLocked = false
        e.cipher = nil
        entries[idx] = e
        sortAndSave()
        return true
    }

    /// Decrypted (title, text) of a locked entry for viewing/editing.
    func decryptedContent(of entry: JournalEntry) -> (title: String, text: String)? {
        guard let key, let payload = decryptPayload(entry, key: key) else { return nil }
        return (payload.title, payload.text)
    }

    /// Save edits to an entry that stays locked: re-encrypt the new content.
    @discardableResult
    func updateLocked(_ entry: JournalEntry, title: String, text: String) -> Bool {
        guard let key, let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        var e = entry
        let payload = LockedPayload(title: title, text: text)
        guard let sealed = try? Crypto.seal(JSONEncoder().encode(payload), key: key) else {
            return false
        }
        e.cipher = sealed.base64EncodedString()
        e.title = ""
        e.text = ""
        e.isLocked = true
        e.date = entry.date.roundedToSecond
        e.modifiedAt = Date().roundedToSecond
        entries[idx] = e
        sortAndSave()
        return true
    }

    private func decryptPayload(_ entry: JournalEntry, key: SymmetricKey) -> LockedPayload? {
        guard let cipher = entry.cipher,
              let data = Data(base64Encoded: cipher),
              let plain = try? Crypto.open(data, key: key),
              let payload = try? JSONDecoder().decode(LockedPayload.self, from: plain)
        else { return nil }
        return payload
    }

    // MARK: Stats & insights

    var entryCount: Int { entries.count }

    private var daySet: Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.date) })
    }

    /// Consecutive days with at least one entry, counting back from today.
    /// A streak also survives if the latest entry day is yesterday.
    var streak: Int {
        let days = daySet
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: Date())
        var cursor = today
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    var longestStreak: Int {
        let days = daySet.sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            if let next = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(next, inSameDayAs: days[i]) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    /// Word count across unlocked entries (locked text is not readable here).
    var totalWords: Int { entries.filter { !$0.isLocked }.reduce(0) { $0 + $1.wordCount } }

    var countsByType: [(type: EntryType, count: Int)] {
        EntryType.allCases
            .map { t in (t, entries.filter { $0.type == t }.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    /// Entry counts for Sunday through Saturday (calendar weekday order).
    var countsByWeekday: [Int] {
        var counts = [Int](repeating: 0, count: 7)
        for e in entries {
            counts[calendar.component(.weekday, from: e.date) - 1] += 1
        }
        return counts
    }

    /// Per-day entry counts for the trailing `days` days, oldest first.
    func dailyCounts(days: Int) -> [(day: Date, count: Int)] {
        let today = calendar.startOfDay(for: Date())
        var byDay: [Date: Int] = [:]
        for e in entries {
            byDay[calendar.startOfDay(for: e.date), default: 0] += 1
        }
        return (0..<days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return (day, byDay[day] ?? 0)
        }
    }

    var entriesThisMonth: Int {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return entries.filter {
            calendar.dateComponents([.year, .month], from: $0.date) == comps
        }.count
    }

    // MARK: Persistence

    private func sortAndSave() {
        entries.sort { $0.date > $1.date }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(StoreFile(version: 3, entries: entries))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Daybook: failed to save entries: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let file = try decoder.decode(StoreFile.self, from: data)
            entries = file.entries.sorted { $0.date > $1.date }
        } catch {
            NSLog("Daybook: failed to load entries: \(error)")
            let backup = fileURL.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    private func saveSettings() {
        guard let settings else { return }
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsURL) else { return }
        settings = try? JSONDecoder().decode(SettingsFile.self, from: data)
    }
}

// MARK: - Writing prompts (per type)

enum WritingPrompts {
    static let pools: [EntryType: [String]] = [
        .reflection: [
            "What did someone teach me today?",
            "What was I wrong about recently?",
            "Who helped me this week, and how?",
            "What is something I still do not understand?",
            "What feedback did I resist hearing?",
            "What went well today that I did not cause?",
            "Where did luck play a part in a recent win?",
            "What would I tell a friend who made my mistake?",
            "What am I grateful for right now?",
            "What did I avoid today, and why?",
        ],
        .general: [
            "Three things that happened today",
            "What am I looking forward to?",
            "Who did I talk to today?",
            "What took more energy than it should have?",
            "One small thing worth remembering",
        ],
        .dream: [
            "What do I remember first?",
            "How did it feel in the dream?",
            "Anything recurring in there?",
            "Who showed up, and why them?",
        ],
        .fitness: [
            "What did I train today?",
            "How is my body feeling?",
            "One rally or rep I'm proud of",
            "What is the next small goal?",
            "What did I skip, and what got in the way?",
        ],
        .travel: [
            "First impressions of this place",
            "What surprised me today?",
            "Something I want to remember from here",
            "What does this place smell and sound like?",
        ],
        .reading: [
            "What am I reading, and why this book?",
            "A passage that stuck with me",
            "Do I agree with the author?",
            "What would I ask the author?",
        ],
    ]

    static func random(for type: EntryType, excluding current: String? = nil) -> String {
        let pool = (pools[type] ?? pools[.general]!).filter { $0 != current }
        return pool.randomElement() ?? "What happened today?"
    }
}
