# Daybook

A lightweight native macOS journaling app in the style of Apple's iPhone Journal app: a single-window card feed, entry types, date tracking, and nothing else to manage.

## Features

- Card feed grouped by month, newest first
- Three entry types, each with its own icon and color: General (teal), Reflection (orange), Dream (indigo)
- Every entry has an editable date and time
- Search across titles and body text, plus a type filter
- Streak counter (consecutive days with at least one entry; survives until end of the next day)
- Reflection entries offer rotating prompts ("What was I wrong about recently?", "Who helped me this week?", ...)
- Cmd+N for a new entry; Return saves, Escape cancels
- Closing the window quits the app

## Data

Entries live in a single human-readable JSON file:

`~/Library/Application Support/Daybook/entries.json`

Dates are ISO8601. If the file is ever unreadable, Daybook backs it up to `entries.backup.json` instead of overwriting it. Back up or sync that folder and you have your whole journal.

## Building

```
./build.sh          # run tests, build build/Daybook.app
./build.sh test     # store tests only
./build.sh install  # build and copy to /Applications
```

Requires only the Xcode Command Line Tools (no Xcode). Note: CLT 26.3 on this machine ships a stale `usr/include/swift/module.modulemap` that conflicts with `bridging.modulemap` and breaks every Foundation build. `build.sh` works around it with a Clang VFS overlay (`build/overlay.yaml`) that masks the stale file without touching system files. If a future CLT update removes the stale file, the overlay becomes a harmless no-op.

## Layout

- `Sources/Models.swift`: entry model, JSON store, streak logic, prompts
- `Sources/DaybookApp.swift`: app entry point, window, menu commands
- `Sources/ContentView.swift`: feed, cards, search, filter
- `Sources/EntryEditorView.swift`: new/edit sheet
- `tools/store_tests.swift`: store round-trip tests
- `tools/make_icon.swift`: generates the app icon
