// NewSceneInputView.swift
// Form for creating a new Scene in the Boneyard sidebar

import SwiftUI

struct NewSceneInputView: View {
    @Binding var newSceneNumber: String
    @Binding var newSceneTitle: String
    @Binding var newDuration:   String
    @Binding var newEstimate:   String
    @Binding var newDayNightType: DayNightType
    @Binding var allScenes:     [Scene]

    @State private var newRealLocation:      String = ""
    @State private var durationIsValid:      Bool = true
    @State private var estimatedTimeIsValid: Bool = true

    var knownLocations: [String] {
        Array(Set(allScenes.map { $0.realLocation }.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TextField("#", text: $newSceneNumber)
                    .frame(width: 60)
                    .help(L("Scene #"))
                TextField(L("Scene Title"), text: $newSceneTitle)
            }

            // Real Location with Autocomplete
            LocationAutocompleteField(
                title: L("Real Location"),
                placeholder: "e.g. Hotel Renaissance, Room 204",
                text: $newRealLocation,
                suggestions: knownLocations
            )

            // Duration field — optional for Custom strips / notice strips
            VStack(alignment: .leading, spacing: 4) {
                TextField(L("Duration (pages)"), text: $newDuration)
                    .onChange(of: newDuration) { _ in validateInputs() }

                if !durationIsValid {
                    Text("Invalid page format. Use: 15, 1 7/8, 7/8")
                        .font(.caption).foregroundColor(.red)
                } else if let eighths = FractionParser.parseToEighths(newDuration), !newDuration.isEmpty {
                    Text("= \(FractionParser.formatEighths(eighths)) pages")
                        .font(.caption).foregroundColor(.secondary)
                } else if newDuration.isEmpty {
                    Text("Leave blank for no page count")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Estimated time field
            VStack(alignment: .leading, spacing: 4) {
                TextField(L("Estimated Time"), text: $newEstimate)
                    .onChange(of: newEstimate) { _ in validateInputs() }

                if !estimatedTimeIsValid {
                    Text("Invalid time format. Use: 4 (hours), 15 (mins), 2:30")
                        .font(.caption).foregroundColor(.red)
                } else if let hint = TimeParser.getInputHint(newEstimate), !newEstimate.isEmpty {
                    Text(hint).font(.caption).foregroundColor(.secondary)
                } else if newEstimate.isEmpty {
                    Text("Leave blank for no time estimate")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Day / Night / Dawn / Dusk / Afternoon / Custom toggle
            VStack(alignment: .leading, spacing: 4) {
                Text("\(L("Type")):").font(.caption).foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(DayNightType.allCases, id: \.self) { type in
                        Button {
                            newDayNightType = type
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: newDayNightType == type ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(newDayNightType == type ? .accentColor : .secondary)
                                    .font(.caption)
                                Text(L(type.rawValue.uppercased()))
                                    .font(.caption)
                                    .foregroundColor(newDayNightType == type ? .primary : .secondary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(L("Add Scene")) {
                addScene()
            }
            .disabled(!canAddScene())
        }
    }

    private func validateInputs() {
        durationIsValid = newDuration.isEmpty || FractionParser.parseToEighths(newDuration) != nil
        estimatedTimeIsValid = newEstimate.isEmpty || TimeParser.parseToMinutes(newEstimate) != nil
    }

    private func canAddScene() -> Bool {
        guard !newSceneTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return durationIsValid && estimatedTimeIsValid
    }

    private func addScene() {
        let duration = FractionParser.parseToEighths(newDuration) ?? 0
        let estimatedTime: Int
        if let explicitMinutes = TimeParser.parseToMinutes(newEstimate) {
            estimatedTime = explicitMinutes
        } else if duration > 0 {
            estimatedTime = TimeParser.estimatedMinutes(forEighths: duration)
        } else {
            estimatedTime = 0
        }

        allScenes.append(Scene(
            title:         newSceneTitle,
            sceneNumber:   newSceneNumber,
            duration:      duration,
            estimatedTime: estimatedTime,
            dayNightType:  newDayNightType,
            realLocation:  newRealLocation
        ))

        newSceneNumber  = ""
        newSceneTitle   = ""
        newDuration     = ""
        newEstimate     = ""
        newRealLocation = ""
        newDayNightType = .day
    }
}
