// DaysOutOfDaysExporter.swift
// Generates a landscape US Letter "Days Out of Days" (DOOD) PDF — one row per cast
// member, one column per shoot day, showing when each character starts, works,
// holds, and finishes across the schedule.

import SwiftUI
import AppKit

enum DOODStatus: Equatable {
    case startWork, work, hold, finish, startFinish, none

    var code: String {
        switch self {
        case .startWork:   return "SW"
        case .work:        return "W"
        case .hold:        return "H"
        case .finish:      return "WF"
        case .startFinish: return "SWF"
        case .none:        return ""
        }
    }

    var isWorkDay: Bool {
        switch self {
        case .startWork, .work, .finish, .startFinish: return true
        case .hold, .none: return false
        }
    }

    var textColor: NSColor {
        switch self {
        case .startWork, .finish, .startFinish: return .white
        case .work:  return .black
        case .hold:  return NSColor(calibratedWhite: 0.35, alpha: 1)
        case .none:  return .clear
        }
    }

    var fillColor: NSColor {
        switch self {
        case .startWork, .finish, .startFinish: return NSColor.systemBlue
        case .work:  return NSColor(calibratedWhite: 0.94, alpha: 1)
        case .hold:  return NSColor.systemYellow.withAlphaComponent(0.35)
        case .none:  return .clear
        }
    }
}

struct DOODRow {
    let displayName: String
    let statuses: [DOODStatus]     // one entry per shoot day, aligned by index
    let workDayCount: Int
    let holdDayCount: Int
    let totalSpan: Int             // finish day minus start day, inclusive; 0 if never scheduled
}

struct DaysOutOfDaysExporter {

    /// Builds one row per character that's actually scheduled anywhere in the project.
    /// Characters from Production Setup's cast list come first (in that order), followed
    /// by any character names found only in scene cast lists (e.g. background/unlisted).
    static func buildRows(shootDays: [ShootDay], productionInfo: ProductionInfo) -> (days: [ShootDay], rows: [DOODRow]) {
        let sortedDays = shootDays.sorted { $0.date < $1.date }

        var seen: Set<String> = []
        var orderedCharacters: [String] = []
        for member in productionInfo.castList {
            let name = member.characterName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !seen.contains(name.lowercased()) else { continue }
            seen.insert(name.lowercased())
            orderedCharacters.append(name)
        }
        let sceneCharacters = Set(sortedDays.flatMap { $0.scenes.flatMap { $0.cast } })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for name in sceneCharacters.sorted() where !seen.contains(name.lowercased()) {
            seen.insert(name.lowercased())
            orderedCharacters.append(name)
        }

        var rows: [DOODRow] = []
        for character in orderedCharacters {
            var workDayIndices: [Int] = []
            for (idx, day) in sortedDays.enumerated() {
                let works = day.scenes.contains { scene in
                    scene.cast.contains { $0.caseInsensitiveCompare(character) == .orderedSame }
                }
                if works { workDayIndices.append(idx) }
            }
            guard !workDayIndices.isEmpty else { continue }

            let firstIdx = workDayIndices.first!
            let lastIdx  = workDayIndices.last!
            var statuses = Array(repeating: DOODStatus.none, count: sortedDays.count)

            if firstIdx == lastIdx {
                statuses[firstIdx] = .startFinish
            } else {
                statuses[firstIdx] = .startWork
                statuses[lastIdx]  = .finish
                if lastIdx - firstIdx > 1 {
                    for idx in (firstIdx + 1)..<lastIdx {
                        if workDayIndices.contains(idx) {
                            statuses[idx] = .work
                        } else if !sortedDays[idx].scenes.isEmpty {
                            // A shoot day where *other* people are working, but not this
                            // character — a true hold. A production-wide day off (no
                            // scenes scheduled for anyone) is left blank instead, since
                            // that's not specific to this cast member.
                            statuses[idx] = .hold
                        }
                    }
                }
            }

            let displayName: String = {
                if let match = productionInfo.castList.first(where: {
                    $0.characterName.trimmingCharacters(in: .whitespaces)
                        .caseInsensitiveCompare(character) == .orderedSame
                }) {
                    return match.displayString
                }
                return character
            }()

            rows.append(DOODRow(
                displayName: displayName,
                statuses: statuses,
                workDayCount: statuses.filter { $0.isWorkDay }.count,
                holdDayCount: statuses.filter { $0 == .hold }.count,
                totalSpan: lastIdx - firstIdx + 1
            ))
        }
        return (sortedDays, rows)
    }

