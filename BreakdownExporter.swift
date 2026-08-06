// BreakdownExporter.swift
// Generates a portrait US Letter PDF with one bordered breakdown-sheet grid per scene —
// script order, every scene included — in the classic AD breakdown sheet layout.

import AppKit

struct BreakdownExporter {

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
        let margin:     CGFloat = 46
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

            // "BREAKDOWN SHEET" masthead
            var y = pageHeight - margin
            NSAttributedString(string: "BREAKDOWN SHEET", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 20), .foregroundColor: NSColor.black
            ]).draw(at: CGPoint(x: margin, y: y - 20))
            y -= 34

            let gridTop = y

            // Row heights — Description gets the lion's share; short fixed-vocabulary
            // fields (Day/Night, Script Pages) get just enough room for their actual
            // content instead of matching Description's width.
            let rowHeights: [CGFloat] = [58, 72, 165, 92, 92, 78, 70]
            var rowTops: [CGFloat] = []
            var rowY = gridTop
            for h in rowHeights { rowTops.append(rowY); rowY -= h }
            let gridBottom = rowY

            // Row 1: Breakdown Sheet # | Project Title | Scene #
            let narrowCol1: CGFloat = 100
            let wideCol1 = contentWidth - 2 * narrowCol1
            var x = margin
            drawCell(label: "BREAKDOWN SHEET #", value: "\(index + 1)",
                     rect: CGRect(x: x, y: rowTops[0] - rowHeights[0], width: narrowCol1, height: rowHeights[0]))
            x += narrowCol1
            drawCell(label: "", value: displayTitle,
                     rect: CGRect(x: x, y: rowTops[0] - rowHeights[0], width: wideCol1, height: rowHeights[0]),
                     valueSize: 20, valueBold: true, centered: true)
            x += wideCol1
            drawCell(label: "SCENE #", value: sceneNumber.isEmpty ? "—" : sceneNumber,
                     rect: CGRect(x: x, y: rowTops[0] - rowHeights[0], width: narrowCol1, height: rowHeights[0]),
                     valueSize: 16, valueBold: true, centered: true)

            // Row 2: INT/EXT (narrow) | Setting (wide — needs the room) | Location (medium, fillable)
            let intExtCol: CGFloat = 70
            let locationCol: CGFloat = 130
            let settingCol = contentWidth - intExtCol - locationCol
            x = margin
            drawCell(label: "INT / EXT", value: intExt,
                     rect: CGRect(x: x, y: rowTops[1] - rowHeights[1], width: intExtCol, height: rowHeights[1]))
            x += intExtCol
            drawCell(label: "SETTING", value: setting,
                     rect: CGRect(x: x, y: rowTops[1] - rowHeights[1], width: settingCol, height: rowHeights[1]))
            x += settingCol
            drawCell(label: "LOCATION", value: "",
                     rect: CGRect(x: x, y: rowTops[1] - rowHeights[1], width: locationCol, height: rowHeights[1]))

            // Row 3: Description (wide) | Day/Night + Script Pages stacked in a narrow column —
            // those two only ever hold a couple of words or "3/8", so they don't need to match
            // Description's width; stacking them instead gives Description most of the row.
            let rightCol3: CGFloat = 150
            let descCol = contentWidth - rightCol3
            let halfHeight3 = rowHeights[2] / 2
            x = margin
            drawCell(label: "DESCRIPTION", value: scene.summary,
                     rect: CGRect(x: x, y: rowTops[2] - rowHeights[2], width: descCol, height: rowHeights[2]))
            x += descCol
            drawCell(label: "DAY / NIGHT", value: scene.dayNightType.displayName,
                     rect: CGRect(x: x, y: rowTops[2] - halfHeight3, width: rightCol3, height: halfHeight3))
            drawCell(label: "SCRIPT PAGES", value: formattedEighths(scene.duration),
                     rect: CGRect(x: x, y: rowTops[2] - rowHeights[2], width: rightCol3, height: halfHeight3))

            // Row 4: Cast | Extras | VFX
            drawThreeUp(row: 3, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                        a: ("CAST", scene.cast.joined(separator: ", ")),
                        b: ("EXTRAS / BACKGROUND", scene.extras.joined(separator: ", ")),
                        c: ("VFX", scene.vfx.joined(separator: ", ")))

            // Row 5: Props | Wardrobe | Vehicles
            drawThreeUp(row: 4, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                        a: ("PROPS", scene.props.joined(separator: ", ")),
                        b: ("WARDROBE", scene.wardrobe.joined(separator: ", ")),
                        c: ("VEHICLES", scene.vehicles.joined(separator: ", ")))

            // Row 6: Special Equipment | Stunts | SFX
            drawThreeUp(row: 5, rowTops: rowTops, rowHeights: rowHeights, margin: margin, contentWidth: contentWidth,
                        a: ("SPECIAL EQUIPMENT", scene.specialEquipment.joined(separator: ", ")),
                        b: ("STUNTS", scene.stunts.joined(separator: ", ")),
                        c: ("SFX", scene.sfx.joined(separator: ", ")))

            // Row 7: Notes (full width)
            drawCell(label: "NOTES", value: scene.breakdownNotes,
                     rect: CGRect(x: margin, y: rowTops[6] - rowHeights[6], width: contentWidth, height: rowHeights[6]))

            // Footer: est. time + page counter, outside the grid
            NSAttributedString(string: "Est. Time: \(formattedTime(scene.estimatedTime))", attributes: [
                .font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.gray
            ]).draw(at: CGPoint(x: margin, y: gridBottom - 16))
            NSAttributedString(string: "Scene \(index + 1) of \(scenes.count)", attributes: [
                .font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.gray
            ]).draw(at: CGPoint(x: pageWidth - margin - 90, y: gridBottom - 16))

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return pdfData as Data
    }

    // MARK: - Drawing helpers

    private static func drawThreeUp(
        row: Int, rowTops: [CGFloat], rowHeights: [CGFloat], margin: CGFloat, contentWidth: CGFloat,
        a: (String, String), b: (String, String), c: (String, String)
    ) {
        let thirdCol = contentWidth / 3
        var x = margin
        let h = rowHeights[row]
        let y = rowTops[row] - h
        drawCell(label: a.0, value: a.1, rect: CGRect(x: x, y: y, width: thirdCol, height: h))
        x += thirdCol
        drawCell(label: b.0, value: b.1, rect: CGRect(x: x, y: y, width: thirdCol, height: h))
        x += thirdCol
        drawCell(label: c.0, value: c.1, rect: CGRect(x: x, y: y, width: contentWidth - 2 * thirdCol, height: h))
    }

    /// Draws one bordered cell: a small bold label at the top, and the value text (wrapped)
    /// below it. Content is clipped to the cell's own bounds — previously, a value too long
    /// for its cell would silently draw past the border and overlap the row below, since
    /// NSAttributedString.draw(in:) only wraps to width, it doesn't clip to height on its
    /// own. Clipping means a too-long value now just cuts off cleanly at the cell edge
    /// instead of bleeding into whatever's underneath it.
    private static func drawCell(
        label: String, value: String, rect: CGRect,
        valueSize: CGFloat = 11, valueBold: Bool = false, centered: Bool = false
    ) {
        NSColor.black.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()

        let pad: CGFloat = 8
        var textTop = rect.maxY - pad

        if !label.isEmpty {
            NSAttributedString(string: label, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 9), .foregroundColor: NSColor.black
            ]).draw(at: CGPoint(x: rect.minX + pad, y: textTop - 10))
            textTop -= 20
        }

        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.alignment = centered ? .center : .left
        let hasValue = !value.trimmingCharacters(in: .whitespaces).isEmpty
        let valueAttr = NSAttributedString(string: hasValue ? value : "", attributes: [
            .font: valueBold ? NSFont.boldSystemFont(ofSize: valueSize) : NSFont.systemFont(ofSize: valueSize),
            .foregroundColor: NSColor.black,
            .paragraphStyle: style
        ])
        let valueRect = CGRect(x: rect.minX + pad, y: rect.minY + pad,
                                width: max(rect.width - 2 * pad, 1), height: max(textTop - rect.minY - pad, 1))
        valueAttr.draw(in: valueRect)

        NSGraphicsContext.restoreGraphicsState()
    }

    /// Splits "12A. EXT. WOODS" into ("12A", "EXT", "WOODS") — reuses the same convention
    /// FinalDraftParser already relies on for imported scene headings.
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
