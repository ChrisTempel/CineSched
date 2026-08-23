// SceneEditSheet.swift
// Modal sheet for editing an existing scene's properties

import SwiftUI

struct SceneEditSheet: View {
    @Binding var scene: Scene
    @Binding var isPresented: Bool
    let onSave:   () -> Void
    let onDelete: () -> Void

    // Optional Previous/Next navigation — when supplied, arrow buttons appear
    // next to the title so scenes can be edited in sequence without closing the sheet.
    var canGoPrevious: Bool          = false
    var canGoNext:     Bool          = false
    var onPrevious:    (() -> Void)? = nil
    var onNext:        (() -> Void)? = nil
    var positionLabel: String?       = nil
    /// The Breakdown section starts expanded by default so breakdown fields are always directly accessible.
    var breakdownExpandedByDefault: Bool = true
    /// Whether Delete Scene closes the sheet afterward. True everywhere this sheet is
    /// normally used (deleting a single scene you were editing should close it) — false
    /// for the Breakdown Browser, where closing on every delete would kick you out of a
    /// script you might be halfway through tagging, forcing a restart from scene one.
    var closeAfterDelete: Bool = true
    var knownLocations: [String] = []

    @State private var editSceneNumber:     String      = ""
    @State private var editTitle:           String      = ""
    @State private var editRealLocation:    String      = ""
    @State private var editLocationAddress: String      = ""
    @State private var editDuration:        String      = ""
    @State private var editEstimatedTime:   String      = ""
    @State private var editCustomStartTime: String      = ""
    @State private var editDayNightType:    DayNightType = .day
    @State private var editCastText:        String      = ""   // comma-separated editing surface
    @State private var editSummary:         String      = ""

    @State private var breakdownExpanded:      Bool   = true
    @State private var editExtras:             String = ""
    @State private var editProps:              String = ""
    @State private var editSetDressing:        String = ""
    @State private var editWardrobe:           String = ""
    @State private var editMakeupHair:         String = ""
    @State private var editVehicles:           String = ""
    @State private var editSpecialEquipment:   String = ""
    @State private var editStunts:             String = ""
    @State private var editSFX:                String = ""
    @State private var editVFX:                String = ""
    @State private var editBreakdownNotes:     String = ""

    @State private var durationIsValid:      Bool = true
    @State private var estimatedTimeIsValid: Bool = true

    private enum Field: Hashable {
        case title, estimate, cast
    }
    @FocusState private var focusedField: Field?
    @State private var focusDurationTrigger: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    navigate(onPrevious)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .disabled(!canGoPrevious || !isValidInput())
                .help("Previous Scene")
                .opacity(onPrevious == nil ? 0 : 1)

