# CineSched - Film Production Scheduling App

A macOS application for scheduling film shoots with visual calendar layouts, scene management, and Final Draft script import.

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green)
![Version](https://img.shields.io/badge/version-3.2-purple)
![License](https://img.shields.io/badge/license-GPL--v3-lightgrey)

> **Free for the film community.** Built by a filmmaker, for filmmakers. If you find it useful, the best way to say thanks is to share it. If you're a developer who wants to build a Windows version, [read this](#windows--cross-platform).

## Demo

▶️ [Watch the demo on YouTube](https://youtu.be/UVjkRQHj8JU)

## Features

### 📅 Visual Calendar Scheduling
- Drag-and-drop scene strips onto calendar days
- Color-coded scene types: orange for day, blue for night, red for custom (company moves, etc.)
- Dynamic week rows that adjust based on scene count
- Automatic totals for page count and estimated time per day
- Drag entire days (scenes + call sheet) to reschedule — swaps content if target day is occupied

### 🎬 Scene Management
- Create scenes with custom titles, durations, and time estimates
- Day, Night, or Custom type for each scene — Custom strips require only a title, page count and time are optional
- "Boneyard" sidebar for unscheduled scenes with sort options: Location, INT/EXT, Cast, Day/Night, or Default
- Double-click to edit any scene
- Flexible duration input (pages in eighths: "1 7/8", "15", etc.)
- Flexible time input (hours or minutes: "4", "2:30", "15")

### 📄 Final Draft Script Import
- Import `.fdx` files directly from Final Draft
- Automatic scene number extraction
- Location parsing (INT./EXT.)
- Auto-detection of time of day (DAY/NIGHT/MORNING/EVENING/etc.)
- All scene headings automatically capitalized
- Scenes added to Boneyard with default values

### 📋 Call Sheets
- Click any date header to open the call sheet editor for that day
- Per-day fields: general call time, multiple locations, cast, and free-form notes
- Cast auto-pulled from scheduled scenes, fully editable
- Actor → character lookup: enter `Jake Nuttbrock — Blake` in Production Setup and the call sheet resolves character names to full actor credits automatically
- **Per-day crew selection** — choose from your roster with checkboxes; daily defaults arrive pre-checked, specialty crew can be added as needed, and any default can be unchecked if not needed that day
- Export professional PDF call sheets — header, locations, scene breakdown, cast, crew, and notes
- Blue dot indicator on date headers when a call sheet has data

### 🎥 Production Setup
- Project-wide panel for company name, director, and contact number
- Cast list with actor → character mappings (used for call sheet auto-lookup)
- Crew list with name, role, and a **Daily** checkbox — crew marked Daily are pre-populated on every call sheet

### 📊 Export & Statistics
- Export schedule as PDF with professional calendar layout
- Export call sheets as PDF (one per shoot day) — crew section reflects exactly who was called that day
- Real-time statistics: shoot days, total scenes, total pages, estimated time

### 💾 Auto-Save
- Automatic project saving after any change
- Manual save/load for sharing projects as `.json` files
- "New" fully resets the project — clears all scenes, call sheets, title, and production info

### 🎨 Customization
- Dark/Light mode toggle
- Adjustable date ranges
- Shift schedule or lock scenes to dates

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later

### Setup
1. Clone or download this repository
2. Open `CineSched.xcodeproj` in Xcode
3. Build and run (⌘R)

## Usage

### Creating a New Schedule

1. **Set Your Movie Title**
   - Enter your project name in the title field (top of sidebar)

2. **Set Date Range**
   - Choose start and end dates for your shoot
   - Toggle "Shift Schedule" if you want scenes to move when you change dates
   - Click "Update Calendar" to generate your schedule

3. **Set Up Production Info** *(optional but recommended)*
   - Click **Production Setup** in the toolbar
   - Enter company name, director, and contact number
   - Add your crew — check "Daily" for anyone on set every day
   - Add cast with actor → character mappings for automatic call sheet lookup

4. **Add Scenes**
   - **Manual Entry**: Use the "New Scene" section in the sidebar
     - Enter scene title (e.g., "3. INT. KITCHEN - DAY")
     - Enter duration in pages (e.g., "1 7/8", "2", "15" for 15/8ths)
     - Enter estimated time (e.g., "4" for 4 hours, "2:30" for 2.5 hours, "15" for 15 minutes). Less than "14" is interpreted as hours. "15" and greater is minutes.
     - Select Day, Night, or Custom (for company moves, meal breaks, etc.)
     - Click "Add Scene"

   - **Import from Script**:
     - Click "Import Script" button
     - Select your Final Draft `.fdx` file
     - All scenes automatically appear in the Boneyard
     - Edit page counts and times as needed

5. **Sort the Boneyard** *(optional)*
   - Use the sort menu next to the Boneyard heading to group scenes by Location, INT/EXT, Cast, or Day/Night
   - Default order is always available to restore the original sequence
   - Sorting is display-only and does not affect scheduling

6. **Schedule Scenes**
   - Drag scenes from the Boneyard onto calendar days
   - Day scenes appear in white boxes, night in gray, custom in a red-outlined box
   - Daily totals appear at the bottom of each day

7. **Edit Scenes**
   - Double-click any scene (scheduled or in Boneyard) to edit
   - Update title, duration, time, or type
   - Delete scenes from the edit sheet if needed

### Building Call Sheets

1. Click any **date header** on the calendar to open that day's call sheet editor
2. Set the general call time, locations, and notes
3. Cast is auto-pulled from the scenes scheduled that day — edit as needed
4. Crew shows your full roster as checkboxes:
   - Daily crew arrive pre-checked — uncheck anyone not needed that day
   - Specialty crew arrive unchecked — check anyone needed that day
   - Type a name in the one-off field for crew not in your roster
5. Click **Save** or **Export PDF** to generate the call sheet

### Exporting Your Schedule

1. Click **"Export PDF"** button
2. Choose save location
3. PDF includes:
   - Project title and shoot day count
   - Weekly calendar layout
   - Scene strips with truncated titles if needed
   - Daily totals (pages and estimated time)
   - Automatic page breaks for long schedules

### Saving & Loading Projects

- **Auto-save**: Your project saves automatically after changes
- **Manual Save**: Click "Save" to export as `.json` file for sharing
- **Load**: Click "Load" to import a saved project
- **New**: Click "New" (red button) to clear and start fresh

## Button Reference

**Toolbar Buttons (left to right):**
1. **New** (red) — Clear all scenes and start fresh
2. **Production Setup** — Set production company, director, contact, cast, and crew
3. **Import Script** — Import scenes from a Final Draft `.fdx` file
4. **Save** — Export project as `.json` file
5. **Load** — Import a saved project
6. **Export PDF** (blue) — Generate calendar PDF
7. **Light/Dark** — Toggle appearance mode

## Duration & Time Input Examples

### Page Duration (in eighths)
- `15` = 15 eighths (1 7/8 pages)
- `8` = 8 eighths (1 page)
- `1 7/8` = 1 and 7/8 pages
- `7/8` = 7/8 of a page
- `2.5` = 2.5 pages (converts to eighths)

### Estimated Time
- `4` = 4 hours (numbers ≤10 default to hours)
- `15` = 15 minutes (numbers >10 default to minutes)
- `2:30` = 2 hours 30 minutes
- `0:45` = 45 minutes

## Final Draft Import Details

### What Gets Imported
From a scene heading like: **"3. EXT. WOODS - DAY"**
- Scene Number: `3`
- Location: `EXT. WOODS`
- Time of Day: Automatically checks "Day"
- Title becomes: `3. EXT. WOODS`

### Supported Time of Day Keywords
- **Day**: DAY, MORNING, AFTERNOON
- **Night**: NIGHT, EVENING, DUSK, DAWN
- **Unknown**: Defaults to DAY

### After Import
- All scenes appear in the Boneyard
- Default values: 1/8 page, 15 min
- Edit scenes to set accurate page counts and times
- Drag to schedule on calendar

## Project Structure

```
CineSched/
├── CineSchedApp.swift         # App entry point
├── Models.swift               # Data types: Scene, ShootDay, ProjectData, CallSheetData, ProductionInfo
├── Parsers.swift              # FractionParser and TimeParser utilities
├── Formatting.swift           # Shared date/time/page formatting helpers
├── FinalDraftParser.swift     # FDX script file parsing
├── PDFExporter.swift          # Schedule PDF generation
├── CallSheetExporter.swift    # Call sheet PDF generation
├── ProjectStore.swift         # Save, load, auto-save, and all file operations
├── ContentView.swift          # Root view: state, toolbar, sidebar wiring
├── CalendarView.swift         # Calendar grid, drag-and-drop scenes and days
├── CallSheetEditor.swift      # Per-day call sheet editor sheet
├── ProductionSetupSheet.swift # Project-wide production info panel
├── SceneEditSheet.swift       # Modal sheet for editing a scene
└── NewSceneInputView.swift    # Sidebar form for adding new scenes
```

## File Formats

### Project Files (.json)
Save and share your schedules as JSON files containing:
- All scenes (scheduled and unscheduled)
- Calendar days with assigned scenes and call sheet data
- Project title and settings
- Production info (crew, cast, company details)

### Final Draft Scripts (.fdx)
Import scripts directly from Final Draft:
- XML-based format
- Extracts scene headings automatically
- Preserves scene numbers from script

## Tips & Tricks

1. **Efficient Workflow**
   - Import your script first, then set up Production Setup before building call sheets
   - Edit page counts in batches (double-click each scene in the Boneyard)
   - Use the Location sort in the Boneyard to cluster scenes by place before scheduling
   - Use Custom strips for company moves so they stand out on the calendar and print clearly on B&W

2. **Keyboard Shortcuts**
   - `⌘S` — Save (triggers native save dialog)
   - `⌘N` — New project

3. **PDF Export Tips**
   - Tight row heights maximize page usage
   - Scene titles truncate with "..." if too long
   - Totals always align at bottom for easy scanning
   - Weekends included for complete view

4. **Scene Naming Best Practices**
   - Keep titles concise for PDF readability
   - Use consistent location names (e.g., always "OWENS HOUSE" not "Owen's house")
   - Include scene numbers in the title for easy reference (imported scenes do this automatically)

## Known Limitations

- Schedule PDF exports are landscape US Letter (792 x 612 pts)
- Call sheet PDF exports are portrait US Letter (612 x 792 pts)
- Very long scene titles will truncate in the calendar and PDF (ellipsis added)
- Scene strips have a maximum of ~160px row height in the calendar PDF

## Troubleshooting

### Import Script button not working
1. Make sure `FinalDraftParser.swift` is in your Xcode project
2. Clean build folder (Product → Clean Build Folder)
3. Rebuild (⌘B)

### Scenes not importing from FDX
- Verify file is a valid Final Draft `.fdx` file
- Check Xcode console for error messages
- Try opening the FDX in Final Draft first to verify it's not corrupted

### PDF export shows truncated text
- This is expected for very long scene titles
- Edit scene titles to be more concise if needed
- Full titles are visible in the app itself

### Load button not responding
- Check that you're selecting a `.json` file (not `.fdx`)
- Verify file permissions
- Try saving a new project and loading that to test

## Future Enhancement Ideas

- [ ] Days Out of Days report
- [ ] Location color coding on the calendar
- [ ] Multi-select scenes for batch operations
- [ ] Copy/paste scenes between days
- [ ] Export to CSV/Excel
- [ ] iCloud sync
- [ ] Windows / cross-platform port

## Windows / Cross-Platform

CineSched is currently macOS-only, but the `.json` project format is simple and portable by design. A Windows developer who wants to build a compatible version — using Electron, Flutter, or Avalonia — would be able to read and write the same save files. See [CONTRIBUTING.md](CONTRIBUTING.md) for more detail.

## Contributing

Contributions are welcome — bug fixes, new features, documentation, or a Windows port. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

## Credits

Built with SwiftUI for macOS by a film production professional who needed a better way to schedule shoots.

Special thanks to:
- **Final Draft** for the `.fdx` format
- **Claude (Anthropic)** for development assistance

## License

GNU General Public License v3 — free to use, modify, and distribute, but any modified versions must also be released as open source under the same license. See [LICENSE](LICENSE) for details.

## Support

For issues or questions, please open a GitHub issue. Check the troubleshooting section above or the Xcode console for detailed error messages first.

---

**Version**: 3.2
**Compatible With**: macOS 13.0+, Final Draft 12+
