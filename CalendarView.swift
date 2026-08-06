// CalendarView.swift
// Calendar grid with drag-and-drop scene scheduling

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - CompactMonthCalendarView

struct CompactMonthCalendarView: View {
    @Binding var shootDays: [ShootDay]
    let assignScene:  (Scene, ShootDay) -> Void
    @Binding var allScenes: [Scene]
    let updateScene:  (Scene, UUID) -> Void
    let removeScene:  (Scene, UUID) -> Void
    let projectTitle: String
    let productionInfo: ProductionInfo
    let isSidebarCollapsed: Bool
    @Binding var selectedSceneIDs:    Set<UUID>
    @Binding var lastSelectedSceneID: UUID?
    let conflictDates: Set<Date>
    let conflictSceneIDs: Set<UUID>
    let scheduleLockChangedDates: Set<Date>
    @Binding var scrollToDate: Date?
    /// Called immediately before a structural mutation (drag/drop, remove, duplicate,
    /// send-to-day, day rearrange) — lets the caller snapshot state for undo purposes
    /// before the change happens.
    let onBeforeSceneChange: () -> Void
    let onSceneChanged: () -> Void
    let onCallSheetExport: (ShootDay) -> Void   // called when Export PDF tapped in editor

    // Editing state
    @State private var editingScene:      Scene?
    @State private var editingDayId:      UUID?
    @State private var editingDayIndex:   Int?
    @State private var editingSceneIndex: Int?
    @State private var showingEditSheet = false

    // Call sheet state — using sheet(item:) guarantees data is present when sheet renders
    @State private var callSheetDay: ShootDay? = nil

    // "Send to Day" state — lets a selection be moved to a day that isn't currently
    // scrolled into view, instead of dragging across a long schedule.
    @State private var showingSendToDaySheet = false
    @State private var sendToDaySceneIDs: [UUID] = []

    // Day rearrange drag/drop state
    @State private var draggingDayId:       UUID? = nil
    @State private var dayDropTargetId:     UUID? = nil