                VStack(spacing: 2) {
                    Text("Edit Scene")
                        .font(.title2)
                        .fontWeight(.semibold)
                    if let positionLabel {
                        Text(positionLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    navigate(onNext)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .disabled(!canGoNext || !isValidInput())
                .help("Next Scene")
                .opacity(onNext == nil ? 0 : 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                // Scene Number & Title
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scene #").font(.headline)
                        TextField("#", text: $editSceneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scene Title").font(.headline)
                        TextField("Scene Title", text: $editTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .title)
                    }
                }

                // Real Location (Set) with Autocomplete
                LocationAutocompleteField(
                    title: "Real Location / Set",
                    placeholder: "e.g. Playa de la Concha, Airport Hangar",
                    text: $editRealLocation,
                    suggestions: knownLocations
                )

                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration (pages)").font(.headline)
                    SelectAllTextField(
                        placeholder: FractionParser.placeholderText,
                        text: $editDuration,
                        focusTrigger: $focusDurationTrigger
                    )
                    .frame(height: 22)
                    .border(durationIsValid ? Color.clear : Color.red, width: 1)
                    .onChange(of: editDuration) { _ in validateDuration() }

                    if !durationIsValid {
                        Text("Invalid format. Use: 15 (eighths), 1 7/8 (mixed), or 7/8 (fraction)")
                            .font(.caption).foregroundColor(.red)
                    } else if let eighths = FractionParser.parseToEighths(editDuration), !editDuration.isEmpty {
                        Text("= \(FractionParser.formatEighths(eighths)) pages (\(eighths) eighths)")
                            .font(.caption).foregroundColor(.secondary)
                    } else if editDayNightType == .custom {
                        Text("Leave blank for no page count")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                // Estimated Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Time").font(.headline)
                    TextField(TimeParser.placeholderText, text: $editEstimatedTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .estimate)
                        .border(estimatedTimeIsValid ? Color.clear : Color.red, width: 1)
                        .onChange(of: editEstimatedTime) { _ in validateEstimatedTime() }

                    if !estimatedTimeIsValid {
                        Text("Invalid format. Use: 4 (4 hours), 15 (15 minutes), or 2:30 (2hr 30min)")
                            .font(.caption).foregroundColor(.red)
                    } else if let hint = TimeParser.getInputHint(editEstimatedTime), !editEstimatedTime.isEmpty {
                        Text(hint).font(.caption).foregroundColor(.secondary)
                    }
                }

                // Cast
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cast").font(.headline)
                    TextField("John, Mary, Bob", text: $editCastText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .cast)
                    Text("Separate names with commas")
                        .font(.caption).foregroundColor(.secondary)
                }

                // Scene Summary
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scene Summary").font(.headline)
                    TextEditor(text: $editSummary)
                        .frame(minHeight: 100)
                        .padding(6)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .cornerRadius(4)
                }

                // Day / Night / Custom
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Type")).font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(DayNightType.allCases, id: \.self) { type in
                            Button {
                                editDayNightType = type
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: editDayNightType == type ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(editDayNightType == type ? .accentColor : .secondary)
                                    Text(L(type.rawValue.uppercased()))
                                        .foregroundColor(editDayNightType == type ? .primary : .secondary)
                                        .fontWeight(editDayNightType == type ? .semibold : .regular)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Breakdown tagging
                DisclosureGroup(isExpanded: $breakdownExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        breakdownField("Extras / Background", text: $editExtras)
                        breakdownField("Props", text: $editProps)
                        breakdownField("Set Dressing", text: $editSetDressing)
                        breakdownField("Wardrobe", text: $editWardrobe)
                        breakdownField("Hair & Makeup", text: $editMakeupHair)
                        breakdownField("Vehicles", text: $editVehicles)
                        breakdownField("Special Equipment", text: $editSpecialEquipment)
                        breakdownField("Stunts", text: $editStunts)
                        breakdownField("SFX", text: $editSFX)
                        breakdownField("VFX", text: $editVFX)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Breakdown Notes").font(.subheadline).foregroundColor(.secondary)
                            TextEditor(text: $editBreakdownNotes)
                                .frame(minHeight: 60)
                                .padding(6)
                                .border(Color.gray.opacity(0.3), width: 1)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Breakdown").font(.headline)
                }
                }
            }
            .frame(maxHeight: 480)

            HStack(spacing: 16) {
                Button("Delete Scene") {
                    onDelete()
                    if closeAfterDelete { isPresented = false }
                }
                .foregroundColor(.red)
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)

