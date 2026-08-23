// StripboardPDFExporter.swift
// A modernized, printed take on a Movie Magic Scheduling color strip
// schedule — a portrait, day-by-day stack of color-coded strips ending in a
// black "END OF DAY" bar, generated straight from the stripboard view.
// Deliberately not a reskin of PDFExporter's landscape calendar-grid layout;
// this is the "hand someone the stripboard" document, not the month view.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

class StripboardPDFExporter {

    private static let pageWidth:  CGFloat = 612   // US Letter portrait
    private static let pageHeight: CGFloat = 792
    private static let margin:     CGFloat = 40
    private static let contentWidth: CGFloat = pageWidth - 2 * margin

    private static let fontTitle     = NSFont.boldSystemFont(ofSize: 18)
    private static let fontSubtitle  = NSFont.systemFont(ofSize: 10)
    private static let fontDayHeader = NSFont.boldSystemFont(ofSize: 11)
    private static let fontDaySub    = NSFont.systemFont(ofSize: 8.5)
    private static let fontStripNum  = NSFont.boldSystemFont(ofSize: 9)
    private static let fontStripTitle = NSFont.boldSystemFont(ofSize: 9.5)
    private static let fontStripMeta  = NSFont.systemFont(ofSize: 8)
    private static let fontEOD        = NSFont.boldSystemFont(ofSize: 8.5)
    private static let fontFooter     = NSFont.systemFont(ofSize: 7.5)

    private static let colorBlack  = NSColor.black
    private static let colorDark   = NSColor(white: 0.15, alpha: 1)
    private static let colorMid    = NSColor(white: 0.45, alpha: 1)
    private static let dayHeaderBG = NSColor(white: 0.88, alpha: 1)

    private static let dayHeaderHeight: CGFloat = 20
    private static let stripHeight:     CGFloat = 18
    private static let eodHeight:       CGFloat = 20
    private static let stripSpacing:    CGFloat = 1.5

    // MARK: - Entry point

