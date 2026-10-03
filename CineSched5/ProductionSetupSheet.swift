// ProductionSetupSheet.swift
// Project-wide production info — company, director, contact number, cast, and crew.
// Filled in once per project; opened from the toolbar.

import SwiftUI

struct ProductionSetupSheet: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Binding var productionInfo: ProductionInfo
    var scenes: [Scene] = []
    @Binding var isPresented: Bool
    let onSave: () -> Void
    /// Called once per renamed character (oldName, newName) when Save is pressed, so the
    /// caller can propagate the rename into every scene's cast list and existing call sheets.
    var onCharacterRenamed: (String, String) -> Void = { _, _ in }

    @State private var companyName:      String = ""
    @State private var directorName:     String = ""
    @State private var directorPhone:    String = ""
    @State private var producerName:     String = ""
    @State private var producerPhone:    String = ""
    @State private var adName:           String = ""
    @State private var adPhone:          String = ""
    @State private var defaultLunchTime: String = "01:30 PM"
    @State private var castList:         [CastMember] = []
    @State private var crew:             [CrewMember] = []
    @State private var locationRoster:   [Location] = []

    @State private var newActorName:          String = ""
    @State private var availabilityEditorIndex: Int? = nil
    @State private var newCharacterName:      String = ""
    @State private var newCrewName:           String = ""
    @State private var newCrewRole:           String = ""
    @State private var newCrewPhone:          String = ""
    @State private var newCrewIsDailyDefault: Bool   = false
    @State private var newLocationName:    String = ""
    @State private var newLocationAddress: String = ""

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Production Setup"))
                        .font(.title2).fontWeight(.bold)
                    Text(L("These details appear on every call sheet"))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Production details
                    Group {
                        Label(L("Production Details"), systemImage: "building.2").font(.headline)
                        LabeledField(L("Production Company"), placeholder: "e.g. Tempel Films", text: $companyName)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Director")).font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                TextField(L("Director name"), text: $directorName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField(L("Phone"), text: $directorPhone)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: 180)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Producer")).font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                TextField(L("Producer name"), text: $producerName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField(L("Phone"), text: $producerPhone)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: 180)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("1st AD (Assistant Director)")).font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                TextField(L("1st AD name"), text: $adName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField(L("Phone"), text: $adPhone)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: 180)
                            }
                        }
                    }

                    Divider()

                    // Cast list
                    Label(L("Cast Roster"), systemImage: "star").font(.headline)

                    if castList.isEmpty {
                        Text(L("No cast added yet.")).font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(castList.enumerated()), id: \.element.id) { index, member in
                            HStack(spacing: 8) {
                                TextField(L("Actor Name"), text: Binding(
                                    get: { castList[index].actorName },
                                    set: { castList[index].actorName = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                TextField(L("Character"), text: Binding(
                                    get: { castList[index].characterName },
                                    set: { castList[index].characterName = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button {
                                    availabilityEditorIndex = index
                                } label: {
                                    let count = castList[index].unavailableRanges.count
                                    HStack(spacing: 3) {
                                        Image(systemName: count > 0 ? "calendar.badge.exclamationmark" : "calendar")
                                        if count > 0 { Text("\(count)").font(.caption2) }
                                    }
                                    .foregroundColor(count > 0 ? .orange : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Set dates this actor is unavailable")
                                .popover(isPresented: Binding(
                                    get: { availabilityEditorIndex == index },
                                    set: { if !$0 { availabilityEditorIndex = nil } }
                                )) {
                                    AvailabilityEditor(ranges: Binding(
                                        get: { castList[index].unavailableRanges },
                                        set: { castList[index].unavailableRanges = $0 }
                                    ), personLabel: castList[index].displayString)
                                }

                                Button { castList.remove(at: index) } label: {
                                    Image(systemName: "minus.circle").foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField(L("Actor Name"), text: $newActorName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField(L("Character"), text: $newCharacterName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button {
                            let actor     = newActorName.trimmingCharacters(in: .whitespaces)
                            let character = newCharacterName.trimmingCharacters(in: .whitespaces)
                            guard !actor.isEmpty || !character.isEmpty else { return }
                            castList.append(CastMember(actorName: actor, characterName: character))
                            newActorName     = ""
                            newCharacterName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            newActorName.trimmingCharacters(in: .whitespaces).isEmpty &&
                            newCharacterName.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                    }

                    Divider()

                    // Crew list
                    Label(L("Crew Roster"), systemImage: "person.3").font(.headline)

                    // Column header
                    HStack {
                        Text(L("Crew Member Name"))
                            .font(.caption).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(L("Role / Department"))
                            .font(.caption).foregroundColor(.secondary)
                            .frame(maxWidth: 120, alignment: .leading)
                        Text(L("Phone"))
                            .font(.caption).foregroundColor(.secondary)
                            .frame(maxWidth: 110, alignment: .leading)
                        Text(L("Daily"))
                            .font(.caption).foregroundColor(.secondary)
                            .frame(width: 44, alignment: .center)
                        Spacer().frame(width: 28)
                    }
                    .padding(.horizontal, 8)

                    if crew.isEmpty {
                        Text(L("No crew added yet.")).font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(crew.enumerated()), id: \.element.id) { index, member in
                            HStack(spacing: 6) {
                                TextField(L("Name"), text: Binding(
                                    get: { crew[index].name },
                                    set: { crew[index].name = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                TextField(L("Role"), text: Binding(
                                    get: { crew[index].role },
                                    set: { crew[index].role = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 120)

                                TextField(L("Phone"), text: Binding(
                                    get: { crew[index].phone },
                                    set: { crew[index].phone = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 110)

                                Toggle("", isOn: Binding(
                                    get: { crew[index].isDailyDefault },
                                    set: { crew[index].isDailyDefault = $0 }
                                ))
                                .toggleStyle(.checkbox)
                                .frame(width: 44, alignment: .center)

                                Button { crew.remove(at: index) } label: {
                                    Image(systemName: "minus.circle").foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 28)
                            }
                            .padding(8)
                            .background(member.isDailyDefault
                                ? Color.blue.opacity(0.07)
                                : Color.gray.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    // Add crew member
                    HStack(spacing: 6) {
                        TextField(L("Crew Member Name"), text: $newCrewName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField(L("Role / Department"), text: $newCrewRole)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 120)
                        TextField(L("Phone"), text: $newCrewPhone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 110)
                        Toggle(L("Daily"), isOn: $newCrewIsDailyDefault)
                            .toggleStyle(.checkbox)
                        Button {
                            let name = newCrewName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            crew.append(CrewMember(
                                name:           name,
                                role:           newCrewRole.trimmingCharacters(in: .whitespaces),
                                phone:          newCrewPhone.trimmingCharacters(in: .whitespaces),
                                isDailyDefault: newCrewIsDailyDefault
                            ))
                            newCrewName           = ""
                            newCrewRole           = ""
                            newCrewPhone          = ""
                            newCrewIsDailyDefault = false
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(newCrewName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Divider()

                    // Location roster
                    HStack {
                        Label(L("Location Roster"), systemImage: "mappin.and.ellipse").font(.headline)
                        Spacer()
                        Button {
                            pullLocationsFromBreakdown()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text(L("Pull from Breakdown"))
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .help("Extract and import all locations from scene breakdown")
                    }

                    if locationRoster.isEmpty {
                        Text(L("No locations added yet.")).font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(locationRoster.enumerated()), id: \.element.id) { index, loc in
                            HStack(spacing: 8) {
                                TextField(L("Location Name"), text: Binding(
                                    get: { locationRoster[index].name },
                                    set: { locationRoster[index].name = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                TextField(L("Address"), text: Binding(
                                    get: { locationRoster[index].address },
                                    set: { locationRoster[index].address = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button { locationRoster.remove(at: index) } label: {
                                    Image(systemName: "minus.circle").foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField(L("Location Name"), text: $newLocationName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField(L("Address"), text: $newLocationAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button {
                            let name = newLocationName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            locationRoster.append(Location(name: name, address: newLocationAddress.trimmingCharacters(in: .whitespaces)))
                            newLocationName = ""; newLocationAddress = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(newLocationName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button(L("Cancel")) { isPresented = false }.buttonStyle(.bordered)
                Spacer()
                Button(L("Save")) {
                    let oldByID = Dictionary(uniqueKeysWithValues: productionInfo.castList.map { ($0.id, $0) })
                    for member in castList {
                        if let old = oldByID[member.id],
                           old.characterName.trimmingCharacters(in: .whitespaces) != member.characterName.trimmingCharacters(in: .whitespaces),
                           !old.characterName.trimmingCharacters(in: .whitespaces).isEmpty,
                           !member.characterName.trimmingCharacters(in: .whitespaces).isEmpty {
                            onCharacterRenamed(old.characterName, member.characterName)
                        }
                    }

                    productionInfo.companyName      = companyName
                    productionInfo.directorName     = directorName
                    productionInfo.directorPhone    = directorPhone
                    productionInfo.producerName     = producerName
                    productionInfo.producerPhone    = producerPhone
                    productionInfo.adName           = adName
                    productionInfo.adPhone          = adPhone
                    productionInfo.defaultLunchTime = defaultLunchTime
                    productionInfo.castList         = castList
                    productionInfo.crew             = crew
                    productionInfo.locationRoster   = locationRoster
                    onSave()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .frame(width: 620, height: 720)
        .onAppear {
            companyName      = productionInfo.companyName
            directorName     = productionInfo.directorName
            directorPhone    = productionInfo.directorPhone
            producerName     = productionInfo.producerName
            producerPhone    = productionInfo.producerPhone
            adName           = productionInfo.adName
            adPhone          = productionInfo.adPhone
            defaultLunchTime = productionInfo.defaultLunchTime
            castList         = productionInfo.castList
            crew             = productionInfo.crew
            locationRoster   = productionInfo.locationRoster

            if locationRoster.isEmpty {
                pullLocationsFromBreakdown()
            }
        }
    }

    private func pullLocationsFromBreakdown() {
        var existingNames = Set(locationRoster.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() })
        for s in scenes where !s.isBanner && !s.isCalendarEvent {
            let locName: String
            let locAddr = s.locationAddress.trimmingCharacters(in: .whitespaces)
            if !s.realLocation.trimmingCharacters(in: .whitespaces).isEmpty {
                locName = s.realLocation.trimmingCharacters(in: .whitespaces)
            } else {
                locName = s.decoradoOnly.trimmingCharacters(in: .whitespaces)
            }
            guard !locName.isEmpty else { continue }
            let key = locName.lowercased()
            if !existingNames.contains(key) {
                existingNames.insert(key)
                locationRoster.append(Location(name: locName, address: locAddr))
            }
        }
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    init(_ label: String, placeholder: String, text: Binding<String>) {
        self.label       = label
        self.placeholder = placeholder
        self._text       = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

/// Popover content for adding/removing the date ranges a cast member is unavailable —
/// feeds both the schedule-wide conflict scan and the live red-strip coloring on the
/// calendar.
private struct AvailabilityEditor: View {
    @Binding var ranges: [DateRange]
    let personLabel: String

    @State private var newStart: Date = Date()
    @State private var newEnd:   Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Unavailable Dates").font(.headline)
            Text(personLabel.isEmpty ? "Unnamed" : personLabel)
                .font(.caption).foregroundColor(.secondary)

            if ranges.isEmpty {
                Text("No dates marked yet.").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(ranges) { range in
                    HStack {
                        Text(rangeLabel(range)).font(.caption)
                        Spacer()
                        Button {
                            ranges.removeAll { $0.id == range.id }
                        } label: {
                            Image(systemName: "minus.circle").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            Text("Add a range").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 8) {
                DatePicker("From", selection: $newStart, displayedComponents: .date)
                    .labelsHidden()
                Text("–")
                DatePicker("To", selection: $newEnd, displayedComponents: .date)
                    .labelsHidden()
                Button {
                    ranges.append(DateRange(start: newStart, end: newEnd))
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func rangeLabel(_ range: DateRange) -> String {
        let cal = Calendar.current
        if cal.isDate(range.start, inSameDayAs: range.end) {
            return formattedDate(range.start)
        }
        return "\(formattedDate(range.start)) – \(formattedDate(range.end))"
    }
}