                Button("Save Changes") {
                    saveChanges()
                    onSave()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidInput())
            }
        }
        .padding(24)
        .frame(width: 550)
        .onAppear {
            populateFields()
            focusDurationField()
            breakdownExpanded = breakdownExpandedByDefault
        }
        .onChange(of: scene.id) { _ in
            populateFields()
            focusDurationField()
            breakdownExpanded = breakdownExpandedByDefault
        }
    }

    // MARK: - Helpers

    /// Duration is the field users almost always need to correct — even on imported
    /// scenes where every field already has a default value — so focus starts there
    /// instead of landing on whatever the first empty field happens to be.
    private func focusDurationField() {
        DispatchQueue.main.async {
            focusDurationTrigger = true
        }
    }

    /// Saves the current edits (so they aren't lost) and moves to the adjacent scene.
    private func navigate(_ direction: (() -> Void)?) {
        guard let direction, isValidInput() else { return }
        saveChanges()
        onSave()
        direction()
    }

    private func populateFields() {
        var tempScene = scene
        tempScene.autoExtractSceneNumberIfNeeded()
        editSceneNumber      = tempScene.sceneNumber
        editTitle            = tempScene.title
        editRealLocation     = scene.realLocation
        editLocationAddress  = scene.locationAddress
        editDuration         = scene.duration > 0 ? FractionParser.formatEighths(scene.duration) : ""
        editEstimatedTime    = scene.estimatedTime > 0 ? formatMinutesForEditing(scene.estimatedTime) : ""
        editCustomStartTime  = scene.customStartTime
        editDayNightType     = scene.dayNightType
        editCastText         = scene.cast.joined(separator: ", ")
        editSummary          = scene.summary
        editExtras           = scene.extras.joined(separator: ", ")
        editProps            = scene.props.joined(separator: ", ")
        editSetDressing      = scene.setDressing.joined(separator: ", ")
        editWardrobe         = scene.wardrobe.joined(separator: ", ")
        editMakeupHair       = scene.makeupHair.joined(separator: ", ")
        editVehicles         = scene.vehicles.joined(separator: ", ")
        editSpecialEquipment = scene.specialEquipment.joined(separator: ", ")
        editStunts           = scene.stunts.joined(separator: ", ")
        editSFX              = scene.sfx.joined(separator: ", ")
        editVFX              = scene.vfx.joined(separator: ", ")
        editBreakdownNotes   = scene.breakdownNotes
        validateDuration()
        validateEstimatedTime()
    }

    /// Converts a stored minute count back to an editable string (no units suffix).
    private func formatMinutesForEditing(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins  = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours):\(String(format: "%02d", mins))" }
        if hours > 0              { return "\(hours)" }
        return "\(mins)"
    }

    private func validateDuration() {
        durationIsValid = FractionParser.parseToEighths(editDuration) != nil || editDuration.isEmpty
    }

    private func validateEstimatedTime() {
        estimatedTimeIsValid = TimeParser.parseToMinutes(editEstimatedTime) != nil || editEstimatedTime.isEmpty
    }

    private func isValidInput() -> Bool {
        let titleOK = !editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return titleOK && durationIsValid && estimatedTimeIsValid
    }

    private func saveChanges() {
        scene.sceneNumber     = editSceneNumber.trimmingCharacters(in: .whitespaces)
        scene.title           = editTitle
        scene.realLocation    = editRealLocation.trimmingCharacters(in: .whitespaces)
        scene.locationAddress = editLocationAddress.trimmingCharacters(in: .whitespaces)
        scene.dayNightType    = editDayNightType
        scene.cast            = editCastText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        scene.summary         = editSummary
        scene.customStartTime = editCustomStartTime.trimmingCharacters(in: .whitespaces)
        if let d = FractionParser.parseToEighths(editDuration) { scene.duration      = d }
        else if editDayNightType == .custom                     { scene.duration      = 0 }
        if let t = TimeParser.parseToMinutes(editEstimatedTime) { scene.estimatedTime = t }
        else if editDayNightType == .custom                     { scene.estimatedTime = 0 }

        scene.extras           = parseCommaList(editExtras)
        scene.props            = parseCommaList(editProps)
        scene.setDressing      = parseCommaList(editSetDressing)
        scene.wardrobe         = parseCommaList(editWardrobe)
        scene.makeupHair       = parseCommaList(editMakeupHair)
        scene.vehicles         = parseCommaList(editVehicles)
        scene.specialEquipment = parseCommaList(editSpecialEquipment)
        scene.stunts           = parseCommaList(editStunts)
        scene.sfx              = parseCommaList(editSFX)
        scene.vfx              = parseCommaList(editVFX)
        scene.breakdownNotes   = editBreakdownNotes
    }

    private func parseCommaList(_ text: String) -> [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private func breakdownField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            TextField("Comma-separated", text: text).textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}
