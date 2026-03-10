# Contributing to CineSched

Thanks for your interest in contributing. CineSched is a gift to the film production community and welcomes contributions of all kinds — bug fixes, features, documentation, and ports to other platforms.

## Getting Started

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later

### Setup
1. Fork and clone the repository
2. Open `CineSched.xcodeproj` in Xcode
3. Build and run with ⌘R

## Project Structure

The codebase is organized into focused single-purpose files. Before diving in, it's worth spending a few minutes reading through them:

```
CineSched/
├── CineSchedApp.swift         # App entry point
├── Models.swift               # Core data types: Scene, ShootDay, ProjectData
├── Parsers.swift              # Page duration and time input parsing
├── Formatting.swift           # Shared formatting helpers
├── FinalDraftParser.swift     # .fdx script file parsing
├── PDFExporter.swift          # PDF generation
├── ProjectStore.swift         # Save, load, and auto-save logic
├── ContentView.swift          # Root view and app state
├── CalendarView.swift         # Calendar grid and drag-and-drop
├── SceneEditSheet.swift       # Scene editing modal
└── NewSceneInputView.swift    # Add scene form
```

## How to Contribute

### Reporting Bugs
Open an issue with:
- macOS version and Xcode version
- Steps to reproduce
- What you expected vs. what happened
- Console output if relevant

### Submitting a Pull Request
1. Create a branch from `main` with a descriptive name (e.g. `feature/call-sheets` or `fix/pdf-grid-lines`)
2. Keep changes focused — one feature or fix per PR
3. Follow the existing code style (each file has a single clear responsibility)
4. Test on macOS 13+ before submitting
5. Update `CHANGELOG.md` under an `[Unreleased]` section

### Code Style
- Swift standard conventions throughout
- `// MARK: -` sections to organize code within files
- New features should live in their own file where it makes sense
- Avoid adding logic to `ContentView.swift` — use extensions or new files

## Project File Format

CineSched saves projects as standard `.json` files. The format is intentionally simple and human-readable. Any contributions that touch the data model should:
- Maintain backwards compatibility with existing save files
- Use optional fields with sensible defaults for any new properties
- Document the migration path in the PR description

The JSON format is also designed to be portable — a Windows or Linux version of CineSched should be able to read and write the same files.

## Windows / Cross-Platform Port

A Windows version that reads and writes the same `.json` format would be a hugely valuable contribution to the film community. If you're a Windows developer interested in building one, please open an issue to discuss it — the data model is stable and well-documented in `Models.swift`, and the project maintainer is happy to help ensure JSON compatibility.

Suggested frameworks for a Windows port:
- **Electron** — web technologies, runs identically on Mac and Windows
- **Flutter** — single codebase for Mac and Windows desktop
- **Avalonia** — declarative .NET UI, closest in style to SwiftUI

## Feature Ideas

Some areas where contributions would be particularly welcome:

- [ ] Call sheets — per-day PDF with cast, crew, location, and scene breakdown
- [ ] Strip board view — vertical scene list sortable by location, cast, or day/night
- [ ] Cast conflict detection — flag days where the same actor appears in multiple scenes
- [ ] Multi-select scenes for batch editing
- [ ] iCloud sync
- [ ] Location color coding on the calendar
- [ ] CSV / Excel export

## License

By contributing, you agree that your contributions will be licensed under the GNU General Public License v3. This means any modified versions of CineSched — including ports to other platforms — must also be released as open source under the same license.
