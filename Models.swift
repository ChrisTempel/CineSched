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
    var castOverride:    [String]?
    var crewOverride:    [String]?
    var notes:           String

    init(
        generalCallTime: String    = "",
        locations:       [Location] = [],
        castOverride:    [String]?  = nil,
        crewOverride:    [String]?  = nil,
        notes:           String    = ""
    ) {
        self.generalCallTime = generalCallTime
        self.locations       = locations
        self.castOverride    = castOverride
        self.crewOverride    = crewOverride
        self.notes           = notes
    }

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
            return character
        }
    }

    func resolvedCrew(productionInfo: ProductionInfo) -> [String] {
        if let override = crewOverride { return override }
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
