// ContentView.swift
// Root view: holds app state, sidebar, toolbar, and calendar.
// Business logic lives in ProjectStore.swift (persistence),
// CalendarView.swift (calendar/drag-drop), and the other focused files.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Custom UTType for FDX files

extension UTType {
    static var fdx: UTType { UTType(importedAs: "com.finaldraft.fdx") }
}

// MARK: - ContentView

struct ContentView: View {

    // MARK: Project state
    @State var allScenes:   [Scene]    = []
    @State var shootDays:   [ShootDay] = generateDays(
        from: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
        to:   Calendar.current.date(byAdding: .day, value: 30,  to: Date())!
    )
    @State var startDate:   Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State var endDate:     Date = Calendar.current.date(
        byAdding: .day, value: 30, to: Date())!
    @State var projectTitle: String = "Untitled Movie"
    @State var isShiftModeEnabled: Bool = false
    @State var projectCreatedDate: Date = Date()  // preserved across saves; never reset on re-save
    @State var productionInfo: ProductionInfo = ProductionInfo()

    // Auto-save: flip to true on any change; a debounced .onChange triggers the actual write
    @State var hasUnsavedChanges: Bool = false

    // MARK: UI / sheet state
    @State private var newSceneTitle: String = ""
    @State private var newDuration:   String = ""
    @State private var newEstimate:   String = ""

    @State var showingAlert             = false
    @State var showingImportAlert       = false
    @State private var showingClearAllConfirmation = false
    @State private var showingUnscheduledSceneEditSheet = false

    @State var alertMessage:   String = ""
    @State var importMessage:  String = ""
    @State private var importedScenesCount = 0

    // Unscheduled-scene editing
    @State private var editingUnscheduledScene:      Scene?
    @State private var editingUnscheduledSceneIndex: Int?

    // Appearance
    @AppStorage("CineSchedDarkMode") var isDarkMode: Bool = false
    @AppStorage("CineSchedIncludeHoldInDOOD") var includeHoldInDOOD: Bool = true
    @EnvironmentObject var recentFiles: RecentFilesStore
    /// The file this project was last saved to or loaded from — nil for a project that's
    /// never touched disk yet. "Save" writes here silently when set; "Save As…" always
    /// prompts and updates this to the newly chosen location. Persisted across launches
    /// (see setCurrentFileURL/restoreCurrentFileURL in ProjectStore.swift) — otherwise
    /// every first Save after relaunching the app would have nowhere remembered to save
    /// to and would silently fall back to acting like Save As.
    @State var currentFileURL: URL? = nil

    // Production Setup sheet
    @State private var showingProductionSetup = false
    @State private var showingConflictReport = false
    @State private var conflictReportResults: [ScheduleConflict] = []
    /// Set to trigger the calendar scrolling to a specific date — used when jumping to a
    /// conflict from the report. Reset to nil right after the calendar handles it.
    @State private var scrollToDate: Date? = nil
    /// Cached like sortedScenes — recomputed only on relevant changes rather than on every
    /// render, so the red-strip/warning-badge check doesn't re-scan the whole schedule on
    /// every interaction. This is the "autoscan": conflicts are recomputed automatically
    /// any time scenes, the schedule, or cast availability changes, with no need to
    /// manually trigger a scan — Scan for Conflicts… just opens the full report on demand.
    @State private var conflictDates: Set<Date> = []
    @State private var searchQuery: String = ""

    // MARK: - Breakdown Browser
    // A dedicated way to step through every scene in script order (regardless of
    // scheduling status) for breakdown tagging — see openBreakdownBrowser().
    @State private var showingBreakdownBrowser = false
    @State private var breakdownBrowserScenes: [Scene] = []   // snapshot in script order, captured on open
    @State private var breakdownBrowserIndex: Int = 0

    // MARK: - Undo/Redo
    //
    // Scoped deliberately to *structural* schedule changes — moving, removing, sending to
    // a day, duplicating, or rearranging whole days — rather than every field edit. A
    // dragged-to-the-wrong-day scene is the classic "oops" moment this exists for; a typo
    // mid-edit already has Cancel as its own undo, so wrapping every keystroke would add a
    // lot of snapshot noise for little real benefit. Snapshots capture the whole
    // allScenes + shootDays pair together (not the two arrays independently) so one
    // undo step always reverts exactly one user-perceived action, even for actions that
    // touch both arrays at once (like scheduling a Boneyard scene onto a day).
    private struct SceneUndoSnapshot {
        let allScenes: [Scene]
        let shootDays: [ShootDay]
    }
    @State private var undoStack: [SceneUndoSnapshot] = []
    @State private var redoStack: [SceneUndoSnapshot] = []
    private let maxUndoDepth = 30
    @State private var conflictSceneIDs: Set<UUID> = []
    @State private var scheduleLockChanges: [ScheduleLockChange] = []
    @State private var scheduleLockChangedDates: Set<Date> = []
    @State private var showingScheduleLockReport = false

