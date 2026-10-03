// Formatting.swift
// Shared formatting helpers used across views and PDF export

import Foundation

/// Returns the appropriate Locale based on current app language
func appLocale() -> Locale {
    LocalizationManager.shared.currentLanguage == .spanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
}

/// Returns a short date string, e.g. "Mon Jun 2" or "Lun 2 Jun"
func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.dateFormat = LocalizationManager.shared.currentLanguage == .spanish ? "E d MMM" : "E MMM d"
    return formatter.string(from: date).capitalized
}

/// Returns a full date string, e.g. "Tuesday, October 6, 2026" or "Martes, 6 de octubre de 2026"
func formattedFullDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.dateFormat = LocalizationManager.shared.currentLanguage == .spanish ? "EEEE, d 'de' MMMM, yyyy" : "EEEE, MMMM d, yyyy"
    return formatter.string(from: date).capitalized
}

/// Returns weekday name in the current language, e.g. "Monday" / "Lunes"
func weekdayName(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = appLocale()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date).capitalized
}

/// Returns a minute count as "H:MM", e.g. 510 -> "8:30" — used by the
/// stripboard's "END OF DAY" marker; distinct from formattedTime's word-based
/// "8 hr 30 min" style used elsewhere.
func formattedTimeHM(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins  = minutes % 60
    return "\(hours):\(String(format: "%02d", mins))"
}

/// Returns an eighths-of-a-page count as a readable fraction string.
func formattedEighths(_ totalEighths: Int) -> String {
    FractionParser.formatEighths(totalEighths)
}

/// Returns a minute count as a readable time string.
func formattedTime(_ minutes: Int) -> String {
    TimeParser.formatMinutes(minutes)
}

/// Weekday component is 1-7 with 1 = Sunday, 7 = Saturday in the Gregorian
/// calendar, regardless of locale — independent of any calendar grid's own
/// first-day-of-week display setting.
func isWeekend(_ date: Date) -> Bool {
    let weekday = Calendar.current.component(.weekday, from: date)
    return weekday == 1 || weekday == 7
}

/// Maps each ShootDay's id to its "Day N" production-day number — the Nth
/// day, in date order, that has at least one actual script scene scheduled (excluding calendar-only events).
func productionDayNumbers(for shootDays: [ShootDay]) -> [UUID: Int] {
    var result: [UUID: Int] = [:]
    var counter = 0
    for day in shootDays {
        let hasScriptScenes = day.scenes.contains { !$0.isCalendarEvent }
        if hasScriptScenes && !day.isBlackout {
            counter += 1
            result[day.id] = counter
        }
    }
    return result
}

/// Generates an array of ShootDays between two dates (inclusive).
func generateDays(from startDate: Date, to endDate: Date) -> [ShootDay] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 1 // Sunday

    var days: [ShootDay] = []
    var current = calendar.startOfDay(for: startDate)
    let end     = calendar.startOfDay(for: endDate)

    while current <= end {
        days.append(ShootDay(date: current))
        current = calendar.date(byAdding: .day, value: 1, to: current)!
    }
    return days
}

/// Parses "11:00 AM", "01:30 PM", or "11:00" into total minutes from midnight
func parseTimeToMinutes(_ raw: String) -> Int? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces).uppercased()
    guard !trimmed.isEmpty else { return nil }

    let isPM = trimmed.contains("PM")
    let isAM = trimmed.contains("AM")

    let clean = trimmed.replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "").trimmingCharacters(in: .whitespaces)
    let parts = clean.components(separatedBy: ":")
    if parts.count == 2, var h = Int(parts[0]), let m = Int(parts[1]) {
        if isPM && h < 12 { h += 12 }
        if isAM && h == 12 { h = 0 }
        return h * 60 + m
    }
    if let h = Int(clean) {
        return h * 60
    }
    return nil
}

/// Formats total minutes from midnight into 12-hour or 24-hour clock string (e.g. 690 -> "11:30 AM")
func formatMinutesToClock(_ minutes: Int) -> String {
    let totalMinutes = (minutes % 1440 + 1440) % 1440
    let h24 = totalMinutes / 60
    let m = totalMinutes % 60
    let isPM = h24 >= 12
    let h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
    let ampm = isPM ? "PM" : "AM"
    return String(format: "%02d:%02d %@", h12, m, ampm)
}
