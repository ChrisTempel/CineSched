// CallSheetExporter.swift
// Generates a professional call sheet PDF for a single shoot day.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CallSheetExporter

class CallSheetExporter {

    // MARK: - Page constants
    private static let pageWidth:  CGFloat = 612   // US Letter portrait
    private static let pageHeight: CGFloat = 792
    private static let margin:     CGFloat = 50
    private static let colWidth:   CGFloat = 612 - 100  // content width

    // MARK: - Fonts
    private static let fontTitle     = NSFont.boldSystemFont(ofSize: 16)
    private static let fontHeading   = NSFont.boldSystemFont(ofSize: 11)
    private static let fontSubhead   = NSFont.boldSystemFont(ofSize: 9)
    private static let fontBody      = NSFont.systemFont(ofSize: 9)
    private static let fontSmall     = NSFont.systemFont(ofSize: 8)
    private static let fontCaption   = NSFont.systemFont(ofSize: 7.5)

    // MARK: - Colors
    private static let colorBlack    = NSColor.black
    private static let colorDark     = NSColor(white: 0.15, alpha: 1)
    private static let colorMid      = NSColor(white: 0.45, alpha: 1)
    private static let colorLight    = NSColor(white: 0.92, alpha: 1)
    private static let colorDivider  = NSColor(white: 0.75, alpha: 1)

    // MARK: - Generate

