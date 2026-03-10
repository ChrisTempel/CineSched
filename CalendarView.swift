// CalendarView.swift
// Calendar grid with drag-and-drop scene scheduling

import SwiftUI
import UniformTypeIdentifiers

// MARK: - CompactMonthCalendarView

struct CompactMonthCalendarView: View {
    @Binding var shootDays: [ShootDay]
    let assignScene:  (Scene, ShootDay) -> Void
    @Binding var allScenes: [Scene]
    let updateScene:  (Scene, UUID) -> Void
    let removeScene:  (Scene, UUID) -> Void
    let projectTitle: String
    let onSceneChanged: () -> Void

    // Editing state
    @State private var editingScene:      Scene?
    @State private var editingDayId:      UUID?
    @State private var editingDayIndex:   Int?
    @State private var editingSceneIndex: Int?
    @State private var showingEditSheet = false

    // Drag/drop state
    @State private var dropTargetDayId:   UUID?
    @State private var dropTargetPosition: Int?
    @State private var draggedSceneId:    UUID?
    @State private var interactingSceneId: UUID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(shootDays.enumerated()), id: \.element.id) { dayIndex, day in
                    dayCell(day: day, dayIndex: dayIndex)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingEditSheet) {
            editSheetContent()
        }
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing { clearEditingState() }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(day: ShootDay, dayIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate(day.date))
                .font(.caption).bold().foregroundColor(.primary)

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
                            onEdit:      { editScene(dayIndex: dayIndex, sceneIndex: sceneIndex, scene: scene, dayId: day.id) },
                            onRemove:    { removeScene(scene, day.id); onSceneChanged() },
                            onDuplicate: { duplicateScene(scene) },
                            onDragStart: { draggedSceneId = scene.id },
                            onDragEnd:   { draggedSceneId = nil }
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
                        .font(.caption2).foregroundColor(.gray)
                    Text("Est: \(formattedTime(day.totalEstimatedTime))")
                        .font(.caption2).foregroundColor(.gray)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color.gray.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(dropTargetDayId == day.id ? Color.red : Color.black,
                        lineWidth: dropTargetDayId == day.id ? 2 : 1)
        )
        .cornerRadius(8)
        .onDrop(of: [UTType.text.identifier], delegate: DayDropDelegate(
            dayId: day.id,
            scenes: day.scenes,
            dropTargetDayId: $dropTargetDayId,
            dropTargetPosition: $dropTargetPosition,
            onDrop: { sceneId in handleSceneDrop(sceneId: sceneId, targetDayId: day.id, targetPosition: day.scenes.count) }
        ))
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
                    clearEditingState()
                },
                onDelete: {
                    if let id = editingDayId {
                        removeScene(shootDays[dayIndex].scenes[sceneIndex], id)
                        onSceneChanged()
                    }
                    clearEditingState()
                }
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

    private func handleSceneDrop(sceneId: String, targetDayId: UUID, targetPosition: Int) {
        guard let uuid = UUID(uuidString: sceneId) else { return }

        // From Boneyard
        if let idx = allScenes.firstIndex(where: { $0.id == uuid }) {
            let scene = allScenes.remove(at: idx)
            insertSceneIntoDay(scene: scene, dayId: targetDayId, position: targetPosition)
            onSceneChanged()
            return
        }

        // From another (or same) day
        for dayIdx in shootDays.indices {
            if let sceneIdx = shootDays[dayIdx].scenes.firstIndex(where: { $0.id == uuid }) {
                let scene = shootDays[dayIdx].scenes.remove(at: sceneIdx)
                var adjustedPos = targetPosition
                if shootDays[dayIdx].id == targetDayId && sceneIdx < targetPosition { adjustedPos -= 1 }
                insertSceneIntoDay(scene: scene, dayId: targetDayId, position: adjustedPos)
                break
            }
        }
        onSceneChanged()
    }

    private func insertSceneIntoDay(scene: Scene, dayId: UUID, position: Int) {
        guard let dayIdx = shootDays.firstIndex(where: { $0.id == dayId }) else { return }
        let clamped = min(max(0, position), shootDays[dayIdx].scenes.count)
        shootDays[dayIdx].scenes.insert(scene, at: clamped)
    }

    private func duplicateScene(_ scene: Scene) {
        allScenes.append(Scene(
            title: scene.title + " (Copy)",
            duration: scene.duration,
            estimatedTime: scene.estimatedTime,
            dayNightType: scene.dayNightType,
            cast: scene.cast,
            summary: scene.summary
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
}

// MARK: - SceneCardView

struct SceneCardView: View {
    let scene:      Scene
    let dayId:      UUID
    let dayIndex:   Int
    let sceneIndex: Int
    @Binding var interactingSceneId: UUID?
    let onEdit:      () -> Void
    let onRemove:    () -> Void
    let onDuplicate: () -> Void
    let onDragStart: () -> Void
    let onDragEnd:   () -> Void

    private var isDragging: Bool { interactingSceneId == scene.id }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Circle()
                .fill(scene.dayNightType.color)
                .frame(width: 8, height: 8)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.title)
                    .font(.caption2).fontWeight(.medium).lineLimit(2)

                HStack {
                    Text("(\(formattedEighths(scene.duration)), \(formattedTime(scene.estimatedTime)))")
                        .font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text(scene.dayNightType.displayName)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(scene.dayNightType.color)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(scene.dayNightType.color.opacity(isDragging ? 0.3 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(scene.dayNightType.color.opacity(isDragging ? 0.8 : 0.4),
                                lineWidth: isDragging ? 2 : 1)
                )
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .onDrag {
            interactingSceneId = scene.id
            onDragStart()
            return NSItemProvider(object: scene.id.uuidString as NSString)
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
        .onTapGesture(count: 2) { interactingSceneId = nil; onEdit() }
        .onTapGesture(count: 1) { interactingSceneId = nil }
        .contextMenu {
            Button("Edit Scene")       { interactingSceneId = nil; onEdit() }
            Button("Remove from Day")  { interactingSceneId = nil; onRemove() }
            Divider()
            Button("Duplicate Scene")  { interactingSceneId = nil; onDuplicate() }
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

// MARK: - DayDropDelegate

struct DayDropDelegate: DropDelegate {
    let dayId:  UUID
    let scenes: [Scene]
    @Binding var dropTargetDayId:    UUID?
    @Binding var dropTargetPosition: Int?
    let onDrop: (String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }
    func dropEntered(info: DropInfo) {
        if scenes.isEmpty { dropTargetDayId = dayId; dropTargetPosition = 0 }
    }
    func dropExited(info: DropInfo) {
        if dropTargetDayId == dayId && scenes.isEmpty {
            dropTargetDayId = nil; dropTargetPosition = nil
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
