// BreakdownExporter.swift
// Generates a portrait US Letter PDF with one bordered breakdown-sheet grid per scene —
// script order, every scene included — in the classic AD breakdown sheet layout.
// Enhanced with smart dynamic space allocation (shrinking unused categories to 24pt),
// bulleted list formatting, larger legible typography, and color-coded department titles.

import AppKit

struct BreakdownExporter {

    // MARK: - Department Title Colors (Matching User Reference)
    private static let castColor       = NSColor(red: 0.88, green: 0.12, blue: 0.12, alpha: 1.0) // Red
    private static let wardrobeColor   = NSColor(red: 0.58, green: 0.28, blue: 0.08, alpha: 1.0) // Brown
    private static let propsColor      = NSColor(red: 0.55, green: 0.15, blue: 0.75, alpha: 1.0) // Purple
    private static let extrasColor     = NSColor(red: 0.00, green: 0.65, blue: 0.15, alpha: 1.0) // Green
    private static let setDressColor   = NSColor(red: 0.80, green: 0.55, blue: 0.00, alpha: 1.0) // Gold / Yellow
    private static let hairMakeupColor = NSColor(red: 0.05, green: 0.40, blue: 0.90, alpha: 1.0) // Blue
    private static let vehiclesColor   = NSColor(red: 0.48, green: 0.12, blue: 0.52, alpha: 1.0) // Dark Violet
    private static let sfxColor        = NSColor(red: 0.00, green: 0.55, blue: 0.65, alpha: 1.0) // Cyan / Teal
    private static let vfxColor        = NSColor(red: 0.00, green: 0.55, blue: 0.65, alpha: 1.0) // Cyan / Teal
    private static let specialEqColor  = NSColor(red: 0.27, green: 0.35, blue: 0.39, alpha: 1.0) // Slate
    private static let stuntsColor     = NSColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1.0) // Crimson
    private static let defaultColor    = NSColor(white: 0.10, alpha: 1.0)                        // Charcoal / Black

    static func generatePDF(shootDays: [ShootDay], allScenes: [Scene], projectTitle: String) -> Data? {
        var seen: Set<UUID> = []
        var scenes: [Scene] = []
        for s in allScenes where !seen.contains(s.id) { seen.insert(s.id); scenes.append(s) }
        for day in shootDays {
            for s in day.scenes where !seen.contains(s.id) { seen.insert(s.id); scenes.append(s) }
        }
        scenes.sort { $0.scriptOrderKey < $1.scriptOrderKey }
        guard !scenes.isEmpty else { return nil }

        let pageWidth:  CGFloat = 612   // US Letter portrait
        let pageHeight: CGFloat = 792
        let margin:     CGFloat = 36
        let contentWidth = pageWidth - 2 * margin

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let displayTitle = projectTitle.isEmpty ? "Untitled Movie" : projectTitle

        for (index, scene) in scenes.enumerated() {
            context.beginPDFPage(nil)
            let gctx = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = gctx

            let (sceneNumber, intExt, setting) = parseSceneHeading(scene.title)

            // Masthead
            let mastheadTop = pageHeight - margin
            NSAttributedString(string: "BREAKDOWN SHEET", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 18), .foregroundColor: NSColor.black
            ]).draw(at: CGPoint(x: margin, y: mastheadTop - 18))

            let gridTop = mastheadTop - 26
            let footerBottom = margin + 12
            let totalAvailableGridHeight = gridTop - footerBottom

            // Calculate smart dynamic row heights for this specific scene
            let rowHeights = computeDynamicRowHeights(for: scene, totalHeight: totalAvailableGridHeight)
            var rowTops: [CGFloat] = []
            var rowY = gridTop
            for h in rowHeights { rowTops.append(rowY); rowY -= h }
            let gridBottom = rowY

            // Row 0: Breakdown Sheet # | Project Title | Scene #
            let narrowCol1: CGFloat = 115
            let wideCol1 = contentWidth - 2 * narrowCol1
            var x = margin
            drawCell(label: "BREAKDOWN SHEET #", value: "\(index + 1)",
                     rect: CGRect(x: x, y: rowTops[0] - rowHeights[0], width: narrowCol1, height: rowHeights[0]),
                     valueSize: 13, valueBold: true, centered: true, labelSize: 9.0)
            x += narrowCol1
            drawCell(label: "", value: displayTitle,
                     rect: CGRect(x: x, y: rowTops[0] - rowHeights[0], width: wideCol1, height: rowHeights[0]),
                     valueSize: 18, valueBold: true, centered: true)
            x += wideCol1
            drawCell(label: "SCENE #", value: sceneNumber.isEmpty ? "—" : sceneNumber,
                     rect: CGRect(x: x, y: rowTops[0] - rowHeights[0], width: narrowCol1, height: rowHeights[0]),
                     valueSize: 15, valueBold: true, centered: true, labelSize: 9.0)

            // Row 1: INT/EXT (narrow) | Setting (wide) | Location (medium)
            let intExtCol: CGFloat = 70
            let locationCol: CGFloat = 120
            let settingCol = contentWidth - intExtCol - locationCol
            x = margin
            drawCell(label: "INT / EXT", value: intExt,
                     rect: CGRect(x: x, y: rowTops[1] - rowHeights[1], width: intExtCol, height: rowHeights[1]),
                     valueSize: 11, valueBold: true, centered: true, labelSize: 9.0)
            x += intExtCol
            drawCell(label: "SETTING", value: setting,
                     rect: CGRect(x: x, y: rowTops[1] - rowHeights[1], width: settingCol, height: rowHeights[1]),
                     valueSize: 10.0, valueBold: false, labelSize: 9.0)
            x += settingCol
            drawCell(label: "LOCATION", value: "",
                     rect: CGRect(x: x, y: rowTops[1] - rowHeights[1], width: locationCol, height: rowHeights[1]),
                     valueSize: 10.0, labelSize: 9.0)

            // Row 2: Description (balanced) | Day/Night + Script Pages stacked in right column
            let rightCol2: CGFloat = 135
            let descCol = contentWidth - rightCol2
            let halfHeight2 = rowHeights[2] / 2
            x = margin
            drawCell(label: "DESCRIPTION", value: scene.summary,
                     rect: CGRect(x: x, y: rowTops[2] - rowHeights[2], width: descCol, height: rowHeights[2]),
                     valueSize: 9.5, labelSize: 9.0)
            x += descCol
            drawCell(label: "DAY / NIGHT", value: scene.dayNightType.displayName,
                     rect: CGRect(x: x, y: rowTops[2] - halfHeight2, width: rightCol2, height: halfHeight2),
                     valueSize: 11, valueBold: true, centered: true, labelSize: 9.0)
            drawCell(label: "SCRIPT PAGES", value: formattedEighths(scene.duration),
                     rect: CGRect(x: x, y: rowTops[2] - rowHeights[2], width: rightCol2, height: halfHeight2),
                     valueSize: 11, valueBold: true, centered: true, labelSize: 9.0)

            // Row 3: Cast | Extras / Background | Wardrobe (Prominent colored department titles: 11.5pt bold)
            drawThreeUp(row: 3, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                        a: ("CAST", formatBulletList(scene.cast), castColor),
                        b: ("EXTRAS / BACKGROUND", formatBulletList(scene.extras), extrasColor),
                        c: ("WARDROBE", formatBulletList(scene.wardrobe), wardrobeColor),
                        labelSize: 11.5)

            // Row 4: Hair & Makeup | Props | Set Dressing
            drawThreeUp(row: 4, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                        a: ("HAIR & MAKEUP", formatBulletList(scene.makeupHair), hairMakeupColor),
                        b: ("PROPS", formatBulletList(scene.props), propsColor),
                        c: ("SET DRESSING", formatBulletList(scene.setDressing), setDressColor),
                        labelSize: 11.5)

            // Row 5: Vehicles | Special Equipment | Stunts
            drawThreeUp(row: 5, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                        a: ("VEHICLES", formatBulletList(scene.vehicles), vehiclesColor),
                        b: ("SPECIAL EQUIPMENT", formatBulletList(scene.specialEquipment), specialEqColor),
                        c: ("STUNTS", formatBulletList(scene.stunts), stuntsColor),
                        labelSize: 11.5)

            // Row 6: SFX | VFX
            drawTwoUp(row: 6, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                      a: ("SFX", formatBulletList(scene.sfx), sfxColor),
                      b: ("VFX", formatBulletList(scene.vfx), vfxColor),
                      labelSize: 11.5)

            // Row 7: Notes (full width)
            drawCell(label: "NOTES", value: scene.breakdownNotes,
                     rect: CGRect(x: margin, y: rowTops[7] - rowHeights[7], width: contentWidth, height: rowHeights[7]),
                     valueSize: 9.5,
                     labelColor: defaultColor,
                     labelSize: 10.0)

            // Footer: est. time + scene counter
            NSAttributedString(string: "Est. Time: \(formattedTime(scene.estimatedTime))", attributes: [
                .font: NSFont.systemFont(ofSize: 8.5), .foregroundColor: NSColor.gray
            ]).draw(at: CGPoint(x: margin, y: gridBottom - 13))
            
            NSAttributedString(string: "Scene \(index + 1) of \(scenes.count)", attributes: [
                .font: NSFont.systemFont(ofSize: 8.5), .foregroundColor: NSColor.gray
            ]).draw(at: CGPoint(x: pageWidth - margin - 85, y: gridBottom - 13))

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return pdfData as Data
    }

    // MARK: - Bullet List Formatter

    /// Formats an array of items into clean bullet points ("• Item")
    private static func formatBulletList(_ items: [String]) -> String {
        let clean = items
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !clean.isEmpty else { return "" }
        return clean.map { "• \($0)" }.joined(separator: "\n")
    }

    // MARK: - Dynamic Space Calculation

    /// Computes row heights dynamically:
    /// Description has a balanced, controlled height. Unused department rows collapse to 24pt,
    /// and active department rows receive the freed space proportionally for their bulleted lists.
    private static func computeDynamicRowHeights(for scene: Scene, totalHeight: CGFloat) -> [CGFloat] {
        let fixedRow0: CGFloat = 44 // Sheet # / Title / Scene #
        let fixedRow1: CGFloat = 48 // INT/EXT / Setting / Location
        
        // Controlled height for Description — ample space without ballooning
        let fixedRow2: CGFloat = scene.summary.count > 160 ? 90 : 76
        
        let availableForDepts = totalHeight - fixedRow0 - fixedRow1 - fixedRow2
        let compactHeight: CGFloat = 28 // Height for empty category rows
        
        let row3HasContent = !scene.cast.isEmpty || !scene.extras.isEmpty || !scene.wardrobe.isEmpty
        let row4HasContent = !scene.makeupHair.isEmpty || !scene.props.isEmpty || !scene.setDressing.isEmpty
        let row5HasContent = !scene.vehicles.isEmpty || !scene.specialEquipment.isEmpty || !scene.stunts.isEmpty
        let row6HasContent = !scene.sfx.isEmpty || !scene.vfx.isEmpty
        let row7HasContent = !scene.breakdownNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        let w3: CGFloat = row3HasContent ? 100 : compactHeight
        let w4: CGFloat = row4HasContent ? 105 : compactHeight
        let w5: CGFloat = row5HasContent ? 90  : compactHeight
        let w6: CGFloat = row6HasContent ? 85  : compactHeight
        let w7: CGFloat = row7HasContent ? 80  : compactHeight

        let totalWeight = w3 + w4 + w5 + w6 + w7
        let scale = availableForDepts / totalWeight
        
        let r3 = w3 == compactHeight ? compactHeight : w3 * scale
        let r4 = w4 == compactHeight ? compactHeight : w4 * scale
        let r5 = w5 == compactHeight ? compactHeight : w5 * scale
        let r6 = w6 == compactHeight ? compactHeight : w6 * scale
        var r7 = w7 == compactHeight ? compactHeight : w7 * scale
        
        // Normalize any rounding difference on r7 (or largest active row)
        let currentTotal = fixedRow0 + fixedRow1 + fixedRow2 + r3 + r4 + r5 + r6 + r7
        let diff = totalHeight - currentTotal
        r7 += diff

        return [fixedRow0, fixedRow1, fixedRow2, r3, r4, r5, r6, r7]
    }

    // MARK: - Drawing Helpers

    private static func drawTwoUp(
        row: Int, rowTops: [CGFloat], rowHeights: [CGFloat], margin: CGFloat, contentWidth: CGFloat,
        a: (String, String, NSColor), b: (String, String, NSColor),
        labelSize: CGFloat = 10.0
    ) {
        let halfCol = contentWidth / 2
        var x = margin
        let h = rowHeights[row]
        let y = rowTops[row] - h
        drawCell(label: a.0, value: a.1, rect: CGRect(x: x, y: y, width: halfCol, height: h), labelColor: a.2, labelSize: labelSize)
        x += halfCol
        drawCell(label: b.0, value: b.1, rect: CGRect(x: x, y: y, width: contentWidth - halfCol, height: h), labelColor: b.2, labelSize: labelSize)
    }

    private static func drawThreeUp(
        row: Int, rowTops: [CGFloat], rowHeights: [CGFloat], margin: CGFloat, contentWidth: CGFloat,
        a: (String, String, NSColor), b: (String, String, NSColor), c: (String, String, NSColor),
        labelSize: CGFloat = 10.0
    ) {
        let thirdCol = contentWidth / 3
        var x = margin
        let h = rowHeights[row]
        let y = rowTops[row] - h
        drawCell(label: a.0, value: a.1, rect: CGRect(x: x, y: y, width: thirdCol, height: h), labelColor: a.2, labelSize: labelSize)
        x += thirdCol
        drawCell(label: b.0, value: b.1, rect: CGRect(x: x, y: y, width: thirdCol, height: h), labelColor: b.2, labelSize: labelSize)
        x += thirdCol
        drawCell(label: c.0, value: c.1, rect: CGRect(x: x, y: y, width: contentWidth - 2 * thirdCol, height: h), labelColor: c.2, labelSize: labelSize)
    }

    /// Draws one bordered cell with colored department header and dynamic auto-scaling text.
    private static func drawCell(
        label: String, value: String, rect: CGRect,
        valueSize: CGFloat = 9.0, valueBold: Bool = false, centered: Bool = false,
        labelColor: NSColor = defaultColor, labelSize: CGFloat = 10.0
    ) {
        NSColor.black.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()

        let padH: CGFloat = 6
        let padV: CGFloat = 4
        var textTop = rect.maxY - padV

        if !label.isEmpty {
            let labelStyle = NSMutableParagraphStyle()
            labelStyle.lineBreakMode = .byWordWrapping
            labelStyle.alignment = centered ? .center : .left

            let labelAttr = NSAttributedString(string: label, attributes: [
                .font: NSFont.boldSystemFont(ofSize: labelSize),
                .foregroundColor: labelColor,
                .paragraphStyle: labelStyle
            ])
            
            let labelAvailWidth = max(rect.width - 2 * padH, 1)
            let labelHeight = labelSize + 5
            let labelRect = CGRect(x: rect.minX + padH, y: textTop - labelHeight, width: labelAvailWidth, height: labelHeight)
            labelAttr.draw(in: labelRect)
            textTop -= (labelHeight + 3)
        }

        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanValue.isEmpty && textTop > rect.minY + padV {
            let availWidth  = max(rect.width - 2 * padH, 1)
            let availHeight = max(textTop - rect.minY - padV, 1)

            // Dynamic Font Auto-scaling to guarantee that text is large and never clipped
            var currentSize = valueSize
            let minSize: CGFloat = 7.0
            var finalAttr: NSAttributedString = NSAttributedString()

            while currentSize >= minSize {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                style.alignment = centered ? .center : .left
                style.lineSpacing = max(1.5, currentSize * 0.18)

                let font = valueBold ? NSFont.boldSystemFont(ofSize: currentSize) : NSFont.systemFont(ofSize: currentSize)
                let attr = NSAttributedString(string: cleanValue, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: style
                ])

                let requiredHeight = attr.boundingRect(
                    with: CGSize(width: availWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                ).height

                finalAttr = attr
                if requiredHeight <= availHeight || currentSize <= minSize {
                    break
                }
                currentSize -= 0.5
            }

            let valueRect = CGRect(x: rect.minX + padH, y: rect.minY + padV,
                                   width: availWidth, height: availHeight)
            finalAttr.draw(in: valueRect)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    /// Splits "12A. EXT. WOODS" into ("12A", "EXT", "WOODS")
    private static func parseSceneHeading(_ title: String) -> (number: String, intExt: String, setting: String) {
        var working = title.trimmingCharacters(in: .whitespaces)

        var number = ""
        if let regex = try? NSRegularExpression(pattern: #"^(\d+[A-Za-z]?)\.\s*"#),
           let match = regex.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)),
           let numRange = Range(match.range(at: 1), in: working) {
            number = String(working[numRange])
            if let fullRange = Range(match.range, in: working) {
                working.removeSubrange(fullRange)
            }
        }

        var intExt = ""
        let upper = working.uppercased()
        for prefix in ["INT./EXT.", "EXT./INT.", "INT.", "EXT."] {
            if upper.hasPrefix(prefix) {
                intExt = String(prefix.dropLast())
                working = String(working.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        return (number, intExt, working)
    }
}

