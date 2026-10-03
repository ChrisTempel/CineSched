# CineSched — Film Production Scheduling & One-Line Schedule App

A macOS application for scheduling film shoots — visual calendar and stripboard scheduling, scene breakdown tagging, actor availability and conflict tracking, call sheets, vector PDF exports, and Final Draft script import.

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green)
![License](https://img.shields.io/badge/license-GPL--v3-lightgrey)

> **Free for the film community.** Built by a filmmaker, for filmmakers. If you find it useful, the best way to say thanks is to share it.

## Where this version comes from

This app has three layers of history worth knowing about:

- **The original CineSched**, created by Chris Tempel — a calendar-based scheduler built to solve his own need for a real film scheduling tool without the cost or complexity of commercial software.
- **The Stripboard, the monthly calendar with its day-inspector popup, bilingual English/Español support, the dynamic timeline cascade, vector PDF exports (including the "Plan de Rodaje" one-line schedule), calendar events, and notice banners** — all built by **alucardGonza**, who forked the original project and substantially reworked its interface and feature set. The Stripboard view and the overall visual redesign in particular are entirely their work, not a continuation of the original app's design.
- **This version** takes alucardGonza's fork as its base and layers on a round of bug fixes and personal customizations:
  - A real Sunday-first calendar week (the original fork's week and its exported PDF were both hardcoded Monday-first)
  - A toggleable cast row and a toggleable estimated-time display on calendar strips
  - User-customizable scene colors
  - Persisted view-mode and sidebar preferences
  - **Multi-language support removed** — the app is English-only now; see the note below if you're comparing against alucardGonza's original bilingual version
  - A serious Final Draft import bug fixed — scripts with a DualDialogue block (two characters' dialogue printed side by side) were silently losing every scene after that point; see [Script Import](#-script-import) below
  - Fixes to several drag-and-drop reliability issues (multi-select drags from the Boneyard, gesture-priority conflicts with starting a drag, and stuck day-highlighting after both undo/redo and ordinary drops)

If you're comparing notes with either of their versions: the project-file format is compatible in both directions for the fields both versions share, so a file made in one should open fine in another.

## ✨ Features

### 🗓️ Two ways to view your schedule

- **Full Month** — a traditional monthly calendar grid, Sunday-first, with a day-inspector popup (double-click any day) showing scene counts, page totals, estimated time, call sheet milestones (General Call, Lunch, Snack, Wrap, Basecamp), and quick actions to edit or export that day's call sheet.
- **Full Schedule** — a single continuous vertical scroll through every day in your production's date range, including unscheduled days, with no month-by-month pagination to click through. (Originally called "Shoot Days Only" in alucardGonza's fork, which filtered out a few kinds of days — this version renamed it and removed that filtering so it's a genuinely complete scroll.)
- Your last-used view (Full Month vs. Full Schedule, and whether the sidebar is open or collapsed) is remembered the next time you open the app.
- A separate **Stripboard** view is also available from the toolbar — the traditional paper-strips-on-a-corkboard layout ADs have used for decades, now digital, with a dynamic timeline cascade calculating start/end times for every scene and banner from call time to wrap.

### 📅 Visual Calendar Scheduling

- Drag-and-drop scene strips onto calendar days, individually or as a multi-selected group from the Boneyard
- Color-coded by INT/EXT and time of day (Day, Night, Dawn, Dusk, Afternoon), fully **user-customizable** (see below) — red is reserved for flagged strips
- **Send to Day…** — jump a scene (or selection) to any day via a graphical picker
- Drag entire days (scenes + call sheet) to reschedule — swaps content if the target day is occupied
- Fast custom hover tooltips show a scene's cast and summary
- Search the whole schedule (title, cast, or summary) and jump straight to a match, scheduled or not
- **View menu → Show Cast in Calendar** — adds a second row to every strip showing its cast, independent of whether the sidebar is open
- **View menu → Show Estimated Time Instead of Page Count** — swaps the eighths-of-a-page count on each strip for its estimated shoot time instead

### 🎨 Customizable Scene Colors

- View menu → Customize Scene Colors… lets you override any of the ten INT/EXT × time-of-day color combinations, plus Custom
- Changes apply everywhere a scene's color appears — the calendar, the Stripboard, and both PDF exporters all draw from the same source
- Reset All to Defaults restores the original industry-standard palette at any time

### 🚩 Notice Banners, Calendar Events & Auto-Meals

- Add company moves, meal breaks, and custom notice strips to any shoot day, with dynamic timeline sync
- Independent calendar events (travel days, rehearsals, scouting) that never pollute the Boneyard or scene counts

### 🎬 Scene Management & Breakdown Tagging

- Day, Night, Dawn, Dusk, Afternoon, or Custom type per scene
- "Boneyard" sidebar for unscheduled scenes, sortable, with multi-select drag onto any day
- Tag Extras, Props, Set Dressing, Wardrobe, Makeup/Hair, Vehicles, Special Equipment, Stunts, SFX, and VFX per scene
- **Breakdown Browser** — step through every scene in script order (regardless of scheduling status) to tag as you go
- **Export Scene Breakdowns** — one classic AD-style breakdown sheet per scene, script order

### 👥 Actor Availability, Conflicts & Schedule Lock

- Mark actor unavailable-date ranges in Production Setup; conflicts are scanned automatically and flagged red on the calendar
- **Scan for Conflicts** report jumps you straight to each one
- **Blackout days** — right-click a date to mark it (or every matching weekday) unavailable; scenes can still go there as working space, just flagged
- **Lock Schedule** snapshots each actor's working days; any later change gets flagged via a badge and a full Schedule Lock Report, without restricting further edits

### 📊 Days Out of Days (DOOD) & Vector Schedule Exports

- Standard industry DOOD codes (SW/W/H/WF/SWF/X) with an option to exclude Hold days entirely for productions that only pay for days on set
- Vector one-line shooting schedule PDF export, with time badges, milestone headers, and an end-of-day wrap summary
- Monthly calendar PDF export (2 pages: full-height grid, then a detailed daily breakdown)

### 📄 Script Import

- Final Draft (`.fdx`), Fountain, and Highland archive formats all supported
- Automatic scene number, location, and day/night extraction
- Import summary screen shows what was found before committing to the Boneyard
- **If you imported a long script before and ended up with noticeably fewer scenes than expected** (importing stopped partway through, silently), that was a real bug in how the parser tracked nested XML elements — Final Draft represents DualDialogue blocks as nested paragraphs, and the parser's depth-tracking was structurally incapable of ever recognizing that nesting, which desynced its internal state the first time it hit one and caused every scene after that point to be silently dropped. This is fixed. One known remaining gap: cast members who *only* appear inside a DualDialogue exchange aren't picked up by the automatic cast detection for that scene — add them manually if that comes up.

### 📋 Call Sheets & Production Setup

- Per-day call sheets with cast (auto-pulled, editable), crew (roster-based checkboxes), locations (roster or freeform), and notes
- Renaming an actor or crew member in Production Setup ripples through every call sheet automatically
- Reusable location roster with autocomplete

### 🗂️ Native macOS Menus, Undo & Theming

- Full File/Edit/Production/View menu set, Undo/Redo for structural schedule changes
- Multiple app color themes, plus the scene-color customization above
- Auto-save, Open Recent, and manual Save/Save As as portable `.json` project files

## A note on language

alucardGonza's original fork included full bilingual English/Español support, reactive across every menu, sheet, and export. **This version has that disabled — the app is English-only.** The underlying system is still in the code (so re-enabling it later is a small change, not a rewrite), but the language-switcher menu has been removed, and a few strings that were hardcoded in Spanish regardless of any language setting — including two default PDF export filenames — have been changed to English directly.

## Installation

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later

### Setup

This repository is distributed as loose source files rather than an `.xcodeproj`. To build it:

1. Create a new macOS App project in Xcode (SwiftUI).
2. **Delete Xcode's own auto-generated app-entry and content-view files.** This project brings its own `CineSchedApp.swift` and `ContentView.swift`, and having two `@main` types in one target will fail to build. Double-check afterward, too — if you ever see "1 Alternate" when using Xcode's Open Quickly (⌘⇧O) to search for `CineSchedApp`, that's very likely just Xcode showing the struct itself as a separate symbol match, not a real duplicate file; don't assume it's a problem without actually checking each result's file location first.
3. Add every `.swift` file from this repository to the target, along with `Info.plist` and `CineSched.entitlements`.
4. In **Signing & Capabilities**, under **App Sandbox → File Access**, set **User Selected File** to **Read/Write** — this is required for Save As, Open, and script import to work; Xcode's default new-project entitlements don't include it.
5. Build once before making any changes, to confirm a clean baseline.

### First Launch (Unsigned App)

Since this isn't distributed through the Mac App Store or signed with a Developer certificate, macOS Gatekeeper will likely refuse to open a built copy the first time:

1. Drag `CineSched.app` into Applications.
2. In Terminal: `xattr -c /Applications/CineSched.app`
3. Launch normally from then on.

### If a change you made doesn't seem to take effect

Before assuming the code is wrong: confirm you're editing and replacing the file in the **correct** Xcode project, especially if you have more than one CineSched-family project on your machine (an easy mix-up, and one that cost real time during this app's own development). A reliable way to tell this project apart from an older/different one: search for `StripboardView` in the Project Navigator — that file only exists in this version.

## Updating the App Icon

The app icon is generated from a single 1024×1024 PNG. To update it:

1. Replace the source PNG with your new artwork (must be exactly 1024×1024, RGBA).
2. Generate the full macOS icon set from it (16/32/128/256/512, each at 1x and 2x) and package it as an `AppIcon.appiconset` folder with a `Contents.json` manifest.
3. In Xcode, open `Assets.xcassets`, select (or create) the `AppIcon` entry, and drag the new `.appiconset` folder in to replace it — or drag the individual sized PNGs into their matching slots if the asset catalog already exists.
4. Clean Build Folder (⇧⌘K) and rebuild so Xcode doesn't reuse a cached icon.
5. If the built app still shows a generic icon after a clean rebuild, that's very likely macOS's own system-level icon cache, not your project — quit the app, delete any old built copy, and clear the cache:
   ```
   sudo rm -rf /Library/Caches/com.apple.iconservices.store
   sudo find /private/var/folders/ -name com.apple.dock.iconcache -delete
   killall Dock
   killall Finder
   ```

## Known Limitations

- Schedule PDF exports are landscape US Letter only; call sheet and breakdown sheet exports are portrait US Letter only
- ⇧-click range selection on the calendar only works within a single day
- A conflict or blackout flag only applies to characters matched to a named cast member in Production Setup
- View-mode and sidebar preferences are remembered app-wide, not per-project
- Cast members appearing only inside a DualDialogue exchange aren't automatically added to that scene's cast list (see Script Import above)

## File Formats

### Project Files (`.json`)

All scenes, calendar days, call sheets, production info, and any active schedule lock. Portable and human-readable.

### Script Imports

`.fdx` (Final Draft), Fountain, and Highland archives are all supported for import.

## Contributing

Contributions are welcome — bug fixes, new features, documentation, or a Windows/cross-platform port (the `.json` format is simple enough to support a compatible non-macOS client). See `CONTRIBUTING.md`.

## Credits

- **Chris Tempel** — created the original CineSched.
- **alucardGonza** — forked the project and built the Stripboard view, the monthly calendar's day-inspector, bilingual English/Español support, the dynamic timeline cascade, vector PDF exports, calendar events, and notice banners. The look and feel of this version owes its foundation to that work.
- **Final Draft** for the `.fdx` format.
- **Claude (Anthropic)** for development assistance throughout all three layers of this project's history.

## License

GNU General Public License v3 — free to use, modify, and distribute; modified versions must also be released as open source under the same license. See `LICENSE`.

## Support

For issues or questions, please open a GitHub issue.

---

**Compatible With**: macOS 13.0+, Final Draft 12+
