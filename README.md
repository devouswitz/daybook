<h1 align="center">Daybook</h1>

<p align="center">
  <strong>Write today down. Find the pattern later.</strong>
</p>

<p align="center">
  A quiet, native macOS journal for the moments, details, and habits worth keeping.
</p>

---

Daybook is for the days that do not need a grand story. Open one calm window, write a few lines, add the context you want to remember, and come back when you want to see the shape of your life.

It is built in native SwiftUI. There is no account requirement, no browser shell, and no cloud service in the app.

## A simple rhythm

1. **Start an entry** with a thought, a memory, or a prompt.
2. **Choose a lens** that fits the moment: General, Reflection, Dream, Fitness, Travel, or Reading.
3. **Keep the details** that make it yours, from photos and places to workouts, books, and state of mind.
4. **Return to the thread** through search, bookmarks, filters, and the patterns in Insights.

## The journal

| Feed | Editor | Insights |
| --- | --- | --- |
| Browse a photo-led card feed grouped by month, with search, date browsing, bookmarks, and filters. | Write on a paper-like surface with prompts, a shuffle button, word count, date and time controls, and optional details. | See current and best streaks, entries this month, total words, a 15-week activity heatmap, type breakdown, and weekday rhythm. |

The editor keeps the surface simple while leaving room for the details that matter. Add photos, a location, a workout, a book, or a 1 to 7 state-of-mind rating. Cmd+N opens a new entry. Return saves and Escape cancels. Closing the window quits the app.

## Private by design

Set one journal passcode, then lock the entries that should stay private. Locked titles and bodies are sealed with AES-GCM using a PBKDF2-HMAC-SHA256 key derived with 200,000 rounds. The passcode itself is never stored. Attached photos remain unencrypted, so add only photos you are comfortable keeping in the local store.

A forgotten passcode makes locked entries unrecoverable by design.

## Build

Daybook requires macOS 14 or later and the Xcode Command Line Tools.

```sh
./build.sh          # run tests and build build/Daybook.app
./build.sh test     # run the store tests only
./build.sh install  # build and copy to /Applications
```

The project uses plain `swiftc` and has no package dependency step. `build.sh` carries a small Clang VFS overlay for a broken Command Line Tools 26.3 install; on a healthy toolchain it is a harmless no-op.

## Your entries stay yours

Daybook keeps its journal on this Mac at `~/Library/Application Support/Daybook/`:

- `entries.json`: human-readable JSON with ISO8601 dates. Locked title and body content appears as base64 ciphertext.
- `settings.json`: the passcode salt and verifier, never the passcode itself.
- `photos/`: attached images copied into the local store.

If a file is unreadable, Daybook backs it up instead of overwriting it. Version 1 journals migrate automatically on first save. The repository contains source, tests, and build scripts only; journal entries and photos stay outside Git.

<details>
<summary><strong>Source map</strong></summary>

- `Sources/Models.swift`: entry types, journal model, JSON store, migration, prompts, and insights math
- `Sources/Crypto.swift`: PBKDF2 key derivation and AES-GCM sealing for locked entries
- `Sources/DaybookApp.swift`: app entry point, window, and menu commands
- `Sources/ContentView.swift`: feed, cards, search, filters, date browsing, and unlock flow
- `Sources/EntryEditorView.swift`: editor, prompts, details, photos, and locking
- `Sources/InsightsView.swift`: streaks, heatmap, type breakdown, and weekday rhythm
- `Sources/PasscodeViews.swift`: passcode setup and unlock prompts
- `Sources/JournalTheme.swift`: visual tokens, cards, controls, and photo layout
- `tools/store_tests.swift`: store, migration, insights, and crypto tests
- `tools/make_icon.swift`: generates the app icon

</details>

## Not included yet

True macOS home-screen widgets require a WidgetKit app extension, which needs Xcode's build system rather than plain `swiftc`. Insights covers that ground in-app for now.
