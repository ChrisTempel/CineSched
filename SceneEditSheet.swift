// SceneEditSheet.swift
// Modal sheet for editing an existing scene's properties

import SwiftUI

struct SceneEditSheet: View {
    @Binding var scene: Scene
    @Binding var isPresented: Bool
    let onSave:   () -> Void
    let onDelete: () -> Void

    @State private var editTitle:         String      = ""
    @State private var editDuration:      String      = ""
    @State private var editEstimatedTime: String      = ""
    @State private var editDayNightType:  DayNightType = .day
    @State private var editCastText:      String      = ""   // comma-separated editing surface
    @State private var editSummary:       String      = ""

    @State private var durationIsValid:      Bool = true
    @State private var estimatedTimeIsValid: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Scene")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {

                // Title
                Text("Scene Title").font(.headline)
                TextField("Scene Title", text: $editTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration (pages)").font(.headline)
                    TextField(FractionParser.placeholderText, text: $editDuration)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
            }

            HStack(spacing: 16) {
                Button("Delete Scene") {
                    onDelete()
                    isPresented = false
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
        .onAppear { populateFields() }
    }

    // MARK: - Helpers

    private func populateFields() {
        editTitle         = scene.title
        editDuration      = scene.duration > 0 ? FractionParser.formatEighths(scene.duration) : ""
        editEstimatedTime = scene.estimatedTime > 0 ? formatMinutesForEditing(scene.estimatedTime) : ""
        editDayNightType  = scene.dayNightType
        editCastText      = scene.cast.joined(separator: ", ")
        editSummary       = scene.summary
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
    }
}
