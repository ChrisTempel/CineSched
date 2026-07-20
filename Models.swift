// Models.swift
// Core data models for CineSched

import SwiftUI

// MARK: - DayNightType

enum DayNightType: String, Codable, CaseIterable {
    case day    = "DAY"
    case night  = "NIGHT"
    case custom = "CUSTOM"

    var color: Color {
        switch self {
        case .day:    return Color.orange
        case .night:  return Color.blue
        case .custom: return Color.red
        }
    }

    var displayName: String { rawValue }
}

// MARK: - Scene

struct Scene: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var duration: Int
    var estimatedTime: Int
    var dayNightType: DayNightType
    var cast: [String]
    var summary: String

    init(
        title: String,
        duration: Int,
        estimatedTime: Int,
        dayNightType: DayNightType = .day,
        cast: [String] = [],
        summary: String = ""
    ) {
        self.id            = UUID()
        self.title         = title
        self.duration      = duration
        self.estimatedTime = estimatedTime
        self.dayNightType  = dayNightType
        self.cast          = cast
        self.summary       = summary
    }

    enum CodingKeys: String, CodingKey {
        case id, title, duration, estimatedTime, dayNightType, cast, summary
    }

    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,         forKey: .id)
        title         = try c.decode(String.self,       forKey: .title)
        duration      = try c.decode(Int.self,          forKey: .duration)
        estimatedTime = try c.decode(Int.self,          forKey: .estimatedTime)
        dayNightType  = try c.decode(DayNightType.self, forKey: .dayNightType)
        summary       = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        if let array = try? c.decode([String].self, forKey: .cast) {
            cast = array
        } else if let legacy = try? c.decode(String.self, forKey: .cast) {
            cast = legacy.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            cast = []
        }
    }
}

// MARK: - Location

struct Location: Identifiable, Codable, Hashable {
    let id: UUID
    var name:    String
    var address: String

    init(name: String = "", address: String = "") {
        self.id      = UUID()
        self.name    = name
        self.address = address
    }
}

// MARK: - CallSheetData

struct CallSheetData: Codable {
    var generalCallTime: String
    var locations:       [Location]
    var castOverride:    [String]?       // raw character names (NOT resolved "Actor — Character" text) so
                                          // renaming an actor or character always re-resolves correctly,
                                          // even for a day whose cast list was manually edited
    var crewOverride:    [String]?       // legacy, pre-3.4 saves only — mixed roster display-strings and
                                          // one-off names together; kept so old project files still decode
    var crewIDOverride:  [UUID]?         // roster CrewMember IDs explicitly selected for this day — an ID
                                          // reference instead of frozen text, so a roster rename ripples
                                          // through automatically
    var crewOneOffs:     [String]?       // free-typed crew not in the roster; these have no stable identity
                                          // to rename, so they're just kept as plain text
    var notes:           String

    init(
        generalCallTime: String     = "",
        locations:       [Location] = [],
        castOverride:    [String]?  = nil,
        crewOverride:    [String]?  = nil,
        crewIDOverride:  [UUID]?    = nil,
        crewOneOffs:     [String]?  = nil,
        notes:           String    = ""
    ) {
        self.generalCallTime = generalCallTime
        self.locations       = locations
        self.castOverride    = castOverride
        self.crewOverride    = crewOverride
        self.crewIDOverride  = crewIDOverride
        self.crewOneOffs     = crewOneOffs
        self.notes           = notes
    }

    /// Resolves the raw character names (auto-pulled from scenes, or the manually-edited
    /// override) to "Actor — Character" using the *current* cast list — always live, so a
    /// rename in Production Setup is reflected immediately, whether or not this day's cast
    /// has ever been manually edited.
    func resolvedCast(from scenes: [Scene], productionInfo: ProductionInfo? = nil) -> [String] {
        let characters = castOverride ?? Array(Set(scenes.flatMap { $0.cast })).sorted()
        guard let production = productionInfo, !production.castList.isEmpty else {
            return characters
        }
        return characters.map { character in
            if let match = production.castList.first(where: {
                $0.characterName.trimmingCharacters(in: .whitespaces)
                    .caseInsensitiveCompare(character.trimmingCharacters(in: .whitespaces)) == .orderedSame
            }) {
                return match.displayString
            }
            return character
        }
    }

    /// Resolves selected crew to "Name — Role" using the *current* roster for anyone selected
    /// by ID, so a name/role edit in Production Setup ripples through immediately. One-off
    /// crew (not in the roster) are plain text with no identity to resolve.
    func resolvedCrew(productionInfo: ProductionInfo) -> [String] {
        if crewIDOverride != nil || crewOneOffs != nil {
            let roster = productionInfo.crew
            let selected = (crewIDOverride ?? []).compactMap { id in
                roster.first(where: { $0.id == id })?.displayString
            }
            return selected + (crewOneOffs ?? [])
        }
        // Pre-3.4 project file that hasn't been re-saved since: fall back to the old frozen
        // text so nothing appears to vanish, but it won't ripple until the day is saved again.
        if let legacy = crewOverride { return legacy }
        return productionInfo.crew
            .filter { $0.isDailyDefault }
            .map    { $0.displayString }
    }
}