    static func generatePDF(shootDays: [ShootDay], projectTitle: String, productionInfo: ProductionInfo) -> Data? {
        let (days, rows) = buildRows(shootDays: shootDays, productionInfo: productionInfo)
        guard !days.isEmpty, !rows.isEmpty else { return nil }

        let pageWidth:  CGFloat = 792   // US Letter landscape
        let pageHeight: CGFloat = 612
        let margin:     CGFloat = 36

        let nameColWidth:    CGFloat = 150
        let summaryColWidth: CGFloat = 30
        let dayColWidth:     CGFloat = 22
        let rowHeight:       CGFloat = 18
        let headerHeight:    CGFloat = 30
        let titleHeight:     CGFloat = 34
        let legendHeight:    CGFloat = 20

        let contentWidth  = pageWidth - 2 * margin
        let fixedColsWidth = nameColWidth + summaryColWidth * 3
        let daysAvailableWidth = contentWidth - fixedColsWidth
        let daysPerPage = max(1, Int(daysAvailableWidth / dayColWidth))
        let rowsPerPage = max(1, Int((pageHeight - 2 * margin - titleHeight - headerHeight - legendHeight) / rowHeight))

        let dayChunkStarts = stride(from: 0, to: days.count, by: daysPerPage).map { $0 }
        let rowChunkStarts = stride(from: 0, to: rows.count, by: rowsPerPage).map { $0 }
        let totalPages = dayChunkStarts.count * rowChunkStarts.count

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let dayNumFormatter = DateFormatter(); dayNumFormatter.dateFormat = "d"
        let weekdayFormatter = DateFormatter(); weekdayFormatter.dateFormat = "EEEEE"
        let monthFormatter = DateFormatter(); monthFormatter.dateFormat = "MMM"

        var pageNum = 0
        for dayStart in dayChunkStarts {
            let dayChunk = Array(days[dayStart..<min(dayStart + daysPerPage, days.count)])

            for rowStart in rowChunkStarts {
                let rowChunk = Array(rows[rowStart..<min(rowStart + rowsPerPage, rows.count)])
                pageNum += 1

                context.beginPDFPage(nil)
                let gctx = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = gctx

                var y = pageHeight - margin

                // Title
                let titleText = "\(projectTitle.isEmpty ? "Untitled Movie" : projectTitle) — Days Out of Days"
                NSAttributedString(string: titleText, attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.black
                ]).draw(at: CGPoint(x: margin, y: y - 16))

                NSAttributedString(string: "Page \(pageNum) of \(totalPages)", attributes: [
                    .font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.gray
                ]).draw(at: CGPoint(x: pageWidth - margin - 70, y: y - 14))

                y -= titleHeight

                let gridTop = y
                var x = margin

                // Column headers
                drawCell("", rect: CGRect(x: x, y: y - headerHeight, width: nameColWidth, height: headerHeight),
                          font: .boldSystemFont(ofSize: 9), align: .left, textColor: .black, fill: nil)
                x += nameColWidth
                for label in ["TOT", "WRK", "HLD"] {
                    drawCell(label, rect: CGRect(x: x, y: y - headerHeight, width: summaryColWidth, height: headerHeight),
                             font: .boldSystemFont(ofSize: 8), align: .center, textColor: .black, fill: nil)
                    x += summaryColWidth
                }

                var lastMonth = ""
                for day in dayChunk {
                    let month = monthFormatter.string(from: day.date)
                    let monthLabel = month != lastMonth ? month : ""
                    lastMonth = month
                    let headerText = "\(monthLabel)\n\(weekdayFormatter.string(from: day.date))\n\(dayNumFormatter.string(from: day.date))"
                    drawMultilineHeader(headerText, rect: CGRect(x: x, y: y - headerHeight, width: dayColWidth, height: headerHeight),
                                        isOff: day.scenes.isEmpty)
                    x += dayColWidth
                }
                y -= headerHeight
                let gridBottom0 = y

                // Rows
                for row in rowChunk {
                    var rx = margin
                    drawCell(row.displayName, rect: CGRect(x: rx, y: y - rowHeight, width: nameColWidth, height: rowHeight),
                             font: .systemFont(ofSize: 9), align: .left, textColor: .black, fill: nil)
                    rx += nameColWidth

                    drawCell("\(row.totalSpan)", rect: CGRect(x: rx, y: y - rowHeight, width: summaryColWidth, height: rowHeight),
                             font: .boldSystemFont(ofSize: 9), align: .center, textColor: .black, fill: nil)
                    rx += summaryColWidth
                    drawCell("\(row.workDayCount)", rect: CGRect(x: rx, y: y - rowHeight, width: summaryColWidth, height: rowHeight),
                             font: .systemFont(ofSize: 9), align: .center, textColor: .black, fill: nil)
                    rx += summaryColWidth
                    drawCell("\(row.holdDayCount)", rect: CGRect(x: rx, y: y - rowHeight, width: summaryColWidth, height: rowHeight),
                             font: .systemFont(ofSize: 9), align: .center, textColor: .black, fill: nil)
                    rx += summaryColWidth

                    for i in dayStart..<(dayStart + dayChunk.count) {
                        let status = row.statuses[i]
                        drawCell(status.code, rect: CGRect(x: rx, y: y - rowHeight, width: dayColWidth, height: rowHeight),
                                 font: .boldSystemFont(ofSize: 7), align: .center, textColor: status.textColor, fill: status.fillColor)
                        rx += dayColWidth
                    }
                    y -= rowHeight
                }
                let gridBottom = y

                // Grid lines
                drawGrid(top: gridTop, headerBottom: gridBottom0, bottom: gridBottom,
                         left: margin, nameColWidth: nameColWidth, summaryColWidth: summaryColWidth,
                         dayColWidth: dayColWidth, dayCount: dayChunk.count, rowCount: rowChunk.count, rowHeight: rowHeight)

                // Legend (every page, since pages can be viewed independently)
                let legendY = margin - 4
                let legendText = "SW = Start Work    W = Work    H = Hold    WF = Work Finish    SWF = Start/Work/Finish    TOT = Total Days    WRK = Work Days    HLD = Hold Days"
                NSAttributedString(string: legendText, attributes: [
                    .font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.gray
                ]).draw(at: CGPoint(x: margin, y: legendY))

                NSGraphicsContext.restoreGraphicsState()
                context.endPDFPage()
            }
        }

