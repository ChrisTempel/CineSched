// ContentView.swift
// Root view: holds app state, sidebar, toolbar, and calendar.
// Business logic lives in ProjectStore.swift (persistence),
// CalendarView.swift (calendar/drag-drop), and the other focused files.

import SwiftUI
import UniformTypeIdentifiers

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
    @State var isDarkMode: Bool = false

    // Production Setup sheet
    @State private var showingProductionSetup = false

    // Boneyard sort
    enum BoneyardSort { case defaultOrder, location, intExt, cast, dayNight }
    @State private var boneyardSort: BoneyardSort = .defaultOrder

    // MARK: - Computed statistics

    private var scheduledDays: [ShootDay] { shootDays.filter { !$0.scenes.isEmpty } }
    private var totalScenes:   Int        { scheduledDays.reduce(0) { $0 + $1.scenes.count } }
    private var totalDuration: String     { formattedEighths(scheduledDays.reduce(0) { $0 + $1.totalDuration }) }
    private var totalEstTime:  String     { formattedTime(scheduledDays.reduce(0) { $0 + $1.totalEstimatedTime }) }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert("Script Import",  isPresented: $showingImportAlert) { Button("OK") {} } message: { Text(importMessage) }
        .alert("CineSched",      isPresented: $showingAlert)        { Button("OK") {} } message: { Text(alertMessage) }
        .confirmationDialog("Clear All Scenes", isPresented: $showingClearAllConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) { clearAllScenes() }
            Button("Cancel",    role: .cancel)      {}
        } message: {
            Text("This will clear all scenes, call sheets, and the project title. This action cannot be undone.")
        }
        .sheet(isPresented: $showingUnscheduledSceneEditSheet) { unscheduledEditSheet }
        .onChange(of: showingUnscheduledSceneEditSheet) { isShowing in
            if !isShowing { clearUnscheduledEditingState() }
        }
        .sheet(isPresented: $showingProductionSetup) {
            ProductionSetupSheet(
                productionInfo: $productionInfo,
                isPresented: $showingProductionSetup,
                onSave: { markDirty() }
            )
        }
        .onAppear {
            loadDefaultProject()
            loadAppearancePreference()
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

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Movie Title", text: $projectTitle)
                .font(.title2)
                .padding(.bottom, 2)
                .onChange(of: projectTitle) { _ in markDirty() }

            Text("Shoot Days: \(shootDays.filter { !$0.scenes.isEmpty }.count)")
                .font(.subheadline).foregroundColor(.gray)

            if let first = shootDays.first?.date, let last = shootDays.last?.date {
                Text("From \(formattedDate(first)) to \(formattedDate(last))")
                    .font(.subheadline).foregroundColor(.gray)
            }

            Divider().padding(.vertical)

            // Date range picker
            Group {
                Text("Select Date Range").font(.headline)
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .onChange(of: startDate) { _ in markDirty() }
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    .onChange(of: endDate) { _ in markDirty() }

                Toggle(isOn: $isShiftModeEnabled) { Text("Shift Schedule") }
                    .toggleStyle(.switch)
                    .help("When enabled, changing the Start Date shifts all scenes on the calendar.")
                    .onChange(of: isShiftModeEnabled) { _ in markDirty() }

                Button("Update Calendar") { updateShootDays(from: startDate, to: endDate) }
                    .padding(.top, 5)

                Divider().padding(.vertical)
            }

            NewSceneInputView(
                newSceneTitle: $newSceneTitle,
                newDuration:   $newDuration,
                newEstimate:   $newEstimate,
                allScenes:     $allScenes,
                onSceneAdded:  { markDirty() }
            )

            Divider().padding(.vertical)

            // Boneyard header with sort menu
            HStack {
                Text("Boneyard").font(.headline)
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

            boneyardList

            Spacer()
        }
        .padding()
        .frame(minWidth: 300)
    }

    // MARK: - Boneyard sort helpers

    /// Strips a leading scene number ("7. ", "12A. ") from a title for sorting purposes.
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

    private var sortedScenes: [(index: Int, scene: Scene)] {
        let indexed = allScenes.enumerated().map { (index: $0.offset, scene: $0.element) }
        switch boneyardSort {
        case .defaultOrder:
            return indexed
        case .location:
            return indexed.sorted { locationSortKey($0.scene.title) < locationSortKey($1.scene.title) }
        case .intExt:
            return indexed.sorted {
                let a = intExtSortKey($0.scene.title)
                let b = intExtSortKey($1.scene.title)
                if a != b { return a < b }
                return locationSortKey($0.scene.title) < locationSortKey($1.scene.title)
            }
        case .cast:
            return indexed.sorted {
                let a = $0.scene.cast.sorted().first ?? "ZZZ"
                let b = $1.scene.cast.sorted().first ?? "ZZZ"
                return a < b
            }
        case .dayNight:
            return indexed.sorted {
                if $0.scene.dayNightType != $1.scene.dayNightType {
                    return $0.scene.dayNightType == .day
                }
                return locationSortKey($0.scene.title) < locationSortKey($1.scene.title)
            }
        }
    }

    // MARK: - Boneyard list

    private var boneyardList: some View {
        List {
            ForEach(sortedScenes, id: \.scene.id) { item in
                HStack {
                    Circle().fill(item.scene.dayNightType.color).frame(width: 8, height: 8)
                    Text(item.scene.title)
                    Spacer()
                    Text(item.scene.dayNightType == .day ? "D" : "N")
                        .font(.caption).foregroundColor(item.scene.dayNightType.color).fontWeight(.semibold)
                    Text("\(FractionParser.formatEighths(item.scene.duration)) / \(formattedTime(item.scene.estimatedTime))")
                    Button {
                        allScenes.remove(at: item.index)
                        markDirty()
                    } label: {
                        Image(systemName: "trash").foregroundColor(.red).help("Delete Scene")
                    }
                    .buttonStyle(.plain)
                }
                .onDrag { NSItemProvider(object: item.scene.id.uuidString as NSString) }
                .help(item.scene.title)
                .onTapGesture(count: 2) {
                    editingUnscheduledSceneIndex = item.index
                    editingUnscheduledScene      = item.scene
                    showingUnscheduledSceneEditSheet = true
                }
                .contextMenu {
                    Button("Edit Scene") {
                        editingUnscheduledSceneIndex = item.index
                        editingUnscheduledScene      = item.scene
                        showingUnscheduledSceneEditSheet = true
                    }
                    Button("Duplicate Scene") {
                        allScenes.append(Scene(
                            title:         item.scene.title + " (Copy)",
                            duration:      item.scene.duration,
                            estimatedTime: item.scene.estimatedTime,
                            dayNightType:  item.scene.dayNightType,
                            cast:          item.scene.cast,
                            summary:       item.scene.summary
                        ))
                        markDirty()
                    }
                    Divider()
                    Button("Delete Scene", role: .destructive) {
                        allScenes.remove(at: item.index)
                        markDirty()
                    }
                }
            }
        }
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
                onSceneChanged: { markDirty() },
                onCallSheetExport: { day in
                    showCallSheetPDFSavePanel(for: day)
                }
            )
        }
        .padding()
    }

    // MARK: - Toolbar row

    private var toolbarRow: some View {
        HStack {
            HStack(spacing: 12) {
                Button("New") { showingClearAllConfirmation = true }
                    .buttonStyle(.bordered).foregroundColor(.red)

                Button("Production Setup") { showingProductionSetup = true }
                    .buttonStyle(.bordered)
                    .help("Set production company, director, contact, and crew for call sheets")

                Button("Import Script") { showFDXOpenPanel() }
                    .buttonStyle(.bordered)
                    .help("Import scenes from Final Draft (.fdx)")

                Button("Save") { showNativeSaveDialog() }
                    .buttonStyle(.bordered)

                Button("Load") { showJSONOpenPanel() }
                    .buttonStyle(.bordered)

                Button("Export PDF") { showSchedulePDFSavePanel() }
                    .buttonStyle(.borderedProminent)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isDarkMode.toggle()
                        saveAppearancePreference()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .foregroundColor(isDarkMode ? .yellow : .blue)
                            .font(.system(size: 14, weight: .semibold))
                        Text(isDarkMode ? "Light" : "Dark")
                            .font(.caption).fontWeight(.medium)
                    }
                }
                .buttonStyle(.bordered)
                .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
            }

            Spacer()

            // Compact statistics
            HStack(spacing: 20) {
                Text(projectTitle.isEmpty ? "Untitled Movie" : projectTitle)
                    .font(.headline).fontWeight(.semibold)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: 200)

                Divider().frame(height: 20)

                HStack(spacing: 15) {
                    statBadge(icon: "calendar", value: "\(scheduledDays.count)", label: "days",   color: .blue)
                    statBadge(icon: "film",     value: "\(totalScenes)",          label: "scenes", color: .green)
                    statBadge(icon: "clock",    value: totalEstTime,              label: nil,      color: .purple)
                }
            }
        }
        .padding(.bottom)
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
                onSave: { markDirty(); clearUnscheduledEditingState() },
                onDelete: {
                    if let i = editingUnscheduledSceneIndex { allScenes.remove(at: i) }
                    markDirty()
                    clearUnscheduledEditingState()
                }
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
