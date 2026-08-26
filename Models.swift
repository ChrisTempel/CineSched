// Models.swift
// Core data models for CineSched

import SwiftUI
import AppKit

// MARK: - Color blending

extension Color {
    /// Blends this color toward white by `amount` (0...1) — e.g. 0.1 mixes in
    /// 10% white, keeping 90% of the original. Computed from this color's
    /// actual RGB components rather than a guessed replacement value, so it
    /// tracks whatever the base color really is.
    func lightened(by amount: Double) -> Color {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let r = ns.redComponent, g = ns.greenComponent, b = ns.blueComponent, a = ns.alphaComponent
        return Color(
            red:   r + (1 - r) * amount,
            green: g + (1 - g) * amount,
            blue:  b + (1 - b) * amount,
            opacity: a
        )
    }
}

// MARK: - DayNightType

enum DayNightType: String, Codable, CaseIterable {
    case day       = "DAY"
    case night     = "NIGHT"
    case dawn      = "DAWN"
    case dusk      = "DUSK"
    case afternoon = "AFTERNOON"
    case custom    = "CUSTOM"

    var color: Color {
        color(isInterior: true)
    }

    func color(isInterior: Bool) -> Color {
        switch self {
        case .day:
            return isInterior ? Color(hex: "F3F4F6") : Color(hex: "FEF08A") // INT. DAY (Off-white) vs EXT. DAY (Yellow)
        case .night:
            return isInterior ? Color(hex: "86EFAC") : Color(hex: "93C5FD") // INT. NIGHT (Green) vs EXT. NIGHT (Blue)
        case .dawn:
            return Color(hex: "FDE68A") // DAWN / Amanecer (Gold)
        case .dusk:
            return Color(hex: "E9D5FF") // DUSK / Atardecer (Soft Lavender/Purple)
        case .afternoon:
            return isInterior ? Color(hex: "FFE4C4") : Color(hex: "FDBA74") // INT. TARDE vs EXT. TARDE (Warm Coral/Peach)
        case .custom:
            return Color(hex: "D1D5DB") // Custom / Notice (Gray)
        }
    }

    var displayName: String { rawValue }

    var shortCode: String {
        switch self {
        case .day:       return "D"
        case .night:     return "N"
        case .dawn:      return "DW"
        case .dusk:      return "DK"
        case .afternoon: return "AFT"
        case .custom:    return "C"
        }
    }

    var sortOrder: Int {
        switch self {
        case .day:       return 0
        case .dawn:      return 1
        case .afternoon: return 2
        case .dusk:      return 3
        case .night:     return 4
        case .custom:    return 5
        }
    }
}

// MARK: - Banner & Meal Types

enum BannerType: String, CaseIterable, Codable {
    case companyMove = "Company Move"
    case mealBreak   = "Meal Break"
    case notice      = "Notice"
    case custom      = "Custom Banner"

    var localizedName: String {
        switch self {
        case .companyMove: return L("Company Move")
        case .mealBreak:   return L("Meal Break")
        case .notice:      return L("Notice")
        case .custom:      return L("Custom Banner")
        }
    }

    var defaultIcon: String {
        switch self {
        case .companyMove: return "truck.box.fill"
        case .mealBreak:   return "fork.knife"
        case .notice:      return "note.text"
        case .custom:      return "flag.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        switch raw {
        case "Company Move", "Traslado", "Traslado de Equipo":
            self = .companyMove
        case "Meal Break", "Comida", "Pausa de Comida":
            self = .mealBreak
        case "Notice / Note", "Notice", "Note", "Aviso / Nota", "Aviso", "Nota":
            self = .notice
        case "Custom Banner", "Tira Personalizada", "Banner Personalizado":
            self = .custom
        default:
            self = BannerType(rawValue: raw) ?? .notice
        }
    }
}

enum MealKind: String, CaseIterable, Codable {
    case generalCall  = "General Call"
    case readyToShoot = "Ready to Shoot"
    case lunch        = "Lunch"
    case snack        = "Snack"
    case dinner       = "Dinner"
    case wrap         = "Wrap"

    var icon: String {
        switch self {
        case .generalCall:  return "⏰"
        case .readyToShoot: return "🎬"
        case .lunch:        return "🍽️"
        case .snack:        return "☕"
        case .dinner:       return "🍕"
        case .wrap:         return "🎬"
        }
    }

    var defaultTitle: String {
        switch self {
        case .generalCall:  return L("GENERAL CALL")
        case .readyToShoot: return L("READY TO SHOOT")
        case .lunch:        return L("LUNCH")
        case .snack:        return L("SNACK")
        case .dinner:       return L("DINNER")
        case .wrap:         return L("WRAP")
        }
    }
}

// MARK: - Scene

