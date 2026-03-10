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
    /// Old saves stored cast as a single comma-separated string; new saves store an array.
    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,         forKey: .id)
        title         = try c.decode(String.self,       forKey: .title)
        duration      = try c.decode(Int.self,          forKey: .duration)
        estimatedTime = try c.decode(Int.self,          forKey: .estimatedTime)
        dayNightType  = try c.decode(DayNightType.self, forKey: .dayNightType)
        summary       = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""

        // Migration: try [String] first, fall back to legacy comma-separated String
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

// MARK: - ShootDay

struct ShootDay: Identifiable, Codable {
    let id: UUID
    var date: Date
    var scenes: [Scene] = []
    var locationName:    String = ""   // e.g. "Owen's Farmhouse"
    var locationAddress: String = ""   // e.g. "123 Rural Rd, Whitefish MT"

    init(date: Date, scenes: [Scene] = [], locationName: String = "", locationAddress: String = "") {
        self.id              = UUID()
        self.date            = date
        self.scenes          = scenes
        self.locationName    = locationName
        self.locationAddress = locationAddress
    }

    var totalDuration: Int      { scenes.reduce(0) { $0 + $1.duration } }
    var totalEstimatedTime: Int { scenes.reduce(0) { $0 + $1.estimatedTime } }

    var dayScenes:   [Scene] { scenes.filter { $0.dayNightType == .day } }
    var nightScenes: [Scene] { scenes.filter { $0.dayNightType == .night } }

    var totalDayDuration:   Int { dayScenes.reduce(0)   { $0 + $1.duration } }
    var totalNightDuration: Int { nightScenes.reduce(0) { $0 + $1.duration } }

    /// All unique cast members appearing across this day's scenes, sorted alphabetically.
    var allCast: [String] {
        Array(Set(scenes.flatMap { $0.cast })).sorted()
    }
}

// MARK: - ProjectData

struct ProjectData: Codable {
    var allScenes: [Scene]
    var shootDays: [ShootDay]
    var projectTitle: String
    var createdDate: Date          // set once at creation, never overwritten on re-save
    var isShiftModeEnabled: Bool?

    init(
        allScenes: [Scene],
        shootDays: [ShootDay],
        projectTitle: String = "Untitled Movie",
        isShiftModeEnabled: Bool? = false,
        createdDate: Date = Date()  // pass existing date on re-save to preserve it
    ) {
        self.allScenes          = allScenes
        self.shootDays          = shootDays
        self.projectTitle       = projectTitle
        self.createdDate        = createdDate
        self.isShiftModeEnabled = isShiftModeEnabled
    }
}

// MARK: - Legacy Support

struct LegacyProjectData: Codable {
    var allScenes: [Scene]
    var shootDays: [ShootDay]
}
