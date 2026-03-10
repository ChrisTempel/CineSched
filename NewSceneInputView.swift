// NewSceneInputView.swift
// Sidebar form for manually creating and adding a new scene to the Boneyard

import SwiftUI

struct NewSceneInputView: View {
    @Binding var newSceneTitle: String
    @Binding var newDuration:   String
    @Binding var newEstimate:   String
    @Binding var allScenes:     [Scene]
    let onSceneAdded: () -> Void

    @State private var durationIsValid:      Bool         = true
    @State private var estimatedTimeIsValid: Bool         = true
    @State private var newDayNightType:      DayNightType = .day

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Scene").font(.headline)

            TextField("Scene Title", text: $newSceneTitle)

            // Duration field
            VStack(alignment: .leading, spacing: 4) {
                TextField(FractionParser.placeholderText, text: $newDuration)
                    .border(durationIsValid ? Color.clear : Color.red, width: 1)
                    .onChange(of: newDuration) { validateDuration() }

                if !durationIsValid && !newDuration.isEmpty {
                    Text("Invalid format")
                        .font(.caption).foregroundColor(.red)
                } else if let eighths = FractionParser.parseToEighths(newDuration), !newDuration.isEmpty {
                    Text("= \(FractionParser.formatEighths(eighths)) pages")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Time field
            VStack(alignment: .leading, spacing: 4) {
                TextField(TimeParser.placeholderText, text: $newEstimate)
                    .border(estimatedTimeIsValid ? Color.clear : Color.red, width: 1)
                    .onChange(of: newEstimate) { validateEstimatedTime() }

                if !estimatedTimeIsValid && !newEstimate.isEmpty {
                    Text("Invalid time format")
                        .font(.caption).foregroundColor(.red)
                } else if let hint = TimeParser.getInputHint(newEstimate), !newEstimate.isEmpty {
                    Text(hint).font(.caption).foregroundColor(.secondary)
                }
            }

            // Day / Night toggle
            HStack(spacing: 15) {
                Text("Time:").font(.caption).foregroundColor(.secondary)

                ForEach(DayNightType.allCases, id: \.self) { type in
                    Button {
                        newDayNightType = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: newDayNightType == type ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(newDayNightType == type ? type.color : .secondary)
                                .font(.caption)
                            Text(type.displayName)
                                .font(.caption)
                                .foregroundColor(newDayNightType == type ? type.color : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Add Scene") { addScene() }
                .disabled(!canAddScene())
                .padding(.top, 5)
        }
    }

    // MARK: - Helpers

    private func validateDuration() {
        durationIsValid = FractionParser.parseToEighths(newDuration) != nil || newDuration.isEmpty
    }

    private func validateEstimatedTime() {
        estimatedTimeIsValid = TimeParser.parseToMinutes(newEstimate) != nil || newEstimate.isEmpty
    }

    private func canAddScene() -> Bool {
        let titleOK    = !newSceneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let durationOK = (FractionParser.parseToEighths(newDuration) ?? 0) > 0
        let timeOK     = (TimeParser.parseToMinutes(newEstimate) ?? 0) > 0
        return titleOK && durationOK && timeOK
    }

    private func addScene() {
        guard let duration = FractionParser.parseToEighths(newDuration),
              let estimate = TimeParser.parseToMinutes(newEstimate),
              !newSceneTitle.isEmpty else { return }

        allScenes.append(Scene(
            title:         newSceneTitle,
            duration:      duration,
            estimatedTime: estimate,
            dayNightType:  newDayNightType
        ))

        newSceneTitle   = ""
        newDuration     = ""
        newEstimate     = ""
        newDayNightType = .day
        onSceneAdded()
    }
}
