# Daybook

A lightweight native macOS journaling app in the style of Apple's iPhone Journal app: a single-window card feed, entry types, and enough structure to make writing a habit without making it a chore.

## Features

- Card feed grouped by month, newest first, with search and type filters
- Six entry types, each with its own icon, color, and writing prompts: General (teal), Reflection (orange), Dream (indigo), Fitness (green), Travel (blue), Reading (brown)
- **Locked entries**: set one journal passcode, lock any entry individually. Locked entries are encrypted on disk with AES-GCM (key derived via PBKDF2, 200k rounds; the passcode itself is never stored). No passcode, no plaintext. Photos attached to locked entries stay unencrypted; only title and body are sealed.
- Entry details: attach photos, a location, a workout, a book, and a 1 to 7 state-of-mind rating; each shows as chips on the card
- A roomier editor: per-type prompts with a shuffle button, live word count, editable date and time
- **Insights**: current and best streaks, entries this month, total words, a 15-week activity heatmap, type breakdown, and weekday rhythm
- Cmd+N for a new entry; Return saves, Escape cancels; closing the window quits

## Data

Everything lives in `~/Library/Application Support/Daybook/`:

- `entries.json`: the journal, human-readable JSON, ISO8601 dates. Locked entries appear as base64 ciphertext.
- `settings.json`: passcode salt and verifier (never the passcode)
- `photos/`: attached images

If a file is ever unreadable, Daybook backs it up instead of overwriting it. Version 1 journals migrate automatically on first save. Forgetting the passcode makes locked entries unrecoverable; that is the point of the feature, so pick accordingly.

## Building

```
./build.sh          # run tests, build build/Daybook.app
./build.sh test     # store tests only (45 of them)
./build.sh install  # build and copy to /Applications
```

Requires only the Xcode Command Line Tools (no Xcode). `build.sh` carries a Clang VFS overlay that works around a broken CLT 26.3 install (a stale `usr/include/swift/module.modulemap`); on healthy toolchains it is a harmless no-op.

## Layout

- `Sources/Models.swift`: entry model, JSON store, lock lifecycle, insights math, prompts
- `Sources/Crypto.swift`: PBKDF2 key derivation and AES-GCM sealing for locked entries
- `Sources/DaybookApp.swift`: app entry point, window, menu commands
- `Sources/ContentView.swift`: feed, cards, search, filters, unlock flow
- `Sources/EntryEditorView.swift`: editor with types, prompts, details, photos, locking
- `Sources/InsightsView.swift`: stats, heatmap, breakdowns
- `Sources/PasscodeViews.swift`: passcode setup and unlock prompts
- `tools/store_tests.swift`: store, migration, and crypto tests
- `tools/make_icon.swift`: generates the app icon

## Not included (yet)

True macOS home-screen widgets require a WidgetKit app extension, which needs Xcode's build system rather than plain `swiftc`; the Insights view covers that ground in-app for now.
