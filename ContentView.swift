// CineSched - SwiftUI macOS App (Tahoe Compatible) 

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import PDFKit
import AppKit


// MARK: - Fraction Parser Utility

struct FractionParser {
    /// Converts various fraction formats to eighths
    /// Supports: "15", "1 7/8", "7/8", "2.5", "1.875"
    static func parseToEighths(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty input
        if trimmed.isEmpty { return nil }
        
        // Check if it's a simple integer (already in eighths)
        if let simpleInt = Int(trimmed) {
            return simpleInt
        }
        
        // Check if it's a decimal number (convert to eighths)
        if let decimal = Double(trimmed) {
            return Int(round(decimal * 8))
        }
        
        // Handle mixed fraction format: "1 7/8"
        let mixedFractionRegex = #"^(\d+)\s+(\d+)/(\d+)$"#
        if trimmed.range(of: mixedFractionRegex, options: .regularExpression) != nil {
            let components = trimmed.components(separatedBy: .whitespaces)
            if components.count == 2,
               let wholePart = Int(components[0]) {
                
                let fractionPart = components[1]
                if let fractionEighths = parseFraction(fractionPart) {
                    return (wholePart * 8) + fractionEighths
                }
            }
        }
        
        // Handle simple fraction format: "7/8"
        if trimmed.contains("/") {
            return parseFraction(trimmed)
        }
        
        return nil
    }
    
    /// Parses a simple fraction like "7/8" to eighths
    private static func parseFraction(_ fraction: String) -> Int? {
        let parts = fraction.components(separatedBy: "/")
        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]),
              denominator > 0 else {
            return nil
        }
        
        // Convert to eighths
        let eighths = (numerator * 8) / denominator
        return eighths
    }
    
    /// Formats eighths back to a readable fraction format
    static func formatEighths(_ eighths: Int) -> String {
        let wholePart = eighths / 8
        let remainder = eighths % 8
        
        switch (wholePart, remainder) {
        case (0, 0):
            return "0"
        case (0, _):
            return "\(remainder)/8"
        case (_, 0):
            return "\(wholePart)"
        default:
            return "\(wholePart) \(remainder)/8"
        }
    }
    
    /// Provides example text for the user
    static var placeholderText: String {
        return "e.g. 15, 1 7/8, 7/8"
    }
}

// MARK: - Enhanced Time Parser Utility

struct TimeParser {
    /// Converts various time formats to minutes
    /// Rules:
    /// - Numbers ≤ 14: interpreted as hours (e.g., "4" = 4 hours = 240 minutes)
    /// - Numbers > 14: interpreted as minutes (e.g., "15" = 15 minutes)
    /// - "H:MM" format: explicit hours:minutes (e.g., "2:30" = 2 hours 30 minutes = 150 minutes)
    /// - Decimal hours: (e.g., "2.5" = 2.5 hours = 150 minutes)
    static func parseToMinutes(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty input
        if trimmed.isEmpty { return nil }
        
        // Handle H:MM format (explicit hours:minutes)
        if trimmed.contains(":") {
            let components = trimmed.components(separatedBy: ":")
            guard components.count == 2,
                  let hours = Int(components[0]),
                  let minutes = Int(components[1]),
                  hours >= 0,
                  minutes >= 0,
                  minutes < 60 else {
                return nil
            }
            return (hours * 60) + minutes
        }
        
        // Handle decimal hours (e.g., "2.5" = 2.5 hours)
        if let decimal = Double(trimmed) {
            if decimal <= 14 {
                // Interpret as hours (original logic was <= 14)
                return Int(decimal * 60)
            } else {
                // Interpret as minutes
                return Int(decimal)
            }
        }
        
        // Handle integer input
        if let integer = Int(trimmed) {
            if integer <= 10 { // Original logic was <= 10
                // Interpret as hours
                return integer * 60
            } else {
                // Interpret as minutes
                return integer
            }
        }
        
        return nil
    }
    
    /// Formats minutes back to a readable time format
    static func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        switch (hours, mins) {
        case (0, 0):
            return "0 min"
        case (0, _):
            return "\(mins) min"
        case (_, 0):
            return "\(hours) hr"
        default:
            return "\(hours) hr \(mins) min"
        }
    }
    
    /// Provides example text for the user
    static var placeholderText: String {
        return "e.g. 4 (4hr), 15 (15min), 2:30 (2hr 30min)"
    }
    
    /// Provides a hint based on current input
    static func getInputHint(_ input: String) -> String? {
        guard let minutes = parseToMinutes(input) else { return nil }
        return "= \(formatMinutes(minutes))"
    }
}

// MARK: - Enhanced PDF Export Utility with Dynamic Row Heights

class PDFExporter {
    
    static func generatePDF(
        shootDays: [ShootDay],
        projectTitle: String,
        allScenes: [Scene],
        startDate: Date,
        endDate: Date
    ) -> Data? {
        
        let pageWidth: CGFloat  = 792   // US Letter landscape
        let pageHeight: CGFloat = 612
        let margin: CGFloat     = 40
        
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - 2 * margin,
            height: pageHeight - 2 * margin
        )
        
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        
        let weeks = groupDaysIntoWeeks(shootDays)
        let rowHeights = calculateIdealRowHeights(weeks: weeks)
        let cellWidth = contentRect.width / 7
        
        var pageNumber = 0
        var weekIndex = 0
        var currentY = contentRect.maxY
        
        while weekIndex < weeks.count {
            pageNumber += 1
            
            context.beginPDFPage(nil)
            let gctx = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = gctx
            
            // Header only on first page
            if pageNumber == 1 {
                let headerHeight: CGFloat = 50  // Reduced from 80 to match actual content
                let headerRect = CGRect(
                    x: contentRect.minX,
                    y: contentRect.maxY - headerHeight,
                    width: contentRect.width,
                    height: headerHeight
                )
                drawHeader(
                    in: headerRect,
                    projectTitle: projectTitle,
                    startDate: startDate,
                    endDate: endDate,
                    allScenes: allScenes,
                    shootDays: shootDays
                )
                currentY = contentRect.maxY - headerHeight - 10  // Reduced gap from 20 to 10
            } else {
                currentY = contentRect.maxY
            }
            
            var horizontalYPositionsThisPage: [CGFloat] = [currentY]
            
            // Draw as many weeks as fit on this page
            while weekIndex < weeks.count {
                let rowHeight = rowHeights[weekIndex]
                
                // Not enough space left on page?
                if currentY - rowHeight < contentRect.minY + 10 {  // small safety margin
                    break
                }
                
                let rowRect = CGRect(
                    x: contentRect.minX,
                    y: currentY - rowHeight,
                    width: contentRect.width,
                    height: rowHeight
                )
                
                drawWeekRow(week: weeks[weekIndex], in: rowRect, cellWidth: cellWidth)
                
                currentY -= rowHeight
                horizontalYPositionsThisPage.append(currentY)
                
                weekIndex += 1
            }
            
            // Draw grid lines for this page
            drawGridLinesForPage(
                horizontalLines: horizontalYPositionsThisPage,
                minX: contentRect.minX,
                maxX: contentRect.maxX,
                minY: contentRect.minY,
                maxY: contentRect.maxY
            )
            
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        
        context.closePDF()
        return pdfData as Data
    }
    
    // ────────────────────────────────────────────────
    