    // Drag/drop state
    @State private var dropTargetDayId:    UUID?
    @State private var dropTargetPosition: Int?
    @State private var draggedSceneId:     UUID?
    @State private var interactingSceneId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(shootDays.enumerated()), id: \.element.id) { dayIndex, day in
                        dayCell(day: day, dayIndex: dayIndex)
                            .id(day.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 60)   // extra breathing room so the last row's totals are never flush with the scroll edge
            }
            .onChange(of: scrollToDate) { _, newValue in
                guard let date = newValue else { return }
                if let target = shootDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                    withAnimation { proxy.scrollTo(target.id, anchor: .top) }
                }
                scrollToDate = nil
            }
        }
        // Without an explicit bounded height here, the ScrollView sizes itself to fit
        // *all* of its content rather than the space actually visible in the window,
        // so there's nothing left to scroll past the last row. Filling the parent's
        // available space makes the ScrollView clip properly and scroll the rest.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tooltipContainer()
        .sheet(isPresented: $showingEditSheet) {
            editSheetContent()
        }
        .sheet(item: $callSheetDay) { day in
            callSheetEditorContent(for: day)
        }
        .sheet(isPresented: $showingSendToDaySheet) {
            SendToDaySheet(
                shootDays:  shootDays,
                sceneCount: sendToDaySceneIDs.count,
                onSelect: { targetDayId in
                    sendScenes(sendToDaySceneIDs, toDay: targetDayId)
                    showingSendToDaySheet = false
                },
                onCancel: { showingSendToDaySheet = false }
            )
        }
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing { clearEditingState() }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(day: ShootDay, dayIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {

            // Date header row: grip handle (drag) + date + call sheet indicator
            HStack(spacing: 6) {

                // Grip icon — drag handle for rearranging the day
                // Uses a draggable view isolated from the button hierarchy
                // so it responds to click-and-drag without a prior activation click
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(draggingDayId == day.id ? .blue : .secondary)
                    .padding(4)
                    .contentShape(Rectangle())
                    .onDrag {
                        draggingDayId = day.id
                        return NSItemProvider(object: "day:\(day.id.uuidString)" as NSString)
                    }
                    .simultaneousGesture(TapGesture())   // absorbs tap so parent button doesn't fire
                    .help("Drag to move this day's scenes and call sheet to another date")

                // Tappable date text — opens call sheet editor
                Button {
                    callSheetDay = day
                } label: {
                    HStack(spacing: 4) {
                        Text(formattedDate(day.date))
                            .font(.caption).bold()
                            .foregroundColor(day.isBlackout ? .red : .primary)
                        if day.isBlackout {
                            Image(systemName: "nosign")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                                .help("Marked unavailable — scenes can still be scheduled here, but will be flagged")
                        }
                        if day.hasCallSheetData {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)
                        }
                        if conflictDates.contains(Calendar.current.startOfDay(for: day.date)) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                                .help("An actor scheduled this day is marked unavailable — see Production > Scan for Conflicts…")
                        }
                        if scheduleLockChangedDates.contains(Calendar.current.startOfDay(for: day.date)) {
                            Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.purple)
                                .help("An actor's working days changed here since the schedule was locked — see Production > Schedule Lock Report…")
                        }
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Click to open call sheet for this day")
                .contextMenu {
                    Button(day.isBlackout ? "Mark as Available" : "Mark as Unavailable") {
                        toggleBlackout(day)
                    }
                    Button(day.isBlackout
                           ? "Mark All \(weekdayName(for: day.date))s as Available"
                           : "Mark All \(weekdayName(for: day.date))s as Unavailable") {
                        toggleBlackoutForWeekday(day)
                    }
                }
            }

            VStack(spacing: 2) {
                ForEach(Array(day.scenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                    VStack(spacing: 0) {
                        if shouldShowDropIndicator(dayId: day.id, position: sceneIndex) {
                            DropIndicatorView()
                        }
                        SceneCardView(
                            scene: scene,
                            dayId: day.id,
                            dayIndex: dayIndex,
                            sceneIndex: sceneIndex,
                            interactingSceneId: $interactingSceneId,
                            isSelected: selectedSceneIDs.contains(scene.id),
                            selectionCount: selectedSceneIDs.count,
                            showCast: isSidebarCollapsed,
                            hasConflict: conflictSceneIDs.contains(scene.id),
                            isOnBlackoutDay: day.isBlackout,
                            onEdit:      { editScene(dayIndex: dayIndex, sceneIndex: sceneIndex, scene: scene, dayId: day.id) },
                            onRemove:    { removeFromDay(scene, dayId: day.id) },
                            onDuplicate: { duplicateScene(scene) },
                            onDragStart: { draggedSceneId = scene.id },
                            onDragEnd:   { draggedSceneId = nil },
                            onSelect:    { selectScene(scene, dayId: day.id) },
                            onSendToDay: { beginSendToDay(scene) },
                            dragPayload: { dragPayload(for: scene) }
                        )
                    }
                    .onDrop(of: [UTType.text.identifier], delegate: SceneDropDelegate(
                        dayId: day.id,
                        position: sceneIndex,
                        dropTargetDayId: $dropTargetDayId,
                        dropTargetPosition: $dropTargetPosition,
                        onDrop: { sceneId in handleSceneDrop(sceneId: sceneId, targetDayId: day.id, targetPosition: sceneIndex) }
                    ))
                }

                if shouldShowDropIndicator(dayId: day.id, position: day.scenes.count) {
                    DropIndicatorView()
                }
            }

            Spacer()

            if !day.scenes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total: \(formattedEighths(day.totalDuration))")
                        .font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                    Text("Est: \(formattedTime(day.totalEstimatedTime))")
                        .font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(day.isBlackout ? Color.red.opacity(0.16) : Color.gray.opacity(0.32))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    dayDropTargetId == day.id ? Color.green :
                    dropTargetDayId == day.id ? Color.red :
                    day.isBlackout ? Color.red.opacity(0.5) : Color.primary.opacity(0.3),
                    lineWidth: (dayDropTargetId == day.id || dropTargetDayId == day.id) ? 2.5 : (day.isBlackout ? 2 : 1.5)
                )
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        .onDrop(of: [UTType.text.identifier], delegate: CombinedDayDropDelegate(
            dayId: day.id,
            scenes: day.scenes,
            dropTargetDayId: $dropTargetDayId,
            dropTargetPosition: $dropTargetPosition,
            dayDropTargetId: $dayDropTargetId,
            draggingDayId: $draggingDayId,
            onSceneDrop: { sceneId in
                handleSceneDrop(sceneId: sceneId, targetDayId: day.id, targetPosition: day.scenes.count)
            },
            onDayDrop: { sourceDayId in
                handleDayRearrange(sourceDayId: sourceDayId, targetDayId: day.id)
            }
        ))
    }

    // MARK: - Call Sheet Editor

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
                    onSceneChanged()
                },
                onExportPDF: { exportDay in
                    onCallSheetExport(exportDay)
                }
            )
        }
    }

    // MARK: - Edit Sheet

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
                    onBeforeSceneChange()
                    if let id = editingDayId {
                        removeScene(shootDays[dayIndex].scenes[sceneIndex], id)
                        onSceneChanged()
                    }
                    clearEditingState()
                },
                canGoPrevious: sceneIndex > 0,
                canGoNext: sceneIndex < shootDays[dayIndex].scenes.count - 1,
                onPrevious: { editingSceneIndex = sceneIndex - 1 },
                onNext: { editingSceneIndex = sceneIndex + 1 },
                positionLabel: "Scene \(sceneIndex + 1) of \(shootDays[dayIndex].scenes.count)"
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

    // MARK: - Drag & Drop Helpers

    private func shouldShowDropIndicator(dayId: UUID, position: Int) -> Bool {
        dropTargetDayId == dayId && dropTargetPosition == position
    }

    /// Accepts either a single scene ID or a comma-separated list of scene IDs (dragged
    /// together from a Boneyard multi-selection) and inserts them, in order, starting at
    /// targetPosition so a dragged group lands together as a block.
    private func handleSceneDrop(sceneId: String, targetDayId: UUID, targetPosition: Int) {
        let ids = sceneId.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
        guard !ids.isEmpty else { return }
        onBeforeSceneChange()

        var insertPosition = targetPosition
        for uuid in ids {
            // From Boneyard
            if let idx = allScenes.firstIndex(where: { $0.id == uuid }) {
                let scene = allScenes.remove(at: idx)
                insertSceneIntoDay(scene: scene, dayId: targetDayId, position: insertPosition)
                insertPosition += 1
                continue
            }

            // From another (or same) day
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

    // MARK: - Selection

    /// Applies click / ⌘-click / ⇧-click semantics for scenes on the calendar, reading live
    /// modifier flags the same way the Boneyard does. A shift-click range only applies when
    /// the anchor scene is in the same day — reordering "up or down the schedule" doesn't have
    /// a single obvious axis to range over, so a cross-day shift-click just selects the one scene.
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

    // MARK: - Remove from Day

    /// Removes the clicked scene from its day back into the Boneyard — or, if it's part of
    /// a multi-scene selection, every selected scene that's currently scheduled anywhere on
    /// the calendar, mirroring the grouping behavior of "Send to Day".
    private func removeFromDay(_ scene: Scene, dayId: UUID) {
        onBeforeSceneChange()
        if selectedSceneIDs.contains(scene.id), selectedSceneIDs.count > 1 {
            for dayIdx in shootDays.indices {
                let matching = shootDays[dayIdx].scenes.filter { selectedSceneIDs.contains($0.id) }
                for s in matching {
                    removeScene(s, shootDays[dayIdx].id)
                }
            }
        } else {
            removeScene(scene, dayId)
        }
        onSceneChanged()
    }

    // MARK: - Blackout days

    private func weekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func toggleBlackout(_ day: ShootDay) {
        guard let idx = shootDays.firstIndex(where: { $0.id == day.id }) else { return }
        onBeforeSceneChange()
        shootDays[idx].isBlackout.toggle()
        onSceneChanged()
    }

    /// Toggles every day sharing this date's weekday to match — e.g. "we don't shoot
    /// Saturdays" in one action instead of right-clicking each Saturday individually.
    private func toggleBlackoutForWeekday(_ day: ShootDay) {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: day.date)
        let newValue = !day.isBlackout
        onBeforeSceneChange()
        for idx in shootDays.indices where cal.component(.weekday, from: shootDays[idx].date) == weekday {
            shootDays[idx].isBlackout = newValue
        }
        onSceneChanged()
    }

    // MARK: - Send to Day

    /// Right-clicking a scene that's part of the current multi-selection sends the whole
    /// selection; right-clicking a scene outside the selection sends just that one, mirroring
    /// the same "act on the selection, or act on what you clicked" rule the Boneyard drag uses.
    /// Every currently selected scene ID, ordered sensibly — scheduled ones by their
    /// existing calendar position, then any still-unscheduled selected ones from the
    /// Boneyard — or just [scene.id] if scene isn't part of a multi-selection. Shared by
    /// both Send to Day and dragging a multi-selected scene, so both move a selection in
    /// the same order rather than Set's arbitrary iteration order.
    private func orderedSelectionIDs(for scene: Scene) -> [UUID] {
        guard selectedSceneIDs.contains(scene.id), selectedSceneIDs.count > 1 else { return [scene.id] }
        let scheduledOrdered = shootDays.flatMap { $0.scenes.map(\.id) }.filter { selectedSceneIDs.contains($0) }
        let boneyardOrdered  = allScenes.map(\.id).filter { selectedSceneIDs.contains($0) }
        return scheduledOrdered + boneyardOrdered
    }

    /// Comma-separated drag payload for a scene card — the whole selection if it's part of
    /// a multi-selection, otherwise just itself. handleSceneDrop already accepts either a
    /// single ID or a comma-separated list, so no change was needed on the drop side.
    private func dragPayload(for scene: Scene) -> String {
        if !(selectedSceneIDs.contains(scene.id) && selectedSceneIDs.count > 1) {
            selectedSceneIDs = [scene.id]
            lastSelectedSceneID = scene.id
        }
        return orderedSelectionIDs(for: scene).map(\.uuidString).joined(separator: ",")
    }

    private func beginSendToDay(_ scene: Scene) {
        sendToDaySceneIDs = orderedSelectionIDs(for: scene)
        showingSendToDaySheet = true
    }

    /// Moves the given scenes (from the Boneyard or any day) to the end of the target day,
    /// preserving the order they're passed in, and clears them from the selection afterward.
    private func sendScenes(_ ids: [UUID], toDay targetDayId: UUID) {
        guard let targetIdx = shootDays.firstIndex(where: { $0.id == targetDayId }) else { return }
        onBeforeSceneChange()
        var insertPosition = shootDays[targetIdx].scenes.count

        for uuid in ids {
            if let idx = allScenes.firstIndex(where: { $0.id == uuid }) {
                let scene = allScenes.remove(at: idx)
                insertSceneIntoDay(scene: scene, dayId: targetDayId, position: insertPosition)
                insertPosition += 1
                continue
            }
            for dayIdx in shootDays.indices {
                if let sceneIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == uuid }) {
                    let scene = shootDays[dayIdx].scenes.remove(at: sceneIdx)
                    insertSceneIntoDay(scene: scene, dayId: targetDayId, position: insertPosition)
                    insertPosition += 1
                    break
                }
            }
        }

        selectedSceneIDs.subtract(ids)
        onSceneChanged()
    }

    private func duplicateScene(_ scene: Scene) {
        onBeforeSceneChange()
        allScenes.append(Scene(
            title: scene.title + " (Copy)",
            duration: scene.duration,
            estimatedTime: scene.estimatedTime,
            dayNightType: scene.dayNightType,
            cast: scene.cast,
            summary: scene.summary,
            extras: scene.extras,
            props: scene.props,
            wardrobe: scene.wardrobe,
            vehicles: scene.vehicles,
            specialEquipment: scene.specialEquipment,
            stunts: scene.stunts,
            sfx: scene.sfx,
            vfx: scene.vfx,
            breakdownNotes: scene.breakdownNotes
        ))
        onSceneChanged()
    }

    // MARK: - Edit State

    private func editScene(dayIndex: Int, sceneIndex: Int, scene: Scene, dayId: UUID) {
        editingDayIndex   = dayIndex
        editingSceneIndex = sceneIndex
        editingScene      = scene
        editingDayId      = dayId
        showingEditSheet  = true
    }

    private func clearEditingState() {
        editingScene      = nil
        editingDayId      = nil
        editingDayIndex   = nil
        editingSceneIndex = nil
    }

    // MARK: - Day Rearrange

    /// Moves scenes and call sheet from sourceDayId to targetDayId.
    /// If target has content, swaps both days' scenes and call sheet data.
    /// The calendar dates themselves never change — only the content moves.
    private func handleDayRearrange(sourceDayId: UUID, targetDayId: UUID) {
        guard sourceDayId != targetDayId,
              let sourceIdx = shootDays.firstIndex(where: { $0.id == sourceDayId }),
              let targetIdx = shootDays.firstIndex(where: { $0.id == targetDayId })
        else { return }
        onBeforeSceneChange()

        // Swap scenes and call sheet, preserving both dates
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
}

