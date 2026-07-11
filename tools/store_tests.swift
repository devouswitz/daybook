// Round-trip tests for JournalStore, run against a temp directory.
// Compiled together with Sources/Models.swift; see build.sh test.
import Foundation

var failures = 0

func check(_ condition: Bool, _ label: String) {
    if condition {
        print("PASS: \(label)")
    } else {
        print("FAIL: \(label)")
        failures += 1
    }
}

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("daybook-tests-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: tempDir) }

// 1. Add + persist + reload
let store = JournalStore(directory: tempDir)
check(store.entries.isEmpty, "fresh store is empty")

let calendar = Calendar.current
let now = Date()
let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!

let e1 = JournalEntry(date: now, type: .reflection, title: "On being wrong", text: "I was wrong about the deploy.")
let e2 = JournalEntry(date: yesterday, type: .dream, title: "", text: "Flying over a lake.",
                      createdAt: lastWeek, modifiedAt: lastWeek)
let e3 = JournalEntry(date: lastWeek, type: .general, title: "Groceries", text: "")
store.add(e1)
store.add(e2)
store.add(e3)
check(store.entryCount == 3, "three entries after adds")
check(store.entries.first?.id == e1.id, "entries sorted newest first")

let reloaded = JournalStore(directory: tempDir)
check(reloaded.entries == store.entries, "reload round-trips entries exactly")

// 2. Update
var edited = e2
edited.title = "Lake dream"
edited.type = .dream
reloaded.update(edited)
let afterUpdate = JournalStore(directory: tempDir)
check(afterUpdate.entries.first(where: { $0.id == e2.id })?.title == "Lake dream", "update persists")
let mod = afterUpdate.entries.first(where: { $0.id == e2.id })!
check(mod.modifiedAt > mod.createdAt, "modifiedAt bumped on update")

// 3. Delete
afterUpdate.delete(id: e3.id)
let afterDelete = JournalStore(directory: tempDir)
check(afterDelete.entryCount == 2, "delete persists")
check(!afterDelete.entries.contains(where: { $0.id == e3.id }), "deleted entry gone")

// 4. Streak: entries today + yesterday = 2
check(afterDelete.streak == 2, "streak counts today plus yesterday (got \(afterDelete.streak))")

// Streak with a gap: only entry 3 days ago = 0
let gapDir = tempDir.appendingPathComponent("gap")
let gapStore = JournalStore(directory: gapDir)
gapStore.add(JournalEntry(date: calendar.date(byAdding: .day, value: -3, to: now)!))
check(gapStore.streak == 0, "streak is 0 when latest entry is 3 days old")

// Streak surviving via yesterday only
let yDir = tempDir.appendingPathComponent("yesterday")
let yStore = JournalStore(directory: yDir)
yStore.add(JournalEntry(date: yesterday))
yStore.add(JournalEntry(date: calendar.date(byAdding: .day, value: -2, to: now)!))
check(yStore.streak == 2, "streak survives when latest entry is yesterday")

// 5. displayTitle fallbacks
check(JournalEntry(title: " ", text: "First line\nSecond").displayTitle == "First line", "displayTitle falls back to first body line")
check(JournalEntry(title: "", text: "").displayTitle == "Untitled", "displayTitle falls back to Untitled")
check(JournalEntry(title: "", text: "  \n\nActual\n").displayTitle == "Actual", "displayTitle skips blank lines")

// 6. Corrupt file does not crash and gets backed up
let corruptDir = tempDir.appendingPathComponent("corrupt")
try FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)
try "not json {{{".data(using: .utf8)!.write(to: corruptDir.appendingPathComponent("entries.json"))
let corruptStore = JournalStore(directory: corruptDir)
check(corruptStore.entries.isEmpty, "corrupt file loads as empty store")
check(FileManager.default.fileExists(atPath: corruptDir.appendingPathComponent("entries.backup.json").path),
      "corrupt file backed up before it can be overwritten")

// 7. ISO8601 dates in the file (portability check)
let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
check(raw.contains("\"version\""), "file has version field")

// 8. v1 file (no v2 keys) loads with defaults
let v1Dir = tempDir.appendingPathComponent("v1")
try FileManager.default.createDirectory(at: v1Dir, withIntermediateDirectories: true)
let v1JSON = """
{"version":1,"entries":[{"id":"AAAAAAAA-0000-0000-0000-000000000001",
"date":"2026-07-01T10:00:00Z","type":"reflection","title":"Old entry",
"text":"Written before v2.","createdAt":"2026-07-01T10:00:00Z",
"modifiedAt":"2026-07-01T10:00:00Z"}]}
"""
try v1JSON.data(using: .utf8)!.write(to: v1Dir.appendingPathComponent("entries.json"))
let v1Store = JournalStore(directory: v1Dir)
check(v1Store.entryCount == 1, "v1 file loads")
let migrated = v1Store.entries[0]
check(migrated.title == "Old entry" && !migrated.isLocked && migrated.photos.isEmpty
      && !migrated.isBookmarked && migrated.mood == nil && migrated.location == nil,
      "v1 entry gets current defaults")
