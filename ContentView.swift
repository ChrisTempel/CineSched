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

    // Auto-save: flip to true on any change; a debounced .onChange triggers the actual write
    @State var hasUnsavedChanges: Bool = false

    // MARK: UI / sheet state
    @State private var newSceneTitle: String = ""
    @State private var newDuration:   String = ""
    @State private var newEstimate:   String = ""

    @State var showingFileImporter      = false
    @State var showingPDFExporter       = false
    @State var showingAlert             = false
    @State var showingImportAlert       = false
    @State private var showingClearAllConfirmation = false
    @State private var showingUnscheduledSceneEditSheet = false

    @State var alertMessage:   String = ""
    @State var importMessage:  String = ""
    @State private var importedScenesCount = 0
    @State private var fileImportType: FileImportType = .json

    // Unscheduled-scene editing
    @State private var editingUnscheduledScene:      Scene?
    @State private var editingUnscheduledSceneIndex: Int?

    // Appearance
    @State var isDarkMode: Bool = false

    enum FileImportType { case json, fdx }

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
        .fileExporter(
            isPresented: $showingPDFExporter,
            document: PDFFile(
                shootDays: shootDays,
                projectTitle: projectTitle,
                allScenes: allScenes,
                startDate: startDate,
                endDate: endDate
            ),
            contentType: .pdf,
            defaultFilename: sanitizeFilename("\(projectTitle.isEmpty ? "MovieSchedule" : projectTitle)_Calendar")
        ) { handlePDFExportResult($0) }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: fileImportType == .json ? [.json] : [.fdx, .xml],
            allowsMultipleSelection: false
        ) { result in
            DispatchQueue.main.async {
                fileImportType == .json ? handleLoadResult(result) : handleFDXImport(result)
            }
        }
        .alert("Script Import",  isPresented: $showingImportAlert) { Button("OK") {} } message: { Text(importMessage) }
        .alert("CineSched",      isPresented: $showingAlert)        { Button("OK") {} } message: { Text(alertMessage) }
        .confirmationDialog("Clear All Scenes", isPresented: $showingClearAllConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) { clearAllScenes() }
            Button("Cancel",    role: .cancel)      {}
        } message: {
            Text("This will remove all scenes from your calendar and boneyard. This action cannot be undone.")
        }
        .sheet(isPresented: $showingUnscheduledSceneEditSheet) { unscheduledEditSheet }
        .onChange(of: showingUnscheduledSceneEditSheet) { _, isShowing in
            if !isShowing { clearUnscheduledEditingState() }
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
                .onChange(of: projectTitle) { _, _ in markDirty() }

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
                    .onChange(of: startDate) { _, _ in markDirty() }
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    .onChange(of: endDate) { _, _ in markDirty() }

                Toggle(isOn: $isShiftModeEnabled) { Text("Shift Schedule") }
                    .toggleStyle(.switch)
                    .help("When enabled, changing the Start Date shifts all scenes on the calendar.")
                    .onChange(of: isShiftModeEnabled) { _, _ in markDirty() }

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

            Text("Boneyard").font(.headline)

            boneyardList

            Spacer()
        }
        .padding()
        .frame(minWidth: 300)
    }

    // MARK: - Boneyard list

    private var boneyardList: some View {
        List {
            ForEach(Array(allScenes.enumerated()), id: \.element.id) { index, scene in
                HStack {
                    Circle().fill(scene.dayNightType.color).frame(width: 8, height: 8)
                    Text(scene.title)
                    Spacer()
                    Text(scene.dayNightType.displayName)
                        .font(.caption).foregroundColor(scene.dayNightType.color).fontWeight(.semibold)
                    Text("\(FractionParser.formatEighths(scene.duration)) / \(formattedTime(scene.estimatedTime))")
                    Button {
                        allScenes.remove(at: index)
                        markDirty()
                    } label: {
                        Image(systemName: "trash").foregroundColor(.red).help("Delete Scene")
                    }
                    .buttonStyle(.plain)
                }
                .onDrag { NSItemProvider(object: scene.id.uuidString as NSString) }
                .onTapGesture(count: 2) {
                    editingUnscheduledSceneIndex = index
                    editingUnscheduledScene      = scene
                    showingUnscheduledSceneEditSheet = true
                }
                .contextMenu {
                    Button("Edit Scene") {
                        editingUnscheduledSceneIndex = index
                        editingUnscheduledScene      = scene
                        showingUnscheduledSceneEditSheet = true
                    }
                    Button("Duplicate Scene") {
                        allScenes.append(Scene(
                            title: scene.title + " (Copy)",
                            duration: scene.duration,
                            estimatedTime: scene.estimatedTime,
                            dayNightType: scene.dayNightType,
                            cast: scene.cast,
                            summary: scene.summary
                        ))
                        markDirty()
                    }
                    Divider()
                    Button("Delete Scene", role: .destructive) {
                        allScenes.remove(at: index)
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
                onSceneChanged: { markDirty() }
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

                Button("Import Script") { fileImportType = .fdx; showingFileImporter = true }
                    .buttonStyle(.bordered)
                    .help("Import scenes from Final Draft (.fdx)")

                Button("Save") { showNativeSaveDialog() }
                    .buttonStyle(.bordered)

                Button("Load") { fileImportType = .json; showingFileImporter = true }
                    .buttonStyle(.bordered)

                Button("Export PDF") { showingPDFExporter = true }
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

    // MARK: - File import handlers

    private func handleLoadResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { alertMessage = "No file selected."; showingAlert = true; return }
            loadProject(from: url)
        case .failure(let error):
            alertMessage = "Failed to select file: \(error.localizedDescription)"; showingAlert = true
        }
    }

    private func handleFDXImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { importMessage = "No file selected."; showingImportAlert = true; return }
            importFDXScript(from: url)
        case .failure(let error):
            importMessage = "Failed to select file: \(error.localizedDescription)"; showingImportAlert = true
        }
    }

    private func handlePDFExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "PDF exported to: \(url.lastPathComponent)"; showingAlert = true
        case .failure(let error):
            alertMessage = "Failed to export PDF: \(error.localizedDescription)"; showingAlert = true
        }
    }

    private func importFDXScript(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "Unable to access the selected file."; showingImportAlert = true; return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let parsed = try FinalDraftParser.parseScenes(from: url)
            guard !parsed.isEmpty else {
                importMessage = "No scenes found in the script."; showingImportAlert = true; return
            }
            var count = 0
            for ps in parsed {
                let type: DayNightType = ps.timeOfDay == .night ? .night : .day
                allScenes.append(Scene(
                    title:         "\(ps.sceneNumber). \(ps.location)",
                    duration:      1,
                    estimatedTime: 15,
                    dayNightType:  type
                ))
                count += 1
            }
            markDirty()
            importedScenesCount = count
            importMessage = "Imported \(count) scene\(count == 1 ? "" : "s") from '\(url.lastPathComponent)'.\n\nScenes added to Boneyard with default values (1/8 page, 15 min). Edit before scheduling."
            showingImportAlert = true
        } catch {
            importMessage = "Failed to import script: \(error.localizedDescription)"; showingImportAlert = true
        }
    }
}