// MARK: - SceneCardView

struct SceneCardView: View {
    let scene:      Scene
    let dayId:      UUID
    let dayIndex:   Int
    let sceneIndex: Int
    @Binding var interactingSceneId: UUID?
    let isSelected:     Bool
    let selectionCount: Int
    let showCast:       Bool
    let hasConflict:    Bool
    let isOnBlackoutDay: Bool
    let onEdit:      () -> Void
    let onRemove:    () -> Void
    let onDuplicate: () -> Void
    let onDragStart: () -> Void
    let onDragEnd:   () -> Void
    let onSelect:    () -> Void
    let onSendToDay: () -> Void
    let dragPayload: () -> String

    private var isDragging: Bool { interactingSceneId == scene.id }
    private var isMultiSelected: Bool { isSelected && selectionCount > 1 }
    /// A conflict (this scene's cast includes someone marked unavailable that day) takes
    /// visual priority over the normal Day/Night/Custom color — it's the more urgent thing
    /// to notice at a glance.
    private var isFlagged: Bool { hasConflict || isOnBlackoutDay }
    private var displayColor: Color { isFlagged ? .red : scene.dayNightType.color }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Circle()
                .fill(displayColor)
                .frame(width: 8, height: 8)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(scene.title)
                        .font(.caption2).fontWeight(.medium).lineLimit(2)
                    if hasConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.red)
                            .help("An actor in this scene is marked unavailable this day")
                    }
                    if isOnBlackoutDay {
                        Image(systemName: "nosign")
                            .font(.system(size: 7))
                            .foregroundColor(.red)
                            .help("Scheduled on a day marked unavailable")
                    }
                }

                Text("(\(formattedEighths(scene.duration)), \(formattedTime(scene.estimatedTime)))")
                    .font(.caption2).foregroundColor(.secondary)

                // Cast only shows when the sidebar is collapsed — with the sidebar open there's
                // not enough width for it to read cleanly, and it's left off the PDF entirely
                // since PDFExporter never draws it.
                if showCast, !scene.cast.isEmpty {
                    Text(scene.cast.joined(separator: ", "))
                        .font(.caption2).foregroundColor(.secondary).italic()
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(displayColor.opacity(isDragging ? 0.3 : (isFlagged ? 0.22 : 0.15)))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? Color.accentColor : displayColor.opacity(isDragging ? 0.8 : (isFlagged ? 0.9 : 0.4)),
                            lineWidth: isSelected ? 2 : (isDragging || isFlagged ? 2 : 1)
                        )
                )
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .fastTooltip(scene.tooltipText)
        .onDrag {
            interactingSceneId = scene.id
            onDragStart()
            return NSItemProvider(object: dragPayload() as NSString)
        } preview: {
            HStack(spacing: 4) {
                Circle().fill(scene.dayNightType.color).frame(width: 8, height: 8)
                Text(scene.title).font(.caption).fontWeight(.medium)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(radius: 4)
            )
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { interactingSceneId = nil; onEdit() })
        .simultaneousGesture(TapGesture(count: 1).onEnded { interactingSceneId = nil; onSelect() })
        .contextMenu {
            Button("Edit Scene") { interactingSceneId = nil; onEdit() }

            Button(isMultiSelected ? "Remove \(selectionCount) Scenes from Day" : "Remove from Day") {
                interactingSceneId = nil; onRemove()
            }
            Divider()
            Button("Duplicate Scene") { interactingSceneId = nil; onDuplicate() }
            Divider()
            Button(isMultiSelected ? "Send \(selectionCount) Scenes to Day…" : "Send to Day…") {
                interactingSceneId = nil; onSendToDay()
            }
        }
        .onChange(of: isDragging) { _, dragging in
            if !dragging { onDragEnd() }
        }
    }
}

