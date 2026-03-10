# CineSched - Film Production Scheduling App

A macOS application for scheduling film shoots with visual calendar layouts, scene management, and Final Draft script import.

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green)
![Version](https://img.shields.io/badge/version-2.5-purple)
![License](https://img.shields.io/badge/license-GPL--v3-lightgrey)

> **Free for the film community.** Built by a filmmaker, for filmmakers. If you find it useful, the best way to say thanks is to share it. If you're a developer who wants to build a Windows version, [read this](#windows--cross-platform).

> **Free for the film community.** Built by a filmmaker, for filmmakers. If you find it useful, the best way to say thanks is to share it. If you're a developer who wants to build a Windows version, [read this](#windows--cross-platform).

## Features

### Visual Calendar Scheduling
- Drag-and-drop scene strips onto calendar days
- Color-coded day/night scenes (white for day, gray for night)
- Dynamic week rows that adjust based on scene count
- Automatic totals for page count and estimated time per day

### Scene Management
- Create scenes with custom titles, durations, and time estimates
- Day/Night classification for each scene
- "Boneyard" sidebar for unscheduled scenes
- Double-click to edit any scene
- Flexible duration input (pages in eighths: "1 7/8", "15", etc.)
- Flexible time input (hours or minutes: "4", "2:30", "15")

### Final Draft Script Import
- Import `.fdx` files directly from Final Draft
- Automatic scene number extraction
- Location parsing (INT./EXT.)
- Auto-detection of time of day (DAY/NIGHT/MORNING/EVENING/etc.)
- All scene headings automatically capitalized
- Scenes added to Boneyard with default values (1 page, 4 hours)

### Export & Statistics
- Export calendar as PDF with professional layout
- Real-time statistics: shoot days, total scenes, total pages, estimated time
- Compact toolbar with all key info visible

### Auto-Save
- Automatic project saving to UserDefaults
- No need to manually save - your work is always preserved
- Manual save/load for sharing projects

### Customization
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

3. **Add Scenes**
   - **Manual Entry**: Use the "New Scene" section in the sidebar
     - Enter scene title (e.g., "3. INT. KITCHEN - DAY")
     - Enter duration in pages (e.g., "1 7/8", "2", "15" for 15/8ths)
     - Enter estimated time (e.g., "4" for 4 hours, "2:30" for 2.5 hours, "15" for 15 minutes).  Less than "14" is interpreted as hours.  "15" and greater is minutes.  
     - Select Day or Night
     - Click "Add Scene"
   
   - **Import from Script**: 
     - Click "Import Script" button
     - Select your Final Draft `.fdx` file
     - All scenes automatically appear in the Boneyard
     - Edit page counts and times as needed

4. **Schedule Scenes**
   - Drag scenes from the Boneyard onto calendar days
   - Scenes show their title, with day scenes in white boxes, night scenes in gray
   - Daily totals appear at the bottom of each day

5. **Edit Scenes**
   - Double-click any scene (scheduled or in Boneyard) to edit
   - Update title, duration, time, or day/night setting
   - Delete scenes from the edit sheet if needed

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
1. **New** (red) - Clear all scenes and start fresh
2. **Import Script** - Import Final Draft `.fdx` file
3. **Save** - Export project as JSON file
4. **Load** - Import saved project
5. **Export PDF** (blue) - Generate calendar PDF
6. **Light/Dark** - Toggle appearance mode

## Duration & Time Input Examples

### Page Duration (in eighths)
- `15` = 15 eighths (1 7/8 pages)
- `8` = 8 eighths (1 page)
- `1 7/8` = 1 and 7/8 pages
- `7/8` = 7/8 of a page
- `2.5` = 2.5 pages (converts to eighths)

### Estimated Time
- `4` = 4 hours (numbers ≤14 default to hours)
- `15` = 15 minutes (numbers >14 default to minutes)
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
- Default values: 1 page (8/8ths), 4 hours
- Edit scenes to set accurate page counts and times
- Drag to schedule on calendar

## Project Structure

```
CineSched/
├── CineSchedApp.swift         # App entry point
├── Models.swift               # Data types: Scene, ShootDay, ProjectData
├── Parsers.swift              # FractionParser and TimeParser utilities
├── Formatting.swift           # Shared date/time/page formatting helpers
├── FinalDraftParser.swift     # FDX script file parsing
├── PDFExporter.swift          # PDF generation + PDFFile document wrapper
├── ProjectStore.swift         # Save, load, auto-save, and persistence logic
├── ContentView.swift          # Root view: state, toolbar, sidebar wiring
├── CalendarView.swift         # Calendar grid, drag-and-drop, SceneCardView
├── SceneEditSheet.swift       # Modal sheet for editing a scene
├── NewSceneInputView.swift    # Sidebar form for adding new scenes
└── README.md                  # This file
```

## File Formats

### Project Files (.json)
Save and share your schedules as JSON files containing:
- All scenes (scheduled and unscheduled)
- Calendar days with assigned scenes
- Project title and settings
- Date range information

### Final Draft Scripts (.fdx)
Import scripts directly from Final Draft:
- XML-based format
- Extracts scene headings automatically
- Preserves scene numbers from script

## Tips & Tricks

1. **Efficient Workflow**
   - Import your script first
   - Edit page counts in batches (double-click each scene)
   - Group similar locations together on the calendar
   - Use day/night color coding to balance your schedule

2. **PDF Export Tips**
   - Tight row heights maximize page usage
   - Scene titles truncate with "..." if too long
   - Totals always align at bottom for easy scanning
   - Weekends included for complete view

3. **Scene Naming Best Practices**
   - Keep titles concise for PDF readability
   - Use consistent location names (e.g., always "OWENS HOUSE" not "Owen's house")
   - Include scene numbers in title for easy reference

## Known Limitations

- PDF exports are landscape US Letter (792 x 612 pts)
- Very long scene titles will truncate (ellipsis added)
- Scene strips have a maximum of ~160px row height

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

- [ ] Multi-select scenes for batch operations
- [ ] Copy/paste scenes between days
- [ ] Print directly from app (without PDF step)
- [ ] Export to CSV/Excel
- [ ] Cast lists per scene
- [ ] Location grouping and color coding
- [ ] Budget tracking per scene
- [ ] Integration with other screenwriting tools

## Windows / Cross-Platform

CineSched is currently macOS-only, but the `.json` project format is simple and portable by design. A Windows developer who wants to build a compatible version — using Electron, Flutter, or Avalonia — would be able to read and write the same save files. See [CONTRIBUTING.md](CONTRIBUTING.md) for more detail.

## Contributing

Contributions are welcome — bug fixes, new features, documentation, or a Windows port. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

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

**Version**: 2.5
**Compatible With**: macOS 13.0+, Final Draft 12+
