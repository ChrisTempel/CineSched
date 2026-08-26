// CalendarView.swift
// Calendar grid with drag-and-drop scene scheduling

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - DropIndicatorView & Delegates

struct DropIndicatorView: View {
    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(height: 2)
            .padding(.vertical, 1)
    }
}

struct CombinedDayDropDelegate: DropDelegate {
    let dayId: UUID
    let scenes: [Scene]
    @Binding var dropTargetDayId: UUID?
    @Binding var dropTargetPosition: Int?
    @Binding var dayDropTargetId: UUID?
    @Binding var draggingDayId: UUID?
    let onSceneDrop: (UUID) -> Void
    let onDayDrop: (UUID) -> Void

    func performDrop(info: DropInfo) -> Bool {
        if let dayIdStr = draggingDayId, dayIdStr != dayId {
            onDayDrop(dayIdStr)
            draggingDayId = nil
            dayDropTargetId = nil
            return true
        }
        guard let item = info.itemProviders(for: [UTType.text.identifier]).first else { return false }
        item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
            if let data = data as? Data, let idStr = String(data: data, encoding: .utf8) {
                let firstIdStr = idStr.split(separator: ",").first.map(String.init) ?? idStr
                if let uuid = UUID(uuidString: firstIdStr) {
                    DispatchQueue.main.async {
                        onSceneDrop(uuid)
                    }
                }
            }
        }
        dropTargetDayId = nil
        dropTargetPosition = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        if draggingDayId != nil && draggingDayId != dayId {
            dayDropTargetId = dayId
        } else {
            dropTargetDayId = dayId
            dropTargetPosition = scenes.count
        }
    }

    func dropExited(info: DropInfo) {
        if dayDropTargetId == dayId { dayDropTargetId = nil }
        if dropTargetDayId == dayId { dropTargetDayId = nil }
    }
}

struct SceneDropDelegate: DropDelegate {
    let dayId: UUID
    let position: Int
    @Binding var dropTargetDayId: UUID?
    @Binding var dropTargetPosition: Int?
    let onDrop: (UUID) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [UTType.text.identifier]).first else { return false }
        item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
            if let data = data as? Data, let idStr = String(data: data, encoding: .utf8) {
                let firstIdStr = idStr.split(separator: ",").first.map(String.init) ?? idStr
                if let uuid = UUID(uuidString: firstIdStr) {
                    DispatchQueue.main.async {
                        onDrop(uuid)
                    }
                }
            }
        }
        dropTargetDayId = nil
        dropTargetPosition = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        dropTargetDayId = dayId
        dropTargetPosition = position
    }

    func dropExited(info: DropInfo) {
        if dropTargetDayId == dayId && dropTargetPosition == position {
            dropTargetDayId = nil
            dropTargetPosition = nil
        }
    }
}

// MARK: - Standalone DayCellView

struct DayCellView: View {
    let day: ShootDay
    let dayIndex: Int
    let dayNumber: Int?
    let isSidebarCollapsed: Bool
    let showCastOnCards: Bool
    let showEstTimeOnCards: Bool
    let isInShootRange: Bool
    let selectedSceneIDs: Set<UUID>
    let conflictSceneIDs: Set<UUID>
    let duplicateSceneNumberIDs: Set<UUID>

    @Binding var draggingDayId: UUID?
    @Binding var dropTargetDayId: UUID?
    @Binding var dropTargetPosition: Int?
    @Binding var dayDropTargetId: UUID?
    @Binding var addingEventForDayId: UUID?
    @Binding var callSheetDay: ShootDay?
    @Binding var interactingSceneId: UUID?
    @Binding var draggedSceneId: UUID?

    let onOpenDayDetail: () -> Void
    let onEditScene: (Int, Scene) -> Void
    let onRemoveScene: (Scene) -> Void
    let onDuplicateScene: (Scene) -> Void
    let onToggleCompletedScene: (Scene) -> Void
    let onSelectScene: (Scene) -> Void
    let onSendToDay: (Scene) -> Void
    let onHandleSceneDrop: (UUID, Int) -> Void
    let onHandleDayRearrange: (UUID) -> Void
    let onToggleBlackout: (ShootDay) -> Void
    let onToggleBlackoutWeekday: (ShootDay) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("CineSchedTheme") private var currentTheme: AppTheme = .blue

    private var visibleScenes: [Scene] {
        day.scenes.filter { !$0.isBanner || $0.isCalendarEvent }
    }

    private var isShootDay: Bool {
        !day.isBlackout && (dayNumber != nil || isInShootRange || !day.scenes.filter { !$0.isCalendarEvent }.isEmpty)
    }

    private var isTarget: Bool {
        dayDropTargetId == day.id || dropTargetDayId == day.id
    }