    static func generatePDF(
        shootDays: [ShootDay],
        projectTitle: String,
        productionInfo: ProductionInfo
    ) -> Data? {
        // A printed schedule is a distributable document, not the live planning
        // board — skip days nobody's scheduled anything into yet.
        let scheduledDays = shootDays.filter { !$0.scenes.isEmpty }
        guard !scheduledDays.isEmpty else { return nil }

        let dayNumbers = productionDayNumbers(for: shootDays)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        var y: CGFloat = pageHeight - margin
        var pageNumber = 0

        func beginPage() {
            pageNumber += 1
            ctx.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            y = pageHeight - margin
        }
        func endPage() {
            drawFooter(pageNumber: pageNumber)
            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
        }
        /// Starts a new page if `height` won't fit in what's left above the
        /// bottom margin — used before every row so a strip or bar never gets
        /// sliced in half across a page break.
        func ensureRoom(_ height: CGFloat) {
            if y - height < margin {
                endPage()
                beginPage()
            }
        }

        beginPage()
        y = drawTitleHeader(y: y, projectTitle: projectTitle, productionInfo: productionInfo)

        for day in scheduledDays {
            let dayNumber = dayNumbers[day.id]

            ensureRoom(dayHeaderHeight + stripHeight)   // header alone with nothing under it reads as an error
            y = drawDayHeader(y: y, day: day, dayNumber: dayNumber)

            for scene in day.scenes {
                ensureRoom(stripHeight)
                y = drawSceneStrip(y: y, scene: scene)
            }

            if dayNumber != nil {
                ensureRoom(eodHeight)
                y = drawEndOfDayBar(y: y, day: day, dayNumber: dayNumber!)
            }

            y -= 8   // breathing room before the next day
        }

        endPage()
        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Title header (page 1 only)

    private static func drawTitleHeader(y: CGFloat, projectTitle: String, productionInfo: ProductionInfo) -> CGFloat {
        var y = y
        y = drawText(projectTitle.isEmpty ? "Untitled Movie" : projectTitle,
                     font: fontTitle, color: colorBlack, x: margin, y: y, width: contentWidth)
        var subtitle = "Strip Schedule"
        if !productionInfo.companyName.isEmpty { subtitle += "   —   \(productionInfo.companyName)" }
        y = drawText(subtitle, font: fontSubtitle, color: colorMid, x: margin, y: y, width: contentWidth)
        y -= 8
        drawHRule(y: y)
        y -= 14
        return y
    }

    // MARK: - Day header band

    private static func drawDayHeader(y: CGFloat, day: ShootDay, dayNumber: Int?) -> CGFloat {
        let rect = CGRect(x: margin, y: y - dayHeaderHeight, width: contentWidth, height: dayHeaderHeight)
        dayHeaderBG.setFill()
        NSBezierPath(rect: rect).fill()

        // Left: "Day N", only for counted production days.
        if let dayNumber {
            let leftAttr: [NSAttributedString.Key: Any] = [.font: fontDayHeader, .foregroundColor: colorDark]
            NSAttributedString(string: "Day \(dayNumber)", attributes: leftAttr)
                .draw(in: CGRect(x: rect.minX + 6, y: rect.midY - 6, width: 90, height: 13))
        }

        // Center: the full date — the page/time totals already live on the
        // END OF DAY bar below, so this header doesn't repeat them.
        let centerPara = NSMutableParagraphStyle(); centerPara.alignment = .center
        let centerAttr: [NSAttributedString.Key: Any] = [.font: fontDayHeader, .foregroundColor: colorDark, .paragraphStyle: centerPara]
        NSAttributedString(string: formattedFullDate(day.date), attributes: centerAttr)
            .draw(in: CGRect(x: rect.minX, y: rect.midY - 6, width: rect.width, height: 13))

        // Right: scene count only. The "X/8 pgs" column below is left-anchored
        // at rect.maxX-56 but its values (e.g. "2/8 pgs") don't fill the full
        // 50pt box, so matching that left edge exactly still reads as too far
        // right relative to where those values visually sit. Starting a bit
        // further left — rather than center-aligning within the same box,
        // which only adds *more* left padding and pushes it right — lines the
        // two up.
        let sub = "\(day.scenes.count) scene\(day.scenes.count == 1 ? "" : "s")"
        let rightAttr: [NSAttributedString.Key: Any] = [.font: fontDaySub, .foregroundColor: colorMid]
        NSAttributedString(string: sub, attributes: rightAttr)
            .draw(in: CGRect(x: rect.maxX - 61, y: rect.midY - 5, width: 50, height: 11))

        return y - dayHeaderHeight - stripSpacing
    }

    // MARK: - Scene strip

    private static func drawSceneStrip(y: CGFloat, scene: Scene) -> CGFloat {
        let rect = CGRect(x: margin, y: y - stripHeight, width: contentWidth, height: stripHeight)
        NSColor(scene.stripColor).setFill()
        NSBezierPath(rect: rect).fill()
        NSColor.black.withAlphaComponent(0.25).setStroke()
        let border = NSBezierPath(rect: rect); border.lineWidth = 0.5; border.stroke()

        let textColor = NSColor(scene.stripTextColor)
        var x = rect.minX + 6

        if !scene.sceneNumber.isEmpty {
            let numAttr: [NSAttributedString.Key: Any] = [.font: fontStripNum, .foregroundColor: textColor.withAlphaComponent(0.7)]
            let numStr = NSAttributedString(string: scene.sceneNumber, attributes: numAttr)
            let numWidth: CGFloat = 26
            numStr.draw(in: CGRect(x: x, y: rect.midY - 5, width: numWidth, height: 11))
            x += numWidth
        }

        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byTruncatingTail
        let titleAttr: [NSAttributedString.Key: Any] = [.font: fontStripTitle, .foregroundColor: textColor, .paragraphStyle: para]
        let metaAttr:  [NSAttributedString.Key: Any] = [.font: fontStripMeta, .foregroundColor: textColor.withAlphaComponent(0.65), .paragraphStyle: para]

        let pagesStr = "\(formattedEighths(scene.duration)) pgs"
        let pagesWidth: CGFloat = 50
        NSAttributedString(string: pagesStr, attributes: metaAttr)
            .draw(in: CGRect(x: rect.maxX - pagesWidth - 6, y: rect.midY - 5, width: pagesWidth, height: 11))

        let castStr = scene.cast.isEmpty ? "" : scene.cast.joined(separator: ", ")
        let castWidth: CGFloat = castStr.isEmpty ? 0 : 150
        if !castStr.isEmpty {
            NSAttributedString(string: castStr, attributes: metaAttr)
                .draw(in: CGRect(x: rect.maxX - pagesWidth - castWidth - 12, y: rect.midY - 5, width: castWidth, height: 11))
        }

        let titleWidth = rect.maxX - pagesWidth - castWidth - 18 - x
        NSAttributedString(string: scene.title, attributes: titleAttr)
            .draw(in: CGRect(x: x, y: rect.midY - 5.5, width: max(titleWidth, 20), height: 12))

        return y - stripHeight - stripSpacing
    }

    // MARK: - End of day bar

    private static func drawEndOfDayBar(y: CGFloat, day: ShootDay, dayNumber: Int) -> CGFloat {
        let rect = CGRect(x: margin, y: y - eodHeight, width: contentWidth, height: eodHeight)
        colorBlack.setFill()
        NSBezierPath(rect: rect).fill()

        let text = "-- END OF DAY #\(dayNumber) -- \(formattedFullDate(day.date)) -- \(formattedEighths(day.totalDuration)) pgs. -- Estimated time: \(formattedTimeHM(day.totalEstimatedTime))"
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attr: [NSAttributedString.Key: Any] = [.font: fontEOD, .foregroundColor: NSColor.white, .paragraphStyle: para]
        NSAttributedString(string: text, attributes: attr)
            .draw(in: CGRect(x: rect.minX, y: rect.midY - 5, width: rect.width, height: 11))

        return y - eodHeight
    }

    // MARK: - Footer

    private static func drawFooter(pageNumber: Int) {
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attr: [NSAttributedString.Key: Any] = [.font: fontFooter, .foregroundColor: colorMid, .paragraphStyle: para]
        NSAttributedString(string: "Page \(pageNumber)", attributes: attr)
            .draw(in: CGRect(x: margin, y: margin - 20, width: contentWidth, height: 10))
    }

    // MARK: - Low-level drawing helpers

    private static func drawText(_ text: String, font: NSFont, color: NSColor, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = NSAttributedString(string: text, attributes: attr)
        let height = str.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height
        str.draw(in: CGRect(x: x, y: y - height, width: width, height: height))
        return y - height - 2
    }

    private static func drawHRule(y: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = 1
        NSColor(white: 0.7, alpha: 1).setStroke()
        path.move(to: CGPoint(x: margin, y: y))
        path.line(to: CGPoint(x: pageWidth - margin, y: y))
        path.stroke()
    }
}