struct Scene: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var sceneNumber: String
    var duration: Int
    var estimatedTime: Int
    var dayNightType: DayNightType
    var cast: [String]
    var summary: String
    // Breakdown tagging — set via SceneEditSheet's Breakdown section or the Breakdown
    // Browser, printed one page per scene via BreakdownExporter.
    var realLocation: String
    var locationAddress: String
    var extras: [String]
    var props: [String]
    var setDressing: [String]
    var wardrobe: [String]
    var makeupHair: [String]
    var vehicles: [String]
    var specialEquipment: [String]
    var stunts: [String]
    var sfx: [String]
    var vfx: [String]
    var breakdownNotes: String

    // Banner & Auto-Meal Strip Extensions
    var isBanner: Bool
    var bannerType: BannerType?
    var bannerTitle: String
    var bannerNote: String
    var bannerColorHex: String
    var isAutoMeal: Bool
    var mealKind: MealKind?
    var isCalendarEvent: Bool
    var customStartTime: String
    /// Marks a scene as shot/done. Independent of dayNightType — previously the only way
    /// to flag a scene as complete was hijacking the Custom type, which meant losing the
    /// scene's real Day/Night/Dawn/Dusk/Afternoon classification to do it.
    var isCompleted: Bool

    init(
        title: String,
        sceneNumber: String = "",
        duration: Int = 0,
        estimatedTime: Int = 0,
        dayNightType: DayNightType = .day,
        cast: [String] = [],
        summary: String = "",
        realLocation: String = "",
        locationAddress: String = "",
        extras: [String] = [],
        props: [String] = [],
        setDressing: [String] = [],
        wardrobe: [String] = [],
        makeupHair: [String] = [],
        vehicles: [String] = [],
        specialEquipment: [String] = [],
        stunts: [String] = [],
        sfx: [String] = [],
        vfx: [String] = [],
        breakdownNotes: String = "",
        isBanner: Bool = false,
        bannerType: BannerType? = nil,
        bannerTitle: String = "",
        bannerNote: String = "",
        bannerColorHex: String = "",
        isAutoMeal: Bool = false,
        mealKind: MealKind? = nil,
        isCalendarEvent: Bool = false,
        customStartTime: String = "",
        isCompleted: Bool = false
    ) {
        self.id               = UUID()
        self.title            = title
        self.sceneNumber      = sceneNumber
        self.duration         = duration
        self.estimatedTime    = estimatedTime
        self.dayNightType     = dayNightType
        self.cast             = cast
        self.summary          = summary
        self.realLocation     = realLocation
        self.locationAddress  = locationAddress
        self.extras           = extras
        self.props            = props
        self.setDressing      = setDressing
        self.wardrobe         = wardrobe
        self.makeupHair       = makeupHair
        self.vehicles         = vehicles
        self.specialEquipment = specialEquipment
        self.stunts           = stunts
        self.sfx              = sfx
        self.vfx              = vfx
        self.breakdownNotes   = breakdownNotes
        self.isBanner         = isBanner
        self.bannerType       = bannerType
        self.bannerTitle      = bannerTitle
        self.bannerNote       = bannerNote
        self.bannerColorHex   = bannerColorHex
        self.isAutoMeal       = isAutoMeal
        self.mealKind         = mealKind
        self.isCalendarEvent  = isCalendarEvent
        self.customStartTime  = customStartTime
        self.isCompleted      = isCompleted
    }

    static func createBanner(type: BannerType, title: String, note: String = "", estimatedTime: String = "0:30", colorHex: String = "8B5CF6") -> Scene {
        let estMin = parseMinutes(estimatedTime)
        return Scene(
            title: title,
            sceneNumber: "",
            duration: 0,
            estimatedTime: estMin,
            dayNightType: .custom,
            summary: note,
            isBanner: true,
            bannerType: type,
            bannerTitle: title,
            bannerNote: note,
            bannerColorHex: colorHex,
            isAutoMeal: false,
            mealKind: nil
        )
    }

    static func createAutoMeal(kind: MealKind, timeString: String) -> Scene {
        let cleanTime = timeString.trimmingCharacters(in: .whitespaces)
        let title = "\(kind.icon) \(kind.defaultTitle) \(cleanTime.isEmpty ? "" : "(\(cleanTime))")"
        let colorHex: String
        let estTime: Int
        let bType: BannerType

        switch kind {
        case .generalCall:
            colorHex = "1E3A8A" // Midnight Navy
            estTime  = 0
            bType    = .notice
        case .readyToShoot:
            colorHex = "064E3B" // Deep Forest Green
            estTime  = 0
            bType    = .notice
        case .lunch:
            colorHex = "18181B" // Black / Dark Charcoal
            estTime  = 60
            bType    = .mealBreak
        case .snack:
            colorHex = "18181B" // Black / Dark Charcoal
            estTime  = 15
            bType    = .mealBreak
        case .dinner:
            colorHex = "18181B" // Black / Dark Charcoal
            estTime  = 60
            bType    = .mealBreak
        case .wrap:
            colorHex = "991B1B" // Deep Crimson Red
            estTime  = 0
            bType    = .notice
        }

        return Scene(
            title: title,
            sceneNumber: "",
            duration: 0,
            estimatedTime: estTime,
            dayNightType: .custom,
            summary: cleanTime,
            isBanner: true,
            bannerType: bType,
            bannerTitle: title,
            bannerNote: cleanTime,
            bannerColorHex: colorHex,
            isAutoMeal: true,
            mealKind: kind,
            customStartTime: cleanTime
        )
    }

    static func createCalendarEvent(title: String, time: String, colorHex: String = "6366F1") -> Scene {
        let cleanTime = time.trimmingCharacters(in: .whitespaces)
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        return Scene(
            title: cleanTitle,
            sceneNumber: "",
            duration: 0,
            estimatedTime: 0,
            dayNightType: .custom,
            summary: cleanTime,
            isBanner: true,
            bannerType: .notice,
            bannerTitle: cleanTitle,
            bannerNote: cleanTime,
            bannerColorHex: colorHex,
            isAutoMeal: false,
            mealKind: nil,
            isCalendarEvent: true,
            customStartTime: cleanTime
        )
    }

    private static func parseMinutes(_ raw: String) -> Int {
        let parts = raw.components(separatedBy: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            return h * 60 + m
        } else if let mins = Int(raw) {
            return mins
        }
        return 30
    }

    enum CodingKeys: String, CodingKey {
        case id, title, sceneNumber, duration, estimatedTime, dayNightType, cast, summary
        case realLocation, locationAddress
        case extras, props, setDressing, wardrobe, makeupHair, vehicles, specialEquipment, stunts, sfx, vfx, breakdownNotes
        case isBanner, bannerType, bannerTitle, bannerNote, bannerColorHex, isAutoMeal, mealKind, isCalendarEvent, customStartTime
        case isCompleted
    }

    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,         forKey: .id)
        title         = try c.decode(String.self,       forKey: .title)
        sceneNumber   = try c.decodeIfPresent(String.self, forKey: .sceneNumber) ?? ""
        duration      = try c.decode(Int.self,          forKey: .duration)
        estimatedTime = try c.decode(Int.self,          forKey: .estimatedTime)
        dayNightType  = try c.decode(DayNightType.self, forKey: .dayNightType)
        summary       = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        realLocation  = try c.decodeIfPresent(String.self, forKey: .realLocation) ?? ""
        locationAddress = try c.decodeIfPresent(String.self, forKey: .locationAddress) ?? ""
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
        setDressing      = try c.decodeIfPresent([String].self, forKey: .setDressing) ?? []
        wardrobe         = try c.decodeIfPresent([String].self, forKey: .wardrobe) ?? []
        makeupHair       = try c.decodeIfPresent([String].self, forKey: .makeupHair) ?? []
        vehicles         = try c.decodeIfPresent([String].self, forKey: .vehicles) ?? []
        specialEquipment = try c.decodeIfPresent([String].self, forKey: .specialEquipment) ?? []
        stunts           = try c.decodeIfPresent([String].self, forKey: .stunts) ?? []
        sfx              = try c.decodeIfPresent([String].self, forKey: .sfx) ?? []
        vfx              = try c.decodeIfPresent([String].self, forKey: .vfx) ?? []
        breakdownNotes   = try c.decodeIfPresent(String.self, forKey: .breakdownNotes) ?? ""
        isBanner         = try c.decodeIfPresent(Bool.self, forKey: .isBanner) ?? false
        bannerType       = (try? c.decodeIfPresent(BannerType.self, forKey: .bannerType)) ?? nil
        bannerTitle      = try c.decodeIfPresent(String.self, forKey: .bannerTitle) ?? ""
        bannerNote       = try c.decodeIfPresent(String.self, forKey: .bannerNote) ?? ""
        bannerColorHex   = try c.decodeIfPresent(String.self, forKey: .bannerColorHex) ?? ""
        isAutoMeal       = try c.decodeIfPresent(Bool.self, forKey: .isAutoMeal) ?? false
        mealKind         = (try? c.decodeIfPresent(MealKind.self, forKey: .mealKind)) ?? nil
        isCalendarEvent  = try c.decodeIfPresent(Bool.self, forKey: .isCalendarEvent) ?? false
        customStartTime  = try c.decodeIfPresent(String.self, forKey: .customStartTime) ?? ""
        isCompleted      = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    /// "12A. INT. HOUSE - DAY" for display — combines the dedicated number field
    /// with the title. Falls back to the bare title when there's no number, which
    /// also covers scenes saved before this field existed (their number, if any,
    /// is already part of `title` from that era).
    var displayTitle: String {
        if isBanner { return title }
        let trimmedNum = sceneNumber.trimmingCharacters(in: .whitespaces)
        return trimmedNum.isEmpty ? title : "\(trimmedNum). \(title)"
    }

    /// Auto-parses leading scene number from title if `sceneNumber` is currently empty.
    /// E.g., title "2. EXT. PLAYA. DIA" -> sceneNumber = "2", cleanTitle = "EXT. PLAYA. DIA"
    mutating func autoExtractSceneNumberIfNeeded() {
        guard sceneNumber.trimmingCharacters(in: .whitespaces).isEmpty, !isBanner else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let pattern = #"^#?(\d+[A-Za-z]?)\.?\s*[-–—.]?\s*(.*)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let numRange = Range(match.range(at: 1), in: trimmed) {
            let extractedNum = String(trimmed[numRange])
            self.sceneNumber = extractedNum
            if let restRange = Range(match.range(at: 2), in: trimmed) {
                let rest = String(trimmed[restRange]).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty {
                    self.title = rest
                }
            }
        }
    }

    /// Extracted scene number: uses dedicated sceneNumber or parses leading digits from title (e.g. "2. EXT..." -> "2")
    var extractedSceneNumber: String {
        let trimmed = sceneNumber.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let titleTrimmed = title.trimmingCharacters(in: .whitespaces)
        if let match = titleTrimmed.range(of: "^#?(\\d+[A-Za-z]?)", options: .regularExpression) {
            return String(titleTrimmed[match]).replacingOccurrences(of: "#", with: "")
        }
        return "1"
    }

    /// Extracted decorado/set name: removes leading scene number, INT/EXT, and trailing time of day
    var decoradoOnly: String {
        if !realLocation.trimmingCharacters(in: .whitespaces).isEmpty {
            return realLocation.trimmingCharacters(in: .whitespaces).uppercased()
        }
        var s = title.trimmingCharacters(in: .whitespaces)
        // Strip leading number like "1. ", "12A - ", "#2. "
        s = s.replacingOccurrences(of: "^#?\\d+[A-Za-z]?\\.?\\s*[-–—.]?\\s*", with: "", options: .regularExpression)
        // Strip INT./EXT., INT., EXT., I/E., I/E
        s = s.replacingOccurrences(of: "^(INT\\.?/EXT\\.?|INT\\.?|EXT\\.?|I/E\\.?|INT\\s+/\\s+EXT)\\s*[-–—.]?\\s*", with: "", options: [.regularExpression, .caseInsensitive])
        // Strip trailing time of day: " - DAY", ". DIA", " - NIGHT", " - NOCHE", etc.
        s = s.replacingOccurrences(of: "\\s*[-–—.]+\\s*(DAY|NIGHT|DAWN|DUSK|AFTERNOON|DIA|NOCHE|TARDE|ATARDECER|AMANECER|CONTINUOUS|SAME)\\.?\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " .-–—"))
        return s.isEmpty ? title.uppercased() : s.uppercased()
    }

    // MARK: - Interior / Exterior + Movie Magic strip color

    enum IntExt { case interior, exterior, unknown }

    /// Interior/exterior, sniffed from title even when preceded by scene number
    var intExt: IntExt {
        var upper = title.trimmingCharacters(in: .whitespaces).uppercased()
        upper = upper.replacingOccurrences(of: "^#?\\d+[A-Za-z]?\\.?\\s*", with: "", options: .regularExpression)
        if upper.hasPrefix("EXT.") || upper.hasPrefix("EXT ") || upper.hasPrefix("EXT") {
            return .exterior
        }
        return .interior
    }

    var intExtString: String {
        var upper = title.trimmingCharacters(in: .whitespaces).uppercased()
        upper = upper.replacingOccurrences(of: "^#?\\d+[A-Za-z]?\\.?\\s*", with: "", options: .regularExpression)
        if upper.hasPrefix("INT/EXT") || upper.hasPrefix("INT./EXT") || upper.hasPrefix("I/E") || upper.hasPrefix("INT / EXT") {
            return "INT/EXT"
        }
        if upper.hasPrefix("EXT.") || upper.hasPrefix("EXT ") || upper.hasPrefix("EXT") {
            return "EXT"
        }
        return "INT"
    }

    /// Movie Magic Scheduling's own strip color code:
    /// white = day interior, yellow = day exterior, green = night interior,
    /// blue = night exterior, rose/gold for dawn/afternoon/dusk.
    var isNoticeStrip: Bool {
        let hasNoNum = sceneNumber.trimmingCharacters(in: .whitespaces).isEmpty
        let titleHasNoHeading = !title.uppercased().contains("INT") && !title.uppercased().contains("EXT") && extractedSceneNumber == "1" && sceneNumber.isEmpty && duration == 0
        return hasNoNum && titleHasNoHeading && dayNightType == .custom
    }

    var stripColor: Color {
        if isCompleted {
            return Color(hex: "9CA3AF")
        }
        if isNoticeStrip {
            return Color(hex: "374151")
        }
        if dayNightType == .custom {
            return SceneColorSettings.color(for: .custom)
        }
        switch (intExt, dayNightType) {
        case (.interior, .day):       return SceneColorSettings.color(for: .intDay)
        case (.exterior, .day):       return SceneColorSettings.color(for: .extDay)
        case (.interior, .night):     return SceneColorSettings.color(for: .intNight)
        case (.exterior, .night):     return SceneColorSettings.color(for: .extNight)
        case (.interior, .dawn):      return SceneColorSettings.color(for: .intDawn)
        case (.exterior, .dawn):      return SceneColorSettings.color(for: .extDawn)
        case (.interior, .dusk):      return SceneColorSettings.color(for: .intDusk)
        case (.exterior, .dusk):      return SceneColorSettings.color(for: .extDusk)
        case (.interior, .afternoon): return SceneColorSettings.color(for: .intAfternoon)
        case (.exterior, .afternoon): return SceneColorSettings.color(for: .extAfternoon)
        case (.unknown, .day):        return SceneColorSettings.color(for: .intDay)
        case (.unknown, .night):      return SceneColorSettings.color(for: .extNight)
        case (.unknown, .dawn):       return SceneColorSettings.color(for: .intDawn)
        case (.unknown, .dusk):       return SceneColorSettings.color(for: .intDusk)
        case (.unknown, .afternoon):  return SceneColorSettings.color(for: .extAfternoon)
        case (_, .custom):            return SceneColorSettings.color(for: .custom)
        }
    }

    var stripTextColor: Color {
        if isCompleted { return Color(hex: "4B5563") }
        return isNoticeStrip ? .white : .black
    }

    /// Splits a raw scene number like "12A" into its numeric and letter parts.
    static func parseSceneNumber(_ raw: String) -> (number: Int, letter: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let digits  = trimmed.prefix { $0.isNumber }
        let letter  = trimmed.dropFirst(digits.count).prefix { $0.isLetter }
        guard let number = Int(digits) else { return nil }
        return (number, String(letter).uppercased())
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

// MARK: - CastCallEntry

struct CastCallEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var characterName: String
    var actorName: String
    var sceneNumbers: String     // e.g. "1, 4, 7"
    var ecdt: String             // "E", "ET", "W", etc.
    var pickupTime: String       // e.g. "07:00 AM"
    var hmuWardrobeTime: String  // e.g. "07:30 AM"
    var onSetTime: String        // e.g. "08:00 AM"
    var wrapTime: String         // e.g. "09:30 PM"
    var locationIndex: String    // e.g. "1", "2"

    init(
        id: UUID = UUID(),
        characterName: String = "",
        actorName: String = "",
        sceneNumbers: String = "",
        ecdt: String = "E",
        pickupTime: String = "",
        hmuWardrobeTime: String = "",
        onSetTime: String = "",
        wrapTime: String = "",
        locationIndex: String = "1"
    ) {
        self.id = id
        self.characterName = characterName
        self.actorName = actorName
        self.sceneNumbers = sceneNumbers
        self.ecdt = ecdt
        self.pickupTime = pickupTime
        self.hmuWardrobeTime = hmuWardrobeTime
        self.onSetTime = onSetTime
        self.wrapTime = wrapTime
        self.locationIndex = locationIndex
    }

    enum CodingKeys: String, CodingKey {
        case id, characterName, actorName, sceneNumbers, ecdt, pickupTime, hmuWardrobeTime, onSetTime, wrapTime, locationIndex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        characterName   = try c.decodeIfPresent(String.self, forKey: .characterName) ?? ""
        actorName       = try c.decodeIfPresent(String.self, forKey: .actorName) ?? ""
        sceneNumbers    = try c.decodeIfPresent(String.self, forKey: .sceneNumbers) ?? ""
        ecdt            = try c.decodeIfPresent(String.self, forKey: .ecdt) ?? "E"
        pickupTime      = try c.decodeIfPresent(String.self, forKey: .pickupTime) ?? ""
        hmuWardrobeTime = try c.decodeIfPresent(String.self, forKey: .hmuWardrobeTime) ?? ""
        onSetTime       = try c.decodeIfPresent(String.self, forKey: .onSetTime) ?? ""
        wrapTime        = try c.decodeIfPresent(String.self, forKey: .wrapTime) ?? ""
        locationIndex   = try c.decodeIfPresent(String.self, forKey: .locationIndex) ?? "1"
    }
}

// MARK: - CrewCallEntry

struct CrewCallEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var role: String
    var name: String
    var callTime: String
    var phone: String

    init(
        id: UUID = UUID(),
        role: String = "",
        name: String = "",
        callTime: String = "",
        phone: String = ""
    ) {
        self.id = id
        self.role = role
        self.name = name
        self.callTime = callTime
        self.phone = phone
    }
}