    private var borderColor: Color {
        if dayDropTargetId == day.id { return .green }
        if dropTargetDayId == day.id { return .red }
        if day.isBlackout { return .red.opacity(0.4) }
        if isShootDay { return currentTheme.shootDayBorderColor(isDarkMode: colorScheme == .dark) }
        return .primary.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            sceneList
            Spacer()
            footer
        }
        .padding(8)
        .frame(minHeight: 120, alignment: .topLeading)
        .background(
            ZStack {
                if isShootDay {
                    currentTheme.shootDayRangeHighlight(isDarkMode: colorScheme == .dark)
                } else {
                    Color(NSColor.controlBackgroundColor)
                }
                if isWeekend(day.date) { Color.black.opacity(colorScheme == .dark ? 0.15 : 0.03) }
                if day.isBlackout { Color.red.opacity(colorScheme == .dark ? 0.25 : 0.1) }
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isTarget ? 2 : 1)
        )
        .opacity(draggingDayId == day.id ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpenDayDetail()
        }
        .onDrop(of: [UTType.text.identifier], delegate: CombinedDayDropDelegate(
            dayId: day.id,
            scenes: visibleScenes,
            dropTargetDayId: $dropTargetDayId,
            dropTargetPosition: $dropTargetPosition,
            dayDropTargetId: $dayDropTargetId,
            draggingDayId: $draggingDayId,
            onSceneDrop: { sceneId in onHandleSceneDrop(sceneId, visibleScenes.count) },
            onDayDrop: { sourceDayId in onHandleDayRearrange(sourceDayId) }
        ))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(draggingDayId == day.id ? .blue : .secondary)
                    .padding(2)
                    .contentShape(Rectangle())
                    .onDrag {
                        draggingDayId = day.id
                        return NSItemProvider(object: "day:\(day.id.uuidString)" as NSString)
                    }
                    .help("Drag to move this day's scenes and call sheet to another date")