    private static func drawHeader(
        in rect: CGRect,
        projectTitle: String,
        startDate: Date,
        endDate: Date,
        allScenes: [Scene],
        shootDays: [ShootDay]
    ) {
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),  // Reduced from 18
            .foregroundColor: NSColor.black
        ]
        let title = NSAttributedString(string: projectTitle.isEmpty ? "Untitled Movie" : projectTitle, attributes: titleAttr)
        title.draw(in: CGRect(x: rect.minX, y: rect.maxY - 25, width: rect.width, height: 25))
        
        // Date range removed
        
        let smallAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]
        
        let scheduled = shootDays.filter { !$0.scenes.isEmpty }.count
        NSAttributedString(string: "Shoot Days: \(scheduled)", attributes: smallAttr)
            .draw(in: CGRect(x: rect.minX, y: rect.maxY - 50, width: rect.width, height: 20))
    }
    
    private static func calculateIdealRowHeights(weeks: [[ShootDay?]]) -> [CGFloat] {
        let minHeight: CGFloat = 60
        let baseHeight: CGFloat = 120
        let maxHeight: CGFloat = 220   // Increased to accommodate more scenes
        
        return weeks.map { week in
            let maxScenes = week.compactMap { $0 }.map(\.scenes.count).max() ?? 0
            
            switch maxScenes {
            case 0:       return minHeight
            case 1...2:   return minHeight + 20
            case 3...4:   return baseHeight
            case 5...7:   return baseHeight + 50  // More height for 5-7 scenes
            case 8...10:  return maxHeight - 20
            default:      return maxHeight
            }
        }
    }
    
    private static func drawWeekRow(week: [ShootDay?], in rowRect: CGRect, cellWidth: CGFloat) {
        for (col, day) in week.enumerated() {
            let cellRect = CGRect(
                x: rowRect.minX + CGFloat(col) * cellWidth,
                y: rowRect.minY,
                width: cellWidth,
                height: rowRect.height
            )
            
            if let day = day {
                drawDay(day: day, in: cellRect)
            }
        }
    }
    
    private static func drawGridLinesForPage(
        horizontalLines: [CGFloat],
        minX: CGFloat, maxX: CGFloat,
        minY: CGFloat, maxY: CGFloat
    ) {
        guard !horizontalLines.isEmpty else { return }
        
        let path = NSBezierPath()
        path.lineWidth = 0.5
        NSColor.lightGray.setStroke()
        
        // Calculate the actual content bounds (where calendar rows exist)
        let topOfContent = horizontalLines.first ?? maxY
        let bottomOfContent = horizontalLines.last ?? minY
        
        // Vertical lines – ONLY extend from bottom to top of actual calendar content
        for i in 0...7 {
            let x = minX + CGFloat(i) * ((maxX - minX) / 7)
            path.move(to: CGPoint(x: x, y: bottomOfContent))
            path.line(to: CGPoint(x: x, y: topOfContent))
        }
        
        // Horizontal lines – only the ones that exist on this page
        for y in horizontalLines {
            path.move(to: CGPoint(x: minX, y: y))
            path.line(to: CGPoint(x: maxX, y: y))
        }
        
        path.stroke()
    }
    
    private static func drawDay(day: ShootDay, in rect: CGRect) {
        let padding: CGFloat = 8
        let contentRect = CGRect(
            x: rect.minX + padding,
            y: rect.minY + padding,
            width: rect.width - 2 * padding,
            height: rect.height - 2 * padding
        )
        
        // Date header - positioned at TOP of cell (maxY)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E MMM d"
        let dateString = dateFormatter.string(from: day.date)
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor.black
        ]
        
        let dateAttrString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateRect = CGRect(x: contentRect.minX, y: contentRect.maxY - 12, width: contentRect.width, height: 12)
        dateAttrString.draw(in: dateRect)
        
        // Calculate available space for scenes
        let availableSceneHeight = contentRect.height - 16 - (day.scenes.isEmpty ? 0 : 25) // Reserve space for date and totals
        
        // FIXED: Use consistent small font (8pt) and calculate box height needed
        let fontSize: CGFloat = 8
        let boxHeightPerScene: CGFloat = 11 // 8pt font + 3pt padding
        
        // Scenes - start from just below the date
        var yOffset: CGFloat = 16 // Offset from top
        
        let sceneAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.black
        ]
        
        // Calculate how many scenes we can actually fit
        let maxVisibleScenes = Int(availableSceneHeight / boxHeightPerScene)
        let scenesToShow = min(day.scenes.count, maxVisibleScenes)
        
        for i in 0..<scenesToShow {
            let scene = day.scenes[i]
            
            // Create scene box with consistent height
            let boxHeight = boxHeightPerScene
            let boxRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - yOffset - boxHeight,
                width: contentRect.width,
                height: boxHeight
            )
            
            // Draw box background based on day/night type
            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 2, yRadius: 2)
            if scene.dayNightType == .night {
                NSColor(white: 0.9, alpha: 1.0).setFill() // Light gray for night scenes
            } else {
                NSColor.white.setFill() // White for day scenes
            }
            boxPath.fill()
            
            // Draw box border
            NSColor.lightGray.setStroke()
            boxPath.lineWidth = 0.5
            boxPath.stroke()
            
            // Draw scene text - centered vertically in the box
            let sceneAttrString = NSAttributedString(string: scene.title, attributes: sceneAttributes)
            let textRect = CGRect(
                x: contentRect.minX + 3,
                y: contentRect.maxY - yOffset - boxHeight + 1.5,  // Position from bottom of box with small padding
                width: contentRect.width - 6,
                height: fontSize + 2  // Give a little extra height
            )
            sceneAttrString.draw(in: textRect)
            
            yOffset += boxHeightPerScene
        }
        
        // Show "more" indicator if we couldn't fit all scenes
        if day.scenes.count > scenesToShow {
            let remainingCount = day.scenes.count - scenesToShow
            let moreText = "... +\(remainingCount) more"
            let moreAttrString = NSAttributedString(string: moreText, attributes: sceneAttributes)
            let moreRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - yOffset - fontSize,
                width: contentRect.width,
                height: fontSize
            )
            moreAttrString.draw(in: moreRect)
        }
        
        // Totals at bottom of cell
        if !day.scenes.isEmpty {
            let totalText = "Total: \(formattedEighths(day.totalDuration))\nEst: \(formattedTime(day.totalEstimatedTime))"
            
            let totalAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7),
                .foregroundColor: NSColor.gray
            ]
            
            let totalAttrString = NSAttributedString(string: totalText, attributes: totalAttributes)
            let totalRect = CGRect(
                x: contentRect.minX,
                y: contentRect.minY,
                width: contentRect.width,
                height: 20
            )
            totalAttrString.draw(in: totalRect)
        }
    }
    
    private static func groupDaysIntoWeeks(_ shootDays: [ShootDay]) -> [[ShootDay?]] {
        guard !shootDays.isEmpty else { return [] }
        
        let cal = Calendar.current
        var weeks: [[ShootDay?]] = []
        var currentWeek = Array(repeating: ShootDay?.none, count: 7)
        
        var date = cal.startOfDay(for: shootDays.first!.date)
        let end = cal.startOfDay(for: shootDays.last!.date)
        var idx = 0
        
        while date <= end {
            let weekday = cal.component(.weekday, from: date) - 1   // 0 = Sun
            
            let matching = (idx < shootDays.count && cal.isDate(shootDays[idx].date, inSameDayAs: date))
                ? shootDays[idx] : nil
            
            if matching != nil { idx += 1 }
            
            currentWeek[weekday] = matching ?? ShootDay(date: date)
            
            if weekday == 6 || date == end {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
            }
            
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        
        return weeks
    }
}
    
    // MARK: - Dynamic Calendar Grid with Variable Row Heights
    
private func drawDynamicCalendarGrid(in rect: NSRect, shootDays: [ShootDay]) {
        let columns = 7
        let cellWidth = rect.width / CGFloat(columns)
        
        // Group days into weeks
        let weeks = groupDaysIntoWeeks(shootDays)
        
        // Calculate row heights based on content
        let rowHeights = calculateRowHeights(weeks: weeks, availableHeight: rect.height)
        
        // Draw the dynamic grid
        var currentY = rect.maxY
        
        for (weekIndex, week) in weeks.enumerated() {
            let rowHeight = rowHeights[weekIndex]
            let rowRect = NSRect(
                x: rect.minX,
                y: currentY - rowHeight,
                width: rect.width,
                height: rowHeight
            )
            
            drawWeekRow(week: week, in: rowRect, cellWidth: cellWidth)
            currentY -= rowHeight
        }
        
        // Draw grid lines
        drawGridLines(in: rect, weeks: weeks, rowHeights: rowHeights, cellWidth: cellWidth)
    }
    
private func groupDaysIntoWeeks(_ shootDays: [ShootDay]) -> [[ShootDay?]] {
        guard let firstDay = shootDays.first else { return [] }
        
        let calendar = Calendar.current
        var weeks: [[ShootDay?]] = []
        var currentWeek: [ShootDay?] = Array(repeating: nil, count: 7)
        
        // Ensure iteration starts from the start of the first day and ends at the end of the last day
        var currentDate = calendar.startOfDay(for: firstDay.date)
        let endDate = calendar.startOfDay(for: shootDays.last?.date ?? firstDay.date)
        var dayIndex = 0
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate) - 1 // 0-6 (Sunday-Saturday)
            
            // Find matching shoot day
            let matchingDay = dayIndex < shootDays.count &&
                             calendar.isDate(shootDays[dayIndex].date, inSameDayAs: currentDate) ?
                             shootDays[dayIndex] : nil
            
            if matchingDay != nil {
                dayIndex += 1
            }
            
            currentWeek[weekday] = matchingDay ?? ShootDay(date: currentDate)
            
            // If we've reached Saturday or it's the last day, complete the week
            if weekday == 6 || calendar.isDate(currentDate, inSameDayAs: endDate) {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return weeks
    }
    