        context.closePDF()
        return pdfData as Data
    }

    // MARK: - Drawing helpers

    private static func drawCell(_ text: String, rect: CGRect, font: NSFont, align: NSTextAlignment, textColor: NSColor, fill: NSColor?) {
        if let fill = fill {
            fill.setFill()
            NSBezierPath(rect: rect).fill()
        }
        guard !text.isEmpty else { return }
        let style = NSMutableParagraphStyle()
        style.alignment = align
        let attrString = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: textColor, .paragraphStyle: style
        ])
        let textHeight = attrString.size().height
        let textRect = CGRect(x: rect.minX + 2, y: rect.minY + (rect.height - textHeight) / 2,
                               width: rect.width - 4, height: textHeight)
        attrString.draw(in: textRect)
    }

    private static func drawMultilineHeader(_ text: String, rect: CGRect, isOff: Bool) {
        if isOff {
            NSColor(calibratedWhite: 0.9, alpha: 1).setFill()
            NSBezierPath(rect: rect).fill()
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 0
        let attrString = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 7), .foregroundColor: NSColor.black, .paragraphStyle: style
        ])
        attrString.draw(in: rect.insetBy(dx: 0, dy: 2))
    }

    private static func drawGrid(
        top: CGFloat, headerBottom: CGFloat, bottom: CGFloat,
        left: CGFloat, nameColWidth: CGFloat, summaryColWidth: CGFloat,
        dayColWidth: CGFloat, dayCount: Int, rowCount: Int, rowHeight: CGFloat
    ) {
        let path = NSBezierPath()
        path.lineWidth = 0.4
        NSColor.lightGray.setStroke()

        let right = left + nameColWidth + summaryColWidth * 3 + dayColWidth * CGFloat(dayCount)

        // Header underline + outer box
        path.move(to: CGPoint(x: left, y: headerBottom)); path.line(to: CGPoint(x: right, y: headerBottom))
        path.move(to: CGPoint(x: left, y: top)); path.line(to: CGPoint(x: right, y: top))
        path.move(to: CGPoint(x: left, y: bottom)); path.line(to: CGPoint(x: right, y: bottom))
        path.move(to: CGPoint(x: left, y: top)); path.line(to: CGPoint(x: left, y: bottom))
        path.move(to: CGPoint(x: right, y: top)); path.line(to: CGPoint(x: right, y: bottom))

        // Row separators
        for i in 0...rowCount {
            let y = headerBottom - CGFloat(i) * rowHeight
            path.move(to: CGPoint(x: left, y: y)); path.line(to: CGPoint(x: right, y: y))
        }

        // Column separators: name | TOT | WRK | HLD | day, day, day...
        var x = left + nameColWidth
        path.move(to: CGPoint(x: x, y: top)); path.line(to: CGPoint(x: x, y: bottom))
        for _ in 0..<3 {
            x += summaryColWidth
            path.move(to: CGPoint(x: x, y: top)); path.line(to: CGPoint(x: x, y: bottom))
        }
        for _ in 0..<dayCount {
            x += dayColWidth
            path.move(to: CGPoint(x: x, y: top)); path.line(to: CGPoint(x: x, y: bottom))
        }
        path.stroke()
    }
}
