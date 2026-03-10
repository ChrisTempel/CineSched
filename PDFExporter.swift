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
                drawWeekRow(week: weeks[weekIndex], in: rowRect, cellWidth: cellWidth)
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

    private static func drawWeekRow(week: [ShootDay?], in rowRect: CGRect, cellWidth: CGFloat) {
        for (col, day) in week.enumerated() {
            let cellRect = CGRect(
                x: rowRect.minX + CGFloat(col) * cellWidth,
                y: rowRect.minY,
                width: cellWidth,
                height: rowRect.height
            )
            if let day = day { drawDay(day: day, in: cellRect) }
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

    private static func drawDay(day: ShootDay, in rect: CGRect) {
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

            let attrStr    = NSAttributedString(string: scene.title, attributes: sceneAttr)
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
