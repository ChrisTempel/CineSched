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
    /// The Breakdown section starts collapsed in normal scene editing (keeps a quick
    /// duration/cast tweak fast), but the Breakdown Browser opens it expanded since
    /// tagging is the whole point of that mode.
    var breakdownExpandedByDefault: Bool = false
    /// Whether Delete Scene closes the sheet afterward. True everywhere this sheet is
    /// normally used (deleting a single scene you were editing should close it) — false
    /// for the Breakdown Browser, where closing on every delete would kick you out of a
    /// script you might be halfway through tagging, forcing a restart from scene one.
    var closeAfterDelete: Bool = true

    @State private var editTitle:         String      = ""
    @State private var editDuration:      String      = ""
    @State private var editEstimatedTime: String      = ""
    @State private var editDayNightType:  DayNightType = .day
    @State private var editCastText:      String      = ""   // comma-separated editing surface
    @State private var editSummary:       String      = ""

    @State private var breakdownExpanded:      Bool   = false
    @State private var editExtras:             String = ""
    @State private var editProps:              String = ""
    @State private var editWardrobe:           String = ""
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

                // Title
                Text("Scene Title").font(.headline)
                TextField("Scene Title", text: $editTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .title)

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
                    .onChange(of: editDuration) { validateDuration() }

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
                        .onChange(of: editEstimatedTime) { validateEstimatedTime() }

                    if !estimatedTimeIsValid {
                        Text("Invalid format. Use: 4 (4 hours), 15 (15 minutes), or 2:30 (2hr 30min)")
                            .font(.caption).foregroundColor(.red)
                    } else if let hint = TimeParser.getInputHint(editEstimatedTime), !editEstimatedTime.isEmpty {
                        Text(hint).font(.caption).foregroundColor(.secondary)
                    } else if editDayNightType == .custom {
                        Text("Leave blank for no time estimate")
                            .font(.caption).foregroundColor(.secondary)
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
                    Text("Type").font(.headline)
                    HStack(spacing: 20) {
                        ForEach(DayNightType.allCases, id: \.self) { type in
                            HStack(spacing: 8) {
                                Button {
                                    editDayNightType = type
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: editDayNightType == type ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(editDayNightType == type ? type.color : .secondary)
                                        Text(type == .custom ? "Custom" : type.displayName)
                                            .foregroundColor(editDayNightType == type ? type.color : .primary)
                                            .fontWeight(editDayNightType == type ? .semibold : .regular)
                                    }
                                }
                                .buttonStyle(.plain)

                                Circle()
                                    .fill(type.color)
                                    .frame(width: 12, height: 12)
                                    .opacity(editDayNightType == type ? 1.0 : 0.5)
                            }
                        }
                    }
                }

                Divider()

                // Breakdown tagging
                DisclosureGroup(isExpanded: $breakdownExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        breakdownField("Extras / Background", text: $editExtras)
                        breakdownField("Props", text: $editProps)
                        breakdownField("Wardrobe", text: $editWardrobe)
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
        .onChange(of: scene.id) {
            populateFields()
            focusDurationField()
            breakdownExpanded = breakdownExpandedByDefault
        }
    }

    // MARK: - Helpers

    /// Duration is the field users almost always need to correct — even on imported
    /// scenes where every field already has a default value — so focus starts there
    /// instead of landing on whatever the first empty field happens to be. Using
    /// SelectAllTextField also means the existing value is selected, so typing
    /// immediately replaces it rather than requiring a manual select/delete first.
    /// The dispatch is needed because on macOS a same-frame focus assignment in a
    /// freshly-presented sheet is often dropped.
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
        editTitle         = scene.title
        editDuration      = scene.duration > 0 ? FractionParser.formatEighths(scene.duration) : ""
        editEstimatedTime = scene.estimatedTime > 0 ? formatMinutesForEditing(scene.estimatedTime) : ""
        editDayNightType  = scene.dayNightType
        editCastText      = scene.cast.joined(separator: ", ")
        editSummary       = scene.summary
        editExtras           = scene.extras.joined(separator: ", ")
        editProps            = scene.props.joined(separator: ", ")
        editWardrobe         = scene.wardrobe.joined(separator: ", ")
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
        if editDayNightType == .custom {
            // Custom strips only require a title
            return titleOK && durationIsValid && estimatedTimeIsValid
        }
        let durationOK = (FractionParser.parseToEighths(editDuration) ?? 0) > 0
        let timeOK     = (TimeParser.parseToMinutes(editEstimatedTime) ?? 0) > 0
        return titleOK && durationOK && timeOK
    }

    private func saveChanges() {
        scene.title        = editTitle
        scene.dayNightType = editDayNightType
        scene.cast         = editCastText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        scene.summary      = editSummary
        if let d = FractionParser.parseToEighths(editDuration) { scene.duration      = d }
        else if editDayNightType == .custom                     { scene.duration      = 0 }
        if let t = TimeParser.parseToMinutes(editEstimatedTime) { scene.estimatedTime = t }
        else if editDayNightType == .custom                     { scene.estimatedTime = 0 }

        scene.extras           = parseCommaList(editExtras)
        scene.props            = parseCommaList(editProps)
        scene.wardrobe         = parseCommaList(editWardrobe)
        scene.vehicles         = parseCommaList(editVehicles)
        scene.specialEquipment = parseCommaList(editSpecialEquipment)
        scene.stunts           = parseCommaList(editStunts)
        scene.sfx              = parseCommaList(editSFX)
        scene.vfx               = parseCommaList(editVFX)
        scene.breakdownNotes    = editBreakdownNotes
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
