# Changelog

All notable changes to CineSched are documented here.

## [3.1] - 2026
### Added
- Drag entire shoot days to reschedule — grip icon (☰) on each date header lets you drag a day's scenes and call sheet to any other date; swaps content if the target day is occupied

### Improved
- Grip icon now responds to a single click-and-drag (no longer requires a prior activation click)
- Production Setup button moved before Import Script in the toolbar
- "New" fully resets the project — now also clears call sheets, project title, and production info
- Confirmation dialog for "New" accurately describes what will be cleared

## [3.0] - 2026
### Added
- **Call sheets** — click any date header in the calendar to open the call sheet editor for that day
- Per-day call sheet editor with general call time, multiple locations (add/remove), cast, and free-form notes
- Call sheet PDF export in US Letter portrait — professional layout with header, locations, scene breakdown, cast, crew, and notes
- **Production Setup** — project-wide panel (toolbar button) for company name, director, contact number, cast list, and crew list
- Actor → character mapping in Production Setup: enter `Jake Nuttbrock — Blake` once, and the call sheet automatically resolves character names from scenes to full actor credits
- Cast list on scenes now stores individual names as an array (previously a single string) — existing saves migrate automatically
- Blue dot indicator on calendar date headers when a call sheet has data entered
- General call time displayed prominently bold and right-aligned on call sheet PDF
- Grip icon (☰) on date headers — click and drag to move an entire day's scenes and call sheet to another date, swapping content if the target day has scenes
- "New" now fully resets the project — clears scenes, call sheets, project title, and production info

### Improved
- All file operations (Load, Import Script, Export PDF, Export Call Sheet) now use native macOS panels — more reliable than SwiftUI's fileExporter/fileImporter on macOS 13
- Auto-save reworked with a dirty-flag + debounce pattern — no more timer objects
- `createdDate` on projects now correctly preserved across saves (was being reset on every save)
- Scene edit sheet text area has improved internal padding
- General call time stands out on call sheet PDF — bold, larger, right-aligned
- Cast on call sheet displayed as a single-column list matching crew style
- Notes in call sheet PDF now correctly render below the NOTES header
- Production Setup button moved before Import Script in the toolbar
- Code split into focused single-responsibility files — ContentView reduced from 2,800 lines to ~450

### Fixed
- Calendar date header popup occasionally showing as a blank square — fixed by switching to `sheet(item:)` pattern
- Load button silently doing nothing — fixed by replacing fileImporter with NSOpenPanel
- PDF export not triggering — fixed by replacing fileExporter with NSSavePanel
- Day drag handle requiring two clicks — fixed with `simultaneousGesture` and `contentShape`
- "New" leaving call sheet data behind on calendar days

## [2.5] - 2026
### Added
- Final Draft `.fdx` script import — parse scene headings directly from your screenplay
- Automatic scene number extraction from FDX files
- Auto-detection of time of day (DAY / NIGHT / MORNING / EVENING / DUSK / DAWN)
- Location parsing (INT. / EXT.) from scene headings
- All imported scene headings automatically capitalized
- Imported scenes land in the Boneyard with default values ready to edit

## [2.0] - 2026
### Added
- Drag-and-drop scene scheduling with precise drop positioning between scenes
- Day/Night classification with color-coded indicators (orange for day, blue for night)
- Visual drop indicators showing exactly where a scene will land
- Duplicate scene from context menu in both calendar and Boneyard
- Cast and scene summary fields on each scene
- Shift Schedule toggle — shift all scenes when changing the start date, or lock them in place
- Dark/Light mode toggle with saved preference
- Compact statistics bar showing shoot days, total scenes, and estimated time
- Native save dialog for exporting project files

### Improved
- PDF export redesigned with tighter, more professional layout
- Scene strips truncate cleanly with ellipsis when titles are long
- Dynamic row heights in PDF based on scene density per week
- Grid lines constrained to actual calendar content area
- Auto-save triggers reliably on all state changes

## [1.0] - 2025
### Added
- Visual weekly calendar grid for scheduling shoot days
- Scene creation with title, page duration (in eighths), and estimated time
- Flexible duration input: eighths, mixed fractions (1 7/8), and decimals
- Flexible time input: hours, minutes, and H:MM format
- Boneyard sidebar for holding unscheduled scenes
- Drag scenes from Boneyard onto calendar days
- Double-click any scene to edit
- Daily totals for page count and estimated shoot time
- PDF export in landscape US Letter format
- Save and load projects as `.json` files
- Auto-save to local storage