    // Boneyard sort — persisted so your preferred sort (e.g. Location) is still
    // applied the next time you open the project.
    enum BoneyardSort: String, CaseIterable { case defaultOrder, location, intExt, cast, dayNight }
    @AppStorage("CineSchedBoneyardSort") private var boneyardSort: BoneyardSort = .defaultOrder

    // Collapsible sidebar sections — persisted so the layout you leave with is the
    // layout you come back to. Collapsing "Select Date Range" and "New Scene" frees
    // up vertical room for the Boneyard, which expands to fill whatever is left.
    @AppStorage("CineSchedDateRangeExpanded") private var isDateRangeExpanded: Bool = true
    @AppStorage("CineSchedNewSceneExpanded")  private var isNewSceneExpanded:  Bool = true

    // Scene multi-selection — shared between the Boneyard and the calendar so a selection
    // made in one place (e.g. ⇧-click a range) can be dragged or sent-to-day from either.
    // ⌘-click toggles, ⇧-click extends a range (in whatever order the current view shows),
    // and a selection of more than one scene moves as a group.
    @State private var selectedSceneIDs:   Set<UUID> = []
    @State private var lastSelectedSceneID: UUID?

    // MARK: - Computed statistics

    private var scheduledDays: [ShootDay] { shootDays.filter { !$0.scenes.isEmpty } }
    private var totalScenes:   Int        { scheduledDays.reduce(0) { $0 + $1.scenes.count } }
    private var totalDuration: String     { formattedEighths(scheduledDays.reduce(0) { $0 + $1.totalDuration }) }
    private var totalEstTime:  String     { formattedTime(scheduledDays.reduce(0) { $0 + $1.totalEstimatedTime }) }

    // MARK: - Body

    // Sidebar visibility — tracked explicitly (rather than the default NavigationSplitView
    // behavior) so the calendar can show more detail on scene strips (cast) when the sidebar
    // is collapsed and there's more horizontal room to use.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    private var isSidebarCollapsed: Bool { columnVisibility == .detailOnly }

    var body: some View {
        let base = NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            detailView
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)