v1Store.add(JournalEntry(title: "New", text: "post-migration write"))
let v1Raw = try String(contentsOf: v1Store.fileURL, encoding: .utf8)
check(v1Raw.contains("\"version\" : 3"), "migrated file saves as version 3")

// 9. v2 detail fields round-trip
let d2 = tempDir.appendingPathComponent("v2fields")
let s2 = JournalStore(directory: d2)
s2.add(JournalEntry(type: .fitness, title: "Badminton", text: "Won 2 of 3.",
                    location: "Utrecht", workout: "Badminton, 90 min",
                    book: nil, mood: 6, photos: ["a.png"]))
let s2r = JournalStore(directory: d2)
let e2r = s2r.entries[0]
check(e2r.workout == "Badminton, 90 min" && e2r.location == "Utrecht"
      && e2r.mood == 6 && e2r.photos == ["a.png"] && e2r.type == .fitness,
      "v2 fields round-trip")

// Bookmark lifecycle
let bookmarkedID = s2r.entries[0].id
s2r.toggleBookmark(id: bookmarkedID)
let bookmarkedReload = JournalStore(directory: d2)
check(bookmarkedReload.entries[0].isBookmarked, "bookmark persists")
bookmarkedReload.toggleBookmark(id: bookmarkedID)
check(!JournalStore(directory: d2).entries[0].isBookmarked, "bookmark can be removed")

// 10. Passcode + lock lifecycle
let d3 = tempDir.appendingPathComponent("locks")
let s3 = JournalStore(directory: d3)
check(!s3.hasPasscode, "no passcode initially")
check(s3.setPasscode(current: nil, new: "hunter2"), "passcode set")
check(s3.hasPasscode && s3.isUnlocked, "setting passcode unlocks session")
s3.add(JournalEntry(title: "Secret feelings", text: "The plaintext I want hidden."))
let secretID = s3.entries[0].id
check(s3.lockEntry(id: secretID), "entry locks")
let lockedRaw = try String(contentsOf: s3.fileURL, encoding: .utf8)
check(!lockedRaw.contains("Secret feelings") && !lockedRaw.contains("plaintext I want hidden"),
      "no plaintext on disk after lock")
check(lockedRaw.contains("\"isLocked\" : true"), "lock flag persisted")

// Reload: locked until passcode entered
let s3r = JournalStore(directory: d3)
check(s3r.hasPasscode && !s3r.isUnlocked, "fresh load requires passcode")
check(s3r.decryptedContent(of: s3r.entries[0]) == nil, "no decryption without key")
check(!s3r.unlock(passcode: "wrong"), "wrong passcode rejected")
check(s3r.unlock(passcode: "hunter2"), "right passcode accepted")
let dec = s3r.decryptedContent(of: s3r.entries[0])
check(dec?.title == "Secret feelings" && dec?.text == "The plaintext I want hidden.",
      "locked entry decrypts to original content")

// Edit while staying locked
check(s3r.updateLocked(s3r.entries[0], title: "Secret feelings", text: "Edited ciphertext body."),
      "locked edit re-encrypts")
check(s3r.decryptedContent(of: s3r.entries[0])?.text == "Edited ciphertext body.",
      "locked edit readable after re-encrypt")

// Passcode change re-encrypts
check(!s3r.setPasscode(current: "nope", new: "newpass"), "passcode change rejects wrong current")
check(s3r.setPasscode(current: "hunter2", new: "newpass99"), "passcode change accepted")
let s3c = JournalStore(directory: d3)
check(s3c.unlock(passcode: "newpass99"), "new passcode works after change")
check(s3c.decryptedContent(of: s3c.entries[0])?.title == "Secret feelings",
      "locked entry survives passcode change")

// Permanent unlock restores plaintext
check(s3c.unlockEntryPermanently(id: secretID), "permanent unlock")
let s3f = JournalStore(directory: d3)
check(s3f.entries[0].title == "Secret feelings" && !s3f.entries[0].isLocked
      && s3f.entries[0].cipher == nil,
      "plaintext restored after removing lock")

// Relock forgets the key
s3c.relock()
check(!s3c.isUnlocked, "relock clears session")

// 11. Insights math
let d4 = tempDir.appendingPathComponent("insights")
let s4 = JournalStore(directory: d4)
let day = 86400.0
let base = calendar.startOfDay(for: now)
// 3-day run last week (days -9,-8,-7), plus today
for offset in [-9.0, -8.0, -7.0, 0.0] {
    s4.add(JournalEntry(date: base.addingTimeInterval(offset * day + 3600),
                        title: "e", text: "one two three"))
}
check(s4.longestStreak == 3, "longest streak finds the 3-day run (got \(s4.longestStreak))")
check(s4.totalWords == 12, "total words across entries (got \(s4.totalWords))")
check(s4.dailyCounts(days: 3).count == 3, "dailyCounts returns requested window")
check(s4.dailyCounts(days: 1).last?.count == 1, "today counted in dailyCounts")
check(s4.countsByType.first?.type == .general && s4.countsByType.first?.count == 4,
      "countsByType aggregates")

print(failures == 0 ? "ALL TESTS PASSED" : "\(failures) TEST(S) FAILED")
exit(failures == 0 ? 0 : 1)