### Added
- **Call sheets** — click any date header in the calendar to open the call sheet editor for that day
- Per-day call sheet editor with general call time, multiple locations (add/remove), cast, and free-form notes
- Call sheet PDF export in US Letter portrait — professional layout with header, locations, scene breakdown, cast, crew, and notes
- **Production Setup** — project-wide panel (toolbar button) for company name, director, contact number, cast list, and crew list
- Actor → character mapping in Production Setup: enter `Jake Nuttbrock — Blake` once, and the call sheet automatically resolves character names from scenes to full actor credits
- Cast list on scenes now stores individual names as an array (previously a single string) — existing saves migrate automatically
- Blue dot indicator on calendar date headers when a call sheet has data entered
- General call time displayed prominently bold and right-aligned on call sheet PDF
- Location name and address support per shoot day
- `ShootDay.allCast` computed property — sorted unique cast across all scenes in a day

### Improved
- All file operations (Load, Import Script, Export PDF, Export Call Sheet) now use native macOS panels — more reliable than SwiftUI's fileExporter/fileImporter on macOS 13
- Auto-save reworked with a dirty-flag + debounce pattern — no more timer objects
- `createdDate` on projects now correctly preserved across saves (was being reset on every save)
- Scene edit sheet text area has improved internal padding
- Code split into focused single-responsibility files — ContentView reduced from 2,800 lines to ~450

### Fixed
- Calendar date header popup occasionally showing as a blank square — fixed by switching to `sheet(item:)` pattern
- Load button silently doing nothing — fixed by replacing fileImporter with NSOpenPanel
- PDF export not triggering — fixed by replacing fileExporter with NSSavePanel

## [2.5] - 2026
### Added
- Final Draft `.fdx` script import — parse scene headings directly from your screenplay
- Automatic scene number extraction from FDX files
- Auto-detection of time of day (DAY / NIGHT / MORNING / EVENING / DUSK / DAWN)
- Location parsing (INT. / EXT.) from scene headings
- All imported scene headings automatically capitalized
- Imported scenes land in the Boneyard with default values ready to edit

## [2.0] - 2026
### Added
- Drag-and-drop scene scheduling with precise drop positioning between scenes
- Day/Night classification with color-coded indicators (orange for day, blue for night)
- Visual drop indicators showing exactly where a scene will land
- Duplicate scene from context menu in both calendar and Boneyard
- Cast and scene summary fields on each scene
- Shift Schedule toggle — shift all scenes when changing the start date, or lock them in place
- Dark/Light mode toggle with saved preference
- Compact statistics bar showing shoot days, total scenes, and estimated time
- Native save dialog for exporting project files

### Improved
- PDF export redesigned with tighter, more professional layout
- Scene strips truncate cleanly with ellipsis when titles are long
- Dynamic row heights in PDF based on scene density per week
- Grid lines constrained to actual calendar content area
- Auto-save triggers reliably on all state changes

## [1.0] - 2025
### Added
- Visual weekly calendar grid for scheduling shoot days
- Scene creation with title, page duration (in eighths), and estimated time
- Flexible duration input: eighths, mixed fractions (1 7/8), and decimals
- Flexible time input: hours, minutes, and H:MM format
- Boneyard sidebar for holding unscheduled scenes
- Drag scenes from Boneyard onto calendar days
- Double-click any scene to edit
- Daily totals for page count and estimated shoot time
- PDF export in landscape US Letter format
- Save and load projects as `.json` files
- Auto-save to local storage

### Added
- Final Draft `.fdx` script import — parse scene headings directly from your screenplay
- Automatic scene number extraction from FDX files
- Auto-detection of time of day (DAY / NIGHT / MORNING / EVENING / DUSK / DAWN)
- Location parsing (INT. / EXT.) from scene headings
- All imported scene headings automatically capitalized
- Imported scenes land in the Boneyard with default values ready to edit

## [2.0] - 2026
### Added
- Drag-and-drop scene scheduling with precise drop positioning between scenes
- Day/Night classification with color-coded indicators (orange for day, blue for night)
- Visual drop indicators showing exactly where a scene will land
- Duplicate scene from context menu in both calendar and Boneyard
- Cast and scene summary fields on each scene
- Shift Schedule toggle — shift all scenes when changing the start date, or lock them in place
- Dark/Light mode toggle with saved preference
- Compact statistics bar showing shoot days, total scenes, and estimated time
- Native save dialog for exporting project files

### Improved
- PDF export redesigned with tighter, more professional layout
- Scene strips truncate cleanly with ellipsis when titles are long
- Dynamic row heights in PDF based on scene density per week
- Grid lines constrained to actual calendar content area
- Auto-save triggers reliably on all state changes

## [1.0] - 2025
### Added
- Visual weekly calendar grid for scheduling shoot days
- Scene creation with title, page duration (in eighths), and estimated time
- Flexible duration input: eighths, mixed fractions (1 7/8), and decimals
- Flexible time input: hours, minutes, and H:MM format
- Boneyard sidebar for holding unscheduled scenes
- Drag scenes from Boneyard onto calendar days
- Double-click any scene to edit
- Daily totals for page count and estimated shoot time
- PDF export in landscape US Letter format
- Save and load projects as `.json` files
- Auto-save to local storage
