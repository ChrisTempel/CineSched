// PDFExporter.swift
// Generates a landscape US Letter PDF calendar from shoot data

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - PDFExporter

class PDFExporter {

    static func generatePDF(
        shootDays: [ShootDay],
        projectTitle: String,
        allScenes: [Scene],
        startDate: Date,
        endDate: Date
    ) -> Data? {

        let pageWidth:  CGFloat = 792   // US Letter landscape
        let pageHeight: CGFloat = 612
        let margin:     CGFloat = 40

        let contentRect = CGRect(
            x: margin, y: margin,
            width:  pageWidth  - 2 * margin,
            height: pageHeight - 2 * margin
        )

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let weeks      = groupDaysIntoWeeks(shootDays)
        let rowHeights = calculateIdealRowHeights(weeks: weeks)
        let cellWidth  = contentRect.width / 7
        let dayNumbers = productionDayNumbers(for: shootDays)

        var pageNumber = 0
        var weekIndex  = 0
        var currentY   = contentRect.maxY

        while weekIndex < weeks.count {
            pageNumber += 1
            context.beginPDFPage(nil)

            let gctx = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = gctx

            // Header on first page only
            if pageNumber == 1 {
                let headerHeight: CGFloat = 50
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
                currentY = contentRect.maxY - headerHeight - 10
            } else {
                currentY = contentRect.maxY
            }

            var horizontalLines: [CGFloat] = [currentY]

            while weekIndex < weeks.count {
                let rowHeight = rowHeights[weekIndex]
                guard currentY - rowHeight >= contentRect.minY + 10 else { break }

                let rowRect = CGRect(
                    x: contentRect.minX,
                    y: currentY - rowHeight,
                    width: contentRect.width,
                    height: rowHeight
                )
                drawWeekRow(week: weeks[weekIndex], in: rowRect, cellWidth: cellWidth, dayNumbers: dayNumbers)
                currentY -= rowHeight
                horizontalLines.append(currentY)
                weekIndex += 1
            }

            drawGridLines(
                horizontalLines: horizontalLines,
                minX: contentRect.minX, maxX: contentRect.maxX,
                minY: contentRect.minY, maxY: contentRect.maxY
            )

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return pdfData as Data
    }

    // MARK: - Private Drawing Helpers

    private static func drawHeader(
        in rect: CGRect,
        projectTitle: String,
        startDate: Date,
        endDate: Date,
        allScenes: [Scene],
        shootDays: [ShootDay]
    ) {
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]
        let displayTitle = projectTitle.isEmpty ? "Untitled Movie" : projectTitle
        NSAttributedString(string: displayTitle, attributes: titleAttr)
            .draw(in: CGRect(x: rect.minX, y: rect.maxY - 25, width: rect.width, height: 25))

        let smallAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]
        let scheduled = shootDays.filter { !$0.scenes.isEmpty }.count
        NSAttributedString(string: "Shoot Days: \(scheduled)", attributes: smallAttr)
            .draw(in: CGRect(x: rect.minX, y: rect.maxY - 50, width: rect.width, height: 20))
    }

    private static func calculateIdealRowHeights(weeks: [[ShootDay?]]) -> [CGFloat] {
        let minHeight: CGFloat = 50
        let maxHeight: CGFloat = 160

        return weeks.map { week in
            let maxScenes     = week.compactMap { $0 }.map(\.scenes.count).max() ?? 0
            let contentHeight = 40 + CGFloat(maxScenes) * 11
            return min(max(contentHeight + 20, minHeight), maxHeight)
        }
    }

    private static func drawWeekRow(week: [ShootDay?], in rowRect: CGRect, cellWidth: CGFloat, dayNumbers: [UUID: Int]) {
        for (col, day) in week.enumerated() {
            let cellRect = CGRect(
                x: rowRect.minX + CGFloat(col) * cellWidth,
                y: rowRect.minY,
                width: cellWidth,
                height: rowRect.height
            )
            if let day = day { drawDay(day: day, in: cellRect, dayNumber: dayNumbers[day.id]) }
        }
    }

    private static func drawGridLines(
        horizontalLines: [CGFloat],
        minX: CGFloat, maxX: CGFloat,
        minY: CGFloat, maxY: CGFloat
    ) {
        guard !horizontalLines.isEmpty else { return }

        let path = NSBezierPath()
        path.lineWidth = 0.5
        NSColor.lightGray.setStroke()

        let top    = horizontalLines.first ?? maxY
        let bottom = horizontalLines.last  ?? minY

        // Vertical lines spanning actual calendar content only
        for i in 0...7 {
            let x = minX + CGFloat(i) * ((maxX - minX) / 7)
            path.move(to: CGPoint(x: x, y: bottom))
            path.line(to: CGPoint(x: x, y: top))
        }

        // Horizontal row separators
        for y in horizontalLines {
            path.move(to: CGPoint(x: minX, y: y))
            path.line(to: CGPoint(x: maxX, y: y))
        }
        path.stroke()
    }

    private static func drawDay(day: ShootDay, in rect: CGRect, dayNumber: Int?) {
        let padding = CGFloat(8)
        let content = CGRect(
            x: rect.minX + padding, y: rect.minY + padding,
            width:  rect.width  - 2 * padding,
            height: rect.height - 2 * padding
        )

        // Date header (top of cell)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E MMM d"
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor.black
        ]
        NSAttributedString(string: dateFormatter.string(from: day.date), attributes: dateAttr)
            .draw(in: CGRect(x: content.minX, y: content.maxY - 12, width: content.width, height: 12))

        // Production day number, right-justified — matches the on-screen calendar
        if let dayNumber {
            let para = NSMutableParagraphStyle(); para.alignment = .right
            let dayNumAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor(white: 0.4, alpha: 1),
                .paragraphStyle: para
            ]
            NSAttributedString(string: "Day \(dayNumber)", attributes: dayNumAttr)
                .draw(in: CGRect(x: content.minX, y: content.maxY - 12, width: content.width, height: 12))
        }

        // Scene strips
        let boxHeight:     CGFloat = 11
        let paragraphStyle         = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let sceneAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        var yOffset: CGFloat = 16
        for scene in day.scenes {
            let boxRect = CGRect(
                x: content.minX,
                y: content.maxY - yOffset - boxHeight,
                width: content.width,
                height: boxHeight
            )

            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 2, yRadius: 2)
            (scene.dayNightType == .night
                ? NSColor(white: 0.9, alpha: 1.0)
                : NSColor.white).setFill()
            boxPath.fill()
            NSColor.lightGray.setStroke()
            boxPath.lineWidth = 0.5
            boxPath.stroke()

            let attrStr    = NSAttributedString(string: scene.displayTitle, attributes: sceneAttr)
            let textHeight = attrStr.size().height
            let textRect   = CGRect(
                x: content.minX + 3,
                y: content.maxY - yOffset - boxHeight + (boxHeight - textHeight) / 2,
                width: content.width - 6,
                height: textHeight
            )
            attrStr.draw(in: textRect)
            yOffset += boxHeight
        }

        // Totals at bottom
        if !day.scenes.isEmpty {
            let totalAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7),
                .foregroundColor: NSColor.gray
            ]
            let totalText = "Total: \(formattedEighths(day.totalDuration))\nEst: \(formattedTime(day.totalEstimatedTime))"
            NSAttributedString(string: totalText, attributes: totalAttr)
                .draw(in: CGRect(x: content.minX, y: content.minY, width: content.width, height: 20))
        }
    }

    private static func groupDaysIntoWeeks(_ shootDays: [ShootDay]) -> [[ShootDay?]] {
        guard !shootDays.isEmpty else { return [] }

        let cal  = Calendar.current
        var weeks: [[ShootDay?]] = []
        var week = Array(repeating: ShootDay?.none, count: 7)

        var date = cal.startOfDay(for: shootDays.first!.date)
        let end  = cal.startOfDay(for: shootDays.last!.date)
        var idx  = 0

        while date <= end {
            let weekday = cal.component(.weekday, from: date) - 1 // 0 = Sun

            let match = (idx < shootDays.count && cal.isDate(shootDays[idx].date, inSameDayAs: date))
                ? shootDays[idx] : nil
            if match != nil { idx += 1 }

            week[weekday] = match ?? ShootDay(date: date)

            if weekday == 6 || date == end {
                weeks.append(week)
                week = Array(repeating: nil, count: 7)
            }
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        return weeks
    }

    // MARK: - Monthly Calendar PDF Generator

    static func generateMonthPDF(
        month: Date,
        shootDays: [ShootDay],
        projectTitle: String,
        productionInfo: ProductionInfo
    ) -> Data? {
        let pageWidth:  CGFloat = 792   // US Letter landscape
        let pageHeight: CGFloat = 612
        let margin:     CGFloat = 36

        let contentRect = CGRect(
            x: margin, y: margin,
            width:  pageWidth  - 2 * margin,
            height: pageHeight - 2 * margin
        )

        let cal = Calendar.current
        let monthComps = cal.dateComponents([.year, .month], from: month)
        guard let startOfMonth = cal.date(from: monthComps),
              let dayRange = cal.range(of: .day, in: .month, for: startOfMonth) else { return nil }

        let dayNumbers = productionDayNumbers(for: shootDays)

        // Build month weeks (Sunday-based: 0=Sun, 6=Sat)
        var monthWeeks: [[(date: Date, shootDay: ShootDay?)]] = []
        var currentWeek: [(date: Date, shootDay: ShootDay?)] = []

        let firstWeekday = cal.component(.weekday, from: startOfMonth) // 1=Sun, 2=Mon...
        let leadingEmpty = firstWeekday - 1 // Sunday=0

        // Fill leading empty days from previous month
        for i in (0..<leadingEmpty).reversed() {
            if let prevDate = cal.date(byAdding: .day, value: -(i + 1), to: startOfMonth) {
                let match = shootDays.first(where: { cal.isDate($0.date, inSameDayAs: prevDate) })
                currentWeek.append((date: prevDate, shootDay: match))
            }
        }

        // Fill month days
        for d in dayRange {
            if let date = cal.date(byAdding: .day, value: d - 1, to: startOfMonth) {
                let match = shootDays.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                currentWeek.append((date: date, shootDay: match))
                if currentWeek.count == 7 {
                    monthWeeks.append(currentWeek)
                    currentWeek = []
                }
            }
        }

        // Fill trailing empty days
        if !currentWeek.isEmpty {
            var nextD = 1
            while currentWeek.count < 7 {
                let lastDate = startOfMonth
                if let nextDate = cal.date(byAdding: .month, value: 1, to: lastDate),
                   let trailDate = cal.date(byAdding: .day, value: nextD - 1, to: nextDate) {
                    let match = shootDays.first(where: { cal.isDate($0.date, inSameDayAs: trailDate) })
                    currentWeek.append((date: trailDate, shootDay: match))
                }
                nextD += 1
            }
            monthWeeks.append(currentWeek)
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        context.beginPDFPage(nil)
        let gctx = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx

        // Header (Month & Year + Project info)
        let headerHeight: CGFloat = 46
        let headerRect = CGRect(
            x: contentRect.minX,
            y: contentRect.maxY - headerHeight,
            width: contentRect.width,
            height: headerHeight
        )

        let isSpanish = LocalizationManager.shared.currentLanguage == .spanish
        let df = DateFormatter()
        df.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        df.dateFormat = "MMMM yyyy"
        let monthTitle = df.string(from: month).uppercased()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]
        let displayTitle = (projectTitle.isEmpty ? "CineSched" : projectTitle) + " — " + monthTitle
        NSAttributedString(string: displayTitle, attributes: titleAttr)
            .draw(in: CGRect(x: headerRect.minX, y: headerRect.maxY - 20, width: headerRect.width, height: 20))

        let metaAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.darkGray
        ]
        let scheduledCount = shootDays.filter { !$0.scenes.isEmpty && cal.isDate($0.date, equalTo: month, toGranularity: .month) }.count
        let metaText = isSpanish
            ? "Días de Rodaje en el Mes: \(scheduledCount)  ·  Director: \(productionInfo.directorName.isEmpty ? "—" : productionInfo.directorName)  ·  Productor: \(productionInfo.producerName.isEmpty ? "—" : productionInfo.producerName)"
            : "Month Shoot Days: \(scheduledCount)  ·  Director: \(productionInfo.directorName.isEmpty ? "—" : productionInfo.directorName)  ·  Producer: \(productionInfo.producerName.isEmpty ? "—" : productionInfo.producerName)"
        NSAttributedString(string: metaText, attributes: metaAttr)
            .draw(in: CGRect(x: headerRect.minX, y: headerRect.maxY - 36, width: headerRect.width, height: 16))

        // Weekday header bar
        let weekdayBarHeight: CGFloat = 16
        let weekdayBarRect = CGRect(
            x: contentRect.minX,
            y: headerRect.minY - weekdayBarHeight - 4,
            width: contentRect.width,
            height: weekdayBarHeight
        )

        let barPath = NSBezierPath(roundedRect: weekdayBarRect, xRadius: 3, yRadius: 3)
        NSColor(white: 0.92, alpha: 1.0).setFill()
        barPath.fill()

        let weekdaySymbols = isSpanish
            ? ["DOMINGO", "LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO"]
            : ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

        let cellWidth = contentRect.width / 7
        let weekAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8.5),
            .foregroundColor: NSColor(white: 0.3, alpha: 1.0)
        ]
        for (col, symbol) in weekdaySymbols.enumerated() {
            let colRect = CGRect(x: weekdayBarRect.minX + CGFloat(col) * cellWidth, y: weekdayBarRect.minY + 2, width: cellWidth, height: 12)
            let para = NSMutableParagraphStyle(); para.alignment = .center
            var attr = weekAttr; attr[.paragraphStyle] = para
            NSAttributedString(string: symbol, attributes: attr).draw(in: colRect)
        }

        // Draw Weeks Grid (Page 1 gets 100% full height for maximum cell room)
        let gridTop = weekdayBarRect.minY - 4
        let gridHeight = gridTop - contentRect.minY
        let numWeeks = max(CGFloat(monthWeeks.count), 1)
        let rowHeight = gridHeight / numWeeks

        for (wIdx, week) in monthWeeks.enumerated() {
            let rowY = gridTop - CGFloat(wIdx + 1) * rowHeight
            let rowRect = CGRect(x: contentRect.minX, y: rowY, width: contentRect.width, height: rowHeight)

            for (cIdx, cell) in week.enumerated() {
                let cellRect = CGRect(x: rowRect.minX + CGFloat(cIdx) * cellWidth, y: rowRect.minY, width: cellWidth, height: rowHeight)
                let isCurrentMonth = cal.isDate(cell.date, equalTo: month, toGranularity: .month)
                let dayNum = cell.shootDay != nil ? dayNumbers[cell.shootDay!.id] : nil

                drawMonthGridCell(
                    date: cell.date,
                    shootDay: cell.shootDay,
                    dayNumber: dayNum,
                    in: cellRect,
                    isCurrentMonth: isCurrentMonth
                )
            }
        }

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()

        // Page 2: Detailed Activity & Shoot Schedule Breakdown (if month has scheduled content)
        let activeDays = shootDays.filter { day in
            cal.isDate(day.date, equalTo: month, toGranularity: .month) && !day.scenes.isEmpty
        }.sorted { $0.date < $1.date }

        if !activeDays.isEmpty {
            context.beginPDFPage(nil)
            let gctx2 = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = gctx2

            drawMonthBreakdownPage(
                contentRect: contentRect,
                monthTitle: monthTitle,
                projectTitle: projectTitle,
                activeDays: activeDays,
                dayNumbers: dayNumbers,
                isSpanish: isSpanish
            )

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()

        return pdfData as Data
    }

    private static func drawMonthGridCell(
        date: Date,
        shootDay: ShootDay?,
        dayNumber: Int?,
        in rect: CGRect,
        isCurrentMonth: Bool
    ) {
        let path = NSBezierPath(rect: rect)
        let isShoot = shootDay != nil && !shootDay!.isBlackout && (dayNumber != nil || !shootDay!.scenes.filter { !$0.isCalendarEvent }.isEmpty)

        if isShoot {
            NSColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 1.0).setFill()
        } else if let sd = shootDay, sd.isBlackout {
            NSColor(red: 1.0, green: 0.94, blue: 0.94, alpha: 1.0).setFill()
        } else if !isCurrentMonth {
            NSColor(white: 0.97, alpha: 1.0).setFill()
        } else {
            NSColor.white.setFill()
        }
        path.fill()

        NSColor(white: 0.82, alpha: 1.0).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let cal = Calendar.current
        let dayDigit = cal.component(.day, from: date)
        let padding: CGFloat = 4
        let inner = rect.insetBy(dx: padding, dy: padding)

        // Day Number Header
        let dayNumAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: isCurrentMonth ? NSColor.black : NSColor.lightGray
        ]
        NSAttributedString(string: "\(dayDigit)", attributes: dayNumAttr)
            .draw(at: CGPoint(x: inner.minX, y: inner.maxY - 13))

        // Shoot Day Badge
        if let dayNumber = dayNumber, isShoot {
            let para = NSMutableParagraphStyle(); para.alignment = .right
            let badgeAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 8.5),
                .foregroundColor: NSColor(red: 0.1, green: 0.35, blue: 0.85, alpha: 1.0),
                .paragraphStyle: para
            ]
            let badgeText = LocalizationManager.shared.currentLanguage == .spanish ? "DÍA #\(dayNumber)" : "DAY #\(dayNumber)"
            NSAttributedString(string: badgeText, attributes: badgeAttr)
                .draw(in: CGRect(x: inner.minX, y: inner.maxY - 13, width: inner.width, height: 13))
        }

        // Scenes and Calendar Events list
        if let day = shootDay {
            let boxHeight: CGFloat = 12
            var yOff: CGFloat = 16
            let pStyle = NSMutableParagraphStyle()
            pStyle.lineBreakMode = .byTruncatingTail

            for scene in day.scenes {
                guard inner.maxY - yOff - boxHeight >= inner.minY + 4 else { break }

                let bRect = CGRect(x: inner.minX, y: inner.maxY - yOff - boxHeight, width: inner.width, height: boxHeight)
                let bPath = NSBezierPath(roundedRect: bRect, xRadius: 2.5, yRadius: 2.5)

                if scene.isCalendarEvent {
                    let evColor = NSColor(hexString: scene.bannerColorHex.isEmpty ? "6366F1" : scene.bannerColorHex)
                    evColor.withAlphaComponent(0.18).setFill()
                    bPath.fill()
                    evColor.withAlphaComponent(0.6).setStroke()
                    bPath.lineWidth = 0.5
                    bPath.stroke()

                    let evAttr: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: 7.2),
                        .foregroundColor: evColor,
                        .paragraphStyle: pStyle
                    ]
                    let timePrefix = scene.customStartTime.isEmpty ? "" : "\(scene.customStartTime) · "
                    NSAttributedString(string: "\(timePrefix)\(scene.title)", attributes: evAttr)
                        .draw(in: bRect.insetBy(dx: 3, dy: 1))
                } else if !scene.isBanner {
                    (scene.dayNightType == .night ? NSColor(red: 0.88, green: 0.92, blue: 0.98, alpha: 1.0) : NSColor.white).setFill()
                    bPath.fill()
                    NSColor(white: 0.72, alpha: 1.0).setStroke()
                    bPath.lineWidth = 0.5
                    bPath.stroke()

                    let scAttr: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 7.2),
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: pStyle
                    ]
                    let numPrefix = scene.sceneNumber.isEmpty ? "" : "\(scene.sceneNumber). "
                    let durStr = scene.duration > 0 ? " (\(formattedEighths(scene.duration)))" : ""
                    NSAttributedString(string: "\(numPrefix)\(scene.title)\(durStr)", attributes: scAttr)
                        .draw(in: bRect.insetBy(dx: 3, dy: 1))
                }
                yOff += boxHeight + 2
            }
        }
    }

    private static func drawMonthBreakdownPage(
        contentRect: CGRect,
        monthTitle: String,
        projectTitle: String,
        activeDays: [ShootDay],
        dayNumbers: [UUID: Int],
        isSpanish: Bool
    ) {
        // Page 2 Header
        let headerTitle = (projectTitle.isEmpty ? "CineSched" : projectTitle) + " — " + monthTitle + (isSpanish ? " — Desglose y Actividades" : " — Schedule & Breakdown")
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: NSColor.black
        ]
        NSAttributedString(string: headerTitle, attributes: titleAttr)
            .draw(at: CGPoint(x: contentRect.minX, y: contentRect.maxY - 20))

        let subTitle = isSpanish
            ? "Detalle completo de escenas, llamados, personajes y eventos programados para este mes."
            : "Complete detail of scheduled scenes, call times, cast and calendar events for this month."
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5),
            .foregroundColor: NSColor.darkGray
        ]
        NSAttributedString(string: subTitle, attributes: subAttr)
            .draw(at: CGPoint(x: contentRect.minX, y: contentRect.maxY - 34))

        let divider = NSBezierPath()
        divider.move(to: CGPoint(x: contentRect.minX, y: contentRect.maxY - 40))
        divider.line(to: CGPoint(x: contentRect.maxX, y: contentRect.maxY - 40))
        NSColor(white: 0.8, alpha: 1.0).setStroke()
        divider.lineWidth = 0.75
        divider.stroke()

        let df = DateFormatter()
        df.locale = isSpanish ? Locale(identifier: "es_ES") : Locale(identifier: "en_US")
        df.dateStyle = .full

        var curY = contentRect.maxY - 52
        let cardWidth = contentRect.width

        for day in activeDays {
            let isShoot = dayNumbers[day.id] != nil
            let scriptScenes = day.scenes.filter { !$0.isCalendarEvent && !$0.isBanner }
            let events = day.scenes.filter { $0.isCalendarEvent }

            let totalEighths = scriptScenes.reduce(0) { $0 + $1.duration }
            let totalMins = scriptScenes.reduce(0) { $0 + $1.estimatedTime }

            // Estimate card height
            let sceneLineHeight: CGFloat = 13
            let scenesHeight = CGFloat(scriptScenes.count) * sceneLineHeight
            let eventsHeight = CGFloat(events.count) * sceneLineHeight
            let cardHeight: CGFloat = max(38 + scenesHeight + eventsHeight, 44)

            guard curY - cardHeight >= contentRect.minY else { break }

            let cardRect = CGRect(x: contentRect.minX, y: curY - cardHeight, width: cardWidth, height: cardHeight)
            let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 4, yRadius: 4)

            if isShoot {
                NSColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1.0).setFill()
                cardPath.fill()
                NSColor(red: 0.7, green: 0.82, blue: 0.96, alpha: 1.0).setStroke()
            } else {
                NSColor(white: 0.97, alpha: 1.0).setFill()
                cardPath.fill()
                NSColor(white: 0.85, alpha: 1.0).setStroke()
            }
            cardPath.lineWidth = 0.5
            cardPath.stroke()

            // Card Header: Date + Day Badge
            let dateString = df.string(from: day.date).capitalized
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9.5),
                .foregroundColor: NSColor.black
            ]
            NSAttributedString(string: dateString, attributes: dateAttr)
                .draw(at: CGPoint(x: cardRect.minX + 8, y: cardRect.maxY - 15))

            if let dayNum = dayNumbers[day.id] {
                let badgeText = isSpanish
                    ? "DÍA #\(dayNum) DE RODAJE (\(scriptScenes.count) esc · \(formattedEighths(totalEighths)) págs · \(formattedTime(totalMins)))"
                    : "SHOOT DAY #\(dayNum) (\(scriptScenes.count) sc · \(formattedEighths(totalEighths)) pgs · \(formattedTime(totalMins)))"
                let badgeAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 8.5),
                    .foregroundColor: NSColor(red: 0.1, green: 0.35, blue: 0.85, alpha: 1.0)
                ]
                NSAttributedString(string: badgeText, attributes: badgeAttr)
                    .draw(at: CGPoint(x: cardRect.minX + 220, y: cardRect.maxY - 15))
            } else {
                let eventBadgeText = isSpanish ? "📅 DÍA DE AGENDA" : "📅 AGENDA / PREP DAY"
                let badgeAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 8.5),
                    .foregroundColor: NSColor(hexString: "6366F1")
                ]
                NSAttributedString(string: eventBadgeText, attributes: badgeAttr)
                    .draw(at: CGPoint(x: cardRect.minX + 220, y: cardRect.maxY - 15))
            }

            // Call sheet times summary if shoot day
            var itemY = cardRect.maxY - 28
            if isShoot && (!day.callSheet.generalCallTime.isEmpty || !day.callSheet.lunchTime.isEmpty || !day.callSheet.dinnerTime.isEmpty) {
                var callParts: [String] = []
                if !day.callSheet.generalCallTime.isEmpty { callParts.append("\(isSpanish ? "Llamado" : "Call"): \(day.callSheet.generalCallTime)") }
                if !day.callSheet.lunchTime.isEmpty { callParts.append("\(isSpanish ? "Almuerzo" : "Lunch"): \(day.callSheet.lunchTime)") }
                if !day.callSheet.dinnerTime.isEmpty { callParts.append("\(isSpanish ? "Wrap" : "Wrap"): \(day.callSheet.dinnerTime)") }
                if !day.callSheet.basecampLocation.isEmpty { callParts.append("\(isSpanish ? "Loc" : "Base"): \(day.callSheet.basecampLocation)") }

                let callAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 7.8),
                    .foregroundColor: NSColor(white: 0.35, alpha: 1.0)
                ]
                NSAttributedString(string: "⏰ " + callParts.joined(separator: "  ·  "), attributes: callAttr)
                    .draw(at: CGPoint(x: cardRect.minX + 8, y: itemY))
                itemY -= 13
            }

            // Events list
            for ev in events {
                let evTime = ev.customStartTime.isEmpty ? "" : "[\(ev.customStartTime)] "
                let evAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 7.8),
                    .foregroundColor: NSColor(hexString: ev.bannerColorHex.isEmpty ? "6366F1" : ev.bannerColorHex)
                ]
                NSAttributedString(string: "🗓️  \(evTime)\(ev.title)", attributes: evAttr)
                    .draw(at: CGPoint(x: cardRect.minX + 8, y: itemY))
                itemY -= sceneLineHeight
            }

            // Scenes list
            for scene in scriptScenes {
                let numStr = scene.sceneNumber.isEmpty ? "" : "Esc \(scene.sceneNumber): "
                let intExt = scene.intExtString
                let dayNight = scene.dayNightType.rawValue.uppercased()
                let dur = scene.duration > 0 ? " · \(formattedEighths(scene.duration)) págs" : ""
                let castStr = scene.cast.isEmpty ? "" : " · Cast: \(scene.cast.joined(separator: ", "))"
                let locStr = scene.realLocation.isEmpty ? "" : " · Loc: \(scene.realLocation)"

                let sceneAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 7.8),
                    .foregroundColor: NSColor.black
                ]
                let fullSceneLine = "🎬  \(numStr)\(scene.title) [\(intExt) \(dayNight)]\(dur)\(castStr)\(locStr)"
                NSAttributedString(string: fullSceneLine, attributes: sceneAttr)
                    .draw(in: CGRect(x: cardRect.minX + 8, y: itemY, width: cardRect.width - 16, height: 12))
                itemY -= sceneLineHeight
            }

            curY -= (cardHeight + 8)
        }
    }
}

// MARK: - NSColor Hex Extension

private extension NSColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
            (a, r, g, b) = (255, 99, 102, 241)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - PDFFile (FileDocument wrapper)

struct PDFFile: FileDocument {
    static var readableContentTypes:  [UTType] = [.pdf]
    static var writableContentTypes: [UTType] = [.pdf]

    private let shootDays:    [ShootDay]
    private let projectTitle: String
    private let allScenes:    [Scene]
    private let startDate:    Date
    private let endDate:      Date

    init(shootDays: [ShootDay], projectTitle: String, allScenes: [Scene], startDate: Date, endDate: Date) {
        self.shootDays    = shootDays
        self.projectTitle = projectTitle
        self.allScenes    = allScenes
        self.startDate    = startDate
        self.endDate      = endDate
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = PDFExporter.generatePDF(
            shootDays: shootDays,
            projectTitle: projectTitle,
            allScenes: allScenes,
            startDate: startDate,
            endDate: endDate
        ) else { throw CocoaError(.fileWriteUnknown) }
        return FileWrapper(regularFileWithContents: data)
    }
}
