// SceneColorSettings.swift
// User-customizable scene strip colors. Scene.stripColor is the single source of truth
// for every scene color in the app — the calendar, Stripboard, and both PDF exporters all
// derive from it — so making it read from here covers all of them automatically.

import SwiftUI
import AppKit

/// Every distinct color slot Scene.stripColor's (interior/exterior × time-of-day) matrix
/// can produce, plus Custom. Matches that matrix exactly so customizing a slot here changes
/// the same cell everywhere it's used.
enum SceneColorSlot: String, CaseIterable, Identifiable {
    case intDay, extDay, intNight, extNight, intDawn, extDawn, intDusk, extDusk, intAfternoon, extAfternoon, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .intDay:       return "INT. Day"
        case .extDay:       return "EXT. Day"
        case .intNight:     return "INT. Night"
        case .extNight:     return "EXT. Night"
        case .intDawn:      return "INT. Dawn"
        case .extDawn:      return "EXT. Dawn"
        case .intDusk:      return "INT. Dusk"
        case .extDusk:      return "EXT. Dusk"
        case .intAfternoon: return "INT. Afternoon"
        case .extAfternoon: return "EXT. Afternoon"
        case .custom:       return "Custom"
        }
    }

    /// The original hardcoded values Scene.stripColor always used — unchanged, just moved
    /// here so a non-customized slot still looks exactly like it did before.
    var defaultHex: String {
        switch self {
        case .intDay:       return "F3F4F6"
        case .extDay:       return "FEF08A"
        case .intNight:     return "86EFAC"
        case .extNight:     return "93C5FD"
        case .intDawn:      return "FDE68A"
        case .extDawn:      return "FCD34D"
        case .intDusk:      return "E9D5FF"
        case .extDusk:      return "C084FC"
        case .intAfternoon: return "FFE4C4"
        case .extAfternoon: return "FDBA74"
        case .custom:       return "D1D5DB"
        }
    }
}

/// Reads/writes overrides directly via UserDefaults rather than @AppStorage — stripColor is
/// a plain computed property on Scene, not a SwiftUI View, so it can't use a property wrapper.
enum SceneColorSettings {
    private static func key(for slot: SceneColorSlot) -> String {
        "CineSchedSceneColor_\(slot.rawValue)"
    }

    static func hex(for slot: SceneColorSlot) -> String {
        UserDefaults.standard.string(forKey: key(for: slot)) ?? slot.defaultHex
    }

    static func color(for slot: SceneColorSlot) -> Color {
        Color(hex: hex(for: slot))
    }

    static func setHex(_ hex: String, for slot: SceneColorSlot) {
        UserDefaults.standard.set(hex, forKey: key(for: slot))
    }

    static func resetToDefaults() {
        for slot in SceneColorSlot.allCases {
            UserDefaults.standard.removeObject(forKey: key(for: slot))
        }
    }
}

extension Color {
    /// Best-effort hex string for persisting a user-picked color from a ColorPicker.
    /// Rounds to 8-bit sRGB, which is plenty of precision for a strip-color swatch.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
