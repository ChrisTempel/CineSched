// CallSheetEditor.swift
// Per-day call sheet editor with basecamp location, scene numbers per actor,
// cast calls, crew calls, weather, meal milestones, locations, and general notes.

import SwiftUI

struct CallSheetEditor: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @AppStorage("CineSchedTheme") private var currentTheme: AppTheme = .blue
    @Environment(\.colorScheme) private var colorScheme
    @Binding var shootDay: ShootDay
    let productionInfo: ProductionInfo
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onExportPDF: (ShootDay) -> Void
    let dayNumber: Int?
    let totalProductionDays: Int

    private enum EditorSection: String, CaseIterable {
        case general   = "General & Schedule"
        case weather   = "Weather"
        case locations = "Locations"
        case cast      = "Cast"
        case crew      = "Crew"
        case notes     = "General Notes"
    }

    @State private var currentSection: EditorSection = .general

    // General & Milestones
    @State private var generalCallTime:  String = ""
    @State private var workDaySchedule:  String = ""
    @State private var quoteOfTheDay:    String = ""
    @State private var readyToShootTime: String = ""
    @State private var lunchTime:        String = ""
    @State private var snackTime:        String = ""
    @State private var dinnerTime:       String = ""
    @State private var wrapTime:         String = ""
    @State private var nearestHospital:  String = ""

    // Weather
    @State private var weatherTemp:       String = ""
    @State private var weatherCondition:  String = ""
    @State private var weatherPrecipWind: String = ""
    @State private var sunTimes:          String = ""

    // Locations & Basecamp
    @State private var basecampLocation:   String = ""
    @State private var locations: [Location] = []
    @State private var newLocationName:    String = ""
    @State private var newLocationAddress: String = ""

    // Cast Call
    @State private var castCallEntries: [CastCallEntry] = []
    @State private var newCastCharacter: String = ""
    @State private var newCastActor:     String = ""

    // Crew Call
    @State private var crewCallEntries: [CrewCallEntry] = []
    @State private var newCrewRole:     String = ""
    @State private var newCrewName:     String = ""
    @State private var newCrewCallTime: String = ""
    @State private var newCrewPhone:    String = ""

    // Unified General Notes
    @State private var generalObservations: String = ""

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(dayNumber != nil ? "\(L("Call Sheet")) #\(String(format: "%02d", dayNumber!))" : L("Call Sheet"))
                            .font(.title2).fontWeight(.bold)
                        if let dayNumber {
                            Text("\(L("Day")) \(dayNumber) \(L("of")) \(totalProductionDays)")
                                .font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
                        }
                    }
                    Text(formattedFullDate(shootDay.date)).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            // Section Picker
            Picker("", selection: $currentSection) {
                ForEach(EditorSection.allCases, id: \.self) { section in
                    Text(L(section.rawValue)).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch currentSection {
                    case .general:
                        generalAndMilestonesView
                    case .weather:
                        weatherView
                    case .locations:
                        locationsView
                    case .cast:
                        castCallTableView
                    case .crew:
                        crewCallTableView
                    case .notes:
                        productionNotesView
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Button(L("Export PDF")) {
                    saveToDay()
                    onExportPDF(shootDay)
                }
                .buttonStyle(.bordered)
                .help("Generates a clean call sheet PDF")

                Spacer()

                Button(L("Cancel")) { isPresented = false }
                    .buttonStyle(.bordered)

                Button(L("Save")) {
                    saveToDay()
                    onSave()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 780, height: 750)
        .onAppear { populateFields() }
    }

    // MARK: - Section 1: General & Schedule

    // MARK: - Section 1: General & Schedule

    private var generalAndMilestonesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("General Call & Schedule"), systemImage: "clock.badge.checkmark").font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("General Call (12h)")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 07:30 AM", text: $generalCallTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Estimated Schedule")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 07:30 AM to 09:30 PM", text: $workDaySchedule)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("Quote of the day")).font(.subheadline).foregroundColor(.secondary)
                TextField("e.g. \"Every great film begins with a great schedule.\"", text: $quoteOfTheDay)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Divider()

            Label(L("Milestones & Meal Times (12h format)"), systemImage: "timer").font(.headline)
            Text(L("Set ready time, meals, and estimated wrap time."))
                .font(.caption).foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(L("Ready to Shoot (On Set):")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 08:00 AM", text: $readyToShootTime).textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(L("Lunch:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 01:30 PM", text: $lunchTime).textFieldStyle(RoundedBorderTextFieldStyle())
                }
                GridRow {
                    Text(L("Snack:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 05:00 PM", text: $snackTime).textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(L("Dinner:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 08:30 PM", text: $dinnerTime).textFieldStyle(RoundedBorderTextFieldStyle())
                }
                GridRow {
                    Text(L("Wrap / Fin de Rodaje:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 09:30 PM", text: $wrapTime).textFieldStyle(RoundedBorderTextFieldStyle())
                    Spacer()
                    Spacer()
                }
            }

            Divider()

            Label(L("Nearest Hospital"), systemImage: "cross.case").font(.headline)
            TextField("Hospital name, address, emergency phone number", text: $nearestHospital)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // MARK: - Section 2: Weather

    private var weatherView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("Weather Forecast & Sun Times"), systemImage: "cloud.sun").font(.headline)
            Text(L("Fill in weather details for this day. Left blank if not needed."))
                .font(.caption).foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(L("Temperature:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. 68°F - 55°F / 15°C - 12°C", text: $weatherTemp).textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(L("Sky Condition:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. Partly cloudy", text: $weatherCondition).textFieldStyle(RoundedBorderTextFieldStyle())
                }
                GridRow {
                    Text(L("Precipitation & Wind:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. Rain: 10%, Wind: 10 km/h", text: $weatherPrecipWind).textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(L("Sunrise / Sunset:")).font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. SUNRISE: 06:45 AM / SUNSET: 07:30 PM", text: $sunTimes).textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }

    // MARK: - Section 3: Locations & Basecamp

    private var locationsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Basecamp section
            VStack(alignment: .leading, spacing: 4) {
                Label(L("Basecamp Location / Address"), systemImage: "tent").font(.headline)
                TextField("e.g. Parking Basecamp — 123 Studio Way, Lot B", text: $basecampLocation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text(L("Appears prominently on the call sheet above the hospital."))
                    .font(.caption).foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Label(L("Today's Shooting Locations"), systemImage: "mappin.and.ellipse").font(.headline)
                Spacer()
                if !availableRosterLocations.isEmpty {
                    Menu(L("+ Add from Roster")) {
                        ForEach(availableRosterLocations) { loc in
                            Button(loc.name) {
                                locations.append(loc)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Each location is assigned a number (LOC 1, LOC 2...) and appears on scene breakdown.")
                .font(.caption).foregroundColor(.secondary)

            if locations.isEmpty {
                Text("No locations added for this day yet.").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(Array(locations.enumerated()), id: \.element.id) { index, loc in
                    HStack(alignment: .top, spacing: 10) {
                        Text("LOC \(index + 1)")
                            .font(.caption).fontWeight(.bold).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.blue)
                            .cornerRadius(4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.name.isEmpty ? "Unnamed Location" : loc.name).fontWeight(.medium)
                            if !loc.address.isEmpty {
                                Text(loc.address).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button { locations.remove(at: index) } label: {
                            Image(systemName: "minus.circle").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(6)
                }
            }

            // New manual location
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a new location for today:").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    TextField("Location name (e.g. Airport Hangar)", text: $newLocationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Address (e.g. 123 Runway St, City)", text: $newLocationAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button {
                        let name = newLocationName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        locations.append(Location(name: name, address: newLocationAddress.trimmingCharacters(in: .whitespaces)))
                        newLocationName = ""; newLocationAddress = ""
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(newLocationName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.top, 8)
        }
    }

    private var availableRosterLocations: [Location] {
        let addedNames = Set(locations.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() })
        return productionInfo.locationRoster.filter {
            !addedNames.contains($0.name.trimmingCharacters(in: .whitespaces).lowercased())
        }
    }

    // MARK: - Section 4: Cast

    private var castCallTableView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L("Cast Call Times"), systemImage: "person.crop.rectangle.stack").font(.headline)
                Spacer()
                Button(L("+ Auto-populate from Scenes")) {
                    populateCastFromScenes()
                }
                .buttonStyle(.bordered)
                .help("Pulls all characters scheduled today with their assigned actors and scene numbers")
            }

            // Table Header
            HStack(spacing: 4) {
                Text(L("CHARACTER")).font(.caption2).fontWeight(.bold).frame(width: 85, alignment: .leading)
                Text(L("ACTOR/ACTRESS")).font(.caption2).fontWeight(.bold).frame(width: 105, alignment: .leading)
                Text(L("SCENES")).font(.caption2).fontWeight(.bold).frame(width: 55, alignment: .center)
                Text(L("STATUS")).font(.caption2).fontWeight(.bold).frame(width: 38, alignment: .center)
                Text(L("PICK UP")).font(.caption2).fontWeight(.bold).frame(width: 60, alignment: .center)
                Text(L("H/MU")).font(.caption2).fontWeight(.bold).frame(width: 60, alignment: .center)
                Text(L("ON SET")).font(.caption2).fontWeight(.bold).frame(width: 60, alignment: .center)
                Text(L("WRAP")).font(.caption2).fontWeight(.bold).frame(width: 60, alignment: .center)
                Text(L("LOC")).font(.caption2).fontWeight(.bold).frame(width: 34, alignment: .center)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(4)

            if castCallEntries.isEmpty {
                Text(L("No cast members listed. Click 'Auto-populate from Scenes' or add one below."))
                    .font(.caption).foregroundColor(.secondary).padding(.vertical, 8)
            } else {
                ForEach(Array(castCallEntries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 4) {
                        TextField(L("CHARACTER"), text: Binding(
                            get: { castCallEntries[index].characterName },
                            set: { castCallEntries[index].characterName = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 85)

                        TextField(L("ACTOR"), text: Binding(
                            get: { castCallEntries[index].actorName },
                            set: { castCallEntries[index].actorName = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 105)

                        TextField("1, 4", text: Binding(
                            get: { castCallEntries[index].sceneNumbers },
                            set: { castCallEntries[index].sceneNumbers = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 55)

                        TextField("E", text: Binding(
                            get: { castCallEntries[index].ecdt },
                            set: { castCallEntries[index].ecdt = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 38)

                        TextField("07:00 AM", text: Binding(
                            get: { castCallEntries[index].pickupTime },
                            set: { castCallEntries[index].pickupTime = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)

                        TextField("07:30 AM", text: Binding(
                            get: { castCallEntries[index].hmuWardrobeTime },
                            set: { castCallEntries[index].hmuWardrobeTime = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)

                        TextField("08:00 AM", text: Binding(
                            get: { castCallEntries[index].onSetTime },
                            set: { castCallEntries[index].onSetTime = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)

                        TextField("09:30 PM", text: Binding(
                            get: { castCallEntries[index].wrapTime },
                            set: { castCallEntries[index].wrapTime = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)

                        TextField("1", text: Binding(
                            get: { castCallEntries[index].locationIndex },
                            set: { castCallEntries[index].locationIndex = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 34)

                        Button { castCallEntries.remove(at: index) } label: {
                            Image(systemName: "minus.circle").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Add Cast Member
            HStack(spacing: 8) {
                TextField(L("Character"), text: $newCastCharacter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField(L("Actor Name"), text: $newCastActor)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button {
                    let char = newCastCharacter.trimmingCharacters(in: .whitespaces)
                    guard !char.isEmpty else { return }
                    
                    let scenesForChar = shootDay.scenes.filter { scene in
                        scene.cast.contains(where: { $0.caseInsensitiveCompare(char) == .orderedSame })
                    }.map { $0.extractedSceneNumber }.joined(separator: ", ")

                    castCallEntries.append(CastCallEntry(
                        characterName: char,
                        actorName: newCastActor.trimmingCharacters(in: .whitespaces),
                        sceneNumbers: scenesForChar,
                        ecdt: "E",
                        pickupTime: "",
                        hmuWardrobeTime: "",
                        onSetTime: readyToShootTime.isEmpty ? generalCallTime : readyToShootTime,
                        wrapTime: dinnerTime,
                        locationIndex: "1"
                    ))
                    newCastCharacter = ""; newCastActor = ""
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newCastCharacter.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 6)
        }
    }

    private func populateCastFromScenes() {
        let chars = shootDay.allCast
        for char in chars {
            let matchedActor = productionInfo.castList.first(where: {
                $0.characterName.caseInsensitiveCompare(char) == .orderedSame
            })?.actorName ?? ""

            let scenesForChar = shootDay.scenes.filter { scene in
                scene.cast.contains(where: { $0.caseInsensitiveCompare(char) == .orderedSame })
            }.map { $0.extractedSceneNumber }.joined(separator: ", ")

            if let existingIdx = castCallEntries.firstIndex(where: { $0.characterName.caseInsensitiveCompare(char) == .orderedSame }) {
                if castCallEntries[existingIdx].sceneNumbers.isEmpty {
                    castCallEntries[existingIdx].sceneNumbers = scenesForChar
                }
                if castCallEntries[existingIdx].actorName.isEmpty {
                    castCallEntries[existingIdx].actorName = matchedActor
                }
            } else {
                castCallEntries.append(CastCallEntry(
                    characterName: char,
                    actorName: matchedActor,
                    sceneNumbers: scenesForChar,
                    ecdt: "E",
                    pickupTime: "",
                    hmuWardrobeTime: "",
                    onSetTime: readyToShootTime.isEmpty ? generalCallTime : readyToShootTime,
                    wrapTime: dinnerTime,
                    locationIndex: "1"
                ))
            }
        }
    }

    // MARK: - Section 5: Crew

    private var crewCallTableView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L("CREW CALL TIMES"), systemImage: "person.3").font(.headline)
                Spacer()
                Button(L("Load Crew from Setup")) {
                    populateCrewFromProductionInfo()
                }
                .buttonStyle(.bordered)
                .help("Loads all crew members from Production Setup with their roles and phone numbers")
            }

            // Table Header
            HStack(spacing: 6) {
                Text(L("DEPARTMENT / ROLE")).font(.caption2).fontWeight(.bold).frame(width: 140, alignment: .leading)
                Text(L("NAME")).font(.caption2).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                Text(L("CALL TIME")).font(.caption2).fontWeight(.bold).frame(width: 95, alignment: .leading)
                Text(L("PHONE")).font(.caption2).fontWeight(.bold).frame(width: 110, alignment: .leading)
                Spacer().frame(width: 24)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(4)

            if crewCallEntries.isEmpty {
                Text("No crew members added yet. Click 'Load Crew from Setup' or add one below.")
                    .font(.caption).foregroundColor(.secondary).padding(.vertical, 8)
            } else {
                ForEach(Array(crewCallEntries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 6) {
                        TextField("Role (e.g. DP)", text: Binding(
                            get: { crewCallEntries[index].role },
                            set: { crewCallEntries[index].role = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 140)

                        TextField("Name", text: Binding(
                            get: { crewCallEntries[index].name },
                            set: { crewCallEntries[index].name = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("07:30 AM", text: Binding(
                            get: { crewCallEntries[index].callTime },
                            set: { crewCallEntries[index].callTime = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 95)

                        TextField("Phone", text: Binding(
                            get: { crewCallEntries[index].phone },
                            set: { crewCallEntries[index].phone = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 110)

                        Button { crewCallEntries.remove(at: index) } label: {
                            Image(systemName: "minus.circle").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Add crew member
            HStack(spacing: 6) {
                TextField("Role / Function", text: $newCrewRole)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 140)
                TextField("Name", text: $newCrewName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Call Time", text: $newCrewCallTime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 95)
                TextField("Phone", text: $newCrewPhone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 110)
                Button {
                    let role = newCrewRole.trimmingCharacters(in: .whitespaces)
                    let name = newCrewName.trimmingCharacters(in: .whitespaces)
                    guard !role.isEmpty || !name.isEmpty else { return }
                    crewCallEntries.append(CrewCallEntry(
                        role: role,
                        name: name,
                        callTime: newCrewCallTime.isEmpty ? generalCallTime : newCrewCallTime,
                        phone: newCrewPhone.trimmingCharacters(in: .whitespaces)
                    ))
                    newCrewRole = ""; newCrewName = ""; newCrewCallTime = ""; newCrewPhone = ""
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newCrewRole.trimmingCharacters(in: .whitespaces).isEmpty && newCrewName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 6)
        }
    }

    private func populateCrewFromProductionInfo() {
        for member in productionInfo.crew {
            if !crewCallEntries.contains(where: { $0.name.caseInsensitiveCompare(member.name) == .orderedSame && $0.role.caseInsensitiveCompare(member.role) == .orderedSame }) {
                crewCallEntries.append(CrewCallEntry(
                    role: member.role,
                    name: member.name,
                    callTime: generalCallTime.isEmpty ? "07:30 AM" : generalCallTime,
                    phone: member.phone
                ))
            }
        }
    }

    // MARK: - Section 6: General Notes (Unified)

    private var productionNotesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("General Notes", systemImage: "note.text").font(.headline)
            Text("Write all production notes and instructions in a single unified text block.")
                .font(.caption).foregroundColor(.secondary)

            TextEditor(text: $generalObservations)
                .font(.body)
                .frame(minHeight: 180)
                .padding(6)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Populate / Save

    private func populateFields() {
        generalCallTime    = shootDay.callSheet.generalCallTime
        workDaySchedule    = shootDay.callSheet.workDaySchedule
        quoteOfTheDay      = shootDay.callSheet.quoteOfTheDay
        readyToShootTime   = shootDay.callSheet.readyToShootTime
        lunchTime          = shootDay.callSheet.lunchTime.isEmpty ? productionInfo.defaultLunchTime : shootDay.callSheet.lunchTime
        snackTime          = shootDay.callSheet.snackTime
        dinnerTime         = shootDay.callSheet.dinnerTime
        wrapTime           = shootDay.callSheet.wrapTime
        nearestHospital    = shootDay.callSheet.nearestHospital
        basecampLocation   = shootDay.callSheet.basecampLocation

        weatherTemp       = shootDay.callSheet.weatherTemp
        weatherCondition  = shootDay.callSheet.weatherCondition
        weatherPrecipWind = shootDay.callSheet.weatherPrecipWind
        sunTimes          = shootDay.callSheet.sunTimes

        locations = shootDay.callSheet.locations

        // Auto-extract distinct realLocations from today's scenes (no duplicates)
        for scene in shootDay.scenes {
            let locName = scene.realLocation.trimmingCharacters(in: .whitespaces)
            guard !locName.isEmpty else { continue }
            if !locations.contains(where: { $0.name.caseInsensitiveCompare(locName) == .orderedSame }) {
                let matchedAddress = productionInfo.locationRoster.first(where: {
                    $0.name.caseInsensitiveCompare(locName) == .orderedSame
                })?.address ?? scene.locationAddress
                locations.append(Location(name: locName, address: matchedAddress))
            }
        }

        if locations.isEmpty && !productionInfo.locationRoster.isEmpty {
            locations = [productionInfo.locationRoster.first!]
        }

        castCallEntries   = shootDay.callSheet.castCallEntries
        if castCallEntries.isEmpty {
            populateCastFromScenes()
        } else {
            // Update sceneNumbers for existing entries
            for i in 0..<castCallEntries.count {
                let char = castCallEntries[i].characterName
                let scenesForChar = shootDay.scenes.filter { scene in
                    scene.cast.contains(where: { $0.caseInsensitiveCompare(char) == .orderedSame })
                }.map { $0.extractedSceneNumber }.joined(separator: ", ")
                if castCallEntries[i].sceneNumbers.isEmpty {
                    castCallEntries[i].sceneNumbers = scenesForChar
                }
            }
        }

        crewCallEntries = shootDay.callSheet.crewCallEntries
        if crewCallEntries.isEmpty && !productionInfo.crew.isEmpty {
            populateCrewFromProductionInfo()
        } else {
            // Fill in missing names and phone numbers from productionInfo.crew if they were added later
            for i in 0..<crewCallEntries.count {
                if let matched = productionInfo.crew.first(where: {
                    $0.role.caseInsensitiveCompare(crewCallEntries[i].role) == .orderedSame
                }) {
                    if crewCallEntries[i].name.trimmingCharacters(in: .whitespaces).isEmpty {
                        crewCallEntries[i].name = matched.name
                    }
                    if crewCallEntries[i].phone.trimmingCharacters(in: .whitespaces).isEmpty {
                        crewCallEntries[i].phone = matched.phone
                    }
                }
            }
        }

        if !shootDay.callSheet.notes.isEmpty {
            generalObservations = shootDay.callSheet.notes
        } else if !shootDay.callSheet.productionNotes.isEmpty {
            generalObservations = shootDay.callSheet.productionNotes.joined(separator: "\n")
        }
    }

    private func saveToDay() {
        shootDay.callSheet.generalCallTime    = generalCallTime
        shootDay.callSheet.workDaySchedule    = workDaySchedule
        shootDay.callSheet.quoteOfTheDay      = quoteOfTheDay
        shootDay.callSheet.readyToShootTime   = readyToShootTime
        shootDay.callSheet.lunchTime          = lunchTime
        shootDay.callSheet.snackTime          = snackTime
        shootDay.callSheet.dinnerTime         = dinnerTime
        shootDay.callSheet.wrapTime           = wrapTime
        shootDay.callSheet.basecampLocation   = basecampLocation
        shootDay.callSheet.nearestHospital    = nearestHospital
        shootDay.callSheet.weatherTemp        = weatherTemp
        shootDay.callSheet.weatherCondition   = weatherCondition
        shootDay.callSheet.weatherPrecipWind  = weatherPrecipWind
        shootDay.callSheet.sunTimes           = sunTimes
        shootDay.callSheet.locations          = locations
        shootDay.callSheet.castCallEntries    = castCallEntries
        shootDay.callSheet.crewCallEntries    = crewCallEntries
        shootDay.callSheet.notes              = generalObservations
        shootDay.callSheet.productionNotes    = generalObservations.isEmpty ? [] : generalObservations.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