// MARK: - CallSheetData

struct CallSheetData: Codable {
    var generalCallTime: String
    var workDaySchedule: String       // e.g. "Schedule: 07:30 AM to 09:30 PM"
    var readyToShootTime: String      // e.g. "08:00 AM"
    var lunchTime: String             // e.g. "01:30 PM"
    var snackTime: String             // Merienda, e.g. "05:00 PM"
    var dinnerTime: String            // Cena, e.g. "08:30 PM"
    var wrapTime: String              // Fin de Rodaje / Wrap, e.g. "09:30 PM"
    var quoteOfTheDay: String         // "Quote of the day"
    var prodManagerContact: String    // Producer contact override if needed
    var adContact: String             // AD contact
    var weatherTemp: String
    var weatherCondition: String
    var weatherPrecipWind: String
    var sunTimes: String
    var basecampLocation: String      // Basecamp location / address
    var nearestHospital: String
    var castCallEntries: [CastCallEntry]
    var crewCallEntries: [CrewCallEntry]
    var productionNotes: [String]
    var locations:       [Location]
    var castOverride:    [String]?
    var crewOverride:    [String]?
    var crewIDOverride:  [UUID]?
    var crewOneOffs:     [String]?
    var notes:           String

    init(
        generalCallTime: String     = "",
        workDaySchedule: String     = "",
        readyToShootTime: String    = "",
        lunchTime: String           = "",
        snackTime: String           = "",
        dinnerTime: String          = "",
        wrapTime: String            = "",
        quoteOfTheDay: String       = "",
        prodManagerContact: String  = "",
        adContact: String           = "",
        weatherTemp: String         = "",
        weatherCondition: String    = "",
        weatherPrecipWind: String   = "",
        sunTimes: String            = "",
        basecampLocation: String    = "",
        nearestHospital: String     = "",
        castCallEntries: [CastCallEntry] = [],
        crewCallEntries: [CrewCallEntry] = [],
        productionNotes: [String]   = [],
        locations:       [Location] = [],
        castOverride:    [String]?  = nil,
        crewOverride:    [String]?  = nil,
        crewIDOverride:  [UUID]?    = nil,
        crewOneOffs:     [String]?  = nil,
        notes:           String     = ""
    ) {
        self.generalCallTime    = generalCallTime
        self.workDaySchedule    = workDaySchedule
        self.readyToShootTime   = readyToShootTime
        self.lunchTime          = lunchTime
        self.snackTime          = snackTime
        self.dinnerTime         = dinnerTime
        self.wrapTime           = wrapTime
        self.quoteOfTheDay      = quoteOfTheDay
        self.prodManagerContact = prodManagerContact
        self.adContact          = adContact
        self.weatherTemp        = weatherTemp
        self.weatherCondition   = weatherCondition
        self.weatherPrecipWind  = weatherPrecipWind
        self.sunTimes           = sunTimes
        self.basecampLocation   = basecampLocation
        self.nearestHospital    = nearestHospital
        self.castCallEntries    = castCallEntries
        self.crewCallEntries    = crewCallEntries
        self.productionNotes    = productionNotes
        self.locations          = locations
        self.castOverride       = castOverride
        self.crewOverride       = crewOverride
        self.crewIDOverride     = crewIDOverride
        self.crewOneOffs        = crewOneOffs
        self.notes              = notes
    }