    static func generatePDF(
        shootDay: ShootDay,
        productionInfo: ProductionInfo,
        projectTitle: String
    ) -> Data? {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox  = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        ctx.beginPDFPage(nil)
        let gctx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx

        var y = pageHeight - margin
        y = drawPageHeader(y: y, shootDay: shootDay, productionInfo: productionInfo, projectTitle: projectTitle)
        y = drawSection(y: y, title: "LOCATIONS",       content: { yy in drawLocations(y: yy,  shootDay: shootDay) })
        y = drawSection(y: y, title: "SCENE BREAKDOWN", content: { yy in drawScenes(y: yy,     shootDay: shootDay) })
        y = drawSection(y: y, title: "CAST",            content: { yy in drawCast(y: yy,       shootDay: shootDay, productionInfo: productionInfo) })
        y = drawSection(y: y, title: "CREW",            content: { yy in drawCrew(y: yy,       productionInfo: productionInfo) })
           _ = drawSection(y: y, title: "NOTES",           content: { yy in drawNotes(y: yy,      shootDay: shootDay) })

        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Page Header

    private static func drawPageHeader(
        y: CGFloat,
        shootDay: ShootDay,
        productionInfo: ProductionInfo,
        projectTitle: String
    ) -> CGFloat {
        var y = y

        // Company name
        if !productionInfo.companyName.isEmpty {
            y = drawText(productionInfo.companyName.uppercased(),
                         font: fontHeading, color: colorMid, x: margin, y: y, width: colWidth)
            y -= 4
        }

        // Movie title (large)
        y = drawText(projectTitle.isEmpty ? "Untitled Movie" : projectTitle,
                     font: fontTitle, color: colorBlack, x: margin, y: y, width: colWidth * 0.65)

        // Date (right-aligned on same baseline as title)
        let dateStr = "Call Sheet — \(fullFormattedDate(shootDay.date))"
        drawTextRight(dateStr, font: fontBody, color: colorMid,
                      x: margin, y: y + 16, width: colWidth)

        y -= 6

        // Director / Contact — info row (without call time)
        var infoLine = ""
        if !productionInfo.directorName.isEmpty  { infoLine += "Director: \(productionInfo.directorName)     " }
        if !productionInfo.contactNumber.isEmpty { infoLine += "Contact: \(productionInfo.contactNumber)" }
        if !infoLine.isEmpty {
            y = drawText(infoLine.trimmingCharacters(in: .whitespaces),
                         font: fontBody, color: colorDark, x: margin, y: y, width: colWidth)
            y -= 4
        }

        // General Call Time — prominent, bold, right-aligned
        if !shootDay.callSheet.generalCallTime.isEmpty {
            let callAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 14),
                .foregroundColor: colorBlack
            ]
            let callLabel = NSAttributedString(
                string: "GENERAL CALL:  \(shootDay.callSheet.generalCallTime)",
                attributes: callAttr
            )
            let h = callLabel.size().height
            let para = NSMutableParagraphStyle()
            para.alignment = .right
            let callAttrRight: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 14),
                .foregroundColor: colorBlack,
                .paragraphStyle: para
            ]
            NSAttributedString(
                string: "GENERAL CALL:  \(shootDay.callSheet.generalCallTime)",
                attributes: callAttrRight
            ).draw(in: CGRect(x: margin, y: y - h, width: colWidth, height: h))
            y -= h + 4
        }

        // Heavy rule under header
        y -= 6
        drawHRule(y: y, thick: true)
        y -= 12
        return y
    }

    // MARK: - Section wrapper

    private static func drawSection(
        y: CGFloat,
        title: String,
        content: (CGFloat) -> CGFloat
    ) -> CGFloat {
        var y = y
        guard y > margin + 40 else { return y }   // no room — skip gracefully

        // Section title bar
        let barRect = CGRect(x: margin, y: y - 16, width: colWidth, height: 16)
        colorLight.setFill()
        NSBezierPath(rect: barRect).fill()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: fontSubhead,
            .foregroundColor: colorDark
        ]
        NSAttributedString(string: title, attributes: titleAttr)
            .draw(in: CGRect(x: margin + 6, y: y - 14, width: colWidth - 12, height: 14))

        y -= 20
        y = content(y)
        y -= 10
        drawHRule(y: y, thick: false)
        y -= 10
        return y
    }

    // MARK: - Section content drawers

    private static func drawLocations(y: CGFloat, shootDay: ShootDay) -> CGFloat {
        var y = y
        let locs = shootDay.callSheet.locations
        if locs.isEmpty {
            return drawText("No locations specified.", font: fontBody, color: colorMid,
                            x: margin + 6, y: y, width: colWidth - 12)
        }
        for (i, loc) in locs.enumerated() {
            let nameStr = "\(i + 1).  \(loc.name.isEmpty ? "Unnamed Location" : loc.name)"
            y = drawText(nameStr, font: fontHeading, color: colorDark,
                         x: margin + 6, y: y, width: colWidth - 12)
            if !loc.address.isEmpty {
                y = drawText("      \(loc.address)", font: fontBody, color: colorMid,
                             x: margin + 6, y: y - 2, width: colWidth - 12)
                y -= 2
            }
            y -= 4
        }
        return y
    }

    private static func drawScenes(y: CGFloat, shootDay: ShootDay) -> CGFloat {
        var y = y
        if shootDay.scenes.isEmpty {
            return drawText("No scenes scheduled.", font: fontBody, color: colorMid,
                            x: margin + 6, y: y, width: colWidth - 12)
        }

        // Column headers
        let col1: CGFloat = margin + 6
        let col2: CGFloat = col1 + 36
        let col3: CGFloat = col2 + 260
        let col4: CGFloat = col3 + 50
        let colW1: CGFloat = 30
        let colW2: CGFloat = 255
        let colW3: CGFloat = 45
        let colW4: CGFloat = 60

        let headerAttr: [NSAttributedString.Key: Any] = [.font: fontSubhead, .foregroundColor: colorMid]
        NSAttributedString(string: "#",        attributes: headerAttr).draw(in: CGRect(x: col1, y: y - 12, width: colW1, height: 12))
        NSAttributedString(string: "LOCATION", attributes: headerAttr).draw(in: CGRect(x: col2, y: y - 12, width: colW2, height: 12))
        NSAttributedString(string: "D/N",      attributes: headerAttr).draw(in: CGRect(x: col3, y: y - 12, width: colW3, height: 12))
        NSAttributedString(string: "PAGES",    attributes: headerAttr).draw(in: CGRect(x: col4, y: y - 12, width: colW4, height: 12))
        y -= 16

        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingTail
        let rowAttr: [NSAttributedString.Key: Any] = [.font: fontBody, .foregroundColor: colorDark, .paragraphStyle: para]

        for (i, scene) in shootDay.scenes.enumerated() {
            // Zebra stripe
            if i % 2 == 0 {
                let stripe = CGRect(x: margin, y: y - 12, width: colWidth, height: 13)
                NSColor(white: 0.97, alpha: 1).setFill()
                NSBezierPath(rect: stripe).fill()
            }
            let sceneNum = extractSceneNumber(from: scene.title)
            let location = extractLocation(from: scene.title)
            NSAttributedString(string: sceneNum,                        attributes: rowAttr).draw(in: CGRect(x: col1, y: y - 11, width: colW1, height: 11))
            NSAttributedString(string: location,                        attributes: rowAttr).draw(in: CGRect(x: col2, y: y - 11, width: colW2, height: 11))
            NSAttributedString(string: scene.dayNightType.displayName,  attributes: rowAttr).draw(in: CGRect(x: col3, y: y - 11, width: colW3, height: 11))
            NSAttributedString(string: formattedEighths(scene.duration), attributes: rowAttr).draw(in: CGRect(x: col4, y: y - 11, width: colW4, height: 11))
            y -= 14
        }
        return y
    }

    private static func drawCast(y: CGFloat, shootDay: ShootDay, productionInfo: ProductionInfo) -> CGFloat {
        var y = y
        let cast = shootDay.callSheet.resolvedCast(from: shootDay.scenes, productionInfo: productionInfo)
        if cast.isEmpty {
            return drawText("No cast assigned to scenes on this day.", font: fontBody, color: colorMid,
                            x: margin + 6, y: y, width: colWidth - 12)
        }
        for (i, member) in cast.enumerated() {
            if i % 2 == 0 {
                let stripe = CGRect(x: margin, y: y - 12, width: colWidth, height: 13)
                NSColor(white: 0.97, alpha: 1).setFill()
                NSBezierPath(rect: stripe).fill()
            }
            drawTextInline(member, font: fontBody, color: colorDark,
                           x: margin + 6, y: y - 11, width: colWidth - 12)
            y -= 14
        }
        return y
    }

    private static func drawCrew(y: CGFloat, productionInfo: ProductionInfo) -> CGFloat {
        var y = y
        if productionInfo.crew.isEmpty {
            return drawText("No crew listed.", font: fontBody, color: colorMid,
                            x: margin + 6, y: y, width: colWidth - 12)
        }
        let nameWidth: CGFloat = 200
        let roleWidth: CGFloat = colWidth - 12 - nameWidth
        for (i, member) in productionInfo.crew.enumerated() {
            if i % 2 == 0 {
                let stripe = CGRect(x: margin, y: y - 12, width: colWidth, height: 13)
                NSColor(white: 0.97, alpha: 1).setFill()
                NSBezierPath(rect: stripe).fill()
            }
            drawTextInline(member.name, font: fontBody,    color: colorDark, x: margin + 6,             y: y - 11, width: nameWidth)
            drawTextInline(member.role, font: fontCaption, color: colorMid,  x: margin + 6 + nameWidth, y: y - 11, width: roleWidth)
            y -= 14
        }
        return y
    }

    private static func drawNotes(y: CGFloat, shootDay: ShootDay) -> CGFloat {
        let notes = shootDay.callSheet.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let startY = y - 6   // drop below the section header bar
        if notes.isEmpty {
            return drawText("No notes.", font: fontBody, color: colorMid,
                            x: margin + 6, y: startY, width: colWidth - 12)
        }
        return drawTextMultiline(notes, font: fontBody, color: colorDark,
                                 x: margin + 6, y: startY, width: colWidth - 12)
    }

    // MARK: - Low-level drawing helpers

    @discardableResult
    private static func drawText(
        _ text: String, font: NSFont, color: NSColor,
        x: CGFloat, y: CGFloat, width: CGFloat
    ) -> CGFloat {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str  = NSAttributedString(string: text, attributes: attr)
        let h    = str.size().height
        str.draw(in: CGRect(x: x, y: y - h, width: width, height: h))
        return y - h
    }

    private static func drawTextInline(
        _ text: String, font: NSFont, color: NSColor,
        x: CGFloat, y: CGFloat, width: CGFloat
    ) {
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingTail
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
        NSAttributedString(string: text, attributes: attr).draw(in: CGRect(x: x, y: y, width: width, height: 11))
    }

    private static func drawTextRight(
        _ text: String, font: NSFont, color: NSColor,
        x: CGFloat, y: CGFloat, width: CGFloat
    ) {
        let para = NSMutableParagraphStyle()
        para.alignment = .right
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
        let h = NSAttributedString(string: text, attributes: attr).size().height
        NSAttributedString(string: text, attributes: attr).draw(in: CGRect(x: x, y: y - h, width: width, height: h))
    }

    @discardableResult
    private static func drawTextMultiline(
        _ text: String, font: NSFont, color: NSColor,
        x: CGFloat, y: CGFloat, width: CGFloat
    ) -> CGFloat {
        let para = NSMutableParagraphStyle()
        para.lineSpacing    = 2
        para.lineBreakMode  = .byWordWrapping
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para
        ]
        let attrStr    = NSAttributedString(string: text, attributes: attr)
        let maxHeight:  CGFloat = 400
        let boundingSize = attrStr.boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        let h = ceil(boundingSize.height)
        attrStr.draw(in: CGRect(x: x, y: y - h, width: width, height: h))
        return y - h - 4
    }

    private static func drawHRule(y: CGFloat, thick: Bool) {
        let path = NSBezierPath()
        path.lineWidth = thick ? 1.0 : 0.4
        (thick ? colorDark : colorDivider).setStroke()
        path.move(to: CGPoint(x: margin, y: y))
        path.line(to: CGPoint(x: margin + colWidth, y: y))
        path.stroke()
    }

    // MARK: - Scene title parsing helpers

    /// Pulls the scene number from a title like "3. EXT. WOODS" → "3"
    private static func extractSceneNumber(from title: String) -> String {
        let pattern = #"^(\d+[A-Z]?)\."#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        return "—"
    }

    /// Strips the scene number prefix, leaving "EXT. WOODS" from "3. EXT. WOODS"
    private static func extractLocation(from title: String) -> String {
        let pattern = #"^\d+[A-Z]?\.\s*"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let result = regex.stringByReplacingMatches(
                in: title,
                range: NSRange(title.startIndex..., in: title),
                withTemplate: ""
            )
            return result.trimmingCharacters(in: .whitespaces)
        }
        return title
    }

    // MARK: - Date formatting

    private static func fullFormattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - CallSheetFile (FileDocument wrapper)

struct CallSheetFile: FileDocument {
    static var readableContentTypes:  [UTType] = [.pdf]
    static var writableContentTypes: [UTType] = [.pdf]

    private let shootDay:       ShootDay
    private let productionInfo: ProductionInfo
    private let projectTitle:   String

    init(shootDay: ShootDay, productionInfo: ProductionInfo, projectTitle: String) {
        self.shootDay       = shootDay
        self.productionInfo = productionInfo
        self.projectTitle   = projectTitle
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = CallSheetExporter.generatePDF(
            shootDay: shootDay,
            productionInfo: productionInfo,
            projectTitle: projectTitle
        ) else { throw CocoaError(.fileWriteUnknown) }
        return FileWrapper(regularFileWithContents: data)
    }
}
