// Formatting.swift
// Shared formatting helpers used across views and PDF export

import Foundation

/// Returns a short date string, e.g. "Mon Jun 2"
func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E MMM d"
    return formatter.string(from: date)
}

/// Returns an eighths-of-a-page count as a readable fraction string.
func formattedEighths(_ totalEighths: Int) -> String {
    FractionParser.formatEighths(totalEighths)
}

/// Returns a minute count as a readable time string.
func formattedTime(_ minutes: Int) -> String {
    TimeParser.formatMinutes(minutes)
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