private func calculateRowHeights(weeks: [[ShootDay?]], availableHeight: CGFloat) -> [CGFloat] {
        let minRowHeight: CGFloat = 60  // Minimum height for empty/light weeks
        let baseRowHeight: CGFloat = 100 // Standard height for weeks with 1-4 scenes per day
        let maxRowHeight: CGFloat = 160  // Maximum height for heavy weeks
        
        var rowHeights: [CGFloat] = []
        var totalDynamicHeight: CGFloat = 0
        
        // First pass: calculate ideal heights
        for week in weeks {
            let maxScenesInWeek = week.compactMap { $0 }.map { $0.scenes.count }.max() ?? 0
            
            let height: CGFloat
            switch maxScenesInWeek {
            case 0:
                height = minRowHeight
            case 1...2:
                height = minRowHeight + 20 // Slightly taller for 1-2 scenes
            case 3...4:
                height = baseRowHeight
            case 5...7:
                height = baseRowHeight + 30 // Taller for 5-7 scenes
            default:
                height = maxRowHeight // Maximum height for 8+ scenes
            }
            
            rowHeights.append(height)
            totalDynamicHeight += height
        }
        
        // Second pass: scale heights if they don't fit
        if totalDynamicHeight > availableHeight {
            let scaleFactor = availableHeight / totalDynamicHeight
            rowHeights = rowHeights.map { max(minRowHeight, $0 * scaleFactor) }
        } else if totalDynamicHeight < availableHeight && !weeks.isEmpty {
            // Distribute extra space proportionally
            let extraSpace = availableHeight - totalDynamicHeight
            let totalWeight = rowHeights.reduce(0, +)
            
            if totalWeight > 0 {
                rowHeights = rowHeights.map { height in
                    height + (extraSpace * (height / totalWeight))
                }
            }
        }
        
        return rowHeights
    }
    
private func drawWeekRow(week: [ShootDay?], in rowRect: NSRect, cellWidth: CGFloat) {
        for (columnIndex, day) in week.enumerated() {
            let cellRect = NSRect(
                x: rowRect.minX + CGFloat(columnIndex) * cellWidth,
                y: rowRect.minY,
                width: cellWidth,
                height: rowRect.height
            )
            
            if let shootDay = day {
                drawDay(day: shootDay, in: cellRect)
            } else {
                // Draw empty day
                drawEmptyDay(in: cellRect)
            }
        }
    }
    
private func drawGridLines(
        in rect: NSRect,
        weeks: [[ShootDay?]],
        rowHeights: [CGFloat],
        cellWidth: CGFloat
    ) {
        NSColor.lightGray.setStroke()
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5
        
        // Vertical lines
        for col in 0...7 {
            let x = rect.minX + CGFloat(col) * cellWidth
            gridPath.move(to: NSPoint(x: x, y: rect.minY))
            gridPath.line(to: NSPoint(x: x, y: rect.maxY))
        }
        
        // Horizontal lines
        var currentY = rect.maxY
        gridPath.move(to: NSPoint(x: rect.minX, y: currentY))
        gridPath.line(to: NSPoint(x: rect.maxX, y: currentY))
        
        for rowHeight in rowHeights {
            currentY -= rowHeight
            gridPath.move(to: NSPoint(x: rect.minX, y: currentY))
            gridPath.line(to: NSPoint(x: rect.maxX, y: currentY))
        }
        
        gridPath.stroke()
    }
    
private func drawDay(day: ShootDay, in rect: NSRect) {
        let padding: CGFloat = 8
        let contentRect = NSRect(
            x: rect.minX + padding,
            y: rect.minY + padding,
            width: rect.width - 2 * padding,
            height: rect.height - 2 * padding
        )
        
        // Date header - positioned at TOP of cell (maxY)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E MMM d"
        let dateString = dateFormatter.string(from: day.date)
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor.black
        ]
        
        let dateAttrString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateRect = NSRect(x: contentRect.minX, y: contentRect.maxY - 12, width: contentRect.width, height: 12)
        dateAttrString.draw(in: dateRect)
        
        // Calculate available space for scenes
        let availableSceneHeight = contentRect.height - 16 - (day.scenes.isEmpty ? 0 : 25) // Reserve space for date and totals
        let sceneHeight: CGFloat = max(8, min(12, availableSceneHeight / CGFloat(max(1, day.scenes.count))))
        
        // Scenes - start from just below the date
        var yOffset: CGFloat = 16 // Offset from top
        let sceneAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(9, sceneHeight * 0.8)),
            .foregroundColor: NSColor.black
        ]
        
        let maxVisibleScenes = Int(availableSceneHeight / sceneHeight)
        let scenesToShow = min(day.scenes.count, maxVisibleScenes)
        
        for i in 0..<scenesToShow {
            let scene = day.scenes[i]
            
            // Create scene box
            let boxHeight = sceneHeight + 4 // Add some padding
            let boxRect = NSRect(
                x: contentRect.minX,
                y: contentRect.maxY - yOffset - boxHeight,
                width: contentRect.width,
                height: boxHeight
            )
            
            // Draw box background based on day/night type
            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 2, yRadius: 2)
            if scene.dayNightType == .night {
                NSColor(white: 0.9, alpha: 1.0).setFill() // Light gray for night scenes
            } else {
                NSColor.white.setFill() // White for day scenes
            }
            boxPath.fill()
            
            // Draw box border
            NSColor.lightGray.setStroke()
            boxPath.lineWidth = 0.5
            boxPath.stroke()
            
            // Draw scene text
            let sceneAttrString = NSAttributedString(string: scene.title, attributes: sceneAttributes)
            let textRect = NSRect(
                x: contentRect.minX + 4, // Add left padding
                y: contentRect.maxY - yOffset - sceneHeight,
                width: contentRect.width - 8, // Subtract padding from both sides
                height: sceneHeight
            )
            sceneAttrString.draw(in: textRect)
            
            yOffset += sceneHeight + 2 // Add some space between boxes
        }
        
        // Show "more" indicator if we couldn't fit all scenes
        if day.scenes.count > scenesToShow {
            let remainingCount = day.scenes.count - scenesToShow
            let moreText = "... +\(remainingCount) more"
            let moreAttrString = NSAttributedString(string: moreText, attributes: sceneAttributes)
            let moreRect = NSRect(
                x: contentRect.minX,
                y: contentRect.maxY - yOffset - sceneHeight,
                width: contentRect.width,
                height: sceneHeight
            )
            moreAttrString.draw(in: moreRect)
        }
        
        // Totals at bottom of cell
        if !day.scenes.isEmpty {
            let totalText = "Total: \(formattedEighths(day.totalDuration))\nEst: \(formattedTime(day.totalEstimatedTime))"
            
            let totalAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7),
                .foregroundColor: NSColor.gray
            ]
            
            let totalAttrString = NSAttributedString(string: totalText, attributes: totalAttributes)
            let totalRect = NSRect(
                x: contentRect.minX,
                y: contentRect.minY,
                width: contentRect.width,
                height: 20
            )
            totalAttrString.draw(in: totalRect)
        }
    }
    
private func drawEmptyDay(in rect: NSRect) {
        let padding: CGFloat = 8
        _ = NSRect(
            x: rect.minX + padding,
            y: rect.minY + padding,
            width: rect.width - 2 * padding,
            height: rect.height - 2 * padding
        )
        
        // Just draw the date for empty days
        _ = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E MMM d"
        
        // This is a placeholder - in a real implementation you'd pass the actual date
        // For now, we'll just leave it empty since this is called for nil days
        // You might want to modify the calling code to pass the date
    }


// Extension to convert NSRect to CGRect
extension NSRect {
    func toCGRect() -> CGRect {
        return CGRect(x: self.origin.x, y: self.origin.y, width: self.size.width, height: self.size.height)
    }
}

// MARK: - Models

enum DayNightType: String, Codable, CaseIterable {
    case day = "DAY"
    case night = "NIGHT"
    
    var color: Color {
        switch self {
        case .day:
            return Color.orange
        case .night:
            return Color.blue
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

struct Scene: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var duration: Int // eighths
    var estimatedTime: Int // minutes
    var dayNightType: DayNightType // NEW: Day/Night classification
    
    init(title: String, duration: Int, estimatedTime: Int, dayNightType: DayNightType = .day) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.estimatedTime = estimatedTime
        self.dayNightType = dayNightType
    }
}

struct ShootDay: Identifiable, Codable {
    let id: UUID
    var date: Date
    var scenes: [Scene] = []

    // MODIFIED: Init now takes optional scenes array for flexibility in shifting/merging
    init(date: Date, scenes: [Scene] = []) {
        self.id = UUID()
        self.date = date
        self.scenes = scenes
    }

    var totalDuration: Int {
        scenes.reduce(0) { $0 + $1.duration }
    }

    var totalEstimatedTime: Int {
        scenes.reduce(0) { $0 + $1.estimatedTime }
    }
    
    // NEW: Separate totals for day and night scenes
    var dayScenes: [Scene] {
        scenes.filter { $0.dayNightType == .day }
    }
    
    var nightScenes: [Scene] {
        scenes.filter { $0.dayNightType == .night }
    }
    