                Button {
                    onOpenDayDetail()
                } label: {
                    HStack(spacing: 3) {
                        let cal = Calendar.current
                        let dayOfMonth = cal.component(.day, from: day.date)
                        let weekdayStr = localizedShortWeekday(day.date)

                        Text("\(dayOfMonth)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(day.isBlackout ? .red : .primary)

                        Text(weekdayStr)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if day.hasCallSheetData {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 2)

                if let dayNumber, isShootDay {
                    Text("\(L("Day")) \(dayNumber)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(currentTheme.primaryAccent(isDarkMode: colorScheme == .dark))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(currentTheme.primaryAccent(isDarkMode: colorScheme == .dark).opacity(0.18))
                        .cornerRadius(3.5)
                }

                Button {
                    addingEventForDayId = day.id
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("Add Calendar Event"))
            }

            if !day.callSheet.lunchTime.isEmpty || !day.callSheet.snackTime.isEmpty || !day.callSheet.dinnerTime.isEmpty {
                HStack(spacing: 4) {
                    Spacer()
                    if !day.callSheet.lunchTime.isEmpty {
                        Text("🍽️ \(day.callSheet.lunchTime)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if !day.callSheet.snackTime.isEmpty {
                        Text("☕ \(day.callSheet.snackTime)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if !day.callSheet.dinnerTime.isEmpty {
                        Text("🎬 \(day.callSheet.dinnerTime)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .contextMenu {
            Button(LocalizationManager.shared.currentLanguage == .spanish ? "Ver Detalle del Día" : "View Day Details") { onOpenDayDetail() }
            Button(L("Add Calendar Event")) { addingEventForDayId = day.id }
            Divider()
            Button(day.isBlackout ? "Mark as Available" : "Mark as Unavailable") { onToggleBlackout(day) }
            Button(day.isBlackout ? "Mark Weekday Available" : "Mark Weekday Unavailable") { onToggleBlackoutWeekday(day) }
        }
    }

    private func localizedShortWeekday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = LocalizationManager.shared.currentLanguage == .spanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        df.dateFormat = "EEE"
        return df.string(from: date).capitalized
    }

    private var sceneList: some View {
        VStack(spacing: 2) {
            ForEach(Array(visibleScenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                VStack(spacing: 0) {
                    if dropTargetDayId == day.id && dropTargetPosition == sceneIndex {
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
                        showCast: isSidebarCollapsed || showCastOnCards,
                        showEstTimeOnCards: showEstTimeOnCards,
                        hasConflict: conflictSceneIDs.contains(scene.id),
                        hasDuplicateSceneNumber: duplicateSceneNumberIDs.contains(scene.id),
                        isOnBlackoutDay: day.isBlackout,
                        onEdit:      { onEditScene(sceneIndex, scene) },
                        onRemove:    { onRemoveScene(scene) },
                        onDuplicate: { onDuplicateScene(scene) },
                        onToggleCompleted: { onToggleCompletedScene(scene) },
                        onDragStart: { draggedSceneId = scene.id },
                        onDragEnd:   { draggedSceneId = nil },
                        onSelect:    { onSelectScene(scene) },
                        onSendToDay: { onSendToDay(scene) },
                        dragPayload: { scene.id.uuidString }
                    )
                }
                .onDrop(of: [UTType.text.identifier], delegate: SceneDropDelegate(
                    dayId: day.id,
                    position: sceneIndex,
                    dropTargetDayId: $dropTargetDayId,
                    dropTargetPosition: $dropTargetPosition,
                    onDrop: { sceneId in onHandleSceneDrop(sceneId, sceneIndex) }
                ))
            }

            if dropTargetDayId == day.id && dropTargetPosition == visibleScenes.count {
                DropIndicatorView()
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if !visibleScenes.isEmpty {
            let scriptScenes = visibleScenes.filter { !$0.isBanner }
            let totalDur = scriptScenes.reduce(0) { $0 + $1.duration }
            let totalEst = scriptScenes.reduce(0) { $0 + $1.estimatedTime }
            if totalDur > 0 || totalEst > 0 {
                Text("\(L("Total:")) \(formattedEighths(totalDur)) · \(formattedTime(totalEst))")
                    .font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLanguage == .spanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - CompactMonthCalendarView

enum CalendarViewMode: String, CaseIterable {
    case monthGrid
    case shootDaysOnly
}

struct CompactMonthCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("CineSchedTheme") private var currentTheme: AppTheme = .blue
    @ObservedObject private var l10n = LocalizationManager.shared
    @Binding var shootDays: [ShootDay]
    let assignScene:  (Scene, ShootDay) -> Void
    @Binding var allScenes: [Scene]
    let updateScene:  (Scene, UUID) -> Void
    let removeScene:  (Scene, UUID) -> Void
    let projectTitle: String
    let productionInfo: ProductionInfo
    let isSidebarCollapsed: Bool
    let showCastOnCards: Bool
    let showEstTimeOnCards: Bool
    let startDate: Date
    let endDate: Date
    @Binding var selectedSceneIDs:    Set<UUID>
    @Binding var lastSelectedSceneID: UUID?
    let conflictDates: Set<Date>
    let conflictSceneIDs: Set<UUID>
    let duplicateSceneNumberIDs: Set<UUID>
    let scheduleLockChangedDates: Set<Date>
    @Binding var scrollToDate: Date?
    let dragStateResetToken: Int
    let onBeforeSceneChange: () -> Void
    let onSceneChanged: () -> Void
    let onCallSheetExport: (ShootDay) -> Void

    // View Mode Switcher
    @AppStorage("CineSchedCalendarViewMode") private var calendarViewMode: CalendarViewMode = .monthGrid

    // Day Detail Inspector Sheet state
    @State private var inspectingDay: ShootDay? = nil

    // Editing state
    @State private var editingScene:      Scene?
    @State private var editingDayId:      UUID?
    @State private var editingDayIndex:   Int?
    @State private var editingSceneIndex: Int?
    @State private var showingEditSheet = false

    // Call sheet state
    @State private var callSheetDay: ShootDay? = nil

    // Send to Day state
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

    // Add Calendar Event sheet state
    @State private var addingEventForDayId: UUID? = nil
    @State private var editingEventScene: Scene? = nil
    @State private var editingEventDayId: UUID? = nil

    // Month navigation state
    @State private var displayedMonth: Date = Date()

    private var isSpanish: Bool {
        LocalizationManager.shared.currentLanguage == .spanish
    }

    private var startOfDisplayedMonth: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        return cal.date(from: comps) ?? displayedMonth
    }

    private var daysInDisplayedMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: startOfDisplayedMonth) else { return [] }
        return range.compactMap { day -> Date? in
            cal.date(byAdding: .day, value: day - 1, to: startOfDisplayedMonth)
        }
    }

    private var monthLeadingOffsetCount: Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: startOfDisplayedMonth) // 1=Sun, 2=Mon...
        return weekday - 1 // Sunday=0
    }

    private var monthYearTitle: String {
        let df = DateFormatter()
        df.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        df.dateFormat = "LLLL yyyy"
        return df.string(from: displayedMonth).capitalized
    }

    private var weekdaySymbols: [String] {
        if isSpanish {
            return ["DOMINGO", "LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO"]
        } else {
            return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        }
    }

    private var monthNavigationRow: some View {
        HStack(spacing: 12) {
            // View Mode Switcher
            Picker("", selection: $calendarViewMode) {
                Text(isSpanish ? "📅 Mes Completo" : "📅 Full Month").tag(CalendarViewMode.monthGrid)
                Text(isSpanish ? "🎬 Horario Completo" : "🎬 Full Schedule").tag(CalendarViewMode.shootDaysOnly)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Divider().frame(height: 20)

            if calendarViewMode == .monthGrid {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
                .help(L("Previous Month"))

                Text(monthYearTitle)
                    .font(.system(size: 15, weight: .bold))
                    .frame(minWidth: 150, alignment: .center)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
                .help(L("Next Month"))

                Button(L("Go to Shoot")) {
                    if let firstShoot = shootDays.first(where: { !$0.scenes.isEmpty }) ?? shootDays.first {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = firstShoot.date
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button(L("Today")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Date()
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Text("\(onlyActualShootDays.count) \(isSpanish ? "Días en Plan de Rodaje" : "Days in Schedule")")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                exportMonthPDF()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text(L("Export Month (PDF)"))
                }
            }
            .buttonStyle(.bordered)
            .help(L("Export Month (PDF)"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var onlyActualShootDays: [(offset: Int, element: ShootDay)] {
        Array(shootDays.enumerated()).filter { _, day in
            let start = Calendar.current.startOfDay(for: startDate)
            let end = Calendar.current.startOfDay(for: endDate)
            let dayDate = Calendar.current.startOfDay(for: day.date)
            return dayDate >= start && dayDate <= end
        }
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.08))
        .cornerRadius(6)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    var body: some View {
        VStack(spacing: 0) {
            monthNavigationRow

            weekdayHeaderRow

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    let columns = Array(repeating: GridItem(.flexible(minimum: 100), spacing: 8), count: 7)
                    LazyVGrid(columns: columns, spacing: 8) {
                        if calendarViewMode == .monthGrid {
                            ForEach(0..<monthLeadingOffsetCount, id: \.self) { _ in
                                Color.clear
                                    .frame(minHeight: 120)
                            }
                            ForEach(daysInDisplayedMonth, id: \.self) { date in
                                if let dayIndex = shootDays.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                                    dayCell(day: shootDays[dayIndex], dayIndex: dayIndex)
                                        .id(shootDays[dayIndex].id)
                                } else {
                                    emptyDayCell(for: date)
                                        .id(date)
                                }
                            }
                        } else {
                            // Shoot Days Only mode
                            let shootDaysList = onlyActualShootDays
                            let leadingShootOffset: Int = {
                                guard let first = shootDaysList.first?.element else { return 0 }
                                let weekday = Calendar.current.component(.weekday, from: first.date)
                                return weekday - 1 // Sunday=0
                            }()
                            ForEach(0..<leadingShootOffset, id: \.self) { _ in
                                Color.clear
                                    .frame(minHeight: 120)
                            }
                            ForEach(shootDaysList, id: \.element.id) { dayIndex, day in
                                dayCell(day: day, dayIndex: dayIndex)
                                    .id(day.id)
                            }
                        }
                    }
                    .id("\(isSidebarCollapsed)-\(showCastOnCards)")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
                .onChange(of: scrollToDate) { _, newValue in
                    guard let date = newValue else { return }
                    displayedMonth = date
                    if let target = shootDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                        withAnimation { proxy.scrollTo(target.id, anchor: .top) }
                    }
                    scrollToDate = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tooltipContainer()
        .onChange(of: dragStateResetToken) { _, _ in
            // Undo/redo restores allScenes/shootDays but has no way to reach into this
            // view's own local drag-target state — this clears it explicitly so a day
            // cell's drop-target border can't get stuck highlighted after an undo.
            dropTargetDayId = nil
            dropTargetPosition = nil
            draggedSceneId = nil
            dayDropTargetId = nil
            draggingDayId = nil
        }
        .onAppear {
            if let firstShoot = shootDays.first(where: { !$0.scenes.isEmpty }) ?? shootDays.first {
                displayedMonth = firstShoot.date
            }
        }
        .sheet(item: $inspectingDay) { day in
            DayDetailSheet(
                day: day,
                dayNumber: dayNumbers[day.id],
                productionInfo: productionInfo,
                isPresented: Binding(
                    get: { inspectingDay != nil },
                    set: { if !$0 { inspectingDay = nil } }
                ),
                onEditScene: { scene in
                    if let dIdx = shootDays.firstIndex(where: { $0.id == day.id }),
                       let sIdx = shootDays[dIdx].scenes.firstIndex(where: { $0.id == scene.id }) {
                        inspectingDay = nil
                        editScene(dayIndex: dIdx, sceneIndex: sIdx, scene: scene, dayId: day.id)
                    }
                },
                onRemoveScene: { scene in
                    removeFromDay(scene, dayId: day.id)
                    if let updated = shootDays.first(where: { $0.id == day.id }) {
                        inspectingDay = updated
                    } else {
                        inspectingDay = nil
                    }
                },
                onAddCalendarEvent: {
                    inspectingDay = nil
                    addingEventForDayId = day.id
                },
                onOpenCallSheet: {
                    inspectingDay = nil
                    callSheetDay = day
                },
                onExportCallSheetPDF: {
                    inspectingDay = nil
                    onCallSheetExport(day)
                }
            )
        }
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
        .sheet(isPresented: Binding(
            get: { addingEventForDayId != nil },
            set: { if !$0 { addingEventForDayId = nil } }
        )) {
            CalendarEventInputSheet(isPresented: Binding(
                get: { addingEventForDayId != nil },
                set: { if !$0 { addingEventForDayId = nil } }
            ), onSave: { newEvent in
                if let targetId = addingEventForDayId,
                   let idx = shootDays.firstIndex(where: { $0.id == targetId }) {
                    shootDays[idx].scenes.append(newEvent)
                    onSceneChanged()
                }
            })
        }
        .sheet(item: $editingEventScene) { ev in
            CalendarEventInputSheet(
                isPresented: Binding(
                    get: { editingEventScene != nil },
                    set: { if !$0 { editingEventScene = nil; editingEventDayId = nil } }
                ),
                initialEvent: ev,
                onSave: { updatedEvent in
                    if let dId = editingEventDayId ?? shootDays.first(where: { $0.scenes.contains(where: { $0.id == ev.id }) })?.id,
                       let dayIdx = shootDays.firstIndex(where: { $0.id == dId }),
                       let sceneIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == ev.id }) {
                        shootDays[dayIdx].scenes[sceneIdx] = updatedEvent
                        onSceneChanged()
                    }
                    editingEventScene = nil
                    editingEventDayId = nil
                }
            )
        }
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing { clearEditingState() }
        }
    }

    @ViewBuilder
    private func emptyDayCell(for date: Date) -> some View {
        let cal = Calendar.current
        let dayDigit = cal.component(.day, from: date)
        let isShootRange = date >= cal.startOfDay(for: startDate) && date <= cal.startOfDay(for: endDate)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(dayDigit)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isShootRange ? currentTheme.primaryAccent(isDarkMode: colorScheme == .dark) : .secondary)
                Spacer()
                Button {
                    createAndAddEvent(for: date)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("Add Calendar Event"))
            }
            Spacer()
        }
        .padding(8)
        .frame(minHeight: 120, alignment: .topLeading)
        .background(
            isShootRange
                ? currentTheme.shootDayRangeHighlight(isDarkMode: colorScheme == .dark)
                : Color(NSColor.controlBackgroundColor).opacity(0.5)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isShootRange
                        ? currentTheme.shootDayBorderColor(isDarkMode: colorScheme == .dark)
                        : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            createAndAddEvent(for: date)
        }
        .onDrop(of: [UTType.text.identifier], delegate: CombinedDayDropDelegate(
            dayId: UUID(),
            scenes: [],
            dropTargetDayId: $dropTargetDayId,
            dropTargetPosition: $dropTargetPosition,
            dayDropTargetId: $dayDropTargetId,
            draggingDayId: $draggingDayId,
            onSceneDrop: { sceneId in
                onBeforeSceneChange()
                var targetDay: ShootDay
                if let existing = shootDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                    targetDay = existing
                } else {
                    targetDay = ShootDay(date: date)
                    shootDays.append(targetDay)
                    shootDays.sort { $0.date < $1.date }
                }
                handleSceneDrop(sceneId: sceneId, targetDayId: targetDay.id, targetPosition: targetDay.scenes.count)
            },
            onDayDrop: { _ in }
        ))
        .contextMenu {
            Button(L("Add Calendar Event")) {
                createAndAddEvent(for: date)
            }
            Button(L("Mark as Shoot Day")) {
                onBeforeSceneChange()
                let newDay = ShootDay(date: date)
                shootDays.append(newDay)
                shootDays.sort { $0.date < $1.date }
                onSceneChanged()
            }
        }
    }

    private func createAndAddEvent(for date: Date) {
        if let existing = shootDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            addingEventForDayId = existing.id
        } else {
            onBeforeSceneChange()
            let newDay = ShootDay(date: date)
            shootDays.append(newDay)
            shootDays.sort { $0.date < $1.date }
            onSceneChanged()
            addingEventForDayId = newDay.id
        }
    }

    private func exportMonthPDF() {
        guard let pdfData = PDFExporter.generateMonthPDF(
            month: displayedMonth,
            shootDays: shootDays,
            projectTitle: projectTitle,
            productionInfo: productionInfo
        ) else { return }

        let df = DateFormatter()
        df.dateFormat = "yyyy_MM"
        let monthStr = df.string(from: displayedMonth)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = L("Export Month (PDF)")
        savePanel.nameFieldStringValue = "Calendar_\(monthStr).pdf"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? pdfData.write(to: url)
            }
        }
    }

    // MARK: - Day Cell Component

    private var dayNumbers: [UUID: Int] { productionDayNumbers(for: shootDays) }

    @ViewBuilder
    private func dayCell(day: ShootDay, dayIndex: Int) -> some View {
        let cal = Calendar.current
        let inRange = day.date >= cal.startOfDay(for: startDate) && day.date <= cal.startOfDay(for: endDate)

        DayCellView(
            day: day,
            dayIndex: dayIndex,
            dayNumber: dayNumbers[day.id],
            isSidebarCollapsed: isSidebarCollapsed,
            showCastOnCards: showCastOnCards,
            showEstTimeOnCards: showEstTimeOnCards,
            isInShootRange: inRange,
            selectedSceneIDs: selectedSceneIDs,
            conflictSceneIDs: conflictSceneIDs,
            duplicateSceneNumberIDs: duplicateSceneNumberIDs,
            draggingDayId: $draggingDayId,
            dropTargetDayId: $dropTargetDayId,
            dropTargetPosition: $dropTargetPosition,
            dayDropTargetId: $dayDropTargetId,
            addingEventForDayId: $addingEventForDayId,
            callSheetDay: $callSheetDay,
            interactingSceneId: $interactingSceneId,
            draggedSceneId: $draggedSceneId,
            onOpenDayDetail: { inspectingDay = day },
            onEditScene: { sceneIndex, scene in editScene(dayIndex: dayIndex, sceneIndex: sceneIndex, scene: scene, dayId: day.id) },
            onRemoveScene: { scene in removeFromDay(scene, dayId: day.id) },
            onDuplicateScene: { scene in duplicateScene(scene) },
            onToggleCompletedScene: { scene in toggleSceneCompleted(scene) },
            onSelectScene: { scene in selectScene(scene, dayId: day.id) },
            onSendToDay: { scene in beginSendToDay(scene) },
            onHandleSceneDrop: { sceneId, pos in handleSceneDrop(sceneId: sceneId, targetDayId: day.id, targetPosition: pos) },
            onHandleDayRearrange: { sourceDayId in handleDayRearrange(sourceDayId: sourceDayId, targetDayId: day.id) },
            onToggleBlackout: { targetDay in toggleBlackout(targetDay) },
            onToggleBlackoutWeekday: { targetDay in toggleBlackoutForWeekday(targetDay) }
        )
    }

    // MARK: - Actions & Handlers

    private func editScene(dayIndex: Int, sceneIndex: Int, scene: Scene, dayId: UUID) {
        if scene.isCalendarEvent {
            editingEventScene = scene
            editingEventDayId = dayId
            return
        }
        var tempScene = scene
        tempScene.autoExtractSceneNumberIfNeeded()
        editingScene      = tempScene
        editingDayId      = dayId
        editingDayIndex   = dayIndex
        editingSceneIndex = sceneIndex
        showingEditSheet  = true
    }

    private func saveCurrentSceneEdit() {
        guard let editingDayId, let editingDayIndex, let editingSceneIndex,
              editingDayIndex < shootDays.count,
              editingSceneIndex < shootDays[editingDayIndex].scenes.count else { return }
        onBeforeSceneChange()
        // SceneEditSheet already wrote every edited field directly into shootDays via its
        // own live Binding by the time this fires — this call exists purely to trigger
        // updateScene's markDirty() side effect (not exposed directly to this file), so it
        // must use the scene as it now stands, not the `editingScene` snapshot captured
        // back when the sheet was first opened. Passing that stale snapshot was the actual
        // bug: it silently reverted every field — including a changed scene type — right
        // back to whatever it was before the user opened the editor, immediately after
        // SceneEditSheet had just correctly saved the real change.
        let currentScene = shootDays[editingDayIndex].scenes[editingSceneIndex]
        updateScene(currentScene, editingDayId)
    }

    private func clearEditingState() {
        editingScene      = nil
        editingDayId      = nil
        editingDayIndex   = nil
        editingSceneIndex = nil
    }

    private func removeFromDay(_ scene: Scene, dayId: UUID) {
        onBeforeSceneChange()
        removeScene(scene, dayId)
    }

    private func duplicateScene(_ scene: Scene) {
        guard let dayId = shootDays.first(where: { $0.scenes.contains(where: { $0.id == scene.id }) })?.id else { return }
        var dup = scene
        dup.id = UUID()
        onBeforeSceneChange()
        assignScene(dup, shootDays.first(where: { $0.id == dayId })!)
    }

    private func toggleSceneCompleted(_ scene: Scene) {
        let newValue = !scene.isCompleted
        let idsToToggle: Set<UUID> = (selectedSceneIDs.contains(scene.id) && selectedSceneIDs.count > 1)
            ? selectedSceneIDs
            : [scene.id]
        onBeforeSceneChange()
        for id in idsToToggle {
            guard let dayIdx = shootDays.firstIndex(where: { $0.scenes.contains(where: { $0.id == id }) }),
                  let sceneIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == id }) else { continue }
            shootDays[dayIdx].scenes[sceneIdx].isCompleted = newValue
        }
        onSceneChanged()
    }

    private func selectScene(_ scene: Scene, dayId: UUID) {
        if NSEvent.modifierFlags.contains(.command) {
            if selectedSceneIDs.contains(scene.id) {
                selectedSceneIDs.remove(scene.id)
            } else {
                selectedSceneIDs.insert(scene.id)
            }
            lastSelectedSceneID = scene.id
        } else if NSEvent.modifierFlags.contains(.shift), let lastID = lastSelectedSceneID {
            let dayScenes = shootDays.first(where: { $0.id == dayId })?.scenes ?? []
            if let lastIdx = dayScenes.firstIndex(where: { $0.id == lastID }),
               let currentIdx = dayScenes.firstIndex(where: { $0.id == scene.id }) {
                let start = min(lastIdx, currentIdx)
                let end = max(lastIdx, currentIdx)
                for idx in start...end {
                    selectedSceneIDs.insert(dayScenes[idx].id)
                }
            } else {
                selectedSceneIDs = [scene.id]
                lastSelectedSceneID = scene.id
            }
        } else {
            selectedSceneIDs = [scene.id]
            lastSelectedSceneID = scene.id
        }
    }

    private func beginSendToDay(_ scene: Scene) {
        if selectedSceneIDs.contains(scene.id) && selectedSceneIDs.count > 1 {
            sendToDaySceneIDs = Array(selectedSceneIDs)
        } else {
            sendToDaySceneIDs = [scene.id]
        }
        showingSendToDaySheet = true
    }

    private func sendScenes(_ ids: [UUID], toDay targetDayId: UUID) {
        onBeforeSceneChange()
        guard let targetDay = shootDays.first(where: { $0.id == targetDayId }) else { return }
        var scenesToMove: [Scene] = []
        for dIdx in 0..<shootDays.count {
            let matches = shootDays[dIdx].scenes.filter { ids.contains($0.id) }
            scenesToMove.append(contentsOf: matches)
            shootDays[dIdx].scenes.removeAll { ids.contains($0.id) }
        }
        for s in scenesToMove {
            assignScene(s, targetDay)
        }
    }

    private func handleSceneDrop(sceneId: UUID, targetDayId: UUID, targetPosition: Int) {
        onBeforeSceneChange()
        guard let targetDayIndex = shootDays.firstIndex(where: { $0.id == targetDayId }) else { return }

        let idsToMove: [UUID] = selectedSceneIDs.contains(sceneId) && selectedSceneIDs.count > 1
            ? Array(selectedSceneIDs)
            : [sceneId]

        if let sourceDayIndex = shootDays.firstIndex(where: { $0.scenes.contains(where: { $0.id == sceneId }) }) {
            // Dragged from another shoot day or reordering
            var scenesToMove: [Scene] = []
            if sourceDayIndex == targetDayIndex {
                let dayScenes = shootDays[sourceDayIndex].scenes
                let movingSet = Set(idsToMove)
                scenesToMove = dayScenes.filter { movingSet.contains($0.id) }
                var remaining = dayScenes.filter { !movingSet.contains($0.id) }
                let clampedPos = min(targetPosition, remaining.count)
                remaining.insert(contentsOf: scenesToMove, at: clampedPos)
                shootDays[sourceDayIndex].scenes = remaining
            } else {
                for dIdx in 0..<shootDays.count {
                    let matches = shootDays[dIdx].scenes.filter { idsToMove.contains($0.id) }
                    scenesToMove.append(contentsOf: matches)
                    shootDays[dIdx].scenes.removeAll { idsToMove.contains($0.id) }
                }
                let clampedPos = min(targetPosition, shootDays[targetDayIndex].scenes.count)
                shootDays[targetDayIndex].scenes.insert(contentsOf: scenesToMove, at: clampedPos)
            }
            onSceneChanged()
        } else {
            // Dragged from BONEYARD (allScenes)!
            let scenesFromBoneyard = allScenes.filter { idsToMove.contains($0.id) }
            if !scenesFromBoneyard.isEmpty {
                allScenes.removeAll { idsToMove.contains($0.id) }
                let clampedPos = min(targetPosition, shootDays[targetDayIndex].scenes.count)
                shootDays[targetDayIndex].scenes.insert(contentsOf: scenesFromBoneyard, at: clampedPos)
                onSceneChanged()
            }
        }
    }

    private func handleDayRearrange(sourceDayId: UUID, targetDayId: UUID) {
        onBeforeSceneChange()
        guard let srcIdx = shootDays.firstIndex(where: { $0.id == sourceDayId }),
              let dstIdx = shootDays.firstIndex(where: { $0.id == targetDayId }),
              srcIdx != dstIdx else { return }
        let srcScenes    = shootDays[srcIdx].scenes
        let srcCallSheet = shootDays[srcIdx].callSheet
        shootDays[srcIdx].scenes    = shootDays[dstIdx].scenes
        shootDays[srcIdx].callSheet = shootDays[dstIdx].callSheet
        shootDays[dstIdx].scenes    = srcScenes
        shootDays[dstIdx].callSheet = srcCallSheet
        onSceneChanged()
    }

    private func toggleBlackout(_ day: ShootDay) {
        onBeforeSceneChange()
        if let idx = shootDays.firstIndex(where: { $0.id == day.id }) {
            shootDays[idx].isBlackout.toggle()
            onSceneChanged()
        }
    }

    private func toggleBlackoutForWeekday(_ day: ShootDay) {
        onBeforeSceneChange()
        let targetWeekday = Calendar.current.component(.weekday, from: day.date)
        let newValue = !day.isBlackout
        for idx in 0..<shootDays.count {
            if Calendar.current.component(.weekday, from: shootDays[idx].date) == targetWeekday {
                shootDays[idx].isBlackout = newValue
            }
        }
        onSceneChanged()
    }

    // MARK: - Sheets

    @ViewBuilder
    private func editSheetContent() -> some View {
        if let editingDayIndex, let editingSceneIndex,
           editingDayIndex < shootDays.count,
           editingSceneIndex < shootDays[editingDayIndex].scenes.count {
            SceneEditSheet(
                scene: $shootDays[editingDayIndex].scenes[editingSceneIndex],
                isPresented: $showingEditSheet,
                onSave: { saveCurrentSceneEdit() },
                onDelete: {
                    if let dId = editingDayId, let editingScene {
                        removeFromDay(editingScene, dayId: dId)
                    }
                    showingEditSheet = false
                },
                canGoPrevious: editingSceneIndex > 0,
                canGoNext: editingSceneIndex < shootDays[editingDayIndex].scenes.count - 1,
                onPrevious: {
                    if editingSceneIndex > 0 {
                        editScene(dayIndex: editingDayIndex, sceneIndex: editingSceneIndex - 1, scene: shootDays[editingDayIndex].scenes[editingSceneIndex - 1], dayId: shootDays[editingDayIndex].id)
                    }
                },
                onNext: {
                    if editingSceneIndex < shootDays[editingDayIndex].scenes.count - 1 {
                        editScene(dayIndex: editingDayIndex, sceneIndex: editingSceneIndex + 1, scene: shootDays[editingDayIndex].scenes[editingSceneIndex + 1], dayId: shootDays[editingDayIndex].id)
                    }
                },
                positionLabel: "Day \(editingDayIndex + 1), Scene \(editingSceneIndex + 1)"
            )
        }
    }

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
                    onSceneChanged()
                },
                onExportPDF: { exportedDay in
                    callSheetDay = nil
                    onCallSheetExport(exportedDay)
                },
                dayNumber: dayNumbers[day.id],
                totalProductionDays: shootDays.count
            )
        }
    }
}