    enum CodingKeys: String, CodingKey {
        case generalCallTime, workDaySchedule, readyToShootTime, lunchTime, snackTime, dinnerTime, wrapTime
        case quoteOfTheDay, prodManagerContact, adContact, weatherTemp, weatherCondition, weatherPrecipWind, sunTimes, basecampLocation, nearestHospital
        case castCallEntries, crewCallEntries, productionNotes, locations, castOverride, crewOverride, crewIDOverride, crewOneOffs, notes
    }

    init(from decoder: Decoder) throws {
        let c              = try decoder.container(keyedBy: CodingKeys.self)
        generalCallTime    = try c.decodeIfPresent(String.self, forKey: .generalCallTime) ?? ""
        workDaySchedule    = try c.decodeIfPresent(String.self, forKey: .workDaySchedule) ?? ""
        readyToShootTime   = try c.decodeIfPresent(String.self, forKey: .readyToShootTime) ?? ""
        lunchTime          = try c.decodeIfPresent(String.self, forKey: .lunchTime) ?? ""
        snackTime          = try c.decodeIfPresent(String.self, forKey: .snackTime) ?? ""
        dinnerTime         = try c.decodeIfPresent(String.self, forKey: .dinnerTime) ?? ""
        wrapTime           = try c.decodeIfPresent(String.self, forKey: .wrapTime) ?? ""
        quoteOfTheDay      = try c.decodeIfPresent(String.self, forKey: .quoteOfTheDay) ?? ""
        prodManagerContact = try c.decodeIfPresent(String.self, forKey: .prodManagerContact) ?? ""
        adContact          = try c.decodeIfPresent(String.self, forKey: .adContact) ?? ""
        weatherTemp        = try c.decodeIfPresent(String.self, forKey: .weatherTemp) ?? ""
        weatherCondition   = try c.decodeIfPresent(String.self, forKey: .weatherCondition) ?? ""
        weatherPrecipWind  = try c.decodeIfPresent(String.self, forKey: .weatherPrecipWind) ?? ""
        sunTimes           = try c.decodeIfPresent(String.self, forKey: .sunTimes) ?? ""
        basecampLocation   = try c.decodeIfPresent(String.self, forKey: .basecampLocation) ?? ""
        nearestHospital    = try c.decodeIfPresent(String.self, forKey: .nearestHospital) ?? ""
        castCallEntries    = try c.decodeIfPresent([CastCallEntry].self, forKey: .castCallEntries) ?? []
        crewCallEntries    = try c.decodeIfPresent([CrewCallEntry].self, forKey: .crewCallEntries) ?? []
        productionNotes    = try c.decodeIfPresent([String].self, forKey: .productionNotes) ?? []
        locations          = try c.decodeIfPresent([Location].self, forKey: .locations) ?? []
        castOverride       = try c.decodeIfPresent([String].self, forKey: .castOverride)
        crewOverride       = try c.decodeIfPresent([String].self, forKey: .crewOverride)
        crewIDOverride     = try c.decodeIfPresent([UUID].self, forKey: .crewIDOverride)
        crewOneOffs        = try c.decodeIfPresent([String].self, forKey: .crewOneOffs)
        notes              = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    /// Resolves the raw character names (auto-pulled from scenes, or the manually-edited
    /// override) to "Actor — Character" using the *current* cast list.
    func resolvedCast(from scenes: [Scene], productionInfo: ProductionInfo? = nil) -> [String] {
        if !castCallEntries.isEmpty {
            return castCallEntries.map { entry in
                entry.actorName.isEmpty ? entry.characterName : "\(entry.actorName) — \(entry.characterName)"
            }
        }
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
    /// by ID.
    func resolvedCrew(productionInfo: ProductionInfo) -> [String] {
        if !crewCallEntries.isEmpty {
            return crewCallEntries.map { "\($0.name) — \($0.role)" }
        }
        if crewIDOverride != nil || crewOneOffs != nil {
            let roster = productionInfo.crew
            let selected = (crewIDOverride ?? []).compactMap { id in
                roster.first(where: { $0.id == id })?.displayString
            }
            return selected + (crewOneOffs ?? [])
        }
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
    var phone:          String
    var isDailyDefault: Bool

    init(name: String = "", role: String = "", phone: String = "", isDailyDefault: Bool = false) {
        self.id             = UUID()
        self.name           = name
        self.role           = role
        self.phone          = phone
        self.isDailyDefault = isDailyDefault
    }

    enum CodingKeys: String, CodingKey {
        case id, name, role, phone, isDailyDefault
    }

    init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,   forKey: .id)
        name           = try c.decode(String.self, forKey: .name)
        role           = try c.decode(String.self, forKey: .role)
        phone          = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        isDailyDefault = try c.decodeIfPresent(Bool.self, forKey: .isDailyDefault) ?? false
    }

    var displayString: String {
        role.isEmpty ? name : "\(name) — \(role)"
    }
}

// MARK: - DateRange (actor unavailability)

struct DateRange: Identifiable, Codable, Hashable {
    let id: UUID
    var start: Date
    var end: Date