// MARK: - DropIndicatorView

struct DropIndicatorView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.blue.opacity(0.3))
            .frame(height: 6)
            .padding(.horizontal, 8)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.blue, lineWidth: 1))
            .accessibilityLabel("Drop zone")
            .animation(.easeInOut(duration: 0.3), value: true)
    }
}

// MARK: - SceneDropDelegate

struct SceneDropDelegate: DropDelegate {
    let dayId:    UUID
    let position: Int
    @Binding var dropTargetDayId:   UUID?
    @Binding var dropTargetPosition: Int?
    let onDrop: (String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }
    func dropEntered(info: DropInfo) {
        dropTargetDayId      = dayId
        dropTargetPosition   = position
    }
    func dropExited(info: DropInfo) {
        if dropTargetDayId == dayId && dropTargetPosition == position {
            dropTargetDayId    = nil
            dropTargetPosition = nil
        }
    }
    func performDrop(info: DropInfo) -> Bool {
        defer { dropTargetDayId = nil; dropTargetPosition = nil }
        guard let provider = info.itemProviders(for: [UTType.text.identifier]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            if let id = item as? String {
                DispatchQueue.main.async { onDrop(id) }
            }
        }
        return true
    }
}

// MARK: - CombinedDayDropDelegate
// Handles both scene drops (from Boneyard/other days) and day rearrange drops
// by inspecting the "day:" prefix on the drag identifier.

