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
        case .custom: return Color.green
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
    // Breakdown tagging — set via SceneEditSheet's Breakdown section or the Breakdown
    // Browser, printed one page per scene via BreakdownExporter.
    var extras: [String]
    var props: [String]
    var wardrobe: [String]
    var vehicles: [String]
    var specialEquipment: [String]
    var stunts: [String]
    var sfx: [String]
    var vfx: [String]
    var breakdownNotes: String

    init(
        title: String,
        duration: Int,
        estimatedTime: Int,
        dayNightType: DayNightType = .day,
        cast: [String] = [],
        summary: String = "",
        extras: [String] = [],
        props: [String] = [],
        wardrobe: [String] = [],
        vehicles: [String] = [],
        specialEquipment: [String] = [],
        stunts: [String] = [],
        sfx: [String] = [],
        vfx: [String] = [],
        breakdownNotes: String = ""
    ) {
        self.id               = UUID()
        self.title            = title
        self.duration         = duration
        self.estimatedTime    = estimatedTime
        self.dayNightType     = dayNightType
        self.cast              = cast
        self.summary           = summary
        self.extras            = extras
        self.props              = props
        self.wardrobe           = wardrobe
        self.vehicles           = vehicles
        self.specialEquipment   = specialEquipment
        self.stunts             = stunts
        self.sfx                = sfx
        self.vfx                = vfx
        self.breakdownNotes     = breakdownNotes
    }

    enum CodingKeys: String, CodingKey {
        case id, title, duration, estimatedTime, dayNightType, cast, summary
        case extras, props, wardrobe, vehicles, specialEquipment, stunts, sfx, vfx, breakdownNotes
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
        extras           = try c.decodeIfPresent([String].self, forKey: .extras) ?? []
        props            = try c.decodeIfPresent([String].self, forKey: .props) ?? []
        wardrobe         = try c.decodeIfPresent([String].self, forKey: .wardrobe) ?? []
        vehicles         = try c.decodeIfPresent([String].self, forKey: .vehicles) ?? []
        specialEquipment = try c.decodeIfPresent([String].self, forKey: .specialEquipment) ?? []
        stunts           = try c.decodeIfPresent([String].self, forKey: .stunts) ?? []
        sfx              = try c.decodeIfPresent([String].self, forKey: .sfx) ?? []
        vfx              = try c.decodeIfPresent([String].self, forKey: .vfx) ?? []
        breakdownNotes   = try c.decodeIfPresent(String.self, forKey: .breakdownNotes) ?? ""
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

// MARK: - DateRange (actor unavailability)

/// A simple inclusive date range, used to mark when an actor isn't available. Day-level
/// granularity only (no times), matching the rest of the app's day-based scheduling.
struct DateRange: Identifiable, Codable, Hashable {
    let id: UUID
    var start: Date
    var end: Date

    init(start: Date, end: Date) {
        self.id    = UUID()
        self.start = start
        self.end   = max(start, end)   // keep end from ever preceding start
    }

    func contains(_ date: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        return d >= cal.startOfDay(for: start) && d <= cal.startOfDay(for: end)
    }
}

// MARK: - CastMember

struct CastMember: Identifiable, Codable, Hashable {
    let id: UUID
    var actorName:     String
    var characterName: String
    var unavailableRanges: [DateRange]

    init(actorName: String = "", characterName: String = "", unavailableRanges: [DateRange] = []) {
        self.id                = UUID()
        self.actorName         = actorName
        self.characterName     = characterName
        self.unavailableRanges = unavailableRanges
    }

    enum CodingKeys: String, CodingKey {
        case id, actorName, characterName, unavailableRanges
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self,   forKey: .id)
        actorName         = try c.decode(String.self, forKey: .actorName)
        characterName     = try c.decode(String.self, forKey: .characterName)
        unavailableRanges = try c.decodeIfPresent([DateRange].self, forKey: .unavailableRanges) ?? []
    }

    var displayString: String {
        actorName.isEmpty ? characterName : "\(actorName) — \(characterName)"
    }
}

// MARK: - Scene script order