    init(start: Date, end: Date) {
        self.id    = UUID()
        self.start = start
        self.end   = max(start, end)
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
    /// A numeric-aware sort key. If `sceneNumber` is populated, uses `parseSceneNumber`
    /// so scenes sort in true script order — 12, 12A, 12B, 13.
    /// Falls back to parsing a leading scene number in the title for legacy scenes.
    var scriptOrderKey: (Int, String) {
        if let parsed = Scene.parseSceneNumber(sceneNumber) {
            return (parsed.number, parsed.letter)
        }
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
    var tooltipText: String {
        var lines: [String] = [displayTitle]
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
    var directorPhone: String
    var producerName:  String
    var producerPhone: String
    var adName:        String
    var adPhone:       String
    var contactNumber: String
    var defaultLunchTime: String
    var crew:          [CrewMember]
    var castList:      [CastMember]
    var locationRoster: [Location]
    var scheduleLock: ScheduleLock?

    init(
        companyName:   String = "",
        directorName:  String = "",
        directorPhone: String = "",
        producerName:  String = "",
        producerPhone: String = "",
        adName:        String = "",
        adPhone:       String = "",
        contactNumber: String = "",
        defaultLunchTime: String = "01:30 PM",
        crew:          [CrewMember] = [],
        castList:      [CastMember] = [],
        locationRoster: [Location] = [],
        scheduleLock:  ScheduleLock? = nil
    ) {
        self.companyName      = companyName
        self.directorName     = directorName
        self.directorPhone    = directorPhone
        self.producerName     = producerName
        self.producerPhone    = producerPhone
        self.adName           = adName
        self.adPhone          = adPhone
        self.contactNumber    = contactNumber
        self.defaultLunchTime = defaultLunchTime
        self.crew             = crew
        self.castList         = castList
        self.locationRoster   = locationRoster
        self.scheduleLock     = scheduleLock
    }

    enum CodingKeys: String, CodingKey {
        case companyName, directorName, directorPhone, producerName, producerPhone, adName, adPhone, contactNumber, defaultLunchTime, crew, castList, locationRoster, scheduleLock
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        companyName      = try c.decode(String.self, forKey: .companyName)
        directorName     = try c.decode(String.self, forKey: .directorName)
        directorPhone    = try c.decodeIfPresent(String.self, forKey: .directorPhone) ?? ""
        producerName     = try c.decodeIfPresent(String.self, forKey: .producerName) ?? ""
        producerPhone    = try c.decodeIfPresent(String.self, forKey: .producerPhone) ?? ""
        adName           = try c.decodeIfPresent(String.self, forKey: .adName) ?? ""
        adPhone          = try c.decodeIfPresent(String.self, forKey: .adPhone) ?? ""
        contactNumber    = try c.decodeIfPresent(String.self, forKey: .contactNumber) ?? ""
        defaultLunchTime = try c.decodeIfPresent(String.self, forKey: .defaultLunchTime) ?? "01:30 PM"
        crew             = try c.decode([CrewMember].self, forKey: .crew)
        castList         = try c.decode([CastMember].self, forKey: .castList)
        locationRoster   = try c.decodeIfPresent([Location].self, forKey: .locationRoster) ?? []
        scheduleLock     = try c.decodeIfPresent(ScheduleLock.self, forKey: .scheduleLock)
    }
}

// MARK: - ScheduleLock

struct ScheduleLock: Codable, Equatable {
    var lockedAt: Date
    var workingDays: [String: [Date]]
}

// MARK: - ShootDay

struct ShootDay: Identifiable, Codable {
    let id:        UUID
    var date:      Date
    var scenes:    [Scene]       = []
    var callSheet: CallSheetData = CallSheetData()
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

    var dayScenes:       [Scene] { scenes.filter { $0.dayNightType == .day } }
    var nightScenes:     [Scene] { scenes.filter { $0.dayNightType == .night } }
    var dawnScenes:      [Scene] { scenes.filter { $0.dayNightType == .dawn } }
    var duskScenes:      [Scene] { scenes.filter { $0.dayNightType == .dusk } }
    var afternoonScenes: [Scene] { scenes.filter { $0.dayNightType == .afternoon } }
    var customScenes:    [Scene] { scenes.filter { $0.dayNightType == .custom } }

    var totalDayDuration:       Int { dayScenes.reduce(0)       { $0 + $1.duration } }
    var totalNightDuration:     Int { nightScenes.reduce(0)     { $0 + $1.duration } }
    var totalDawnDuration:      Int { dawnScenes.reduce(0)      { $0 + $1.duration } }
    var totalDuskDuration:      Int { duskScenes.reduce(0)      { $0 + $1.duration } }
    var totalAfternoonDuration: Int { afternoonScenes.reduce(0) { $0 + $1.duration } }

    var allCast: [String] {
        Array(Set(scenes.flatMap { $0.cast })).sorted()
    }

    var hasCallSheetData: Bool {
        !callSheet.generalCallTime.isEmpty ||
        !callSheet.lunchTime.isEmpty       ||
        !callSheet.locations.isEmpty       ||
        !callSheet.castCallEntries.isEmpty ||
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