    var totalDayDuration: Int {
        dayScenes.reduce(0) { $0 + $1.duration }
    }
    
    var totalNightDuration: Int {
        nightScenes.reduce(0) { $0 + $1.duration }
    }
}

struct ProjectData: Codable {
    var allScenes: [Scene]
    var shootDays: [ShootDay]
    var projectTitle: String
    var createdDate: Date
    // NEW: Save the shift mode preference
    var isShiftModeEnabled: Bool?
    
    init(allScenes: [Scene], shootDays: [ShootDay], projectTitle: String = "Untitled Movie", isShiftModeEnabled: Bool? = false) {
        self.allScenes = allScenes
        self.shootDays = shootDays
        self.projectTitle = projectTitle
        self.createdDate = Date()
        self.isShiftModeEnabled = isShiftModeEnabled
    }
}

// MARK: - Enhanced Scene Editing Sheet View with Improved Time Input

struct SceneEditSheet: View {
    @Binding var scene: Scene
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onDelete: () -> Void
    
    @State private var editTitle: String = ""
    @State private var editDuration: String = ""
    @State private var editEstimatedTime: String = ""
    @State private var editDayNightType: DayNightType = .day
    
    // Validation states
    @State private var durationIsValid: Bool = true
    @State private var estimatedTimeIsValid: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Scene")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Scene Title")
                    .font(.headline)
                TextField("Scene Title", text: $editTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration (pages)")
                        .font(.headline)
                    TextField(FractionParser.placeholderText, text: $editDuration)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .border(durationIsValid ? Color.clear : Color.red, width: 1)
                        .onChange(of: editDuration) {
                            validateDuration()
                        }
                    
                    if !durationIsValid {
                        Text("Invalid format. Use: 15 (eighths), 1 7/8 (mixed), or 7/8 (fraction)")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !editDuration.isEmpty {
                        if let eighths = FractionParser.parseToEighths(editDuration) {
                            Text("= \(FractionParser.formatEighths(eighths)) pages (\(eighths) eighths)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Time")
                        .font(.headline)
                    TextField(TimeParser.placeholderText, text: $editEstimatedTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .border(estimatedTimeIsValid ? Color.clear : Color.red, width: 1)
                        .onChange(of: editEstimatedTime) {
                            validateEstimatedTime()
                        }
                    
                    if !estimatedTimeIsValid {
                        Text("Invalid format. Use: 4 (4 hours), 15 (15 minutes), or 2:30 (2hr 30min)")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !editEstimatedTime.isEmpty {
                        if let hint = TimeParser.getInputHint(editEstimatedTime) {
                            Text(hint)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Day/Night Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time of Day")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        ForEach(DayNightType.allCases, id: \.self) { type in
                            HStack(spacing: 8) {
                                Button(action: {
                                    editDayNightType = type
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: editDayNightType == type ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(editDayNightType == type ? type.color : .secondary)
                                        
                                        Text(type.displayName)
                                            .foregroundColor(editDayNightType == type ? type.color : .primary)
                                            .fontWeight(editDayNightType == type ? .semibold : .regular)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // Color indicator
                                Circle()
                                    .fill(type.color)
                                    .frame(width: 12, height: 12)
                                    .opacity(editDayNightType == type ? 1.0 : 0.5)
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button("Delete Scene") {
                    onDelete()
                    isPresented = false
                }
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Save Changes") {
                    saveChanges()
                    onSave()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidInput())
            }
        }
        .padding(24)
        .frame(width: 500)
        .onAppear {
            editTitle = scene.title
            editDuration = FractionParser.formatEighths(scene.duration)
            editEstimatedTime = TimeParser.formatMinutes(scene.estimatedTime)
            editDayNightType = scene.dayNightType
            validateDuration()
            validateEstimatedTime()
        }
    }
    
    private func validateDuration() {
        durationIsValid = FractionParser.parseToEighths(editDuration) != nil || editDuration.isEmpty
    }
    
    private func validateEstimatedTime() {
        estimatedTimeIsValid = TimeParser.parseToMinutes(editEstimatedTime) != nil || editEstimatedTime.isEmpty
    }
    
    private func saveChanges() {
        scene.title = editTitle
        scene.dayNightType = editDayNightType
        
        if let parsedDuration = FractionParser.parseToEighths(editDuration) {
            scene.duration = parsedDuration
        }
        
        if let parsedTime = TimeParser.parseToMinutes(editEstimatedTime) {
            scene.estimatedTime = parsedTime
        }
    }
    
    private func isValidInput() -> Bool {
        let titleValid = !editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let durationValid = FractionParser.parseToEighths(editDuration) != nil && FractionParser.parseToEighths(editDuration)! > 0
        let timeValid = TimeParser.parseToMinutes(editEstimatedTime) != nil && TimeParser.parseToMinutes(editEstimatedTime)! > 0
        
        return titleValid && durationValid && timeValid
    }
}

// MARK: - Enhanced New Scene Input with Improved Time Input

struct NewSceneInputView: View {
    @Binding var newSceneTitle: String
    @Binding var newDuration: String
    @Binding var newEstimate: String
    @Binding var allScenes: [Scene]
    let onSceneAdded: () -> Void
    
    @State private var durationIsValid: Bool = true
    @State private var estimatedTimeIsValid: Bool = true
    @State private var newDayNightType: DayNightType = .day
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Scene").font(.headline)
            
            TextField("Scene Title", text: $newSceneTitle)
            
            VStack(alignment: .leading, spacing: 4) {
                TextField(FractionParser.placeholderText, text: $newDuration)
                    .border(durationIsValid ? Color.clear : Color.red, width: 1)
                    .onChange(of: newDuration) {
                        validateDuration()
                    }
                
                if !durationIsValid && !newDuration.isEmpty {
                    Text("Invalid format")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !newDuration.isEmpty {
                    if let eighths = FractionParser.parseToEighths(newDuration) {
                        Text("= \(FractionParser.formatEighths(eighths)) pages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField(TimeParser.placeholderText, text: $newEstimate)
                    .border(estimatedTimeIsValid ? Color.clear : Color.red, width: 1)
                    .onChange(of: newEstimate) {
                        validateEstimatedTime()
                    }
                
                if !estimatedTimeIsValid && !newEstimate.isEmpty {
                    Text("Invalid time format")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !newEstimate.isEmpty {
                    if let hint = TimeParser.getInputHint(newEstimate) {
                        Text(hint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Day/Night Selection for new scenes
            HStack(spacing: 15) {
                Text("Time:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(DayNightType.allCases, id: \.self) { type in
                    Button(action: {
                        newDayNightType = type
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: newDayNightType == type ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(newDayNightType == type ? type.color : .secondary)
                                .font(.caption)
                            
                            Text(type.displayName)
                                .font(.caption)
                                .foregroundColor(newDayNightType == type ? type.color : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Add Scene") {
                addScene()
            }
            .disabled(!canAddScene())
            .padding(.top, 5)
        }
    }
    
    private func validateDuration() {
        durationIsValid = FractionParser.parseToEighths(newDuration) != nil || newDuration.isEmpty
    }
    
    private func validateEstimatedTime() {
        estimatedTimeIsValid = TimeParser.parseToMinutes(newEstimate) != nil || newEstimate.isEmpty
    }
    
    private func canAddScene() -> Bool {
        let titleValid = !newSceneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let durationValid = FractionParser.parseToEighths(newDuration) != nil && FractionParser.parseToEighths(newDuration)! > 0
        let timeValid = TimeParser.parseToMinutes(newEstimate) != nil && TimeParser.parseToMinutes(newEstimate)! > 0
        
        return titleValid && durationValid && timeValid
    }
    
    private func addScene() {
        guard let duration = FractionParser.parseToEighths(newDuration),
              let estimate = TimeParser.parseToMinutes(newEstimate),
              !newSceneTitle.isEmpty else { return }
        
        let scene = Scene(title: newSceneTitle, duration: duration, estimatedTime: estimate, dayNightType: newDayNightType)
        allScenes.append(scene)
        
        // Clear inputs
        newSceneTitle = ""
        newDuration = ""
        newEstimate = ""
        newDayNightType = .day // Reset to default
        
        onSceneAdded()
    }
}

// Enhanced CompactMonthCalendarView with improved drag & drop
struct CompactMonthCalendarView: View {
    @Binding var shootDays: [ShootDay]
    let assignScene: (Scene, ShootDay) -> Void
    @Binding var allScenes: [Scene]
    let updateScene: (Scene, UUID) -> Void
    let removeScene: (Scene, UUID) -> Void
    let projectTitle: String
    let onSceneChanged: () -> Void
    
    @State private var editingScene: Scene?
    @State private var editingDayId: UUID?
    @State private var showingEditSheet = false
    @State private var editingDayIndex: Int?
    @State private var editingSceneIndex: Int?
    
    // Drop indicator states
    @State private var dropTargetDayId: UUID?
    @State private var dropTargetPosition: Int?
    @State private var draggedSceneId: UUID?
    
    // Shared interaction state to prevent stuck visual states
    @State private var interactingSceneId: UUID?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(shootDays.enumerated()), id: \.element.id) { dayIndex, day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate(day.date))
                            .font(.caption)
                            .bold()
                            .foregroundColor(.primary)

                        // Enhanced scene list with drop zones
                        VStack(spacing: 2) {
                            ForEach(Array(day.scenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                                VStack(spacing: 0) {
                                    // Drop indicator above scene
                                    if shouldShowDropIndicator(dayId: day.id, position: sceneIndex) {
                                        DropIndicatorView()
                                    }
                                    
                                    // Scene view
                                    SceneCardView(
                                        scene: scene,
                                        dayId: day.id,
                                        dayIndex: dayIndex,
                                        sceneIndex: sceneIndex,
                                        interactingSceneId: $interactingSceneId,
                                        onEdit: { editScene(dayIndex: dayIndex, sceneIndex: sceneIndex, scene: scene, dayId: day.id) },
                                        onRemove: { removeScene(scene, day.id); onSceneChanged() },
                                        onDuplicate: { duplicateScene(scene) },
                                        onDragStart: { draggedSceneId = scene.id },
                                        onDragEnd: { draggedSceneId = nil }
                                    )
                                }
                                .onDrop(
                                    of: [UTType.text.identifier],
                                    delegate: SceneDropDelegate(
                                        dayId: day.id,
                                        position: sceneIndex,
                                        dropTargetDayId: $dropTargetDayId,
                                        dropTargetPosition: $dropTargetPosition,
                                        onDrop: { sceneId in handleSceneDrop(sceneId: sceneId, targetDayId: day.id, targetPosition: sceneIndex) }
                                    )
                                )
                            }
                            
                            // Drop indicator at the end of the list
                            if shouldShowDropIndicator(dayId: day.id, position: day.scenes.count) {
                                DropIndicatorView()
                            }
                        }

                        Spacer()
                        
                        // Day totals
                        if !day.scenes.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total: \(formattedEighths(day.totalDuration))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("Est: \(formattedTime(day.totalEstimatedTime))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .background(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                dropTargetDayId == day.id ? Color.red : Color.black,
                                lineWidth: dropTargetDayId == day.id ? 2 : 1
                            )
                    )
                    .cornerRadius(8)
                    // Drop delegate for the entire day (for empty days or dropping at the end)
                    .onDrop(
                        of: [UTType.text.identifier],
                        delegate: DayDropDelegate(
                            dayId: day.id,
                            scenes: day.scenes,
                            dropTargetDayId: $dropTargetDayId,
                            dropTargetPosition: $dropTargetPosition,
                            onDrop: { sceneId in handleSceneDrop(sceneId: sceneId, targetDayId: day.id, targetPosition: day.scenes.count) }
                        )
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let dayIndex = editingDayIndex,
               let sceneIndex = editingSceneIndex,
               dayIndex < shootDays.count,
               sceneIndex < shootDays[dayIndex].scenes.count {
                
                SceneEditSheet(
                    scene: $shootDays[dayIndex].scenes[sceneIndex],
                    isPresented: $showingEditSheet,
                    onSave: {
                        onSceneChanged()
                        clearEditingState()
                    },
                    onDelete: {
                        if let editingDayId = editingDayId {
                            let currentScene = shootDays[dayIndex].scenes[sceneIndex]
                            removeScene(currentScene, editingDayId)
                            onSceneChanged()
                        }
                        clearEditingState()
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Text("Error: Scene not found")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("The scene you're trying to edit may have been moved or deleted.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    
                    Button("Close") {
                        showingEditSheet = false
                        clearEditingState()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(width: 400)
            }
        }
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing {
                clearEditingState()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldShowDropIndicator(dayId: UUID, position: Int) -> Bool {
        return dropTargetDayId == dayId && dropTargetPosition == position
    }
    
    private func editScene(dayIndex: Int, sceneIndex: Int, scene: Scene, dayId: UUID) {
        editingDayIndex = dayIndex
        editingSceneIndex = sceneIndex
        editingScene = scene
        editingDayId = dayId
        showingEditSheet = true
    }
    
    private func duplicateScene(_ scene: Scene) {
        let duplicatedScene = Scene(
            title: scene.title + " (Copy)",
            duration: scene.duration,
            estimatedTime: scene.estimatedTime,
            dayNightType: scene.dayNightType
        )
        allScenes.append(duplicatedScene)
        onSceneChanged()
    }
    
    private func handleSceneDrop(sceneId: String, targetDayId: UUID, targetPosition: Int) {
        guard let sceneUUID = UUID(uuidString: sceneId) else { return }
        
        // Find the scene in unscheduled scenes
        if let sceneIndex = allScenes.firstIndex(where: { $0.id == sceneUUID }) {
            let scene = allScenes.remove(at: sceneIndex)
            insertSceneIntoDay(scene: scene, dayId: targetDayId, position: targetPosition)
            return
        }
        
        // Find the scene in scheduled days
        for dayIndex in 0..<shootDays.count {
            if let sceneIndex = shootDays[dayIndex].scenes.firstIndex(where: { $0.id == sceneUUID }) {
                let scene = shootDays[dayIndex].scenes.remove(at: sceneIndex)
                
                // If moving within the same day, adjust target position
                var adjustedPosition = targetPosition
                if shootDays[dayIndex].id == targetDayId && sceneIndex < targetPosition {
                    adjustedPosition -= 1
                }
                
                insertSceneIntoDay(scene: scene, dayId: targetDayId, position: adjustedPosition)
                break
            }
        }
        
        onSceneChanged()
    }
    
    private func insertSceneIntoDay(scene: Scene, dayId: UUID, position: Int) {
        guard let dayIndex = shootDays.firstIndex(where: { $0.id == dayId }) else { return }
        
        let clampedPosition = min(max(0, position), shootDays[dayIndex].scenes.count)
        shootDays[dayIndex].scenes.insert(scene, at: clampedPosition)
    }
    
    private func clearEditingState() {
        editingScene = nil
        editingDayId = nil
        editingDayIndex = nil
        editingSceneIndex = nil
    }
}

// MARK: - Scene Card View Component

struct SceneCardView: View {
    let scene: Scene
    let dayId: UUID
    let dayIndex: Int
    let sceneIndex: Int
    @Binding var interactingSceneId: UUID?
    let onEdit: () -> Void
    let onRemove: () -> Void
    let onDuplicate: () -> Void
    let onDragStart: () -> Void
    let onDragEnd: () -> Void
    
    // Use computed property based on shared state instead of local state
    private var isDragging: Bool {
        interactingSceneId == scene.id
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Color indicator circle
            Circle()
                .fill(scene.dayNightType.color)
                .frame(width: 8, height: 8)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text("(\(formattedEighths(scene.duration)), \(scene.estimatedTime) min)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(scene.dayNightType.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(scene.dayNightType.color)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(scene.dayNightType.color.opacity(isDragging ? 0.3 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(scene.dayNightType.color.opacity(isDragging ? 0.8 : 0.4), lineWidth: isDragging ? 2 : 1)
                )
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .onDrag {
            interactingSceneId = scene.id
            onDragStart()
            return NSItemProvider(object: scene.id.uuidString as NSString)
        } preview: {
            // Custom drag preview
            HStack(spacing: 4) {
                Circle()
                    .fill(scene.dayNightType.color)
                    .frame(width: 8, height: 8)
                Text(scene.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(radius: 4)
            )
        }
        .onTapGesture(count: 2) {
            // Clear any previous interaction state and set current
            interactingSceneId = nil
            onEdit()
        }
        .onTapGesture(count: 1) {
            // Clear interaction state on single tap
            interactingSceneId = nil
        }
        .contextMenu {
            Button("Edit Scene") {
                interactingSceneId = nil
                onEdit()
            }
            
            Button("Remove from Day") {
                interactingSceneId = nil
                onRemove()
            }
            
            Divider()
            
            Button("Duplicate Scene") {
                interactingSceneId = nil
                onDuplicate()
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                onDragEnd()
            }
        }
    }
}

// MARK: - Drop Indicator View

struct DropIndicatorView: View {
    var body: some View {
        Rectangle()
            .fill(Color.red)
            .frame(height: 3)
            .cornerRadius(1.5)
            .padding(.horizontal, 8)
            .opacity(0.8)
            .animation(.easeInOut(duration: 0.3), value: true)
    }
}

// MARK: - Drop Delegates

struct SceneDropDelegate: DropDelegate {
    let dayId: UUID
    let position: Int
    @Binding var dropTargetDayId: UUID?
    @Binding var dropTargetPosition: Int?
    let onDrop: (String) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.text.identifier])
    }
    
    func dropEntered(info: DropInfo) {
        dropTargetDayId = dayId
        dropTargetPosition = position
    }
    
    func dropExited(info: DropInfo) {
        if dropTargetDayId == dayId && dropTargetPosition == position {
            dropTargetDayId = nil
            dropTargetPosition = nil
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropTargetDayId = nil
            dropTargetPosition = nil
        }
        
        guard let itemProvider = info.itemProviders(for: [UTType.text.identifier]).first else {
            return false
        }
        
        itemProvider.loadObject(ofClass: NSString.self) { item, _ in
            if let idString = item as? String {
                DispatchQueue.main.async {
                    onDrop(idString)
                }
            }
        }
        
        return true
    }
}

struct DayDropDelegate: DropDelegate {
    let dayId: UUID
    let scenes: [Scene]
    @Binding var dropTargetDayId: UUID?
    @Binding var dropTargetPosition: Int?
    let onDrop: (String) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.text.identifier])
    }
    
    func dropEntered(info: DropInfo) {
        // Only show day-level drop target if there are no scenes
        if scenes.isEmpty {
            dropTargetDayId = dayId
            dropTargetPosition = 0
        }
    }
    
    func dropExited(info: DropInfo) {
        if dropTargetDayId == dayId && scenes.isEmpty {
            dropTargetDayId = nil
            dropTargetPosition = nil
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropTargetDayId = nil
            dropTargetPosition = nil
        }
        
        guard let itemProvider = info.itemProviders(for: [UTType.text.identifier]).first else {
            return false
        }
        
        itemProvider.loadObject(ofClass: NSString.self) { item, _ in
            if let idString = item as? String {
                DispatchQueue.main.async {
                    onDrop(idString)
                }
            }
        }
        
        return true
    }
}

// MARK: - FIXED ContentView with Native Save Dialog

struct ContentView: View {
    @State private var allScenes: [Scene] = []
    @State private var shootDays: [ShootDay] = generateDays(
        from: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
        to: Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    )
    @State private var startDate: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

    @State private var newSceneTitle: String = ""
    @State private var newDuration: String = ""
    @State private var newEstimate: String = ""

    @State private var showingFileImporter = false
    @State private var showingPDFExporter = false
    @State private var documentURL: URL? = nil
    
    // Add alert states for user feedback
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var projectTitle: String = "Untitled Movie"
    
    // Clear All confirmation
    @State private var showingClearAllConfirmation = false
    
    // Auto-save functionality
    @State private var autoSaveTimer: Timer?
    
    // States for editing unscheduled scenes
    @State private var editingUnscheduledScene: Scene?
    @State private var showingUnscheduledSceneEditSheet = false
    @State private var editingUnscheduledSceneIndex: Int?
    
    // Dark/Light mode state
    @State private var isDarkMode: Bool = false
    
    // NEW: Toggle for schedule shifting vs. merging (default is merge/lock)
    @State private var isShiftModeEnabled: Bool = false

    // MARK: - Computed Properties for Compact Statistics
    private var scheduledDays: [ShootDay] {
        shootDays.filter { !$0.scenes.isEmpty }
    }

    private var totalScenes: Int {
        scheduledDays.reduce(0) { $0 + $1.scenes.count }
    }

    private var totalDuration: String {
        let total = scheduledDays.reduce(0) { $0 + $1.totalDuration }
        return formattedEighths(total)
    }

    private var totalEstimatedTime: String {
        let total = scheduledDays.reduce(0) { $0 + $1.totalEstimatedTime }
        return formattedTime(total)
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Movie Title", text: $projectTitle)
                    .font(.title2)
                    .padding(.bottom, 2)
                    .onChange(of: projectTitle) { _ in
                        scheduleAutoSave()
                    }

                Text("Shoot Days: \(shootDays.filter { !$0.scenes.isEmpty }.count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let firstDate = shootDays.first?.date,
                   let lastDate = shootDays.last?.date {
                    Text("From \(formattedDate(firstDate)) to \(formattedDate(lastDate))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Divider().padding(.vertical)

                // Date Range Picker
                Group {
                    Text("Select Date Range").font(.headline)

                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _ in
                            scheduleAutoSave()
                        }
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .onChange(of: endDate) { _ in
                            scheduleAutoSave()
                        }
                    
                    // NEW: Toggle for Shifting vs. Merging
                    Toggle(isOn: $isShiftModeEnabled) {
                        Text("Shift Schedule")
                    }
                    .toggleStyle(.switch)
                    .help("When enabled, changing the Start Date will shift all scenes on the calendar. When disabled, scenes are locked to their original dates.")
                    .onChange(of: isShiftModeEnabled) { _ in
                        scheduleAutoSave()
                    }

                    Button("Update Calendar") {
                        // MODIFIED: Use the new update logic to merge existing days with the new range
                        updateShootDays(from: startDate, to: endDate)
                    }
                    .padding(.top, 5)

                    Divider().padding(.vertical)
                }

                NewSceneInputView(
                    newSceneTitle: $newSceneTitle,
                    newDuration: $newDuration,
                    newEstimate: $newEstimate,
                    allScenes: $allScenes,
                    onSceneAdded: {
                        scheduleAutoSave()
                    }
                )

                Divider().padding(.vertical)

                Text("Boneyard").font(.headline)
                
                // Enhanced List with day/night color indicators
                List {
                    ForEach(Array(allScenes.enumerated()), id: \.element.id) { index, scene in
                        HStack {
                            // Color indicator for day/night
                            Circle()
                                .fill(scene.dayNightType.color)
                                .frame(width: 8, height: 8)
                            
                            Text(scene.title)
                            Spacer()
                            
                            // Show day/night type
                            Text(scene.dayNightType.displayName)
                                .font(.caption)
                                .foregroundColor(scene.dayNightType.color)
                                .fontWeight(.semibold)
                            
                            Text("\(FractionParser.formatEighths(scene.duration)) / \(scene.estimatedTime) min")

                            Button(action: {
                                allScenes.remove(at: index)
                                scheduleAutoSave()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .help("Delete Scene")
                            }
                            .buttonStyle(.plain)
                        }
                        .onDrag {
                            NSItemProvider(object: scene.id.uuidString as NSString)
                        }
                        .onTapGesture(count: 2) {
                            editingUnscheduledSceneIndex = index
                            editingUnscheduledScene = scene
                            showingUnscheduledSceneEditSheet = true
                        }
                        .contextMenu {
                            Button("Edit Scene") {
                                editingUnscheduledSceneIndex = index
                                editingUnscheduledScene = scene
                                showingUnscheduledSceneEditSheet = true
                            }
                            
                            Button("Duplicate Scene") {
                                let duplicatedScene = Scene(
                                    title: scene.title + " (Copy)",
                                    duration: scene.duration,
                                    estimatedTime: scene.estimatedTime,
                                    dayNightType: scene.dayNightType
                                )
                                allScenes.append(duplicatedScene)
                                scheduleAutoSave()
                            }
                            
                            Divider()
                            
                            Button("Delete Scene", role: .destructive) {
                                allScenes.remove(at: index)
                                scheduleAutoSave()
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 300)
        } detail: {
            VStack {
                
        // MARK: - Updated Statistics Button Bar with Dark/Light Mode Toggle and PDF Export
                HStack {
                    // Action buttons on the left
                    HStack(spacing: 12) {
                        Button("Export PDF") {
                            showingPDFExporter = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        // FIXED SAVE BUTTON - Now uses native dialog
                        Button("Save") {
                            showNativeSaveDialog()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Load") {
                            print("Load Schedule button clicked")
                            showingFileImporter = true
                            print("showingFileImporter is now: \(showingFileImporter)")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("New") {
                            showingClearAllConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        // Dark/Light Mode Toggle Button with better animation
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDarkMode.toggle()
                                saveAppearancePreference()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                    .foregroundColor(isDarkMode ? .yellow : .blue)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(isDarkMode ? "Light" : "Dark")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
                    }
                    
                    Spacer()
                    
                    // Compact statistics on the right
                    HStack(spacing: 20) {
                        // Project title (truncated if too long)
                        Text(projectTitle.isEmpty ? "Untitled Movie" : projectTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 200) // Limit width so it doesn't take up too much space
                        
                        Divider()
                            .frame(height: 20)
                        
                        // Compact stats
                        HStack(spacing: 15) {
                            // Shoot Days
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("\(scheduledDays.count)")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Total Scenes
                            HStack(spacing: 3) {
                                Image(systemName: "film")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("\(totalScenes)")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("scenes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Total Duration
                            HStack(spacing: 3) {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(totalDuration)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Text("pages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Estimated Time
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                Text(totalEstimatedTime)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
                .padding(.bottom)

                CompactMonthCalendarView(
                    shootDays: $shootDays,
                    assignScene: assign,
                    allScenes: $allScenes,
                    updateScene: updateScene,
                    removeScene: removeScene,
                    projectTitle: projectTitle,
                    onSceneChanged: {
                        scheduleAutoSave()
                    }
                )
            }
            .padding()
        }
        // Apply the color scheme directly based on isDarkMode
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .fileExporter(
            isPresented: $showingPDFExporter,
            document: PDFFile(
                shootDays: shootDays,
                projectTitle: projectTitle,
                allScenes: allScenes,
                startDate: startDate,
                endDate: endDate
            ),
            contentType: .pdf,
            defaultFilename: sanitizeFilename("\(projectTitle.isEmpty ? "MovieSchedule" : projectTitle)_Calendar")
        ) { result in
            handlePDFExportResult(result)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            DispatchQueue.main.async {
                handleLoadResult(result)
            }
        }
        .alert("CineSched", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Clear All Scenes", isPresented: $showingClearAllConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                clearAllScenes()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all scenes from your calendar and unscheduled list. This action cannot be undone.")
        }
        .sheet(isPresented: $showingUnscheduledSceneEditSheet) {
            if let sceneIndex = editingUnscheduledSceneIndex,
               sceneIndex < allScenes.count {
                
                SceneEditSheet(
                    scene: $allScenes[sceneIndex],
                    isPresented: $showingUnscheduledSceneEditSheet,
                    onSave: {
                        scheduleAutoSave()
                        clearUnscheduledEditingState()
                    },
                    onDelete: {
                        if let index = editingUnscheduledSceneIndex {
                            allScenes.remove(at: index)
                            scheduleAutoSave()
                        }
                        clearUnscheduledEditingState()
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Text("Error: Scene not found")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("The scene you're trying to edit may have been deleted.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    
                    Button("Close") {
                        showingUnscheduledSceneEditSheet = false
                        clearUnscheduledEditingState()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(width: 400)
            }
        }
        .onAppear {
            loadDefaultProject()
            loadAppearancePreference() // Load saved appearance preference
        }
        .onChange(of: showingUnscheduledSceneEditSheet) { isShowing in
            if !isShowing {
                clearUnscheduledEditingState()
            }
        }
    }

    // MARK: - Helper Methods
    
    // MODIFIED: Function to handle both merge and shift logic based on the toggle state
    private func updateShootDays(from newStartDate: Date, to newEndDate: Date) {
        let calendar = Calendar.current
        
        // Get the current start date of the visible schedule
        let oldStartDate = shootDays.first?.date ?? newStartDate
        
        // Normalize dates to start of day
        let normalizedOldStart = calendar.startOfDay(for: oldStartDate)
        let normalizedNewStart = calendar.startOfDay(for: newStartDate)
        let normalizedNewEnd = calendar.startOfDay(for: newEndDate)

        // Calculate the difference in days for shifting
        let dayOffset = calendar.dateComponents([.day], from: normalizedOldStart, to: normalizedNewStart).day ?? 0
        
        // 1. Map existing days for quick lookup (key is the ORIGINAL date)
        let existingDaysMap: [Date: ShootDay] = shootDays.reduce(into: [:]) { result, day in
            let dateKey = calendar.startOfDay(for: day.date)
            result[dateKey] = day
        }

        var updatedDays: [ShootDay] = []
        var currentDate = normalizedNewStart

        // 2. Iterate through the new date range
        while currentDate <= normalizedNewEnd {
            let dateKey = currentDate
            var dayToInsert: ShootDay
            
            if isShiftModeEnabled {
                // **SHIFT/SLIDE MODE:** Find the corresponding *original* date
                if let originalDate = calendar.date(byAdding: .day, value: -dayOffset, to: dateKey) {
                    // If an old day exists for the calculated original date, use its scenes.
                    if let oldDay = existingDaysMap[originalDate] {
                        dayToInsert = ShootDay(date: dateKey, scenes: oldDay.scenes) // Create a new day with the new date but old scenes
                    } else {
                        dayToInsert = ShootDay(date: dateKey)
                    }
                } else {
                    // This handles dates before the original schedule range
                    dayToInsert = ShootDay(date: dateKey)
                }
            } else {
                // **MERGE/LOCK MODE:** Find if the current date already has scenes
                if let existingDay = existingDaysMap[dateKey] {
                    dayToInsert = existingDay // Use the existing day, preserving its scenes
                } else {
                    dayToInsert = ShootDay(date: dateKey)
                }
            }

            updatedDays.append(dayToInsert)

            // Move to the next day
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }

        // 3. Update the state
        shootDays = updatedDays
        scheduleAutoSave()
    }
    
    // NEW: Native Save Dialog Implementation
    private func showNativeSaveDialog() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save CineSched Project"
        savePanel.prompt = "Save"
        savePanel.nameFieldLabel = "Project Name:"
        savePanel.nameFieldStringValue = sanitizeFilename(projectTitle.isEmpty ? "MovieSchedule" : projectTitle)
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        // Set default directory to Documents
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = documentsURL
        }
        
        savePanel.begin { response in
            DispatchQueue.main.async {
                if response == .OK, let url = savePanel.url {
                    self.saveProjectDirectly(to: url)
                }
            }
        }
    }
    
    private func saveProjectDirectly(to url: URL) {
        do {
            let projectData = ProjectData(
                allScenes: allScenes,
                shootDays: shootDays,
                projectTitle: projectTitle,
                isShiftModeEnabled: isShiftModeEnabled
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // Set up date formatting for consistent saves
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let data = try encoder.encode(projectData)
            
            try data.write(to: url)
            
            // Success feedback
            alertMessage = "Schedule saved successfully to: \(url.lastPathComponent)"
            showingAlert = true
            print("Successfully saved to: \(url.path)")
            
        } catch {
            alertMessage = "Failed to save schedule: \(error.localizedDescription)"
            showingAlert = true
            print("Save error: \(error)")
        }
    }
    
    // Simplified save and load appearance preferences
    private func saveAppearancePreference() {
        UserDefaults.standard.set(isDarkMode, forKey: "CineSchedDarkMode")
        print("Saved appearance preference: \(isDarkMode ? "Dark" : "Light") mode")
    }
    
    private func loadAppearancePreference() {
        // Check if the key exists, otherwise default to false (light mode)
        if UserDefaults.standard.object(forKey: "CineSchedDarkMode") != nil {
            isDarkMode = UserDefaults.standard.bool(forKey: "CineSchedDarkMode")
        } else {
            isDarkMode = false
        }
        print("Loaded appearance preference: \(isDarkMode ? "Dark" : "Light") mode")
    }
    
    // Clear unscheduled scene editing state
    private func clearUnscheduledEditingState() {
        editingUnscheduledScene = nil
        editingUnscheduledSceneIndex = nil
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        return filename.components(separatedBy: CharacterSet.illegalCharacters)
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
    
    private func handlePDFExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "PDF calendar exported successfully to: \(url.lastPathComponent)"
            showingAlert = true
            print("Successfully exported PDF to: \(url.path)")
        case .failure(let error):
            alertMessage = "Failed to export PDF: \(error.localizedDescription)"
            showingAlert = true
            print("PDF export error: \(error)")
        }
    }
    
    private func handleLoadResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                alertMessage = "No file selected"
                showingAlert = true
                return
            }
            loadProject(from: url)
        case .failure(let error):
            alertMessage = "Failed to select file: \(error.localizedDescription)"
            showingAlert = true
            print("File selection error: \(error)")
        }
    }
    
    private func loadProject(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Unable to access the selected file."
                showingAlert = true
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // Set up the same date decoding strategy used when saving
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            do {
                let projectData = try decoder.decode(ProjectData.self, from: data)
                
                allScenes = projectData.allScenes
                shootDays = projectData.shootDays
                projectTitle = projectData.projectTitle
                isShiftModeEnabled = projectData.isShiftModeEnabled ?? false // Load the new toggle state
                
                if let firstDay = shootDays.first?.date,
                   let lastDay = shootDays.last?.date {
                    startDate = firstDay
                    endDate = lastDay
                }
                
                // alertMessage = "Project '\(projectData.projectTitle)' loaded successfully!\nLoaded \(projectData.allScenes.count) scenes and \(projectData.shootDays.count) days." // REMOVED
                // showingAlert = true // REMOVED
                
                print("Successfully loaded project: '\(projectData.projectTitle)'")
                print("Loaded \(projectData.allScenes.count) scenes and \(projectData.shootDays.count) days")
                
            } catch {
                // Try without date formatting (for legacy files or different formats)
                do {
                    let decoderFallback = JSONDecoder()
                    let projectData = try decoderFallback.decode(ProjectData.self, from: data)
                    
                    allScenes = projectData.allScenes
                    shootDays = projectData.shootDays
                    projectTitle = projectData.projectTitle
                    isShiftModeEnabled = projectData.isShiftModeEnabled ?? false // Load the new toggle state
                    
                    if let firstDay = shootDays.first?.date,
                       let lastDay = shootDays.last?.date {
                        startDate = firstDay
                        endDate = lastDay
                    }
                    
                    // alertMessage = "Project '\(projectData.projectTitle)' loaded successfully!\nLoaded \(projectData.allScenes.count) scenes and \(projectData.shootDays.count) days." // REMOVED
                    // showingAlert = true // REMOVED
                    
                    print("Successfully loaded project with fallback decoder: '\(projectData.projectTitle)'")
                    print("Loaded \(projectData.allScenes.count) scenes and \(projectData.shootDays.count) days")
                    
                } catch {
                    // Final fallback to legacy format
                    do {
                        let legacyData = try JSONDecoder().decode(LegacyProjectData.self, from: data)
                        
                        allScenes = legacyData.allScenes
                        shootDays = legacyData.shootDays
                        projectTitle = "Loaded Project"
                        isShiftModeEnabled = false // Default to false for legacy
                        
                        if let firstDay = shootDays.first?.date,
                           let lastDay = shootDays.last?.date {
                            startDate = firstDay
                            endDate = lastDay
                        }
                        
                        // alertMessage = "Legacy project loaded successfully!\nLoaded \(legacyData.allScenes.count) scenes and \(legacyData.shootDays.count) days." // REMOVED
                        // showingAlert = true // REMOVED
                        
                        print("Successfully loaded legacy project")
                        print("Loaded \(legacyData.allScenes.count) scenes and \(legacyData.shootDays.count) days")
                        
                    } catch {
                        throw error
                    }
                }
            }
            
        } catch {
            alertMessage = "Failed to load project: \(error.localizedDescription)"
            showingAlert = true
            print("Load error: \(error)")
        }
    }
    
    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            saveDefaultProject()
        }
    }

    func assign(scene: Scene, to day: ShootDay) {
        if let index = shootDays.firstIndex(where: { $0.id == day.id }) {
            shootDays[index].scenes.append(scene)
            allScenes.removeAll { $0.id == scene.id }
            scheduleAutoSave()
        }
    }
    
    func updateScene(_ updatedScene: Scene, in dayId: UUID) {
        if let dayIndex = shootDays.firstIndex(where: { $0.id == dayId }),
           let sceneIndex = shootDays[dayIndex].scenes.firstIndex(where: { $0.id == updatedScene.id }) {
            shootDays[dayIndex].scenes[sceneIndex] = updatedScene
            scheduleAutoSave()
        }
    }
    
    func removeScene(_ scene: Scene, from dayId: UUID) {
        if let dayIndex = shootDays.firstIndex(where: { $0.id == dayId }) {
            shootDays[dayIndex].scenes.removeAll { $0.id == scene.id }
            allScenes.append(scene)
            scheduleAutoSave()
        }
    }
    
    func saveDefaultProject() {
        let projectData = ProjectData(
            allScenes: allScenes,
            shootDays: shootDays,
            projectTitle: projectTitle,
            isShiftModeEnabled: isShiftModeEnabled
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // Set up the same date formatting strategy used in ProjectFile
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let data = try encoder.encode(projectData)
            UserDefaults.standard.set(data, forKey: "SavedProject")
            print("Auto-saved project to UserDefaults")
        } catch {
            print("Failed to auto-save project: \(error)")
        }
    }
    
    func loadDefaultProject() {
        guard let data = UserDefaults.standard.data(forKey: "SavedProject") else {
            print("No saved project found in UserDefaults")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            
            // Set up the same date decoding strategy
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let loaded = try decoder.decode(ProjectData.self, from: data)
            allScenes = loaded.allScenes
            shootDays = loaded.shootDays
            projectTitle = loaded.projectTitle
            isShiftModeEnabled = loaded.isShiftModeEnabled ?? false
            
            if let firstDay = shootDays.first?.date,
               let lastDay = shootDays.last?.date {
                startDate = firstDay
                endDate = lastDay
            }
            
            print("Auto-loaded project from UserDefaults: '\(loaded.projectTitle)'")
        } catch {
            print("Failed to auto-load project with formatted dates: \(error)")
            // Try without date formatting for backwards compatibility
            do {
                let fallbackDecoder = JSONDecoder()
                let loaded = try fallbackDecoder.decode(ProjectData.self, from: data)
                allScenes = loaded.allScenes
                shootDays = loaded.shootDays
                projectTitle = loaded.projectTitle
                isShiftModeEnabled = loaded.isShiftModeEnabled ?? false
                
                if let firstDay = shootDays.first?.date,
                   let lastDay = shootDays.last?.date {
                    startDate = firstDay
                    endDate = lastDay
                }
                
                print("Auto-loaded project from UserDefaults with fallback: '\(loaded.projectTitle)'")
            } catch {
                print("Failed to auto-load project: \(error)")
                do {
                    let legacy = try JSONDecoder().decode(LegacyProjectData.self, from: data)
                    allScenes = legacy.allScenes
                    shootDays = legacy.shootDays
                    isShiftModeEnabled = false
                    print("Auto-loaded legacy project from UserDefaults")
                } catch {
                    print("Failed to load legacy project: \(error)")
                }
            }
        }
    }
    
    func clearAllScenes() {
        allScenes.removeAll()
        
        for index in shootDays.indices {
            shootDays[index].scenes.removeAll()
        }
        
        scheduleAutoSave()
        
        print("Cleared all scenes from schedule")
    }
}

// MARK: - Legacy Support

struct LegacyProjectData: Codable {
    var allScenes: [Scene]
    var shootDays: [ShootDay]
}

// MARK: - PDF Document Wrapper

struct PDFFile: FileDocument {
    static var readableContentTypes: [UTType] = [.pdf]
    static var writableContentTypes: [UTType] = [.pdf]
    
    private let shootDays: [ShootDay]
    private let projectTitle: String
    private let allScenes: [Scene]
    private let startDate: Date
    private let endDate: Date
    
    init(shootDays: [ShootDay], projectTitle: String, allScenes: [Scene], startDate: Date, endDate: Date) {
        self.shootDays = shootDays
        self.projectTitle = projectTitle
        self.allScenes = allScenes
        self.startDate = startDate
        self.endDate = endDate
    }
    
    init(configuration: ReadConfiguration) throws {
        // PDF files are not meant to be read back, so this is just a placeholder
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let pdfData = PDFExporter.generatePDF(
            shootDays: shootDays,
            projectTitle: projectTitle,
            allScenes: allScenes,
            startDate: startDate,
            endDate: endDate
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        return FileWrapper(regularFileWithContents: pdfData)
    }
}

// MARK: - Helper Functions

func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E MMM d"
    return formatter.string(from: date)
}

func generateDays(from startDate: Date, to endDate: Date) -> [ShootDay] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 1 // Sunday

    var days: [ShootDay] = []
    
    // Ensure we start and end on the start of the day for consistent iteration
    var current = calendar.startOfDay(for: startDate)
    let end = calendar.startOfDay(for: endDate)


    while current <= end {
        days.append(ShootDay(date: current))
        current = calendar.date(byAdding: .day, value: 1, to: current)!
    }

    return days
}

func formattedEighths(_ totalEighths: Int) -> String {
    let fullPages = totalEighths / 8
    let remainder = totalEighths % 8

    switch (fullPages, remainder) {
    case (0, 0):
        return "0"
    case (0, _):
        return "\(remainder)/8"
    case (_, 0):
        return "\(fullPages)"
    default:
        return "\(fullPages) \(remainder)/8"
    }
}

func formattedTime(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60

    switch (hours, mins) {
    case (0, 0):
        return "0 min"
    case (0, _):
        return "\(mins) min"
    case (_, 0):
        return "\(hours) hr"
    default:
        return "\(hours) hr \(mins) min"
    }
}

// MARK: - Document Wrapper (Legacy - No Longer Used for Saving)

struct ProjectFile: FileDocument {
    static var readableContentTypes: [UTType] = [.json]
    var projectData: ProjectData

    init(allScenes: [Scene], shootDays: [ShootDay], projectTitle: String = "Untitled Movie") {
        self.projectData = ProjectData(
            allScenes: allScenes,
            shootDays: shootDays,
            projectTitle: projectTitle
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let decoder = JSONDecoder()
        
        // Try new format first
        do {
            self.projectData = try decoder.decode(ProjectData.self, from: data)
        } catch {
            // Fallback to legacy format
            let legacy = try decoder.decode(LegacyProjectData.self, from: data)
            self.projectData = ProjectData(
                allScenes: legacy.allScenes,
                shootDays: legacy.shootDays,
                projectTitle: "Imported Project"
            )
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        // Set up date formatting for consistent saves
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        
        let data = try encoder.encode(projectData)
        return FileWrapper(regularFileWithContents: data)
    }
}