extension Scene {
    /// A numeric-aware sort key parsed from a leading scene number in the title (e.g.
    /// "12A. INT. CABIN" → (12, "A")), so scenes sort in true script order — 12, 12A, 12B,
    /// 13 — rather than plain alphabetical (which would put "12A" before "2"). Scenes with
    /// no leading number sort after every numbered scene, alphabetically among themselves.
    var scriptOrderKey: (Int, String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let pattern = #"^(\d+)([A-Za-z]*)\."#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let numRange = Range(match.range(at: 1), in: trimmed) {
            let num = Int(trimmed[numRange]) ?? Int.max
            let letterRange = Range(match.range(at: 2), in: trimmed)
            let letter = letterRange.map { String(trimmed[$0]) } ?? ""
            return (num, letter)
        }
        return (Int.max, trimmed)
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

struct ProductionInfo: Codable, Equatable {
    var companyName:   String
    var directorName:  String
    var contactNumber: String
    var crew:          [CrewMember]
    var castList:      [CastMember]
    /// A reusable roster of locations, picked from when building a day's call sheet
    /// instead of retyping the same address every time you shoot there again.
    var locationRoster: [Location]
    /// A snapshot of each character's working days at the moment the schedule was
    /// locked — see ScheduleLockScanner for how this is used to flag changes. Nil means
    /// no lock is currently set.
    var scheduleLock: ScheduleLock?

    init(
        companyName:   String = "",
        directorName:  String = "",
        contactNumber: String = "",
        crew:          [CrewMember] = [],
        castList:      [CastMember] = [],
        locationRoster: [Location] = [],
        scheduleLock:  ScheduleLock? = nil
    ) {
        self.companyName   = companyName
        self.directorName  = directorName
        self.contactNumber = contactNumber
        self.crew          = crew
        self.castList      = castList
        self.locationRoster = locationRoster
        self.scheduleLock   = scheduleLock
    }

    enum CodingKeys: String, CodingKey {
        case companyName, directorName, contactNumber, crew, castList, locationRoster, scheduleLock
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        companyName    = try c.decode(String.self, forKey: .companyName)
        directorName   = try c.decode(String.self, forKey: .directorName)
        contactNumber  = try c.decode(String.self, forKey: .contactNumber)
        crew           = try c.decode([CrewMember].self, forKey: .crew)
        castList       = try c.decode([CastMember].self, forKey: .castList)
        locationRoster = try c.decodeIfPresent([Location].self, forKey: .locationRoster) ?? []
        scheduleLock   = try c.decodeIfPresent(ScheduleLock.self, forKey: .scheduleLock)
    }
}

// MARK: - ScheduleLock

/// A snapshot of which days each character was scheduled to work, captured when the
/// schedule was locked. The schedule can still be freely rearranged after locking —
/// nothing is blocked — this is purely a baseline to compare the current schedule
/// against, so a change to an actor's working days can be flagged rather than silently
/// slipping through.
struct ScheduleLock: Codable, Equatable {
    var lockedAt: Date
    /// Character name -> the dates (start-of-day) they were scheduled to work at lock time.
    var workingDays: [String: [Date]]
}

// MARK: - ShootDay

struct ShootDay: Identifiable, Codable {
    let id: UUID
    var date:      Date
    var scenes:    [Scene]       = []
    var callSheet: CallSheetData = CallSheetData()
    /// A production-wide day off — a recurring non-shoot day (e.g. "we don't shoot
    /// Saturdays") or a specific holiday. Scenes can still be scheduled here (used as
    /// working space while rearranging the board); they're just flagged as a warning
    /// rather than silently allowed, since it usually means something needs a second look.
    var isBlackout: Bool = false

    init(date: Date, scenes: [Scene] = [], callSheet: CallSheetData = CallSheetData(), isBlackout: Bool = false) {
        self.id         = UUID()
        self.date       = date
        self.scenes     = scenes
        self.callSheet  = callSheet
        self.isBlackout = isBlackout
    }

    enum CodingKeys: String, CodingKey {
        case id, date, scenes, callSheet, isBlackout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        date       = try c.decode(Date.self, forKey: .date)
        scenes     = try c.decode([Scene].self, forKey: .scenes)
        callSheet  = try c.decode(CallSheetData.self, forKey: .callSheet)
        isBlackout = try c.decodeIfPresent(Bool.self, forKey: .isBlackout) ?? false
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