struct CombinedDayDropDelegate: DropDelegate {
    let dayId:    UUID
    let scenes:   [Scene]
    @Binding var dropTargetDayId:    UUID?
    @Binding var dropTargetPosition: Int?
    @Binding var dayDropTargetId:    UUID?
    @Binding var draggingDayId:      UUID?
    let onSceneDrop: (String) -> Void
    let onDayDrop:   (UUID)   -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropEntered(info: DropInfo) {
        // Peek at the identifier to decide which highlight to show
        // We can't read the value synchronously, so we show day highlight
        // if draggingDayId is set, scene highlight otherwise
        if draggingDayId != nil {
            dayDropTargetId = dayId
        } else if scenes.isEmpty {
            dropTargetDayId  = dayId
            dropTargetPosition = 0
        }
    }

    func dropExited(info: DropInfo) {
        if dayDropTargetId == dayId   { dayDropTargetId  = nil }
        if dropTargetDayId == dayId   { dropTargetDayId  = nil; dropTargetPosition = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropTargetDayId    = nil
            dropTargetPosition = nil
            dayDropTargetId    = nil
        }

        guard let provider = info.itemProviders(for: [UTType.text.identifier]).first else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let idString = item as? String else { return }
            DispatchQueue.main.async {
                if idString.hasPrefix("day:"),
                   let uuid = UUID(uuidString: String(idString.dropFirst(4))) {
                    onDayDrop(uuid)
                } else {
                    onSceneDrop(idString)
                }
            }
        }
        return true
    }
}