// MARK: - CrewMember

struct CrewMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name:           String
    var role:           String
    var isDailyDefault: Bool

    init(name: String = "", role: String = "", isDailyDefault: Bool = false) {
        self.id             = UUID()
        self.name           = name
        self.role           = role
        self.isDailyDefault = isDailyDefault
    }

    enum CodingKeys: String, CodingKey {
        case id, name, role, isDailyDefault
    }

    init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,   forKey: .id)
        name           = try c.decode(String.self, forKey: .name)
        role           = try c.decode(String.self, forKey: .role)
        isDailyDefault = try c.decodeIfPresent(Bool.self, forKey: .isDailyDefault) ?? false
    }

    var displayString: String {
        role.isEmpty ? name : "\(name) — \(role)"
    }
}

// MARK: - CastMember

struct CastMember: Identifiable, Codable, Hashable {
    let id: UUID
    var actorName:     String
    var characterName: String

    init(actorName: String = "", characterName: String = "") {
        self.id            = UUID()
        self.actorName     = actorName
        self.characterName = characterName
    }

    var displayString: String {
        actorName.isEmpty ? characterName : "\(actorName) — \(characterName)"
    }
}

// MARK: - Scene tooltip

extension Scene {
    /// Hover-tooltip text combining cast and summary — shown via the native macOS tooltip
    /// (`.help()`) in both the Boneyard and the calendar, which already has the ~1-2 second
    /// hover delay built in.
    var tooltipText: String {
        var lines: [String] = [title]
        if !cast.isEmpty {
            lines.append("Cast: " + cast.joined(separator: ", "))
        }
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            lines.append(trimmedSummary)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - ProductionInfo

struct ProductionInfo: Codable {
    var companyName:   String
    var directorName:  String
    var contactNumber: String
    var crew:          [CrewMember]
    var castList:      [CastMember]

    init(
        companyName:   String = "",
        directorName:  String = "",
        contactNumber: String = "",
        crew:          [CrewMember] = [],
        castList:      [CastMember] = []
    ) {
        self.companyName   = companyName
        self.directorName  = directorName
        self.contactNumber = contactNumber
        self.crew          = crew
        self.castList      = castList
    }
}

// MARK: - ShootDay

struct ShootDay: Identifiable, Codable {
    let id: UUID
    var date:      Date
    var scenes:    [Scene]       = []
    var callSheet: CallSheetData = CallSheetData()

    init(date: Date, scenes: [Scene] = [], callSheet: CallSheetData = CallSheetData()) {
        self.id        = UUID()
        self.date      = date
        self.scenes    = scenes
        self.callSheet = callSheet
    }

    var totalDuration:      Int { scenes.reduce(0) { $0 + $1.duration } }
    var totalEstimatedTime: Int { scenes.reduce(0) { $0 + $1.estimatedTime } }

    var dayScenes:    [Scene] { scenes.filter { $0.dayNightType == .day } }
    var nightScenes:  [Scene] { scenes.filter { $0.dayNightType == .night } }
    var customScenes: [Scene] { scenes.filter { $0.dayNightType == .custom } }

    var totalDayDuration:   Int { dayScenes.reduce(0)   { $0 + $1.duration } }
    var totalNightDuration: Int { nightScenes.reduce(0) { $0 + $1.duration } }

    var allCast: [String] {
        Array(Set(scenes.flatMap { $0.cast })).sorted()
    }

    var hasCallSheetData: Bool {
        !callSheet.generalCallTime.isEmpty ||
        !callSheet.locations.isEmpty       ||
        !callSheet.notes.isEmpty
    }
}

// MARK: - ProjectData

struct ProjectData: Codable {
    var allScenes:          [Scene]
    var shootDays:          [ShootDay]
    var projectTitle:       String
    var createdDate:        Date
    var isShiftModeEnabled: Bool?
    var productionInfo:     ProductionInfo?

    init(
        allScenes:          [Scene],
        shootDays:          [ShootDay],
        projectTitle:       String = "Untitled Movie",
        isShiftModeEnabled: Bool?  = false,
        createdDate:        Date   = Date(),
        productionInfo:     ProductionInfo? = nil
    ) {
        self.allScenes          = allScenes
        self.shootDays          = shootDays
        self.projectTitle       = projectTitle
        self.createdDate        = createdDate
        self.isShiftModeEnabled = isShiftModeEnabled
        self.productionInfo     = productionInfo
    }
}

// MARK: - Legacy Support

struct LegacyProjectData: Codable {
    var allScenes: [Scene]
    var shootDays: [ShootDay]
}