// MARK: - SceneCardView (Compact single-line horizontal strip for Calendar View)

struct SceneCardView: View {
    let scene: Scene
    let dayId: UUID
    let dayIndex: Int
    let sceneIndex: Int
    @Binding var interactingSceneId: UUID?
    let isSelected:     Bool
    let selectionCount: Int
    let showCast:       Bool
    let showEstTimeOnCards: Bool
    let hasConflict:    Bool
    let hasDuplicateSceneNumber: Bool
    let isOnBlackoutDay: Bool
    let onEdit:      () -> Void
    let onRemove:    () -> Void
    let onDuplicate: () -> Void
    let onToggleCompleted: () -> Void
    let onDragStart: () -> Void
    let onDragEnd:   () -> Void
    let onSelect:    () -> Void
    let onSendToDay: () -> Void
    let dragPayload: () -> String

    private var isDragging: Bool { interactingSceneId == scene.id }
    private var isFlagged: Bool { hasConflict || isOnBlackoutDay }
    private var displayColor: Color {
        if scene.isCalendarEvent {
            return Color(hex: scene.bannerColorHex.isEmpty ? "6366F1" : scene.bannerColorHex)
        }
        return isFlagged ? .red : scene.stripColor
    }

    var body: some View {
        Group {
            if scene.isCalendarEvent {
                HStack(spacing: 4) {
                    let clockStr = scene.customStartTime.isEmpty ? scene.summary : scene.customStartTime
                    if !clockStr.isEmpty {
                        Text(clockStr)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(displayColor)
                        Text("·")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(displayColor.opacity(0.6))
                    }
                    Text(scene.bannerTitle.isEmpty ? scene.title : scene.bannerTitle)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(displayColor.opacity(0.15))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(displayColor.opacity(0.4), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        let numStr = scene.sceneNumber.isEmpty ? "" : "\(scene.sceneNumber). "
                        Text("\(numStr)\(scene.title)")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(scene.stripTextColor)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if hasConflict || isOnBlackoutDay {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.red)
                        }
                        if showEstTimeOnCards {
                            if scene.estimatedTime > 0 {
                                Text(formattedTime(scene.estimatedTime))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(scene.stripTextColor.opacity(0.8))
                            }
                        } else if scene.duration > 0 {
                            Text(formattedEighths(scene.duration))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(scene.stripTextColor.opacity(0.8))
                        }
                    }

                    // Second row: cast, shown when showCast is on (sidebar collapsed, or
                    // the "Show Cast in Calendar" toggle) — showCast already existed as a
                    // parameter here but nothing in this body ever rendered it.
                    if showCast, !scene.cast.isEmpty {
                        Text(scene.cast.joined(separator: ", "))
                            .font(.system(size: 8))
                            .foregroundColor(scene.stripTextColor.opacity(0.75))
                            .italic()
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
                .background(displayColor)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.15), lineWidth: isSelected ? 2 : 0.5)
                )
            }
        }
        .simultaneousGesture(TapGesture(count: 1).onEnded { onSelect() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { onEdit() })
        .contextMenu {
            if scene.isCalendarEvent {
                Button(LocalizationManager.shared.currentLanguage == .spanish ? "Editar Evento" : "Edit Event") { onEdit() }
                Divider()
                Button(LocalizationManager.shared.currentLanguage == .spanish ? "Eliminar Evento" : "Delete Event") { onRemove() }
            } else {
                Button(LocalizationManager.shared.currentLanguage == .spanish ? "Editar Escena" : "Edit Scene") { onEdit() }
                Button(LocalizationManager.shared.currentLanguage == .spanish ? "Duplicar Escena" : "Duplicate Scene") { onDuplicate() }
                Button(LocalizationManager.shared.currentLanguage == .spanish ? "Mover a Día..." : "Move to Day...") { onSendToDay() }
                Divider()
                Button((isSelected && selectionCount > 1)
                       ? "Mark \(selectionCount) Scenes as \(scene.isCompleted ? "Incomplete" : "Completed")"
                       : (scene.isCompleted ? "Mark as Incomplete" : "Mark as Completed")) { onToggleCompleted() }
                Divider()
                Button(LocalizationManager.shared.currentLanguage == .spanish ? "Quitar del Día" : "Remove from Day") { onRemove() }
            }
        }
        .onDrag {
            onDragStart()
            return NSItemProvider(object: dragPayload() as NSString)
        }
        .fastTooltip(scene.tooltipText)
    }
}
