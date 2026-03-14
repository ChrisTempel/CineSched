// Models.swift
// Core data models for CineSched

import SwiftUI

// MARK: - DayNightType

enum DayNightType: String, Codable, CaseIterable {
    case day = "DAY"
    case night = "NIGHT"

    var color: Color {
        switch self {
        case .day:   return Color.orange
        case .night: return Color.blue
        }
    }

    var displayName: String { rawValue }
}

// MARK: - Scene

struct Scene: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var duration: Int        // in eighths of a page
    var estimatedTime: Int   // in minutes
    var dayNightType: DayNightType
    var cast: [String]       // individual cast member names
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

    // MARK: - Codable with migration

    enum CodingKeys: String, CodingKey {
        case id, title, duration, estimatedTime, dayNightType, cast, summary
    }

    /// Decodes cast from either the new [String] format or the legacy String format.
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
            cast = legacy
                .components(separatedBy: ",")
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
    var name:    String   // e.g. "Owen's Farmhouse"
    var address: String   // e.g. "123 Rural Rd, Whitefish MT"

    init(name: String = "", address: String = "") {
        self.id      = UUID()
        self.name    = name
        self.address = address
    }
}

// MARK: - CallSheetData
// Per-day call sheet fields. Stored on ShootDay and saved with the project.

struct CallSheetData: Codable {
    var generalCallTime: String    // e.g. "7:00 AM"
    var locations: [Location]      // ordered list; first is primary
    var castOverride: [String]?    // nil = use auto-pulled cast from scenes
    var notes: String

    init(
        generalCallTime: String = "",
        locations: [Location] = [],
        castOverride: [String]? = nil,
        notes: String = ""
    ) {
        self.generalCallTime = generalCallTime
        self.locations       = locations
        self.castOverride    = castOverride
        self.notes           = notes
    }

    /// Returns cast display strings for the call sheet.
    /// Each character name from the scenes is looked up in the production cast list.
    /// If a match is found, returns "Actor Name — Character". Otherwise just the character name.
    /// If castOverride is set, those strings are returned as-is.
    func resolvedCast(from scenes: [Scene], productionInfo: ProductionInfo? = nil) -> [String] {
        if let override = castOverride { return override }

        let characters = Array(Set(scenes.flatMap { $0.cast })).sorted()
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
            return character  // no match — show character name alone
        }
    }
}

// MARK: - CrewMember

struct CrewMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: String

    init(name: String = "", role: String = "") {
        self.id   = UUID()
        self.name = name
        self.role = role
    }

    var displayString: String {
        role.isEmpty ? name : "\(name) — \(role)"
    }
}

// MARK: - CastMember
// Project-wide mapping of actor to character name.

struct CastMember: Identifiable, Codable, Hashable {
    let id: UUID
    var actorName:     String   // e.g. "Jake Nuttbrock"
    var characterName: String   // e.g. "Blake"

    init(actorName: String = "", characterName: String = "") {
        self.id            = UUID()
        self.actorName     = actorName
        self.characterName = characterName
    }

    var displayString: String {
        actorName.isEmpty ? characterName : "\(actorName) — \(characterName)"
    }
}

// MARK: - ProductionInfo
// Project-wide fields filled in once, saved with ProjectData.

struct ProductionInfo: Codable {
    var companyName:   String
    var directorName:  String
    var contactNumber: String
    var crew:          [CrewMember]
    var castList:      [CastMember]   // actor → character mappings

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
    var date: Date
    var scenes: [Scene] = []
    var callSheet: CallSheetData = CallSheetData()

    init(date: Date, scenes: [Scene] = [], callSheet: CallSheetData = CallSheetData()) {
        self.id        = UUID()
        self.date      = date
        self.scenes    = scenes
        self.callSheet = callSheet
    }

    var totalDuration: Int      { scenes.reduce(0) { $0 + $1.duration } }
    var totalEstimatedTime: Int { scenes.reduce(0) { $0 + $1.estimatedTime } }

    var dayScenes:   [Scene] { scenes.filter { $0.dayNightType == .day } }
    var nightScenes: [Scene] { scenes.filter { $0.dayNightType == .night } }

    var totalDayDuration:   Int { dayScenes.reduce(0)   { $0 + $1.duration } }
    var totalNightDuration: Int { nightScenes.reduce(0) { $0 + $1.duration } }

    /// Auto-pulled cast from all scenes this day, sorted alphabetically.
    var allCast: [String] {
        Array(Set(scenes.flatMap { $0.cast })).sorted()
    }

    /// True if the call sheet has any meaningful data entered.
    var hasCallSheetData: Bool {
        !callSheet.generalCallTime.isEmpty ||
        !callSheet.locations.isEmpty ||
        !callSheet.notes.isEmpty
    }
}

// MARK: - ProjectData

struct ProjectData: Codable {
    var allScenes: [Scene]
    var shootDays: [ShootDay]
    var projectTitle: String
    var createdDate: Date
    var isShiftModeEnabled: Bool?
    var productionInfo: ProductionInfo?   // optional for backwards compatibility

    init(
        allScenes: [Scene],
        shootDays: [ShootDay],
        projectTitle: String = "Untitled Movie",
        isShiftModeEnabled: Bool? = false,
        createdDate: Date = Date(),
        productionInfo: ProductionInfo? = nil
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
