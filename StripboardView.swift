// StripboardView.swift
// A Movie Magic Scheduling-style stripboard: a vertically-scrolling list of
// full-width day sections, each a thin rule, a plain date header, another
// rule, then that day's scenes as dense color-coded strips — closer to a
// printed one-line/strip schedule than a UI card grid. An alternate to
// CompactMonthCalendarView's square calendar grid — same underlying
// shootDays/allScenes data, same drag-and-drop payload format, so the
// existing Boneyard sidebar (and its own drag-in/drag-out handling) works
// with this view for free.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct StripboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("CineSchedTheme") private var currentTheme: AppTheme = .blue
    @Binding var shootDays: [ShootDay]
    @Binding var allScenes: [Scene]
    let productionInfo: ProductionInfo
    @Binding var selectedSceneIDs: Set<UUID>
    @Binding var lastSelectedSceneID: UUID?
    let conflictDates: Set<Date>
    let conflictSceneIDs: Set<UUID>
    let duplicateSceneNumberIDs: Set<UUID>
    @Binding var scrollToDate: Date?
    let dragStateResetToken: Int
    let onSceneChanged: () -> Void
    let onCallSheetExport: (ShootDay) -> Void
    let onShootingScheduleExport: ([ShootDay]) -> Void

    // Editing state — mirrors CompactMonthCalendarView's
    @State private var editingDayId:      UUID?
    @State private var editingDayIndex:   Int?
    @State private var editingSceneIndex: Int?
    @State private var showingEditSheet = false
    @State private var callSheetDay: ShootDay? = nil
    @State private var addingBannerForDayId: UUID? = nil

    // Scene drag/drop state — own copy, independent of the calendar's
    @State private var dropTargetDayId:    UUID?
    @State private var dropTargetPosition: Int?
    @State private var interactingSceneId: UUID?

    // Day rearrange drag/drop state
    @State private var draggingDayId:   UUID? = nil
    @State private var dayDropTargetId: UUID? = nil

    // Quick Time Edit state
    @State private var quickEditingScene: Scene? = nil
    @State private var quickEditingDayId: UUID? = nil

    private var visibleStripboardDays: [(offset: Int, element: ShootDay)] {
        Array(shootDays.enumerated()).filter { _, day in
            let isCalendarOnly = !day.scenes.isEmpty && day.scenes.allSatisfy { $0.isCalendarEvent }
            return !isCalendarOnly
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(visibleStripboardDays, id: \.element.id) { dayIndex, day in
                        daySection(day: day, dayIndex: dayIndex)
                            .id(day.id)
                            .onAppear {
                                syncAutoBannersAndMeals(for: dayIndex)
                            }
                    }
                }
                .padding(10)
            }
            .onChange(of: scrollToDate) { newValue in
                guard let date = newValue else { return }
                if let target = shootDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                    withAnimation { proxy.scrollTo(target.id, anchor: .top) }
                }
                scrollToDate = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tooltipContainer()
        .onChange(of: dragStateResetToken) { _ in
            // Same fix as CompactMonthCalendarView: undo/redo restores allScenes/shootDays
            // but can't reach into this view's own local drag-target state, so a day
            // cell's drop-target border could otherwise stay stuck highlighted after undo.
            dropTargetDayId = nil
            dropTargetPosition = nil
            dayDropTargetId = nil
        }
        .sheet(isPresented: $showingEditSheet) { editSheetContent() }
        .sheet(item: $callSheetDay) { day in callSheetEditorContent(for: day) }
        .sheet(item: $quickEditingScene) { scn in
            QuickTimeEditSheet(
                scene: scn,
                onSave: { updated in
                    if let dId = quickEditingDayId,
                       let dayIdx = shootDays.firstIndex(where: { $0.id == dId }),
                       let sceneIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == updated.id }) {
                        shootDays[dayIdx].scenes[sceneIdx] = updated
                        if (updated.isAutoMeal && updated.mealKind == .lunch) || updated.title.lowercased().contains("almuerzo") || updated.title.lowercased().contains("lunch") {
                            if !updated.customStartTime.isEmpty {
                                shootDays[dayIdx].callSheet.lunchTime = updated.customStartTime
                            }
                        }
                        onSceneChanged()
                    }
                    quickEditingScene = nil
                    quickEditingDayId = nil
                },
                onCancel: {
                    quickEditingScene = nil
                    quickEditingDayId = nil
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { addingBannerForDayId != nil },
            set: { if !$0 { addingBannerForDayId = nil } }
        )) {
            BannerInputSheet(isPresented: Binding(
                get: { addingBannerForDayId != nil },
                set: { if !$0 { addingBannerForDayId = nil } }
            ), onSave: { newBanner in
                if let targetId = addingBannerForDayId,
                   let idx = shootDays.firstIndex(where: { $0.id == targetId }) {
                    shootDays[idx].scenes.append(newBanner)
                    onSceneChanged()
                }
            })
        }
        .onChange(of: showingEditSheet) { isShowing in
            if !isShowing { clearEditingState() }
        }
    }

    private func syncAutoBannersAndMeals(for dayIndex: Int) {
        guard dayIndex < shootDays.count else { return }
        let day = shootDays[dayIndex]
        let cs = day.callSheet

        let itemsToEnsure: [(kind: MealKind, time: String)] = [
            (.generalCall, cs.generalCallTime),
            (.readyToShoot, cs.readyToShootTime),
            (.lunch, cs.lunchTime),
            (.snack, cs.snackTime),
            (.dinner, cs.dinnerTime),
            (.wrap, cs.wrapTime)
        ]

        var updatedScenes = shootDays[dayIndex].scenes

        for item in itemsToEnsure {
            let timeClean = item.time.trimmingCharacters(in: .whitespaces)
            let existingIdx = updatedScenes.firstIndex(where: { $0.isAutoMeal && $0.mealKind == item.kind })

            if !timeClean.isEmpty {
                let colorHex: String
                switch item.kind {
                case .generalCall:  colorHex = "1E3A8A"
                case .readyToShoot: colorHex = "064E3B"
                case .lunch, .snack, .dinner: colorHex = "18181B"
                case .wrap:         colorHex = "991B1B"
                }

                if let idx = existingIdx {
                    let title = "\(item.kind.icon) \(item.kind.defaultTitle) (\(timeClean))"
                    updatedScenes[idx].title = title
                    updatedScenes[idx].bannerTitle = title
                    updatedScenes[idx].summary = timeClean
                    updatedScenes[idx].customStartTime = timeClean
                    updatedScenes[idx].bannerColorHex = colorHex
                } else {
                    let newStrip = Scene.createAutoMeal(kind: item.kind, timeString: timeClean)
                    if item.kind == .generalCall {
                        updatedScenes.insert(newStrip, at: 0)
                    } else if item.kind == .readyToShoot {
                        let insertIdx = updatedScenes.firstIndex(where: { $0.isAutoMeal && $0.mealKind == .generalCall }) != nil ? 1 : 0
                        updatedScenes.insert(newStrip, at: min(insertIdx, updatedScenes.count))
                    } else if item.kind == .wrap {
                        updatedScenes.append(newStrip)
                    } else {
                        updatedScenes.append(newStrip)
                    }
                }
            } else if let idx = existingIdx {
                updatedScenes.remove(at: idx)
            }
        }

        if updatedScenes != shootDays[dayIndex].scenes {
            shootDays[dayIndex].scenes = updatedScenes
        }
    }

    // MARK: - Day section

    private var dayNumbers: [UUID: Int] { productionDayNumbers(for: shootDays) }

    // MARK: - Day timeline calculation

    private func computeDayTimeline(day: ShootDay, scenes: [Scene]) -> [UUID: (timeDisplay: String, startStr: String, endStr: String, durStr: String)] {
        var startMin = parseTimeToMinutes(day.callSheet.readyToShootTime.isEmpty ? (day.callSheet.generalCallTime.isEmpty ? "07:30 AM" : day.callSheet.generalCallTime) : day.callSheet.readyToShootTime) ?? (7 * 60 + 30)

        var map: [UUID: (timeDisplay: String, startStr: String, endStr: String, durStr: String)] = [:]
        for s in scenes {
            if !s.customStartTime.isEmpty, let customMin = parseTimeToMinutes(s.customStartTime) {
                startMin = customMin
            }
            let dur: Int
            if s.isBanner {
                dur = s.estimatedTime
            } else {
                dur = s.estimatedTime > 0 ? s.estimatedTime : 15
            }
            let endMin = startMin + dur

            let startClock = formatMinutesToClock(startMin)
            let endClock = formatMinutesToClock(endMin)
            let durClock = formattedTimeHM(dur)
            let fullRange = (dur == 0) ? startClock : "\(startClock) – \(endClock)"

            map[s.id] = (timeDisplay: fullRange, startStr: startClock, endStr: endClock, durStr: durClock)
            startMin = endMin
        }
        return map
    }

    @ViewBuilder
    private func daySceneList(day: ShootDay, dayIndex: Int) -> some View {
        let visibleScenes = day.scenes.filter { !$0.isCalendarEvent }
        let timeline = computeDayTimeline(day: day, scenes: visibleScenes)

        VStack(spacing: 1) {
            ForEach(Array(visibleScenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                VStack(spacing: 0) {
                    if shouldShowDropIndicator(dayId: day.id, position: sceneIndex) {
                        DropIndicatorView()
                    }
                    if scene.isBanner {
                        BannerStripRow(
                            scene: scene,
                            timeDisplay: timeline[scene.id]?.timeDisplay ?? (scene.customStartTime.isEmpty ? "" : scene.customStartTime),
                            interactingSceneId: $interactingSceneId,
                            isSelected: selectedSceneIDs.contains(scene.id),
                            onQuickTimeEdit: {
                                quickEditingScene = scene
                                quickEditingDayId = day.id
                            },
                            onRemove: { removeFromDay(scene, dayId: day.id) },
                            onDragStart: { interactingSceneId = scene.id }
                        )
                    } else {
                        SceneStripRow(
                            scene: scene,
                            timeDisplay: timeline[scene.id]?.timeDisplay ?? (scene.customStartTime.isEmpty ? "" : scene.customStartTime),
                            interactingSceneId: $interactingSceneId,
                            isSelected: selectedSceneIDs.contains(scene.id),
                            selectionCount: selectedSceneIDs.count,
                            hasConflict: conflictSceneIDs.contains(scene.id),
                            hasDuplicateSceneNumber: duplicateSceneNumberIDs.contains(scene.id),
                            onQuickTimeEdit: {
                                quickEditingScene = scene
                                quickEditingDayId = day.id
                            },
                            onEdit:      { editScene(dayIndex: dayIndex, sceneIndex: sceneIndex, dayId: day.id) },
                            onRemove:    { removeFromDay(scene, dayId: day.id) },
                            onDuplicate: { duplicateScene(scene) },
                            onToggleCompleted: { toggleSceneCompleted(scene, dayId: day.id) },
                            onDragStart: { interactingSceneId = scene.id },
                            onDragEnd:   { interactingSceneId = nil },
                            onSelect:    { selectScene(scene, dayId: day.id) }
                        )
                    }
                }
                .onDrop(of: [UTType.text.identifier], delegate: SceneDropDelegate(
                    dayId: day.id,
                    position: sceneIndex,
                    dropTargetDayId: $dropTargetDayId,
                    dropTargetPosition: $dropTargetPosition,
                    onDrop: { sceneId in handleSceneDrop(sceneId: sceneId.uuidString, targetDayId: day.id, targetPosition: sceneIndex) }
                ))
            }

            if visibleScenes.isEmpty {
                VStack(spacing: 0) {
                    if shouldShowDropIndicator(dayId: day.id, position: 0) {
                        DropIndicatorView()
                    }
                    Color.clear.frame(height: 12)
                }
                .contentShape(Rectangle())
                .onDrop(of: [UTType.text.identifier], delegate: SceneDropDelegate(
                    dayId: day.id,
                    position: 0,
                    dropTargetDayId: $dropTargetDayId,
                    dropTargetPosition: $dropTargetPosition,
                    onDrop: { sceneId in handleSceneDrop(sceneId: sceneId.uuidString, targetDayId: day.id, targetPosition: 0) }
                ))
            } else {
                Color.clear
                    .frame(height: 2)
                    .onDrop(of: [UTType.text.identifier], delegate: SceneDropDelegate(
                        dayId: day.id,
                        position: visibleScenes.count,
                        dropTargetDayId: $dropTargetDayId,
                        dropTargetPosition: $dropTargetPosition,
                        onDrop: { sceneId in handleSceneDrop(sceneId: sceneId.uuidString, targetDayId: day.id, targetPosition: visibleScenes.count) }
                    ))
            }
        }
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.22 : 0.12))
    }

    @ViewBuilder
    private func daySection(day: ShootDay, dayIndex: Int) -> some View {
        let visibleScenes = day.scenes.filter { !$0.isCalendarEvent }
        let isSelectedTarget = dayDropTargetId == day.id || dropTargetDayId == day.id
        VStack(alignment: .leading, spacing: 0) {
            dayHeader(day: day)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.22 : 0.12))

            Divider().opacity(0.4)

            daySceneList(day: day, dayIndex: dayIndex)

            EndOfDayStrip(day: day, dayNumber: dayNumbers[day.id] ?? (dayIndex + 1))
        }
        .background(
            ZStack {
                currentTheme.panelBackground(isDarkMode: colorScheme == .dark)
                if isWeekend(day.date) {
                    Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
                }
            }
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    dayDropTargetId == day.id ? Color.green :
                    dropTargetDayId == day.id ? Color.red : Color.primary.opacity(0.2),
                    lineWidth: isSelectedTarget ? 2.5 : 1
                )
        )
        .onDrop(of: [UTType.text.identifier], delegate: CombinedDayDropDelegate(
            dayId: day.id,
            scenes: visibleScenes,
            dropTargetDayId: $dropTargetDayId,
            dropTargetPosition: $dropTargetPosition,
            dayDropTargetId: $dayDropTargetId,
            draggingDayId: $draggingDayId,
            onSceneDrop: { sceneId in
                handleSceneDrop(sceneId: sceneId.uuidString, targetDayId: day.id, targetPosition: visibleScenes.count)
            },
            onDayDrop: { sourceDayId in
                handleDayRearrange(sourceDayId: sourceDayId, targetDayId: day.id)
            }
        ))
    }

    // MARK: - Day header

    @ViewBuilder
    private func dayHeader(day: ShootDay) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .onDrag {
                    draggingDayId = day.id
                    return NSItemProvider(object: "day:\(day.id.uuidString)" as NSString)
                }
                .help("Drag to move this day's scenes and call sheet to another date")

            HStack(spacing: 6) {
                Text(formattedDate(day.date))
                    .font(.headline)
                if day.hasCallSheetData {
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                }
                if conflictDates.contains(Calendar.current.startOfDay(for: day.date)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9)).foregroundColor(.red)
                }
                if let dayNumber = dayNumbers[day.id] {
                    Text("\(L("Day")) \(dayNumber)")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    if !day.callSheet.lunchTime.isEmpty {
                        Text("🍽️ \(day.callSheet.lunchTime)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if !day.callSheet.snackTime.isEmpty {
                        Text("☕ \(day.callSheet.snackTime)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if !day.callSheet.dinnerTime.isEmpty {
                        Text("🍕 \(day.callSheet.dinnerTime)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if !day.callSheet.wrapTime.isEmpty {
                        Text("🎬 \(day.callSheet.wrapTime)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !day.scenes.isEmpty {
                    Text("\(day.scenes.count) \(L("scn")) · \(formattedEighths(day.totalDuration)) \(L("pgs"))")
                        .font(.caption).foregroundColor(.secondary)
                }

                // Action Icons on Day Header: CallSheet, Add Banner, Export PDF
                HStack(spacing: 8) {
                    Button {
                        callSheetDay = day
                    } label: {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Edit Call Sheet"))

                    Button {
                        addingBannerForDayId = day.id
                    } label: {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Add Notice / Banner Strip"))

                    Button {
                        onShootingScheduleExport([day])
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Export Plan de Rodaje (PDF)"))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - Call sheet editor (mirrors CompactMonthCalendarView)

    @ViewBuilder
    private func callSheetEditorContent(for day: ShootDay) -> some View {
        if let idx = shootDays.firstIndex(where: { $0.id == day.id }) {
            CallSheetEditor(
                shootDay: $shootDays[idx],
                productionInfo: productionInfo,
                isPresented: Binding(
                    get: { callSheetDay != nil },
                    set: { if !$0 { callSheetDay = nil } }
                ),
                onSave: {
                    callSheetDay = nil
                    syncAutoBannersAndMeals(for: idx)
                    onSceneChanged()
                },
                onExportPDF: { exportDay in
                    onCallSheetExport(exportDay)
                },
                dayNumber: dayNumbers[day.id],
                totalProductionDays: dayNumbers.values.max() ?? 0
            )
        }
    }

    // MARK: - Edit sheet (mirrors CompactMonthCalendarView)

    @ViewBuilder
    private func editSheetContent() -> some View {
        if let dayIndex   = editingDayIndex,
           let sceneIndex = editingSceneIndex,
           dayIndex   < shootDays.count,
           sceneIndex < shootDays[dayIndex].scenes.count {

            SceneEditSheet(
                scene: $shootDays[dayIndex].scenes[sceneIndex],
                isPresented: $showingEditSheet,
                onSave: {
                    onSceneChanged()
                },
                onDelete: {
                    if let id = editingDayId {
                        removeSceneDirect(shootDays[dayIndex].scenes[sceneIndex], dayId: id)
                        onSceneChanged()
                    }
                    clearEditingState()
                },
                canGoPrevious: sceneIndex > 0,
                canGoNext: sceneIndex < shootDays[dayIndex].scenes.count - 1,
                onPrevious: { editingSceneIndex = sceneIndex - 1 },
                onNext: { editingSceneIndex = sceneIndex + 1 },
                positionLabel: "Scene \(sceneIndex + 1) of \(shootDays[dayIndex].scenes.count)",
                knownLocations: allProjectLocations
            )
        } else {
            VStack(spacing: 20) {
                Text("Error: Scene not found")
                    .font(.title2).foregroundColor(.red)
                Text("The scene may have been moved or deleted.")
                    .font(.body).multilineTextAlignment(.center)
                Button("Close") {
                    showingEditSheet = false
                    clearEditingState()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24).frame(width: 400)
        }
    }

    private func editScene(dayIndex: Int, sceneIndex: Int, dayId: UUID) {
        editingDayIndex   = dayIndex
        editingSceneIndex = sceneIndex
        editingDayId      = dayId
        showingEditSheet  = true
    }

    private func clearEditingState() {
        editingDayId      = nil
        editingDayIndex   = nil
        editingSceneIndex = nil
    }

    private var allProjectLocations: [String] {
        var set = Set<String>()
        for d in shootDays {
            for s in d.scenes where !s.realLocation.isEmpty {
                set.insert(s.realLocation)
            }
        }
        for s in allScenes where !s.realLocation.isEmpty {
            set.insert(s.realLocation)
        }
        for loc in productionInfo.locationRoster where !loc.name.isEmpty {
            set.insert(loc.name)
        }
        return Array(set).sorted()
    }

    // MARK: - Scene drag & drop handling (mirrors CompactMonthCalendarView)

    private func shouldShowDropIndicator(dayId: UUID, position: Int) -> Bool {
        dropTargetDayId == dayId && dropTargetPosition == position
    }

    /// Accepts either a single scene ID or a comma-separated list (a Boneyard
    /// multi-selection) and inserts them, in order, starting at targetPosition.
    private func handleSceneDrop(sceneId: String, targetDayId: UUID, targetPosition: Int) {
        let ids = sceneId.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
        guard !ids.isEmpty else { return }

        var insertPosition = targetPosition
        for uuid in ids {
            // From the Boneyard
            if let idx = allScenes.firstIndex(where: { $0.id == uuid }) {
                let scene = allScenes.remove(at: idx)
                insertSceneIntoDay(scene: scene, dayId: targetDayId, position: insertPosition)
                insertPosition += 1
                continue
            }
            // From another (or the same) day
            for dayIdx in shootDays.indices {
                if let sceneIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == uuid }) {
                    let scene = shootDays[dayIdx].scenes.remove(at: sceneIdx)
                    var adjustedPos = insertPosition
                    if shootDays[dayIdx].id == targetDayId && sceneIdx < insertPosition { adjustedPos -= 1 }
                    insertSceneIntoDay(scene: scene, dayId: targetDayId, position: adjustedPos)
                    insertPosition += 1
                    break
                }
            }
        }
        onSceneChanged()
    }

    private func insertSceneIntoDay(scene: Scene, dayId: UUID, position: Int) {
        guard let dayIdx = shootDays.firstIndex(where: { $0.id == dayId }) else { return }
        let clamped = min(max(0, position), shootDays[dayIdx].scenes.count)
        shootDays[dayIdx].scenes.insert(scene, at: clamped)
    }

    /// Removes the clicked scene from its day back into the Boneyard — or, if it's
    /// part of a multi-scene selection, every selected scene currently scheduled
    /// anywhere on the board, mirroring the calendar's grouped removal.
    private func removeFromDay(_ scene: Scene, dayId: UUID) {
        if selectedSceneIDs.contains(scene.id), selectedSceneIDs.count > 1 {
            for dayIdx in shootDays.indices {
                let matching = shootDays[dayIdx].scenes.filter { selectedSceneIDs.contains($0.id) }
                for s in matching {
                    removeSceneDirect(s, dayId: shootDays[dayIdx].id)
                }
            }
        } else {
            removeSceneDirect(scene, dayId: dayId)
        }
        onSceneChanged()
    }

    private func removeSceneDirect(_ scene: Scene, dayId: UUID) {
        if let di = shootDays.firstIndex(where: { $0.id == dayId }) {
            shootDays[di].scenes.removeAll { $0.id == scene.id }
            allScenes.append(scene)
        }
    }

    private func toggleSceneCompleted(_ scene: Scene, dayId: UUID) {
        let newValue = !scene.isCompleted
        let idsToToggle: Set<UUID> = (selectedSceneIDs.contains(scene.id) && selectedSceneIDs.count > 1)
            ? selectedSceneIDs
            : [scene.id]
        for id in idsToToggle {
            guard let di = shootDays.firstIndex(where: { $0.scenes.contains(where: { $0.id == id }) }),
                  let si = shootDays[di].scenes.firstIndex(where: { $0.id == id }) else { continue }
            shootDays[di].scenes[si].isCompleted = newValue
        }
        onSceneChanged()
    }

    private func duplicateScene(_ scene: Scene) {
        allScenes.append(Scene(
            title:            scene.title + " (Copy)",
            sceneNumber:      scene.sceneNumber,
            duration:         scene.duration,
            estimatedTime:    scene.estimatedTime,
            dayNightType:     scene.dayNightType,
            cast:             scene.cast,
            summary:          scene.summary,
            extras:           scene.extras,
            props:            scene.props,
            setDressing:      scene.setDressing,
            wardrobe:         scene.wardrobe,
            makeupHair:        scene.makeupHair,
            vehicles:         scene.vehicles,
            specialEquipment: scene.specialEquipment,
            stunts:           scene.stunts,
            sfx:              scene.sfx,
            vfx:              scene.vfx,
            breakdownNotes:   scene.breakdownNotes
        ))
        onSceneChanged()
    }

    // MARK: - Day rearrange (mirrors CompactMonthCalendarView.handleDayRearrange)

    /// Swaps scenes and call sheet between two days, preserving both dates —
    /// the calendar dates themselves never change, only the content moves.
    private func handleDayRearrange(sourceDayId: UUID, targetDayId: UUID) {
        guard sourceDayId != targetDayId,
              let sourceIdx = shootDays.firstIndex(where: { $0.id == sourceDayId }),
              let targetIdx = shootDays.firstIndex(where: { $0.id == targetDayId })
        else { return }

        let sourceScenes    = shootDays[sourceIdx].scenes
        let sourceCallSheet = shootDays[sourceIdx].callSheet
        let targetScenes    = shootDays[targetIdx].scenes
        let targetCallSheet = shootDays[targetIdx].callSheet

        shootDays[sourceIdx].scenes    = targetScenes
        shootDays[sourceIdx].callSheet = targetCallSheet
        shootDays[targetIdx].scenes    = sourceScenes
        shootDays[targetIdx].callSheet = sourceCallSheet

        draggingDayId   = nil
        dayDropTargetId = nil
        onSceneChanged()
    }

    // MARK: - Selection

    private func selectScene(_ scene: Scene, dayId: UUID) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedSceneIDs.contains(scene.id) { selectedSceneIDs.remove(scene.id) } else { selectedSceneIDs.insert(scene.id) }
            lastSelectedSceneID = scene.id
        } else if flags.contains(.shift),
                  let anchor = lastSelectedSceneID,
                  let dayIdx = shootDays.firstIndex(where: { $0.id == dayId }),
                  let anchorIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == anchor }),
                  let targetIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == scene.id }) {
            let range = anchorIdx < targetIdx ? anchorIdx...targetIdx : targetIdx...anchorIdx
            selectedSceneIDs.formUnion(range.map { shootDays[dayIdx].scenes[$0].id })
        } else {
            selectedSceneIDs = [scene.id]
            lastSelectedSceneID = scene.id
        }
    }
}

// MARK: - EndOfDayStrip

/// Movie Magic's black "end of day" marker — closes out every production
/// day's card with its number, full date, and running page/time totals, all
/// read live off the ShootDay so it updates the moment scenes move, get
/// edited, or the day itself gets rearranged.
struct EndOfDayStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = LocalizationManager.shared
    let day: ShootDay
    let dayNumber: Int

    private var backgroundColor: Color {
        Color.gray.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    private var textColor: Color {
        Color.primary.opacity(0.8)
    }

    private var wrapPart: String {
        let wrap = day.callSheet.wrapTime.trimmingCharacters(in: .whitespaces)
        return wrap.isEmpty ? "" : " -- \(L("Wrap:")) \(wrap)"
    }

    var body: some View {
        Text("-- \(L("END OF DAY #"))\(dayNumber) \(formattedFullDate(day.date)) -- \(L("Total Pages:")) \(formattedEighths(day.totalDuration)) -- \(L("Est. Time:")) \(formattedTimeHM(day.totalEstimatedTime))\(wrapPart) --")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .background(backgroundColor)
    }
}

// MARK: - SceneStripRow

struct SceneStripRow: View {
    let scene: Scene
    let timeDisplay: String
    @Binding var interactingSceneId: UUID?
    let isSelected:     Bool
    let selectionCount: Int
    let hasConflict:    Bool
    let hasDuplicateSceneNumber: Bool
    let onQuickTimeEdit: () -> Void
    let onEdit:      () -> Void
    let onRemove:    () -> Void
    let onDuplicate: () -> Void
    let onToggleCompleted: () -> Void
    let onDragStart: () -> Void
    let onDragEnd:   () -> Void
    let onSelect:    () -> Void

    private var isDragging: Bool { interactingSceneId == scene.id }
    private var isMultiSelected: Bool { isSelected && selectionCount > 1 }

    var body: some View {
        HStack(spacing: 8) {
            if !timeDisplay.isEmpty {
                Button {
                    onQuickTimeEdit()
                } label: {
                    Text(timeDisplay)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(scene.stripTextColor.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 142, height: 20, alignment: .center)
                        .background(Color.black.opacity(0.18))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Clic para ajustar horario o duración / Click to edit time")
            }

            HStack(spacing: 8) {
                if !scene.sceneNumber.isEmpty {
                    Text(scene.sceneNumber)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(scene.stripTextColor.opacity(0.6))
                        .lineLimit(1)
                        .frame(minWidth: 22, alignment: .leading)
                }

                Text(scene.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(scene.stripTextColor)
                    .lineLimit(1)

                if hasConflict || hasDuplicateSceneNumber {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9)).foregroundColor(.red)
                }

                if !scene.cast.isEmpty {
                    Text(scene.cast.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(scene.stripTextColor.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if scene.estimatedTime > 0 {
                    Text("(\(formattedTimeHM(scene.estimatedTime)))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(scene.stripTextColor.opacity(0.75))
                }

                Text(FractionParser.formatEighths(scene.duration))
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(scene.stripTextColor.opacity(0.8))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                interactingSceneId = nil
                onEdit()
            })
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                interactingSceneId = nil
                onSelect()
            })
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scene.stripColor)
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.accentColor : scene.stripTextColor.opacity(0.2), lineWidth: isSelected ? 2 : 0.5)
        )
        .overlay(
            Rectangle()
                .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .opacity(hasDuplicateSceneNumber ? 1 : 0)
        )
        .scaleEffect(isDragging ? 1.01 : 1.0)
        .opacity(isDragging ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .fastTooltip(scene.tooltipText)
        .onDrag {
            interactingSceneId = scene.id
            onDragStart()
            return NSItemProvider(object: scene.id.uuidString as NSString)
        }
        .contextMenu {
            Button("Set Time...") { interactingSceneId = nil; onQuickTimeEdit() }
            Divider()
            Button(L("Edit Scene")) { interactingSceneId = nil; onEdit() }
            Button(isMultiSelected ? "\(L("Remove")) \(selectionCount) \(L("scenes"))" : L("Remove from Day")) {
                interactingSceneId = nil; onRemove()
            }
            Divider()
            Button(isMultiSelected
                   ? "Mark \(selectionCount) Scenes as \(scene.isCompleted ? "Incomplete" : "Completed")"
                   : (scene.isCompleted ? "Mark as Incomplete" : "Mark as Completed")) {
                interactingSceneId = nil; onToggleCompleted()
            }
            Divider()
            Button(L("Duplicate Scene")) { interactingSceneId = nil; onDuplicate() }
        }
        .onChange(of: isDragging) { dragging in
            if !dragging { onDragEnd() }
        }
    }
}

// MARK: - BannerStripRow

struct BannerStripRow: View {
    let scene: Scene
    let timeDisplay: String
    @Binding var interactingSceneId: UUID?
    let isSelected: Bool
    let onQuickTimeEdit: () -> Void
    let onRemove: () -> Void
    let onDragStart: () -> Void

    private var isDragging: Bool { interactingSceneId == scene.id }
    private var bannerColor: Color {
        if scene.isAutoMeal {
            if let kind = scene.mealKind {
                switch kind {
                case .lunch, .snack, .dinner: return Color(hex: "18181B")
                case .generalCall:  return Color(hex: "1E3A8A")
                case .readyToShoot: return Color(hex: "064E3B")
                case .wrap:         return Color(hex: "991B1B")
                }
            }
            return Color(hex: "18181B")
        }
        if scene.bannerType == .mealBreak || scene.title.lowercased().contains("almuerzo") || scene.title.lowercased().contains("lunch") || scene.title.lowercased().contains("cena") || scene.title.lowercased().contains("dinner") || scene.title.lowercased().contains("snack") || scene.title.lowercased().contains("merienda") {
            return Color(hex: "18181B")
        }
        if scene.bannerColorHex == "F59E0B" {
            return Color(hex: "18181B")
        }
        if scene.bannerColorHex.isEmpty { return Color(hex: "334155") }
        return Color(hex: scene.bannerColorHex)
    }

    private var bannerDisplayTitle: String {
        if let kind = scene.mealKind {
            return "\(kind.icon) \(kind.defaultTitle)"
        }
        let raw = scene.title.replacingOccurrences(of: #"\s*\(\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if raw == "Notice / Note" || raw == "Aviso / Nota" || raw == "Notice" || raw == "Nota" || raw == "Aviso" {
            return L("Notice")
        }
        if raw.contains("ALMUERZO / LUNCH") || raw.contains("LUNCH / ALMUERZO") {
            return "🍽️ \(L("LUNCH"))"
        }
        if raw.contains("MERIENDA / SNACK") || raw.contains("SNACK / MERIENDA") {
            return "☕ \(L("SNACK"))"
        }
        if raw.contains("CENA / DINNER") || raw.contains("DINNER / CENA") {
            return "🍕 \(L("DINNER"))"
        }
        if raw.contains("FIN DE RODAJE / WRAP") || raw.contains("WRAP / FIN DE RODAJE") {
            return "🎬 \(L("WRAP"))"
        }
        if raw.contains("READY TO SHOOT / EN SET") {
            return "🎬 \(L("READY TO SHOOT"))"
        }
        return raw
    }

    var body: some View {
        HStack(spacing: 8) {
            if !timeDisplay.isEmpty {
                Button {
                    onQuickTimeEdit()
                } label: {
                    Text(timeDisplay)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 142, height: 20, alignment: .center)
                        .background(Color.black.opacity(0.32))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Clic para ajustar horario o duración / Click to edit time")
            }

            if !scene.isAutoMeal {
                Image(systemName: scene.bannerType?.defaultIcon ?? "flag.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(bannerDisplayTitle)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            if scene.estimatedTime > 0 {
                Text(formattedTime(scene.estimatedTime))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }

            Button {
                onRemove()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Eliminar Tira / Delete Banner")
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bannerColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.2), lineWidth: isSelected ? 2 : 0.5)
        )
        .onDrag {
            interactingSceneId = scene.id
            onDragStart()
            return NSItemProvider(object: scene.id.uuidString as NSString)
        }
        .contextMenu {
            Button(L("Set Time...")) { interactingSceneId = nil; onQuickTimeEdit() }
            Divider()
            Button(L("Delete Banner"), role: .destructive) {
                onRemove()
            }
        }
    }
}

// MARK: - Quick Time Edit Sheet

struct QuickTimeEditSheet: View {
    let scene: Scene
    let onSave: (Scene) -> Void
    let onCancel: () -> Void

    @State private var isCustomTime: Bool = false
    @State private var customTimeText: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 15

    private var calculatedEndTime: String {
        let startMin = parseTimeToMinutes(customTimeText) ?? (8 * 60)
        let totalDur = (hours * 60) + minutes
        let endMin = startMin + totalDur
        return "\(formatMinutesToClock(startMin)) ➔ \(formatMinutesToClock(endMin)) (\(formattedTimeHM(totalDur)))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(L("Set Shooting Time"), systemImage: "clock.badge.checkmark")
                    .font(.headline)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("STRIP / SCENE:"))
                    .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                Text(scene.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
            }

            Divider()

            // Mode Selector
            VStack(alignment: .leading, spacing: 8) {
                Text(L("TIME MODE:"))
                    .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)

                Picker("", selection: $isCustomTime) {
                    Text(L("Automatic Cascade (by order)")).tag(false)
                    Text(L("Fixed Time (e.g. 11:00 AM)")).tag(true)
                }
                .pickerStyle(.radioGroup)

                if isCustomTime {
                    HStack {
                        Text(L("Start Time:"))
                            .font(.caption).fontWeight(.semibold)
                        TextField("11:00 AM", text: $customTimeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                    }
                    .padding(.top, 2)
                }
            }

            Divider()

            // Duration Selector
            VStack(alignment: .leading, spacing: 8) {
                Text(L("ESTIMATED DURATION:"))
                    .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Stepper("\(hours) h", value: $hours, in: 0...12)
                    }
                    HStack(spacing: 4) {
                        Stepper("\(minutes) min", value: $minutes, in: 0...59, step: 5)
                    }
                }
            }

            // Live Preview Banner
            VStack(alignment: .leading, spacing: 4) {
                Text(L("SCHEDULE PREVIEW:"))
                    .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)

                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.accentColor)
                    if isCustomTime && !customTimeText.isEmpty {
                        Text(calculatedEndTime)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    } else {
                        let dur = (hours * 60) + minutes
                        let autoMsg = LocalizationManager.shared.currentLanguage == .spanish ? "Duración: \(formattedTimeHM(dur)) (se calcula según el orden del día)" : "Duration: \(formattedTimeHM(dur)) (cascades by day order)"
                        Text(autoMsg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            HStack {
                Button(L("Cancel")) { onCancel() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(L("Save Schedule")) {
                    var updated = scene
                    if isCustomTime {
                        updated.customStartTime = customTimeText.trimmingCharacters(in: .whitespaces)
                    } else {
                        updated.customStartTime = ""
                    }
                    updated.estimatedTime = (hours * 60) + minutes
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 360)
        .onAppear {
            let start = scene.customStartTime.trimmingCharacters(in: .whitespaces)
            isCustomTime = !start.isEmpty
            customTimeText = start.isEmpty ? "08:00 AM" : start
            let dur = scene.estimatedTime > 0 ? scene.estimatedTime : (scene.isBanner ? 30 : 15)
            hours = dur / 60
            minutes = dur % 60
        }
    }
}
