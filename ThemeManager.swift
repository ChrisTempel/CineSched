// ThemeManager.swift
// Color Theme System for CineSched (System Normal, Ocean Blue, Emerald Green, Sunny Yellow) with Light and Dark mode variants.

import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case blue   = "blue"
    case green  = "green"
    case yellow = "yellow"

    var localizedName: String {
        switch self {
        case .system: return L("System Normal")
        case .blue:   return L("Ocean Blue")
        case .green:  return L("Emerald Green")
        case .yellow: return L("Sunny Yellow")
        }
    }

    // Palette HEX Mapping for Blue:
    // 1: #6CAEED (Primary Accent)
    // 2: #89CFF0 (Secondary Highlight)
    // 3: #BDE0FE (Selection Border / Hover)
    // 4: #DDEEFA (Panel & Card Background in Light Mode)
    // 5: #FCFBF5 (Canvas Background in Light Mode)

    func primaryAccent(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return .accentColor
        case .blue:
            return Color(hex: "6CAEED")
        case .green:
            return isDarkMode ? Color(hex: "5CD182") : Color(hex: "4EBA6F")
        case .yellow:
            return isDarkMode ? Color(hex: "FACC15") : Color(hex: "EAB308")
        }
    }

    func secondaryHighlight(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return .accentColor.opacity(0.8)
        case .blue:
            return Color(hex: "89CFF0")
        case .green:
            return Color(hex: "7AD995")
        case .yellow:
            return Color(hex: "FDE047")
        }
    }

    func selectionBorder(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return .accentColor
        case .blue:
            return Color(hex: "BDE0FE")
        case .green:
            return Color(hex: "B3EBBF")
        case .yellow:
            return Color(hex: "FEF08A")
        }
    }

    func activeTabColor(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return .accentColor
        case .blue:
            return Color(hex: "6CAEED")
        case .green:
            return isDarkMode ? Color(hex: "4EBA6F") : Color(hex: "3DA65C")
        case .yellow:
            return isDarkMode ? Color(hex: "EAB308") : Color(hex: "CA8A04")
        }
    }

    func canvasBackground(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return Color(NSColor.windowBackgroundColor)
        case .blue:
            return isDarkMode ? Color(hex: "121A24") : Color(hex: "FCFBF5")
        case .green:
            return isDarkMode ? Color(hex: "122016") : Color(hex: "F9FCF8")
        case .yellow:
            return isDarkMode ? Color(hex: "201C12") : Color(hex: "FEFCE8")
        }
    }

    func panelBackground(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return Color(NSColor.controlBackgroundColor)
        case .blue:
            return isDarkMode ? Color(hex: "1C2634") : Color(hex: "DDEEFA")
        case .green:
            return isDarkMode ? Color(hex: "1A2F20") : Color(hex: "DCF7E3")
        case .yellow:
            return isDarkMode ? Color(hex: "2E2818") : Color(hex: "FEF9C3")
        }
    }

    func shootDayRangeHighlight(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return Color.accentColor.opacity(isDarkMode ? 0.22 : 0.09)
        case .blue:
            return Color(hex: "89CFF0").opacity(isDarkMode ? 0.25 : 0.16)
        case .green:
            return Color(hex: "86EFAC").opacity(isDarkMode ? 0.25 : 0.18)
        case .yellow:
            return Color(hex: "FEF08A").opacity(isDarkMode ? 0.25 : 0.20)
        }
    }

    func shootDayBorderColor(isDarkMode: Bool) -> Color {
        switch self {
        case .system:
            return Color.accentColor.opacity(0.4)
        case .blue:
            return Color(hex: "6CAEED").opacity(0.5)
        case .green:
            return Color(hex: "4EBA6F").opacity(0.5)
        case .yellow:
            return Color(hex: "EAB308").opacity(0.5)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
