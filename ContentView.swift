// ContentView.swift
// Root view: holds app state, sidebar, toolbar, calendar and stripboard views.
// Business logic lives in ProjectStore.swift (persistence),
// CalendarView.swift (calendar/drag-drop), StripboardView.swift, and the other focused files.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Custom UTType for FDX files

extension UTType {
    static var fdx: UTType { UTType(importedAs: "com.finaldraft.fdx") }
}

// MARK: - Schedule View Mode

enum ScheduleViewMode: String, CaseIterable {
    case calendar   = "Calendar"
    case stripboard = "Stripboard"

    var localizedTitle: String {
        L(rawValue)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @AppStorage("CineSchedTheme") private var currentTheme: AppTheme = .blue
    @Environment(\.colorScheme) private var colorScheme

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
    @State var projectCreatedDate: Date = Date()
    @State var productionInfo: ProductionInfo = ProductionInfo()

    // Auto-save
    @State var hasUnsavedChanges: Bool = false

    // MARK: UI / sheet state
    @State private var newSceneNumber:   String       = ""
    @State private var newSceneTitle:    String       = ""
    @State private var newDuration:      String       = ""
    @State private var newEstimate:      String       = ""
    @State private var newDayNightType:  DayNightType = .day

    @State var showingAlert                   = false
    @State var showingImportAlert             = false
    @State private var showingClearAllConfirmation = false

    @State var alertMessage:   String = ""
    @State var importMessage:  String = ""
    @State private var importedScenesCount = 0

    // Fountain import confirmation & summary
    @State var pendingFountainImport:   FountainImportResult? = nil
    @State var completedFountainImport: FountainImportResult? = nil
    @State var showingFountainImportConfirmation = false
    @State var showingImportSummary              = false

    // Unscheduled-scene editing
    @State private var editingUnscheduledScene:      Scene?
    @State private var editingUnscheduledSceneIndex: Int?

    // Appearance & view mode
    @AppStorage("CineSchedDarkMode") var isDarkMode: Bool = false
    @AppStorage("CineSchedIncludeHoldInDOOD") var includeHoldInDOOD: Bool = true
    @AppStorage("CineSchedShowCastRow") var showCastOnCards: Bool = false
    @AppStorage("CineSchedShowEstTimeOnCards") var showEstTimeOnCards: Bool = false
    @AppStorage("CineSchedViewMode") private var viewMode: ScheduleViewMode = .calendar
    @EnvironmentObject var recentFiles: RecentFilesStore
    @State var currentFileURL: URL? = nil

    // Production Setup & Conflict states
    @State private var conflictReportResults: [ScheduleConflict] = []
    @State private var scrollToDate: Date? = nil
    @State private var conflictDates: Set<Date> = []
    @State private var conflictSceneIDs: Set<UUID> = []
    @State private var duplicateSceneNumberIDs: Set<UUID> = []
    @State private var searchQuery: String = ""

    // MARK: - Breakdown Browser
    @State private var breakdownBrowserScenes: [Scene] = []
    @State private var breakdownBrowserIndex: Int = 0

    // MARK: - Undo/Redo
    private struct SceneUndoSnapshot {
        let allScenes: [Scene]
        let shootDays: [ShootDay]
    }
    @State private var undoStack: [SceneUndoSnapshot] = []
    @State private var redoStack: [SceneUndoSnapshot] = []
    private let maxUndoDepth = 30
    /// Bumped on every undo/redo so CompactMonthCalendarView and StripboardView know to
    /// clear their own local drag-target state (dropTargetDayId, dayDropTargetId, etc.).
    /// That state lives inside those views, not here, so undo/redo restoring allScenes and
    /// shootDays alone doesn't touch it — without this, a day cell's drop-target border
    /// could stay highlighted indefinitely after an undo, with nothing left to clear it.
    @State private var dragStateResetToken: Int = 0
    @State private var scheduleLockChanges: [ScheduleLockChange] = []
    @State private var scheduleLockChangedDates: Set<Date> = []

    // MARK: - Sheet presentation
    private enum ActiveSheet: Identifiable, Hashable {
        case unscheduledEdit, productionSetup, conflictReport, scheduleLockReport, breakdownBrowser, sceneColorSettings
        var id: Self { self }
    }
    @State private var activeSheet: ActiveSheet? = nil

    private var isPresentedUnscheduledEdit: Binding<Bool> {
        Binding(get: { activeSheet == .unscheduledEdit }, set: { if !$0 { activeSheet = nil } })
    }
    private var isPresentedProductionSetup: Binding<Bool> {
        Binding(get: { activeSheet == .productionSetup }, set: { if !$0 { activeSheet = nil } })
    }
    private var isPresentedBreakdownBrowser: Binding<Bool> {
        Binding(get: { activeSheet == .breakdownBrowser }, set: { if !$0 { activeSheet = nil } })
    }

    // Boneyard sort
    enum BoneyardSort: String, CaseIterable {
        case showOrder    = "Show Order"
        case defaultOrder = "Default"
        case location     = "Location"
        case intExt       = "INT/EXT"
        case cast         = "Cast"
        case dayNight     = "Day/Night"
    }
    @AppStorage("CineSchedBoneyardSort") private var boneyardSort: BoneyardSort = .showOrder

    @AppStorage("CineSchedDateRangeExpanded") private var isDateRangeExpanded: Bool = true
    @AppStorage("CineSchedNewSceneExpanded")  private var isNewSceneExpanded:  Bool = true

    @State private var selectedSceneIDs:    Set<UUID> = []
    @State private var lastSelectedSceneID: UUID?

    // MARK: - Computed statistics
    private var scheduledDays: [ShootDay] { shootDays.filter { !$0.scenes.isEmpty } }
    private var totalScenes:   Int        { scheduledDays.reduce(0) { $0 + $1.scenes.count } }
    private var completedScenesCount: Int {
        scheduledDays.reduce(0) { $0 + $1.scenes.filter { $0.isCompleted }.count }
    }
    private var totalDuration: String     { formattedEighths(scheduledDays.reduce(0) { $0 + $1.totalDuration }) }
    private var totalEstTime:  String     { formattedTime(scheduledDays.reduce(0) { $0 + $1.totalEstimatedTime }) }

    // MARK: - Body
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("CineSchedSidebarCollapsed") private var sidebarCollapsedPreference: Bool = false
    private var isSidebarCollapsed: Bool { columnVisibility == .detailOnly }

    var body: some View {
        let base = NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            detailView
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .accentColor(currentTheme.primaryAccent(isDarkMode: isDarkMode))
        .background(WindowAccessor(backgroundColor: currentTheme.canvasBackground(isDarkMode: isDarkMode)))

        let withAlerts = applyAlerts(base)
        let withSheets = applySheets(withAlerts)
        let withLifecycle = applyLifecycle(withSheets)
        let withNotificationsA = applyNotificationHandlersA(withLifecycle)
        let withNotificationsB = applyNotificationHandlersB(withNotificationsA)
        return applyNotificationHandlersC(withNotificationsB)
    }

    // MARK: - Modifiers

    private func applyAlerts<Content: View>(_ content: Content) -> some View {
        content
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("CineSched"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showingImportAlert) {
                Alert(title: Text("Import Result"), message: Text(importMessage), dismissButton: .default(Text("OK")))
            }
            .confirmationDialog(
                "Import into Current Project?",
                isPresented: $showingFountainImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Import") { confirmPendingFountainImport() }
                Button("Cancel", role: .cancel) { cancelPendingFountainImport() }
            } message: {
                if let result = pendingFountainImport {
                    Text("'\(projectTitle)' already has scenes or a schedule. This will add \(result.scenes.count) new scene\(result.scenes.count == 1 ? "" : "s") to the Boneyard — nothing existing will be changed or removed.")
                }
            }
            .confirmationDialog(
                "Clear All Scenes and Schedule?",
                isPresented: $showingClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Project", role: .destructive) { clearAllScenes() }
                Button("Cancel",        role: .cancel)      {}
            } message: {
                Text("This will clear all scenes, call sheets, and the project title. This action cannot be undone.")
            }
    }

    private func applySheets<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showingColorLegend) {
                ColorLegendView()
            }
            .sheet(isPresented: $showingImportSummary) {
                if let result = completedFountainImport {
                    ImportSummaryView(result: result, onDismiss: { showingImportSummary = false })
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .unscheduledEdit:
                    unscheduledEditSheet
                case .productionSetup:
                    ProductionSetupSheet(
                        productionInfo: $productionInfo,
                        scenes: allScenes + shootDays.flatMap { $0.scenes },
                        isPresented: isPresentedProductionSetup,
                        onSave: { markDirty(); recomputeConflicts(); recomputeScheduleLockChanges() },
                        onCharacterRenamed: renameCastCharacter
                    )
                case .conflictReport:
                    ConflictReportSheet(
                        conflicts: conflictReportResults,
                        onSelectDate: { date in
                            activeSheet = nil
                            scrollToDate = date
                        },
                        onDismiss: { activeSheet = nil }
                    )
                case .scheduleLockReport:
                    ScheduleLockReportSheet(
                        changes: scheduleLockChanges,
                        lockedAt: productionInfo.scheduleLock?.lockedAt,
                        onSelectDate: { date in
                            activeSheet = nil
                            scrollToDate = date
                        },
                        onDismiss: { activeSheet = nil }
                    )
                case .breakdownBrowser:
                    breakdownBrowserEditSheet
                case .sceneColorSettings:
                    SceneColorSettingsSheet(onDismiss: { activeSheet = nil })
                }
            }
            .onChange(of: activeSheet) { _, newValue in
                if newValue != .unscheduledEdit {
                    clearUnscheduledEditingState()
                }
            }
    }

    @ViewBuilder
    private var breakdownBrowserEditSheet: some View {
        Group {
            if breakdownBrowserScenes.indices.contains(breakdownBrowserIndex) {
                SceneEditSheet(
                    scene: $breakdownBrowserScenes[breakdownBrowserIndex],
                    isPresented: isPresentedBreakdownBrowser,
                    onSave: { markDirty(); writeBackCurrentBreakdownScene() },
                    onDelete: { deleteCurrentBreakdownScene() },
                    canGoPrevious: breakdownBrowserIndex > 0,
                    canGoNext: breakdownBrowserIndex < breakdownBrowserScenes.count - 1,
                    onPrevious: goToPreviousBreakdownScene,
                    onNext: goToNextBreakdownScene,
                    positionLabel: "Scene \(breakdownBrowserIndex + 1) of \(breakdownBrowserScenes.count) — script order",
                    breakdownExpandedByDefault: true,
                    closeAfterDelete: false
                )
            } else {
                VStack(spacing: 20) {
                    Text("No scenes to browse").font(.title2).foregroundColor(.secondary)
                    Button("Close") { activeSheet = nil }
                        .buttonStyle(.borderedProminent)
                }
                .padding(24).frame(width: 400)
                .onAppear {
                    populateBreakdownBrowserScenes()
                }
            }
        }
        .id(breakdownBrowserScenes.isEmpty)
    }

    private func applyLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .onAppear {
                loadDefaultProject()
                restoreCurrentFileURL()
                recomputeSortedScenes()
                recomputeConflicts()
                recomputeScheduleLockChanges()
                columnVisibility = sidebarCollapsedPreference ? .detailOnly : .all
            }
            .onChange(of: columnVisibility) { _, newValue in
                sidebarCollapsedPreference = (newValue == .detailOnly)
            }
            .onChange(of: shootDays.map(\.scenes)) { _, _ in
                pruneSelection()
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
            // Debounced auto-save
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
                showScriptImportPanel()
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
            .onReceive(NotificationCenter.default.publisher(for: .csExportStripboardPDF)) { _ in
                showStripboardPDFSavePanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csExportDaysOutOfDays)) { _ in
                showDaysOutOfDaysPDFSavePanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csOpenProductionSetup)) { _ in
                activeSheet = .productionSetup
            }
            .onReceive(NotificationCenter.default.publisher(for: .csScanForConflicts)) { _ in
                conflictReportResults = ConflictScanner.scan(shootDays: shootDays, productionInfo: productionInfo)
                activeSheet = .conflictReport
            }
            .onReceive(NotificationCenter.default.publisher(for: .csUndo)) { _ in
                performUndo()
            }
            .onReceive(NotificationCenter.default.publisher(for: .csRedo)) { _ in
                performRedo()
            }
    }

    @State private var showingColorLegend = false

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
                activeSheet = .scheduleLockReport
            }
            .onReceive(NotificationCenter.default.publisher(for: .csShowSceneColorSettings)) { _ in
                activeSheet = .sceneColorSettings
            }
            .onReceive(NotificationCenter.default.publisher(for: .csShowColorLegend)) { _ in
                showingColorLegend = true
            }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Movie Title", text: $projectTitle)
                .font(.title2)
                .padding(.bottom, 2)
                .onChange(of: projectTitle) { _, _ in markDirty() }

            Text("\(L("Shoot Days:")) \(shootDays.filter { !$0.scenes.isEmpty }.count)")
                .font(.subheadline).foregroundColor(.gray)

            if let first = shootDays.first?.date, let last = shootDays.last?.date {
                Text("\(L("From")) \(formattedDate(first)) \(L("to")) \(formattedDate(last))")
                    .font(.subheadline).foregroundColor(.gray)
            }

            Divider().padding(.vertical, 2)

            // Date range picker — collapsible
            DisclosureGroup(isExpanded: $isDateRangeExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(L("Start Date"), selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, _ in markDirty() }
                    DatePicker(L("End Date"), selection: $endDate, displayedComponents: .date)
                        .onChange(of: endDate) { _, _ in markDirty() }

                    Toggle(isOn: $isShiftModeEnabled) {
                        HStack(spacing: 4) {
                            Text(L("Shift Schedule"))
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .fastTooltip(
                        LocalizationManager.shared.currentLanguage == .spanish
                            ? "Desplazar Calendario\nCuando está activado, al cambiar la Fecha de Inicio se desplazan automáticamente todas las escenas ya programadas en el calendario, conservando la distribución del plan de rodaje."
                            : "Shift Schedule\nWhen enabled, changing the Start Date automatically shifts all scheduled scenes across the calendar, preserving your shoot day plan."
                    )
                    .onChange(of: isShiftModeEnabled) { _, _ in markDirty() }

                    Button(L("Update Calendar")) { updateShootDays(from: startDate, to: endDate) }
                }
                .padding(.top, 4)
            } label: {
                Text(L("Select Date Range")).font(.headline)
            }

            Divider().padding(.vertical, 2)

            // New Scene form — collapsible
            DisclosureGroup(isExpanded: $isNewSceneExpanded) {
                NewSceneInputView(
                    newSceneNumber:   $newSceneNumber,
                    newSceneTitle:    $newSceneTitle,
                    newDuration:      $newDuration,
                    newEstimate:      $newEstimate,
                    newDayNightType:  $newDayNightType,
                    allScenes:        $allScenes
                )
                .padding(.top, 4)
            } label: {
                Text(L("New Scene")).font(.headline)
            }

            Divider().padding(.vertical, 2)

            // Boneyard header with sort menu
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Boneyard")).font(.headline)
                    Spacer()
                    if !selectedSceneIDs.isEmpty {
                        Button(L("Clear")) { selectedSceneIDs = []; lastSelectedSceneID = nil }
                            .buttonStyle(.plain)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                HStack {
                    if !selectedSceneIDs.isEmpty {
                        Text("· \(selectedSceneIDs.count) \(L("selected"))")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(currentTheme.primaryAccent(isDarkMode: isDarkMode))
                    }
                    Spacer()
                    Menu {
                        Button(L("Show Order"))    { boneyardSort = .showOrder }
                        Button(L("Default"))       { boneyardSort = .defaultOrder }
                        Button(L("Location"))      { boneyardSort = .location }
                        Button(L("INT/EXT"))       { boneyardSort = .intExt }
                        Button(L("Cast"))          { boneyardSort = .cast }
                        Button(L("Day/Night"))     { boneyardSort = .dayNight }
                    } label: {
                        HStack(spacing: 3) {
                            Text(boneyardSortLabel)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }
            }

            Text("⌘-click or ⇧-click to select multiple, then drag as a group")
                .font(.caption2).foregroundColor(.secondary)

            boneyardList
                .frame(maxHeight: .infinity)
        }
        .padding(10)
        .frame(minWidth: 300, maxHeight: .infinity)
        .background(currentTheme.panelBackground(isDarkMode: isDarkMode))
    }

    // MARK: - Boneyard sort & conflict helpers

    private func recomputeConflicts() {
        let conflicts = ConflictScanner.scan(shootDays: shootDays, productionInfo: productionInfo)
        conflictDates = ConflictScanner.conflictDates(conflicts)
        conflictSceneIDs = ConflictScanner.conflictSceneIDs(conflicts)
        duplicateSceneNumberIDs = ConflictScanner.duplicateSceneNumberIDs(allScenes: allScenes, shootDays: shootDays)
    }

    // MARK: - Schedule Lock

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

    private func captureUndoSnapshot() {
        undoStack.append(SceneUndoSnapshot(allScenes: allScenes, shootDays: shootDays))
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
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
        dragStateResetToken += 1
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
        dragStateResetToken += 1
    }

    private func pruneSelection() {
        let scheduledIDs = Set(shootDays.flatMap { $0.scenes.map(\.id) })
        let boneyardIDs  = Set(allScenes.map(\.id))
        selectedSceneIDs = selectedSceneIDs.intersection(scheduledIDs.union(boneyardIDs))
    }

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

    private func locationSortKey(_ title: String) -> String {
        let withoutNumber = stripSceneNumber(title)
        let pattern = #"^(INT\.|EXT\.)\s*"#
        if let range = withoutNumber.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            return String(withoutNumber[range.upperBound...])
        }
        return withoutNumber
    }

    private func intExtSortKey(_ title: String) -> String {
        let withoutNumber = stripSceneNumber(title)
        if withoutNumber.uppercased().hasPrefix("INT.") { return "INT." }
        if withoutNumber.uppercased().hasPrefix("EXT.") { return "EXT." }
        return "ZZZ"
    }

    private var boneyardSortLabel: String {
        switch boneyardSort {
        case .showOrder:    return L("Show Order")
        case .defaultOrder: return L("Default")
        case .location:     return L("Location")
        case .intExt:       return L("INT/EXT")
        case .cast:         return L("Cast")
        case .dayNight:     return L("Day/Night")
        }
    }

    // MARK: - Boneyard scene navigation

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

    @State private var sortedScenes: [(index: Int, scene: Scene)] = []

    private func recomputeSortedScenes() {
        let indexed = allScenes.enumerated()
            .filter { !$0.element.isBanner }
            .map { (index: $0.offset, scene: $0.element) }
        switch boneyardSort {
        case .showOrder:
            sortedScenes = indexed.sorted {
                let a = $0.scene.scriptOrderKey
                let b = $1.scene.scriptOrderKey
                if a.0 != b.0 { return a.0 < b.0 }
                return a.1 < b.1
            }
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
                    return $0.scene.dayNightType.sortOrder < $1.scene.dayNightType.sortOrder
                }
                return locationSortKey($0.scene.title) < locationSortKey($1.scene.title)
            }
        }
    }

    // MARK: - Boneyard list (Movie Magic strip styling)

    private var boneyardList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(sortedScenes, id: \.scene.id) { item in
                    let isDup = duplicateSceneNumberIDs.contains(item.scene.id)
                    HStack(spacing: 6) {
                        if !item.scene.sceneNumber.isEmpty {
                            Text(item.scene.sceneNumber)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(item.scene.stripTextColor.opacity(0.6))
                                .lineLimit(1)
                                .frame(minWidth: 18, alignment: .leading)
                        }

                        Text(item.scene.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(item.scene.stripTextColor)
                            .lineLimit(1)

                        if isDup {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                        }

                        Spacer(minLength: 4)

                        Text(FractionParser.formatEighths(item.scene.duration))
                            .font(.system(size: 10, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(item.scene.stripTextColor.opacity(0.8))
                    }
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .background(item.scene.stripColor)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(selectedSceneIDs.contains(item.scene.id) ? Color.accentColor : item.scene.stripTextColor.opacity(0.2), lineWidth: selectedSceneIDs.contains(item.scene.id) ? 2 : 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .opacity(isDup ? 1 : 0)
                    )
                    .onDrag { dragPayload(for: item.scene) }
                    .fastTooltip(item.scene.tooltipText)
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            editingUnscheduledSceneIndex = item.index
                            editingUnscheduledScene      = item.scene
                            activeSheet = .unscheduledEdit
                        }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            selectScene(item.scene.id)
                        }
                    )
                    .contextMenu {
                        Button(L("Edit Scene")) {
                            editingUnscheduledSceneIndex = item.index
                            editingUnscheduledScene      = item.scene
                            activeSheet = .unscheduledEdit
                        }
                        Button(L("Duplicate Scene")) {
                            captureUndoSnapshot()
                            allScenes.append(Scene(
                                title:            item.scene.title + " (Copy)",
                                sceneNumber:      item.scene.sceneNumber,
                                duration:         item.scene.duration,
                                estimatedTime:    item.scene.estimatedTime,
                                dayNightType:     item.scene.dayNightType,
                                cast:             item.scene.cast,
                                summary:          item.scene.summary,
                                extras:           item.scene.extras,
                                props:            item.scene.props,
                                setDressing:      item.scene.setDressing,
                                wardrobe:         item.scene.wardrobe,
                                makeupHair:       item.scene.makeupHair,
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
                        Button(L("Delete Scene"), role: .destructive) {
                            captureUndoSnapshot()
                            allScenes.remove(at: item.index)
                            markDirty()
                        }
                    }
                }
            }
            .padding(4)
        }
        .tooltipContainer()
        .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { item, _ in
                if let idString = item as? String {
                    DispatchQueue.main.async { moveScenesToBoneyard(idString) }
                }
            }
            return true
        }
    }

    private func moveScenesToBoneyard(_ payload: String) {
        let ids = payload.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
        guard !ids.isEmpty else { return }
        captureUndoSnapshot()
        for id in ids {
            guard let day = shootDays.first(where: { day in day.scenes.contains { $0.id == id } }),
                  let scene = day.scenes.first(where: { $0.id == id }) else { continue }
            removeScene(scene, from: day.id)
        }
    }

    // MARK: - Boneyard selection helpers

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
            if viewMode == .calendar {
                CompactMonthCalendarView(
                    shootDays:    $shootDays,
                    assignScene:  assign,
                    allScenes:    $allScenes,
                    updateScene:  updateScene,
                    removeScene:  removeScene,
                    projectTitle: projectTitle,
                    productionInfo: productionInfo,
                    isSidebarCollapsed: isSidebarCollapsed,
                    showCastOnCards: showCastOnCards,
                    showEstTimeOnCards: showEstTimeOnCards,
                    startDate: startDate,
                    endDate: endDate,
                    selectedSceneIDs: $selectedSceneIDs,
                    lastSelectedSceneID: $lastSelectedSceneID,
                    conflictDates: conflictDates,
                    conflictSceneIDs: conflictSceneIDs,
                    duplicateSceneNumberIDs: duplicateSceneNumberIDs,
                    scheduleLockChangedDates: scheduleLockChangedDates,
                    scrollToDate: $scrollToDate,
                    dragStateResetToken: dragStateResetToken,
                    onBeforeSceneChange: captureUndoSnapshot,
                    onSceneChanged: { markDirty(); pruneSelection(); recomputeConflicts(); recomputeScheduleLockChanges() },
                    onCallSheetExport: { day in
                        showCallSheetPDFSavePanel(for: day)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                StripboardView(
                    shootDays: $shootDays,
                    allScenes: $allScenes,
                    productionInfo: productionInfo,
                    selectedSceneIDs: $selectedSceneIDs,
                    lastSelectedSceneID: $lastSelectedSceneID,
                    conflictDates: conflictDates,
                    conflictSceneIDs: conflictSceneIDs,
                    duplicateSceneNumberIDs: duplicateSceneNumberIDs,
                    scrollToDate: $scrollToDate,
                    dragStateResetToken: dragStateResetToken,
                    onSceneChanged: { markDirty(); pruneSelection(); recomputeConflicts(); recomputeScheduleLockChanges() },
                    onCallSheetExport: { day in
                        showCallSheetPDFSavePanel(for: day)
                    },
                    onShootingScheduleExport: { days in
                        showShootingSchedulePDFSavePanel(for: days)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(currentTheme.canvasBackground(isDarkMode: isDarkMode))
    }

    // MARK: - Toolbar row

    private var toolbarRow: some View {
        HStack {
            Text(projectTitle.isEmpty ? "Untitled Movie" : projectTitle)
                .font(.headline).fontWeight(.bold)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: 220)

            Divider().frame(height: 20)

            HStack(spacing: 15) {
                statBadge(icon: "calendar", value: "\(scheduledDays.count)", label: "days",   color: .blue)
                statBadge(icon: "checkmark.circle", value: "\(completedScenesCount)/\(totalScenes)", label: "completed", color: .green)
                statBadge(icon: "clock",    value: totalEstTime,              label: nil,      color: .purple)
                let unscheduledCount = allScenes.filter { !$0.isBanner }.count
                if unscheduledCount > 0 {
                    statBadge(icon: "tray.full", value: "\(unscheduledCount)", label: "unscheduled", color: .orange)
                }
            }

            Spacer()

            // Custom View Mode Switcher pill styled with currentTheme.activeTabColor
            HStack(spacing: 2) {
                ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewMode = mode
                    } label: {
                        Text(mode.localizedTitle)
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .foregroundColor(viewMode == mode ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewMode == mode
                                        ? currentTheme.activeTabColor(isDarkMode: isDarkMode)
                                        : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.gray.opacity(0.18))
            .cornerRadius(8)

            scheduleSearchField
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(currentTheme.panelBackground(isDarkMode: isDarkMode))
        )
        .padding(.bottom, 6)
    }

    private func showShootingSchedulePDFSavePanel(for targetDays: [ShootDay]? = nil) {
        let daysToExport = targetDays ?? shootDays
        let pdfData = ShootingSchedulePDFExporter.generatePDF(
            shootDays: daysToExport,
            projectTitle: projectTitle,
            productionInfo: productionInfo
        )
        let panel = NSSavePanel()
        panel.title = L("Export Plan de Rodaje (PDF)")
        let sanitizeName = projectTitle.isEmpty ? "Shooting_Schedule" : projectTitle.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(sanitizeName)_Shooting_Schedule.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try pdfData.write(to: url)
                } catch {
                    alertMessage = "Error saving Shooting Schedule PDF: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }

    // MARK: - Schedule search

    fileprivate struct ScheduleSearchResult: Identifiable {
        let id = UUID()
        let scene: Scene
        let dayDate: Date?
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
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.caption)
            Text(value)
                .font(.system(.body, design: .rounded)).fontWeight(.semibold).foregroundColor(color)
            if let label = label {
                Text(L(label)).font(.caption).foregroundColor(.secondary)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: true)
    }

    // MARK: - Unscheduled scene edit sheet

    @ViewBuilder
    private var unscheduledEditSheet: some View {
        if let idx = editingUnscheduledSceneIndex, idx < allScenes.count {
            SceneEditSheet(
                scene: $allScenes[idx],
                isPresented: isPresentedUnscheduledEdit,
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
                    activeSheet = nil
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

    @discardableResult
    private func populateBreakdownBrowserScenes() -> Bool {
        var seen = Set<UUID>()
        var combined: [Scene] = []
        for s in allScenes where !seen.contains(s.id) { seen.insert(s.id); combined.append(s) }
        for day in shootDays {
            for s in day.scenes where !seen.contains(s.id) { seen.insert(s.id); combined.append(s) }
        }
        breakdownBrowserScenes = combined.sorted {
            let a = $0.scriptOrderKey
            let b = $1.scriptOrderKey
            if a.0 != b.0 { return a.0 < b.0 }
            return a.1 < b.1
        }
        if breakdownBrowserIndex >= breakdownBrowserScenes.count {
            breakdownBrowserIndex = 0
        }
        return !breakdownBrowserScenes.isEmpty
    }

    private func openBreakdownBrowser() {
        guard populateBreakdownBrowserScenes() else {
            alertMessage = "There are no scenes to browse yet — add some scenes first."
            showingAlert = true
            return
        }
        breakdownBrowserIndex = 0
        activeSheet = .breakdownBrowser
    }

    private func writeBackCurrentBreakdownScene() {
        guard breakdownBrowserScenes.indices.contains(breakdownBrowserIndex) else { return }
        let scene = breakdownBrowserScenes[breakdownBrowserIndex]
        if let i = allScenes.firstIndex(where: { $0.id == scene.id }) {
            allScenes[i] = scene
            return
        }
        for d in shootDays.indices {
            if let i = shootDays[d].scenes.firstIndex(where: { $0.id == scene.id }) {
                shootDays[d].scenes[i] = scene
                return
            }
        }
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
        if breakdownBrowserScenes.isEmpty { activeSheet = nil }
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
        let cal          = Calendar.current
        let normNewStart = cal.startOfDay(for: newStart)
        let normNewEnd   = cal.startOfDay(for: newEnd)

        // 1. Separate calendar events (which stay anchored to their real date) from script scenes
        var calendarEventsByDate: [Date: [Scene]] = [:]
        var scriptScenesByDate: [Date: [Scene]] = [:]
        var allExistingScriptScenes: [UUID: Scene] = [:]

        for day in shootDays {
            let dayNorm = cal.startOfDay(for: day.date)
            let events = day.scenes.filter { $0.isCalendarEvent }
            let scripts = day.scenes.filter { !$0.isCalendarEvent }
            if !events.isEmpty {
                calendarEventsByDate[dayNorm, default: []].append(contentsOf: events)
            }
            if !scripts.isEmpty {
                scriptScenesByDate[dayNorm, default: []].append(contentsOf: scripts)
                for s in scripts { allExistingScriptScenes[s.id] = s }
            }
        }

        // 2. Find old shooting start date (from actual script scenes or previous start)
        let sortedScriptDates = scriptScenesByDate.keys.sorted()
        let oldScriptStart = sortedScriptDates.first ?? normNewStart
        let dayOffset = cal.dateComponents([.day], from: oldScriptStart, to: normNewStart).day ?? 0

        var updatedDays: [ShootDay] = []
        var scheduledSceneIDs: Set<UUID> = []

        var current = normNewStart
        while current <= normNewEnd {
            var dayScenes: [Scene] = []

            // Add script scenes (shifted or merged)
            if isShiftModeEnabled {
                if let sourceDate = cal.date(byAdding: .day, value: -dayOffset, to: current),
                   let sourceScenes = scriptScenesByDate[cal.startOfDay(for: sourceDate)] {
                    dayScenes.append(contentsOf: sourceScenes)
                }
            } else {
                if let existing = scriptScenesByDate[current] {
                    dayScenes.append(contentsOf: existing)
                }
            }

            // Add anchored calendar events for this date
            if let events = calendarEventsByDate[current] {
                dayScenes.append(contentsOf: events)
            }

            for s in dayScenes where !s.isCalendarEvent {
                scheduledSceneIDs.insert(s.id)
            }

            updatedDays.append(ShootDay(date: current, scenes: dayScenes))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // 3. Preserve calendar events that exist outside the new shoot range
        for (eventDate, events) in calendarEventsByDate {
            if eventDate < normNewStart || eventDate > normNewEnd {
                if !updatedDays.contains(where: { cal.isDate($0.date, inSameDayAs: eventDate) }) {
                    updatedDays.append(ShootDay(date: eventDate, scenes: events))
                }
            }
        }

        // 4. ANTI-LOSS SAFETY NET: Any script scenes that didn't fit into the new schedule
        // are returned to allScenes (Boneyard) so they are NEVER permanently lost!
        for (sceneId, scene) in allExistingScriptScenes {
            if !scheduledSceneIDs.contains(sceneId) && !allScenes.contains(where: { $0.id == sceneId }) {
                allScenes.append(scene)
            }
        }

        updatedDays.sort { $0.date < $1.date }
        shootDays = updatedDays
        recomputeSortedScenes()
        pruneSelection()
        recomputeConflicts()
        recomputeScheduleLockChanges()
        markDirty()
    }
}

fileprivate struct ScheduleSearchResultRow: View {
    let result: ContentView.ScheduleSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.scene.displayTitle).font(.callout).lineLimit(1)
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

fileprivate struct WindowAccessor: NSViewRepresentable {
    let backgroundColor: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(backgroundColor)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(backgroundColor)
            }
        }
    }
}