        let withAlerts = applyAlerts(base)
        let withSheets = applySheets(withAlerts)
        let withBreakdownSheet = applyBreakdownBrowserSheet(withSheets)
        let withLifecycle = applyLifecycle(withBreakdownSheet)
        let withNotificationsA = applyNotificationHandlersA(withLifecycle)
        let withNotificationsB = applyNotificationHandlersB(withNotificationsA)
        return applyNotificationHandlersC(withNotificationsB)
    }

    // MARK: - body, split up for the type checker
    //
    // ContentView's body used to be one continuous chain — 3 alerts/dialogs, 3 sheets, an
    // onAppear, twelve onReceive handlers, and 3 onChange handlers all as a single Swift
    // expression. Swift's type checker has a real ceiling on how much it'll try to solve
    // in one expression before giving up with "unable to type-check ... in reasonable
    // time" — which is exactly what started happening once the notification handlers grew
    // to a dozen. Splitting the chain into several smaller functions, each with its own
    // concrete (if opaque) return type, keeps every individual piece well within that
    // limit; nothing about behavior changes, only how the compiler has to reason about it.

    private func applyAlerts<Content: View>(_ content: Content) -> some View {
        content
            .alert("Script Import",  isPresented: $showingImportAlert) { Button("OK") {} } message: { Text(importMessage) }
            .alert("CineSched",      isPresented: $showingAlert)        { Button("OK") {} } message: { Text(alertMessage) }
            .confirmationDialog("Clear All Scenes", isPresented: $showingClearAllConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { clearAllScenes() }
                Button("Cancel",    role: .cancel)      {}
            } message: {
                Text("This will clear all scenes, call sheets, and the project title. This action cannot be undone.")
            }
    }

    private func applySheets<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showingUnscheduledSceneEditSheet) { unscheduledEditSheet }
            .onChange(of: showingUnscheduledSceneEditSheet) { _, isShowing in
                if !isShowing { clearUnscheduledEditingState() }
            }
            .sheet(isPresented: $showingProductionSetup) {
                ProductionSetupSheet(
                    productionInfo: $productionInfo,
                    isPresented: $showingProductionSetup,
                    onSave: { markDirty(); recomputeConflicts(); recomputeScheduleLockChanges() },
                    onCharacterRenamed: renameCastCharacter
                )
            }
            .sheet(isPresented: $showingConflictReport) {
                ConflictReportSheet(
                    conflicts: conflictReportResults,
                    onSelectDate: { date in
                        showingConflictReport = false
                        scrollToDate = date
                    },
                    onDismiss: { showingConflictReport = false }
                )
            }
            .sheet(isPresented: $showingScheduleLockReport) {
                ScheduleLockReportSheet(
                    changes: scheduleLockChanges,
                    lockedAt: productionInfo.scheduleLock?.lockedAt,
                    onSelectDate: { date in
                        showingScheduleLockReport = false
                        scrollToDate = date
                    },
                    onDismiss: { showingScheduleLockReport = false }
                )
            }
    }

    private func applyBreakdownBrowserSheet<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showingBreakdownBrowser) {
                if breakdownBrowserScenes.indices.contains(breakdownBrowserIndex) {
                    SceneEditSheet(
                        scene: breakdownBrowserSceneBinding,
                        isPresented: $showingBreakdownBrowser,
                        onSave: { markDirty() },
                        onDelete: { deleteCurrentBreakdownScene() },
                        canGoPrevious: breakdownBrowserIndex > 0,
                        canGoNext: breakdownBrowserIndex < breakdownBrowserScenes.count - 1,
                        onPrevious: goToPreviousBreakdownScene,
                        onNext: goToNextBreakdownScene,
                        positionLabel: "Scene \(breakdownBrowserIndex + 1) of \(breakdownBrowserScenes.count) — script order",
                        breakdownExpandedByDefault: true,
                        closeAfterDelete: false
                    )
                }
            }
    }

    private func applyLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .onAppear {
                loadDefaultProject()
                restoreCurrentFileURL()
                recomputeSortedScenes()
                recomputeConflicts()
                recomputeScheduleLockChanges()
            }
            .onChange(of: allScenes) { _, _ in
                recomputeSortedScenes()
                pruneSelection()
                recomputeConflicts()
                recomputeScheduleLockChanges()
            }
            .onChange(of: boneyardSort) { _, _ in
                recomputeSortedScenes()
            }
            // Debounced auto-save: waits 2 seconds after the last change before writing
            .onChange(of: hasUnsavedChanges) { _, isDirty in
                guard isDirty else { return }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    saveDefaultProject()
                    hasUnsavedChanges = false
                }
            }
    }

    private func applyNotificationHandlersA<Content: View>(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .csNewProject)) { _ in
                showingClearAllConfirmation = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .csOpenProject)) { _ in
                showJSONOpenPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csOpenRecentProject)) { note in
                guard let url = note.object as? URL else { return }
                loadProject(from: url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .csImportScript)) { _ in
                showFDXOpenPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csSaveProject)) { _ in
                saveProject()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csSaveProjectAs)) { _ in
                showNativeSaveDialog()
            }
    }

    private func applyNotificationHandlersB<Content: View>(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .csExportSchedulePDF)) { _ in
                showSchedulePDFSavePanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csExportDaysOutOfDays)) { _ in
                showDaysOutOfDaysPDFSavePanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csOpenProductionSetup)) { _ in
                showingProductionSetup = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .csScanForConflicts)) { _ in
                conflictReportResults = ConflictScanner.scan(shootDays: shootDays, productionInfo: productionInfo)
                showingConflictReport = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .csUndo)) { _ in
                performUndo()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csRedo)) { _ in
                performRedo()
            }
    }

    private func applyNotificationHandlersC<Content: View>(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .csOpenBreakdownBrowser)) { _ in
                openBreakdownBrowser()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csExportBreakdowns)) { _ in
                showBreakdownPDFSavePanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csLockSchedule)) { _ in
                lockSchedule()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csUnlockSchedule)) { _ in
                unlockSchedule()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csShowScheduleLockReport)) { _ in
                showingScheduleLockReport = true
            }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Movie Title", text: $projectTitle)
                .font(.title2)
                .padding(.bottom, 2)
                .onChange(of: projectTitle) { _, _ in markDirty() }

            Text("Shoot Days: \(shootDays.filter { !$0.scenes.isEmpty }.count)")
                .font(.subheadline).foregroundColor(.gray)

            if let first = shootDays.first?.date, let last = shootDays.last?.date {
                Text("From \(formattedDate(first)) to \(formattedDate(last))")
                    .font(.subheadline).foregroundColor(.gray)
            }

            Divider().padding(.vertical)

            // Date range picker — collapsible to free up room for the Boneyard
            DisclosureGroup(isExpanded: $isDateRangeExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, _ in markDirty() }
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .onChange(of: endDate) { _, _ in markDirty() }

                    Toggle(isOn: $isShiftModeEnabled) { Text("Shift Schedule") }
                        .toggleStyle(.switch)
                        .help("When enabled, changing the Start Date shifts all scenes on the calendar.")
                        .onChange(of: isShiftModeEnabled) { _, _ in markDirty() }

                    Button("Update Calendar") { updateShootDays(from: startDate, to: endDate) }
                }
                .padding(.top, 6)
            } label: {
                Text("Select Date Range").font(.headline)
            }

            Divider().padding(.vertical)

            // New Scene form — collapsible to free up room for the Boneyard
            DisclosureGroup(isExpanded: $isNewSceneExpanded) {
                NewSceneInputView(
                    newSceneTitle: $newSceneTitle,
                    newDuration:   $newDuration,
                    newEstimate:   $newEstimate,
                    allScenes:     $allScenes,
                    onSceneAdded:  { markDirty() }
                )
                .padding(.top, 6)
            } label: {
                Text("New Scene").font(.headline)
            }

            Divider().padding(.vertical)

            // Boneyard header with sort menu
            HStack {
                Text("Boneyard").font(.headline)
                if !selectedSceneIDs.isEmpty {
                    Text("· \(selectedSceneIDs.count) selected")
                        .font(.caption).foregroundColor(.accentColor)
                    Button("Clear") { selectedSceneIDs = []; lastSelectedSceneID = nil }
                        .buttonStyle(.plain)
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    Button("Default Order") { boneyardSort = .defaultOrder }
                    Button("Location")      { boneyardSort = .location }
                    Button("INT / EXT")     { boneyardSort = .intExt }
                    Button("Cast")          { boneyardSort = .cast }
                    Button("Day / Night")   { boneyardSort = .dayNight }
                } label: {
                    HStack(spacing: 3) {
                        Text(boneyardSortLabel)
                            .font(.caption).foregroundColor(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Text("⌘-click or ⇧-click to select multiple, then drag as a group")
                .font(.caption2).foregroundColor(.secondary)

            // No trailing Spacer here — the Boneyard list expands to consume
            // whatever vertical space the collapsed sections above free up.
            boneyardList
                .frame(maxHeight: .infinity)
        }
        .padding()
        .frame(minWidth: 300, maxHeight: .infinity)
    }

    // MARK: - Boneyard sort helpers

    /// Re-scans the schedule against Production Setup's cast availability. Cached into
    /// conflictDates/conflictSceneIDs (like sortedScenes) rather than recomputed on every
    /// render, and called from every place that could change the answer: loading a
    /// project, any calendar-side scene move, and saving Production Setup.
    private func recomputeConflicts() {
        let conflicts = ConflictScanner.scan(shootDays: shootDays, productionInfo: productionInfo)
        conflictDates = ConflictScanner.conflictDates(conflicts)
        conflictSceneIDs = ConflictScanner.conflictSceneIDs(conflicts)
    }

    // MARK: - Schedule Lock

    /// Snapshots every character's current working days as the new baseline. The schedule
    /// itself stays fully editable afterward — this is a comparison point, not a
    /// restriction — see ScheduleLockScanner for how it's used.
    private func lockSchedule() {
        let working = ScheduleLockScanner.currentWorkingDays(shootDays: shootDays)
        var stored: [String: [Date]] = [:]
        for (character, dates) in working { stored[character] = dates.sorted() }
        productionInfo.scheduleLock = ScheduleLock(lockedAt: Date(), workingDays: stored)
        markDirty()
        recomputeScheduleLockChanges()
        alertMessage = "Schedule locked. You'll be notified in the Schedule Lock Report if any actor's working days change from here."
        showingAlert = true
    }

    private func unlockSchedule() {
        guard productionInfo.scheduleLock != nil else { return }
        productionInfo.scheduleLock = nil
        markDirty()
        recomputeScheduleLockChanges()
    }

    private func recomputeScheduleLockChanges() {
        scheduleLockChanges = ScheduleLockScanner.changes(shootDays: shootDays, productionInfo: productionInfo)
        scheduleLockChangedDates = ScheduleLockScanner.changedDates(scheduleLockChanges)
    }

    // MARK: - Undo/Redo

    /// Call BEFORE a structural mutation (not after) — captures the state as it exists
    /// right now, so that state is what gets restored if the caller's upcoming change is
    /// undone.
    private func captureUndoSnapshot() {
        undoStack.append(SceneUndoSnapshot(allScenes: allScenes, shootDays: shootDays))
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()   // a new action invalidates the old redo history
    }

    private func performUndo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(SceneUndoSnapshot(allScenes: allScenes, shootDays: shootDays))
        allScenes = previous.allScenes
        shootDays = previous.shootDays
        markDirty()
        recomputeSortedScenes()
        pruneSelection()
        recomputeConflicts()
        recomputeScheduleLockChanges()
    }

    private func performRedo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(SceneUndoSnapshot(allScenes: allScenes, shootDays: shootDays))
        allScenes = next.allScenes
        shootDays = next.shootDays
        markDirty()
        recomputeSortedScenes()
        pruneSelection()
        recomputeConflicts()
        recomputeScheduleLockChanges()
    }

    private func pruneSelection() {
        let scheduledIDs = Set(shootDays.flatMap { $0.scenes.map(\.id) })
        let boneyardIDs  = Set(allScenes.map(\.id))
        selectedSceneIDs = selectedSceneIDs.intersection(scheduledIDs.union(boneyardIDs))
    }

    /// Renames a character everywhere it appears in scene cast lists — both unscheduled
    /// (Boneyard) scenes and every scheduled day — so a rename in Production Setup keeps
    /// matching up with the actor lookup used by cast lists and call sheets, instead of
    /// silently going stale the moment the character's name changes.
    private func renameCastCharacter(from oldName: String, to newName: String) {
        let old = oldName.trimmingCharacters(in: .whitespaces)
        let new = newName.trimmingCharacters(in: .whitespaces)
        guard !old.isEmpty, !new.isEmpty, old.caseInsensitiveCompare(new) != .orderedSame else { return }

        func renamed(_ cast: [String]) -> [String] {
            cast.map { $0.caseInsensitiveCompare(old) == .orderedSame ? new : $0 }
        }

        for i in allScenes.indices {
            allScenes[i].cast = renamed(allScenes[i].cast)
        }
        for d in shootDays.indices {
            for s in shootDays[d].scenes.indices {
                shootDays[d].scenes[s].cast = renamed(shootDays[d].scenes[s].cast)
            }
            // A day's cast override (if manually edited) also stores raw character names,
            // so it needs the same rename applied to stay in sync.
            if let override = shootDays[d].callSheet.castOverride {
                shootDays[d].callSheet.castOverride = renamed(override)
            }
        }
        markDirty()
    }

    private func stripSceneNumber(_ title: String) -> String {
        let pattern = #"^\d+[A-Za-z]?\.\s*"#
        if let range = title.range(of: pattern, options: .regularExpression) {
            return String(title[range.upperBound...])
        }
        return title
    }

    /// Strips INT./EXT. prefix and scene number, returning just the location name.
    private func locationSortKey(_ title: String) -> String {
        let withoutNumber = stripSceneNumber(title)
        let pattern = #"^(INT\.|EXT\.)\s*"#
        if let range = withoutNumber.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            return String(withoutNumber[range.upperBound...])
        }
        return withoutNumber
    }

    /// Returns the INT/EXT prefix for sorting, or "ZZZ" to sort unknowns last.
    private func intExtSortKey(_ title: String) -> String {
        let withoutNumber = stripSceneNumber(title)
        if withoutNumber.uppercased().hasPrefix("INT.") { return "INT." }
        if withoutNumber.uppercased().hasPrefix("EXT.") { return "EXT." }
        return "ZZZ"
    }

    private var boneyardSortLabel: String {
        switch boneyardSort {
        case .defaultOrder: return "Default"
        case .location:     return "Location"
        case .intExt:       return "INT/EXT"
        case .cast:         return "Cast"
        case .dayNight:     return "Day/Night"
        }
    }

    // MARK: - Boneyard scene navigation (Previous/Next in edit sheet)

    /// Position of the scene currently being edited within the *displayed* (sorted) Boneyard order.
    private var currentBoneyardPosition: Int? {
        guard let idx = editingUnscheduledSceneIndex else { return nil }
        return sortedScenes.firstIndex { $0.index == idx }
    }

    private func goToPreviousUnscheduledScene() {
        guard let pos = currentBoneyardPosition, pos > 0 else { return }
        let target = sortedScenes[pos - 1]
        editingUnscheduledSceneIndex = target.index
        editingUnscheduledScene      = target.scene
    }

    private func goToNextUnscheduledScene() {
        guard let pos = currentBoneyardPosition, pos < sortedScenes.count - 1 else { return }
        let target = sortedScenes[pos + 1]
        editingUnscheduledSceneIndex = target.index
        editingUnscheduledScene      = target.scene
    }

    /// Cached Boneyard ordering. This used to be a computed property, which meant every one
    /// of its many call sites (drag payload, selection range, position lookups, the list body
    /// itself) re-sorted the whole Boneyard — regex key extraction included — on every access,
    /// several times per render. That's what caused the lag when selecting strips. Now it's
    /// only recomputed when allScenes or boneyardSort actually change (see .onChange below).
    @State private var sortedScenes: [(index: Int, scene: Scene)] = []

    private func recomputeSortedScenes() {
        let indexed = allScenes.enumerated().map { (index: $0.offset, scene: $0.element) }
        switch boneyardSort {
        case .defaultOrder:
            sortedScenes = indexed
        case .location:
            sortedScenes = indexed.sorted { locationSortKey($0.scene.title) < locationSortKey($1.scene.title) }
        case .intExt:
            sortedScenes = indexed.sorted {
                let a = intExtSortKey($0.scene.title)
                let b = intExtSortKey($1.scene.title)
                if a != b { return a < b }
                return locationSortKey($0.scene.title) < locationSortKey($1.scene.title)
            }
        case .cast:
            sortedScenes = indexed.sorted {
                let a = $0.scene.cast.sorted().first ?? "ZZZ"
                let b = $1.scene.cast.sorted().first ?? "ZZZ"
                return a < b
            }
        case .dayNight:
            sortedScenes = indexed.sorted {
                if $0.scene.dayNightType != $1.scene.dayNightType {
                    return $0.scene.dayNightType == .day
                }
                return locationSortKey($0.scene.title) < locationSortKey($1.scene.title)
            }
        }
    }

    // MARK: - Boneyard list

    private var boneyardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sortedScenes, id: \.scene.id) { item in
                    HStack {
                        Circle().fill(item.scene.dayNightType.color).frame(width: 8, height: 8)
                        Text(item.scene.title)
                        Spacer()
                        Text(item.scene.dayNightType == .day ? "D" : "N")
                            .font(.caption).foregroundColor(item.scene.dayNightType.color).fontWeight(.semibold)
                        Text("\(FractionParser.formatEighths(item.scene.duration)) / \(formattedTime(item.scene.estimatedTime))")
                        Button {
                            captureUndoSnapshot()
                            allScenes.remove(at: item.index)
                            markDirty()
                        } label: {
                            Image(systemName: "trash").foregroundColor(.red).help("Delete Scene")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3).padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedSceneIDs.contains(item.scene.id) ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.001))
                    )
                    .onDrag { dragPayload(for: item.scene) }
                    .fastTooltip(item.scene.tooltipText)
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            editingUnscheduledSceneIndex = item.index
                            editingUnscheduledScene      = item.scene
                            showingUnscheduledSceneEditSheet = true
                        }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            selectScene(item.scene.id)
                        }
                    )
                    .contextMenu {
                        Button("Edit Scene") {
                            editingUnscheduledSceneIndex = item.index
                            editingUnscheduledScene      = item.scene
                            showingUnscheduledSceneEditSheet = true
                        }
                        Button("Duplicate Scene") {
                            captureUndoSnapshot()
                            allScenes.append(Scene(
                                title:         item.scene.title + " (Copy)",
                                duration:      item.scene.duration,
                                estimatedTime: item.scene.estimatedTime,
                                dayNightType:  item.scene.dayNightType,
                                cast:          item.scene.cast,
                                summary:       item.scene.summary,
                                extras:           item.scene.extras,
                                props:            item.scene.props,
                                wardrobe:         item.scene.wardrobe,
                                vehicles:         item.scene.vehicles,
                                specialEquipment: item.scene.specialEquipment,
                                stunts:           item.scene.stunts,
                                sfx:              item.scene.sfx,
                                vfx:              item.scene.vfx,
                                breakdownNotes:   item.scene.breakdownNotes
                            ))
                            markDirty()
                        }
                        Divider()
                        Button("Delete Scene", role: .destructive) {
                            captureUndoSnapshot()
                            allScenes.remove(at: item.index)
                            markDirty()
                        }
                    }
                    Divider()
                }
            }
        }
        .tooltipContainer()
    }

    // MARK: - Boneyard selection helpers

    /// Applies click / ⌘-click / ⇧-click semantics using the live modifier flags at tap time —
    /// SwiftUI's plain tap gesture has no modifier parameter on macOS, so we read them directly.
    private func selectScene(_ id: UUID) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedSceneIDs.contains(id) { selectedSceneIDs.remove(id) } else { selectedSceneIDs.insert(id) }
            lastSelectedSceneID = id
        } else if flags.contains(.shift), let anchor = lastSelectedSceneID,
                  let anchorIdx  = sortedScenes.firstIndex(where: { $0.scene.id == anchor }),
                  let targetIdx  = sortedScenes.firstIndex(where: { $0.scene.id == id }) {
            let range = anchorIdx < targetIdx ? anchorIdx...targetIdx : targetIdx...anchorIdx
            selectedSceneIDs.formUnion(range.map { sortedScenes[$0].scene.id })
        } else {
            selectedSceneIDs = [id]
            lastSelectedSceneID = id
        }
    }

    /// Builds the drag payload for a Boneyard row. If the dragged scene is part of a multi-scene
    /// selection, the whole selection (in current Boneyard sort order) rides along as a comma-
    /// separated list of scene IDs; otherwise it's treated as a fresh single-scene drag. The
    /// calendar's drop handling already accepts either a single ID or a comma-separated list.
    private func dragPayload(for scene: Scene) -> NSItemProvider {
        let ids: [UUID]
        if selectedSceneIDs.contains(scene.id), selectedSceneIDs.count > 1 {
            ids = sortedScenes.map(\.scene).filter { selectedSceneIDs.contains($0.id) }.map(\.id)
        } else {
            selectedSceneIDs   = [scene.id]
            lastSelectedSceneID = scene.id
            ids = [scene.id]
        }
        let payload = ids.map(\.uuidString).joined(separator: ",")
        return NSItemProvider(object: payload as NSString)
    }

    // MARK: - Detail / main area

    private var detailView: some View {
        VStack {
            toolbarRow
            CompactMonthCalendarView(
                shootDays:    $shootDays,
                assignScene:  assign,
                allScenes:    $allScenes,
                updateScene:  updateScene,
                removeScene:  removeScene,
                projectTitle: projectTitle,
                productionInfo: productionInfo,
                isSidebarCollapsed: isSidebarCollapsed,
                selectedSceneIDs: $selectedSceneIDs,
                lastSelectedSceneID: $lastSelectedSceneID,
                conflictDates: conflictDates,
                conflictSceneIDs: conflictSceneIDs,
                scheduleLockChangedDates: scheduleLockChangedDates,
                scrollToDate: $scrollToDate,
                onBeforeSceneChange: captureUndoSnapshot,
                onSceneChanged: { markDirty(); pruneSelection(); recomputeConflicts(); recomputeScheduleLockChanges() },
                onCallSheetExport: { day in
                    showCallSheetPDFSavePanel(for: day)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Toolbar row

    private var toolbarRow: some View {
        HStack {
            Text(projectTitle.isEmpty ? "Untitled Movie" : projectTitle)
                .font(.headline).fontWeight(.semibold)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: 200)

            Divider().frame(height: 20)

            HStack(spacing: 15) {
                statBadge(icon: "calendar", value: "\(scheduledDays.count)", label: "days",   color: .blue)
                statBadge(icon: "film",     value: "\(totalScenes)",          label: "scenes", color: .green)
                statBadge(icon: "clock",    value: totalEstTime,              label: nil,      color: .purple)
                if !allScenes.isEmpty {
                    statBadge(icon: "tray.full", value: "\(allScenes.count)", label: "unscheduled", color: .orange)
                }
            }

            Spacer()

            scheduleSearchField
        }
        .padding(.bottom)
    }

    // MARK: - Schedule search

    fileprivate struct ScheduleSearchResult: Identifiable {
        let id = UUID()
        let scene: Scene
        let dayDate: Date?   // nil = unscheduled (Boneyard)
    }

    private var scheduleSearchResults: [ScheduleSearchResult] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }

        func matches(_ scene: Scene) -> Bool {
            if scene.title.lowercased().contains(query) { return true }
            if scene.summary.lowercased().contains(query) { return true }
            if scene.cast.contains(where: { $0.lowercased().contains(query) }) { return true }
            return false
        }

        var results: [ScheduleSearchResult] = []
        for scene in allScenes where matches(scene) {
            results.append(ScheduleSearchResult(scene: scene, dayDate: nil))
        }
        for day in shootDays {
            for scene in day.scenes where matches(scene) {
                results.append(ScheduleSearchResult(scene: scene, dayDate: day.date))
            }
        }
        return Array(results.prefix(30))
    }

    private var searchPopoverIsPresented: Binding<Bool> {
        Binding<Bool>(
            get: { self.searchPopoverShouldShow },
            set: { (newValue: Bool) in if !newValue { self.searchQuery = "" } }
        )
    }

    private var searchPopoverShouldShow: Bool {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        return !scheduleSearchResults.isEmpty
    }

    private var searchPopoverHeight: CGFloat {
        let rowHeight: CGFloat = 46
        let padding: CGFloat = 8
        let maxHeight: CGFloat = 340
        let contentHeight: CGFloat = CGFloat(scheduleSearchResults.count) * rowHeight + padding
        return min(contentHeight, maxHeight)
    }

    private func selectSearchResult(_ result: ScheduleSearchResult) {
        selectedSceneIDs = [result.scene.id]
        lastSelectedSceneID = result.scene.id
        if let date = result.dayDate { scrollToDate = date }
        searchQuery = ""
    }

    private var searchResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(scheduleSearchResults) { result in
                    ScheduleSearchResultRow(result: result, onSelect: { self.selectSearchResult(result) })
                    Divider()
                }
            }
        }
        .frame(width: 320, height: searchPopoverHeight)
    }

    private var scheduleSearchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search title, cast, summary…", text: $searchQuery)
                .textFieldStyle(.plain)
                .frame(width: 200)
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)))
        .popover(isPresented: searchPopoverIsPresented, arrowEdge: .bottom) {
            searchResultsList
        }
    }

    private func statBadge(icon: String, value: String, label: String?, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).foregroundColor(color).font(.caption)
            Text(value)
                .font(.system(.body, design: .rounded)).fontWeight(.semibold).foregroundColor(color)
            if let label = label {
                Text(label).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Unscheduled scene edit sheet

    @ViewBuilder
    private var unscheduledEditSheet: some View {
        if let idx = editingUnscheduledSceneIndex, idx < allScenes.count {
            SceneEditSheet(
                scene: $allScenes[idx],
                isPresented: $showingUnscheduledSceneEditSheet,
                onSave: { markDirty() },
                onDelete: {
                    captureUndoSnapshot()
                    if let i = editingUnscheduledSceneIndex { allScenes.remove(at: i) }
                    markDirty()
                    clearUnscheduledEditingState()
                },
                canGoPrevious: (currentBoneyardPosition ?? 0) > 0,
                canGoNext: currentBoneyardPosition.map { $0 < sortedScenes.count - 1 } ?? false,
                onPrevious: goToPreviousUnscheduledScene,
                onNext: goToNextUnscheduledScene,
                positionLabel: currentBoneyardPosition.map { "Scene \($0 + 1) of \(sortedScenes.count)" }
            )
        } else {
            VStack(spacing: 20) {
                Text("Error: Scene not found").font(.title2).foregroundColor(.red)
                Text("The scene may have been deleted.").font(.body).multilineTextAlignment(.center)
                Button("Close") {
                    showingUnscheduledSceneEditSheet = false
                    clearUnscheduledEditingState()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24).frame(width: 400)
        }
    }

    private func clearUnscheduledEditingState() {
        editingUnscheduledScene      = nil
        editingUnscheduledSceneIndex = nil
    }

    // MARK: - Breakdown Browser

    private func openBreakdownBrowser() {
        var seen = Set<UUID>()
        var combined: [Scene] = []
        for s in allScenes where !seen.contains(s.id) { seen.insert(s.id); combined.append(s) }
        for day in shootDays {
            for s in day.scenes where !seen.contains(s.id) { seen.insert(s.id); combined.append(s) }
        }
        breakdownBrowserScenes = combined.sorted { $0.scriptOrderKey < $1.scriptOrderKey }
        breakdownBrowserIndex = 0
        showingBreakdownBrowser = true
    }

    /// Resolves to wherever the current browser scene actually lives right now (Boneyard
    /// or a specific day) for both reading and writing, so SceneEditSheet can edit it
    /// without needing to know or care which one it is.
    private var breakdownBrowserSceneBinding: Binding<Scene> {
        Binding<Scene>(
            get: {
                guard breakdownBrowserScenes.indices.contains(breakdownBrowserIndex) else {
                    return Scene(title: "", duration: 0, estimatedTime: 0)
                }
                let id = breakdownBrowserScenes[breakdownBrowserIndex].id
                if let s = allScenes.first(where: { $0.id == id }) { return s }
                for day in shootDays {
                    if let s = day.scenes.first(where: { $0.id == id }) { return s }
                }
                return breakdownBrowserScenes[breakdownBrowserIndex]
            },
            set: { newValue in
                if let i = allScenes.firstIndex(where: { $0.id == newValue.id }) {
                    allScenes[i] = newValue
                    return
                }
                for d in shootDays.indices {
                    if let i = shootDays[d].scenes.firstIndex(where: { $0.id == newValue.id }) {
                        shootDays[d].scenes[i] = newValue
                        return
                    }
                }
            }
        )
    }

    private func deleteCurrentBreakdownScene() {
        guard breakdownBrowserScenes.indices.contains(breakdownBrowserIndex) else { return }
        captureUndoSnapshot()
        let id = breakdownBrowserScenes[breakdownBrowserIndex].id
        if let i = allScenes.firstIndex(where: { $0.id == id }) {
            allScenes.remove(at: i)
        } else {
            for d in shootDays.indices {
                if let i = shootDays[d].scenes.firstIndex(where: { $0.id == id }) {
                    shootDays[d].scenes.remove(at: i)
                    break
                }
            }
        }
        breakdownBrowserScenes.remove(at: breakdownBrowserIndex)
        if breakdownBrowserIndex >= breakdownBrowserScenes.count {
            breakdownBrowserIndex = max(0, breakdownBrowserScenes.count - 1)
        }
        markDirty()
        if breakdownBrowserScenes.isEmpty { showingBreakdownBrowser = false }
    }

    private func goToPreviousBreakdownScene() {
        guard breakdownBrowserIndex > 0 else { return }
        breakdownBrowserIndex -= 1
    }

    private func goToNextBreakdownScene() {
        guard breakdownBrowserIndex < breakdownBrowserScenes.count - 1 else { return }
        breakdownBrowserIndex += 1
    }

    // MARK: - Scene management

    func assign(scene: Scene, to day: ShootDay) {
        if let idx = shootDays.firstIndex(where: { $0.id == day.id }) {
            shootDays[idx].scenes.append(scene)
            allScenes.removeAll { $0.id == scene.id }
            markDirty()
        }
    }

    func updateScene(_ updated: Scene, in dayId: UUID) {
        if let di = shootDays.firstIndex(where: { $0.id == dayId }),
           let si = shootDays[di].scenes.firstIndex(where: { $0.id == updated.id }) {
            shootDays[di].scenes[si] = updated
            markDirty()
        }
    }

    func removeScene(_ scene: Scene, from dayId: UUID) {
        if let di = shootDays.firstIndex(where: { $0.id == dayId }) {
            shootDays[di].scenes.removeAll { $0.id == scene.id }
            allScenes.append(scene)
            markDirty()
        }
    }

    // MARK: - Calendar update (merge vs shift)

    private func updateShootDays(from newStart: Date, to newEnd: Date) {
        let cal            = Calendar.current
        let oldStart       = shootDays.first?.date ?? newStart
        let normOldStart   = cal.startOfDay(for: oldStart)
        let normNewStart   = cal.startOfDay(for: newStart)
        let normNewEnd     = cal.startOfDay(for: newEnd)
        let dayOffset      = cal.dateComponents([.day], from: normOldStart, to: normNewStart).day ?? 0

        let existingMap: [Date: ShootDay] = shootDays.reduce(into: [:]) {
            $0[cal.startOfDay(for: $1.date)] = $1
        }

        var updated: [ShootDay] = []
        var current = normNewStart
        while current <= normNewEnd {
            let day: ShootDay
            if isShiftModeEnabled {
                if let original = cal.date(byAdding: .day, value: -dayOffset, to: current),
                   let old = existingMap[original] {
                    day = ShootDay(date: current, scenes: old.scenes)
                } else {
                    day = ShootDay(date: current)
                }
            } else {
                day = existingMap[current] ?? ShootDay(date: current)
            }
            updated.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        shootDays = updated
        markDirty()
    }
}

/// Extracted out of scheduleSearchField's popover content — a single flat button row with
/// no dynamic layout math, kept deliberately simple so the type checker never has to fight
/// through it as part of a larger nested expression.
fileprivate struct ScheduleSearchResultRow: View {
    let result: ContentView.ScheduleSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.scene.title).font(.callout).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        guard let date = result.dayDate else { return "Boneyard (unscheduled)" }
        return formattedDate(date)
    }
}
