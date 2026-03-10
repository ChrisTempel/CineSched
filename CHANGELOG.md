# Changelog

All notable changes to CineSched are documented here.

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
