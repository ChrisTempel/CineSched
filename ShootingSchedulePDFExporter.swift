// ShootingSchedulePDFExporter.swift
// Vector PDF exporter for the master Plan de Rodaje (Shooting Schedule / One-Line Schedule) directly from the Stripboard.

import SwiftUI
import AppKit
import CoreText
import PDFKit

struct ShootingSchedulePDFExporter {

    private static func cleanSceneTitle(number: String, rawTitle: String) -> String {
        var cleaned = rawTitle.trimmingCharacters(in: .whitespaces)
        if !number.isEmpty {
            let prefixes = ["\(number).", "\(number).-", "\(number) -", "\(number) ", "\(number))"]
            for p in prefixes {
                if cleaned.hasPrefix(p) {
                    cleaned = String(cleaned.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
        if let match = cleaned.range(of: #"^\d+[\.\-\)\s]+\s*"#, options: .regularExpression) {
            let prefixStr = String(cleaned[match]).trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-) "))
            if prefixStr.isEmpty || prefixStr == number {
                cleaned = String(cleaned[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return cleaned
    }

    private static func cleanBannerTitle(_ rawTitle: String) -> String {
        let isSpanish = LocalizationManager.shared.currentLanguage == .spanish
        // Strip any hardcoded parenthesized times like "(01:30 PM)" or "(07:30 AM)"
        var clean = rawTitle.replacingOccurrences(of: #"\s*\(\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*\)"#, with: "", options: .regularExpression)
        // Strip any existing leading emojis like 🍽️, 🍽, 🍴, 🚌, 🎬
        clean = clean.replacingOccurrences(of: #"^[🍽🍴🚌🎬\s]+"#, with: "", options: .regularExpression)
        clean = clean.trimmingCharacters(in: .whitespaces)

        // Translate typical bilingual or default banner titles
        let lower = clean.lowercased()
        if lower.contains("almuerzo") || lower.contains("lunch") {
            return isSpanish ? "ALMUERZO" : "LUNCH"
        }
        if lower.contains("llegada") || lower.contains("crew call") {
            return isSpanish ? "LLEGADA DEL EQUIPO" : "CREW CALL"
        }
        if lower.contains("inicio") || lower.contains("set call") {
            return isSpanish ? "INICIO DE RODAJE" : "SET CALL"
        }
        if lower.contains("merienda") || lower.contains("snack") {
            return isSpanish ? "MERIENDA" : "SNACK"
        }
        if lower.contains("cena") || lower.contains("dinner") {
            return isSpanish ? "CENA" : "DINNER"
        }
        if lower.contains("aviso") || lower.contains("notice") || lower.contains("note") {
            return isSpanish ? "AVISO" : "NOTICE"
        }
        return clean
    }

    static func generatePDF(
        shootDays: [ShootDay],
        projectTitle: String,
        productionInfo: ProductionInfo
    ) -> Data {
        let isSpanish = LocalizationManager.shared.currentLanguage == .spanish
        let pdfData = NSMutableData()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Standard US Letter Portrait (612 x 792 pt)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        let margin: CGFloat = 30
        let printableWidth = pageRect.width - (margin * 2) // 552pt

        var currentPage = 1
        var yPosition: CGFloat = pageRect.height - margin

        func startNewPage() {
            if currentPage > 1 {
                context.endPDFPage()
            }
            context.beginPDFPage(nil)
            yPosition = pageRect.height - margin

            drawTopHeader(
                context: context,
                margin: margin,
                width: printableWidth,
                projectTitle: projectTitle,
                productionInfo: productionInfo,
                pageNumber: currentPage,
                isSpanish: isSpanish,
                yPosition: &yPosition
            )

            currentPage += 1
        }

        startNewPage()

        let productionNumbers = productionDayNumbers(for: shootDays)
        var cumulativeEighths = 0

        for dayIndex in 0..<shootDays.count {
            let day = shootDays[dayIndex]
            let dayNum = productionNumbers[day.id]

            if yPosition < margin + 90 {
                startNewPage()
            }

            // Find actual calculated lunch time from scheduled scenes if available
            var calculatedLunchTime: String = day.callSheet.lunchTime
            var currentTimeMinutes: Int = parseTimeToMinutes(day.callSheet.readyToShootTime.isEmpty ? (day.callSheet.generalCallTime.isEmpty ? "07:30 AM" : day.callSheet.generalCallTime) : day.callSheet.readyToShootTime) ?? (7 * 60 + 30)

            var runningMin = currentTimeMinutes
            for s in day.scenes.filter({ !$0.isCalendarEvent }) {
                if !s.customStartTime.isEmpty, let customMin = parseTimeToMinutes(s.customStartTime) {
                    runningMin = customMin
                }
                let isMeal = s.title.lowercased().contains("almuerzo") || s.title.lowercased().contains("lunch") || s.isAutoMeal
                if isMeal {
                    calculatedLunchTime = formatMinutesToClock(runningMin)
                }
                let dur = s.estimatedTime > 0 ? s.estimatedTime : (s.isBanner ? 30 : 15)
                runningMin += dur
            }

            drawDayHeaderBar(
                context: context,
                margin: margin,
                width: printableWidth,
                day: day,
                dayNumber: dayNum ?? (dayIndex + 1),
                lunchTime: calculatedLunchTime,
                isSpanish: isSpanish,
                yPosition: &yPosition
            )

            // Render CallSheet Milestones if present
            if !day.callSheet.generalCallTime.isEmpty {
                let callTime = day.callSheet.generalCallTime
                let title = isSpanish ? "LLEGADA DEL EQUIPO" : "CREW CALL"
                let crewCallScene = Scene.createBanner(type: .notice, title: title, note: callTime, estimatedTime: "0:15", colorHex: "3B82F6")
                drawBannerRow(
                    context: context,
                    margin: margin,
                    width: printableWidth,
                    scene: crewCallScene,
                    timeRange: callTime,
                    isSpanish: isSpanish,
                    yPosition: &yPosition
                )
            }
            if !day.callSheet.readyToShootTime.isEmpty {
                let setTime = day.callSheet.readyToShootTime
                let title = isSpanish ? "INICIO DE RODAJE" : "SET CALL"
                let readyScene = Scene.createBanner(type: .notice, title: title, note: setTime, estimatedTime: "0:15", colorHex: "10B981")
                drawBannerRow(
                    context: context,
                    margin: margin,
                    width: printableWidth,
                    scene: readyScene,
                    timeRange: setTime,
                    isSpanish: isSpanish,
                    yPosition: &yPosition
                )
            }

            for scene in day.scenes.filter({ !$0.isCalendarEvent }) {
                let rowH: CGFloat = 24
                if yPosition - rowH < margin + 30 {
                    startNewPage()
                }

                if !scene.customStartTime.isEmpty, let customMin = parseTimeToMinutes(scene.customStartTime) {
                    currentTimeMinutes = customMin
                }

                let startClock = formatMinutesToClock(currentTimeMinutes)
                let durMinutes = scene.estimatedTime > 0 ? scene.estimatedTime : (scene.isBanner ? 30 : 15)
                let endClock = formatMinutesToClock(currentTimeMinutes + durMinutes)
                let timeRange = "\(startClock) – \(endClock)"

                // Estimated script page calculation
                let scriptPageNum = max(1, (cumulativeEighths / 8) + 1)
                cumulativeEighths += scene.duration

                if scene.isBanner {
                    drawBannerRow(
                        context: context,
                        margin: margin,
                        width: printableWidth,
                        scene: scene,
                        timeRange: timeRange,
                        isSpanish: isSpanish,
                        yPosition: &yPosition
                    )
                    currentTimeMinutes += durMinutes
                } else {
                    drawSceneRow(
                        context: context,
                        margin: margin,
                        width: printableWidth,
                        scene: scene,
                        timeRange: timeRange,
                        scriptPageNumber: scriptPageNum,
                        isSpanish: isSpanish,
                        yPosition: &yPosition
                    )
                    currentTimeMinutes += durMinutes
                }
            }

            if yPosition < margin + 30 {
                startNewPage()
            }

            let endTimeStr = formatMinutesToClock(currentTimeMinutes)
            drawEndOfDayStrip(
                context: context,
                margin: margin,
                width: printableWidth,
                day: day,
                dayNumber: dayNum ?? (dayIndex + 1),
                endTimeStr: endTimeStr,
                isSpanish: isSpanish,
                yPosition: &yPosition
            )

            yPosition -= 12
        }

        context.endPDFPage()
        context.closePDF()
        return pdfData as Data
    }

    // MARK: - Top Header (Matching Screenshot Layout)

    private static func drawTopHeader(
        context: CGContext,
        margin: CGFloat,
        width: CGFloat,
        projectTitle: String,
        productionInfo: ProductionInfo,
        pageNumber: Int,
        isSpanish: Bool,
        yPosition: inout CGFloat
    ) {
        let titleStr = projectTitle.isEmpty ? "LA VIDA EDITADA" : projectTitle.uppercased()
        let companyStr = productionInfo.companyName.isEmpty ? "Promo 8" : productionInfo.companyName
        let schedLabel = isSpanish ? "PLAN DE RODAJE" : "SHOOTING SCHEDULE"
        let subStr = "\(schedLabel) — \(companyStr)"

        // Left Side Title
        let fontTitle = NSFont.boldSystemFont(ofSize: 16)
        let fontSub = NSFont.systemFont(ofSize: 9.5)
        let textColor = NSColor(Color(hex: "1F2937"))
        let subColor = NSColor(Color(hex: "6B7280"))

        drawText(titleStr, at: CGPoint(x: margin, y: yPosition - 16), font: fontTitle, color: textColor, context: context)
        drawText(subStr, at: CGPoint(x: margin, y: yPosition - 30), font: fontSub, color: subColor, context: context)

        // Right Side Metadata (Page and Date)
        let df = DateFormatter()
        df.locale = appLocale()
        df.dateFormat = isSpanish ? "d 'de' MMMM, yyyy" : "MMMM d, yyyy"
        let dateStr = "\(isSpanish ? "EMISIÓN:" : "DATE:") \(df.string(from: Date()))"
        let pageStr = isSpanish ? "PÁGINA \(pageNumber)" : "PAGE \(pageNumber)"

        drawRightText(pageStr, at: CGPoint(x: margin + width, y: yPosition - 16), font: fontSub, color: subColor, context: context)
        drawRightText(dateStr, at: CGPoint(x: margin + width, y: yPosition - 30), font: fontSub, color: subColor, context: context)

        yPosition -= 36

        // Horizontal Line Separator
        context.setLineWidth(1.5)
        context.setStrokeColor(NSColor(Color(hex: "374151")).cgColor)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: margin + width, y: yPosition))
        context.strokePath()

        yPosition -= 14
    }

    // MARK: - Day Header Bar

    private static func drawDayHeaderBar(
        context: CGContext,
        margin: CGFloat,
        width: CGFloat,
        day: ShootDay,
        dayNumber: Int,
        lunchTime: String,
        isSpanish: Bool,
        yPosition: inout CGFloat
    ) {
        let rowH: CGFloat = 22
        let rect = CGRect(x: margin, y: yPosition - rowH, width: width, height: rowH)

        // Dark Slate Blue Background (#2E4057)
        context.setFillColor(CGColor(red: 0.18, green: 0.25, blue: 0.34, alpha: 1.0))
        context.fill(rect)

        let df = DateFormatter()
        df.locale = appLocale()
        df.dateFormat = isSpanish ? "EEEE, d 'de' MMMM 'de' yyyy" : "EEEE, MMMM d, yyyy"
        let dateStr = df.string(from: day.date).capitalized

        let shootDayPrefix = isSpanish ? "DÍA DE RODAJE" : "SHOOT DAY"
        let headerText = "\(shootDayPrefix) #\(dayNumber) — \(dateStr)"

        let font = NSFont.boldSystemFont(ofSize: 9.5)
        drawText(headerText, at: CGPoint(x: margin + 8, y: yPosition - 15), font: font, color: .white, context: context)

        // Crew Call, Set Call, Lunch Time on right side
        var milestones: [String] = []
        if !day.callSheet.generalCallTime.isEmpty {
            let label = isSpanish ? "LLEGADA:" : "CREW CALL:"
            milestones.append("🚌 \(label) \(day.callSheet.generalCallTime)")
        }
        if !day.callSheet.readyToShootTime.isEmpty {
            milestones.append("🎬 SET: \(day.callSheet.readyToShootTime)")
        }
        if !lunchTime.isEmpty {
            milestones.append("🍽️ \(lunchTime)")
        }

        let milesStr = milestones.joined(separator: "  |  ")
        if !milesStr.isEmpty {
            drawRightText(milesStr, at: CGPoint(x: margin + width - 8, y: yPosition - 15), font: NSFont.boldSystemFont(ofSize: 9), color: .white, context: context)
        }

        yPosition -= rowH
    }

    // MARK: - Scene Row Strip (Full Width for Scene Title / Description, Script Page & Eighths)

    private static func drawSceneRow(
        context: CGContext,
        margin: CGFloat,
        width: CGFloat,
        scene: Scene,
        timeRange: String,
        scriptPageNumber: Int,
        isSpanish: Bool,
        yPosition: inout CGFloat
    ) {
        let rowH: CGFloat = 22
        let rowY = yPosition - rowH
        let rect = CGRect(x: margin, y: rowY, width: width, height: rowH)

        // Background color matching strip color
        let bgColor = NSColor(scene.stripColor)
        context.setFillColor(bgColor.cgColor)
        context.fill(rect)

        let textColor = NSColor(Color(hex: "1F2937"))

        let col1W: CGFloat = 112
        let xCol1 = margin + 4
        let xCol2 = xCol1 + col1W + 8
        let xCol3 = margin + width - 114
        let xCol4 = margin + width - 6

        // 1. Time Badge
        if !timeRange.isEmpty {
            let timeRect = CGRect(x: xCol1, y: rowY + 3, width: col1W, height: rowH - 6)
            context.setFillColor(NSColor.black.withAlphaComponent(0.08).cgColor)
            context.fill(timeRect)
            drawTextCentered(timeRange, in: timeRect, font: NSFont.boldSystemFont(ofSize: 7.5), color: textColor.withAlphaComponent(0.85), context: context)
        }

        // 2. Scene Number + Clean Full Title
        let rawNum = scene.sceneNumber.isEmpty ? scene.extractedSceneNumber : scene.sceneNumber
        let cleanTitle = cleanSceneTitle(number: rawNum, rawTitle: scene.title)
        let fullTitle = rawNum.isEmpty ? cleanTitle : "\(rawNum). \(cleanTitle)"
        let maxTitleW = (xCol3 - 10) - xCol2

        drawBoundedText(fullTitle, at: CGPoint(x: xCol2, y: yPosition - 15), maxWidth: maxTitleW, font: NSFont.boldSystemFont(ofSize: 9), color: textColor, context: context)

        // 3. Script Page (Fixed Column)
        let pageStr = isSpanish ? "Pág. \(scriptPageNumber)" : "Pg. \(scriptPageNumber)"
        drawText(pageStr, at: CGPoint(x: xCol3, y: yPosition - 15), font: NSFont.systemFont(ofSize: 8.5), color: textColor.withAlphaComponent(0.8), context: context)

        // 4. Page Duration in Eighths (Right Aligned)
        let eighthsUnit = isSpanish ? "pág" : "pgs"
        let eighthsStr = "\(formattedEighths(scene.duration)) \(eighthsUnit)"
        drawRightText(eighthsStr, at: CGPoint(x: xCol4, y: yPosition - 15), font: NSFont.boldSystemFont(ofSize: 9), color: textColor, context: context)

        // Bottom border line
        context.setLineWidth(0.5)
        context.setStrokeColor(CGColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0))
        context.move(to: CGPoint(x: margin, y: rowY))
        context.addLine(to: CGPoint(x: margin + width, y: rowY))
        context.strokePath()

        yPosition -= rowH
    }

    // MARK: - Banner / Notice Row Strip

    private static func drawBannerRow(
        context: CGContext,
        margin: CGFloat,
        width: CGFloat,
        scene: Scene,
        timeRange: String,
        isSpanish: Bool,
        yPosition: inout CGFloat
    ) {
        let rowH: CGFloat = 20
        let rowY = yPosition - rowH
        let rect = CGRect(x: margin, y: rowY, width: width, height: rowH)

        let isMeal = scene.title.lowercased().contains("almuerzo") || scene.title.lowercased().contains("lunch") || scene.isAutoMeal
        let isCrewCall = scene.title.lowercased().contains("llegada") || scene.title.lowercased().contains("crew call")
        let isSetCall = scene.title.lowercased().contains("inicio") || scene.title.lowercased().contains("set call")

        let bannerBgColor: NSColor
        let accentColor: NSColor
        let textColor: NSColor

        if isMeal {
            bannerBgColor = NSColor(Color(hex: "FEF3C7"))
            accentColor = NSColor(Color(hex: "D97706"))
            textColor = NSColor(Color(hex: "B45309"))
        } else if isCrewCall {
            bannerBgColor = NSColor(Color(hex: "EFF6FF"))
            accentColor = NSColor(Color(hex: "3B82F6"))
            textColor = NSColor(Color(hex: "1D4ED8"))
        } else if isSetCall {
            bannerBgColor = NSColor(Color(hex: "ECFDF5"))
            accentColor = NSColor(Color(hex: "10B981"))
            textColor = NSColor(Color(hex: "047857"))
        } else {
            bannerBgColor = NSColor(Color(hex: "E5E7EB"))
            accentColor = NSColor(Color(hex: "4B5563"))
            textColor = NSColor(Color(hex: "374151"))
        }

        // Tinted background
        context.setFillColor(bannerBgColor.cgColor)
        context.fill(rect)

        // 4pt left accent bar
        let accentRect = CGRect(x: margin, y: rowY, width: 4, height: rowH)
        context.setFillColor(accentColor.cgColor)
        context.fill(accentRect)

        let col1W: CGFloat = 112
        let xCol1 = margin + 6
        let xCol2 = xCol1 + col1W + 8

        if !timeRange.isEmpty {
            let timeRect = CGRect(x: xCol1, y: rowY + 3, width: col1W, height: rowH - 6)
            context.setFillColor(accentColor.withAlphaComponent(0.14).cgColor)
            context.fill(timeRect)
            drawTextCentered(timeRange, in: timeRect, font: NSFont.boldSystemFont(ofSize: 7.5), color: textColor, context: context)
        }

        // Cleaned and localized title
        let cleanedTitle = cleanBannerTitle(scene.title)
        let icon = isMeal ? "🍽️ " : (isCrewCall ? "🚌 " : (isSetCall ? "🎬 " : ""))
        let titleText = "\(icon)\(cleanedTitle.uppercased())"
        let maxTitleW = width - (col1W + 90)
        drawBoundedText(titleText, at: CGPoint(x: xCol2, y: yPosition - 14), maxWidth: maxTitleW, font: NSFont.boldSystemFont(ofSize: 8.5), color: textColor, context: context)

        // Right side estimated duration
        if scene.estimatedTime > 0 {
            let timeHM = formattedTimeHM(scene.estimatedTime)
            drawRightText("Est: \(timeHM)", at: CGPoint(x: margin + width - 8, y: yPosition - 14), font: NSFont.boldSystemFont(ofSize: 8.5), color: textColor, context: context)
        }

        // Bottom border line
        context.setLineWidth(0.5)
        context.setStrokeColor(CGColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0))
        context.move(to: CGPoint(x: margin, y: rowY))
        context.addLine(to: CGPoint(x: margin + width, y: rowY))
        context.strokePath()

        yPosition -= rowH
    }

    // MARK: - End of Day Strip

    private static func drawEndOfDayStrip(
        context: CGContext,
        margin: CGFloat,
        width: CGFloat,
        day: ShootDay,
        dayNumber: Int,
        endTimeStr: String,
        isSpanish: Bool,
        yPosition: inout CGFloat
    ) {
        let rowH: CGFloat = 20
        let rowY = yPosition - rowH
        let rect = CGRect(x: margin, y: rowY, width: width, height: rowH)

        context.setFillColor(NSColor(Color(hex: "E5E7EB")).cgColor)
        context.fill(rect)

        let df = DateFormatter()
        df.locale = appLocale()
        df.dateFormat = isSpanish ? "EEEE, d 'de' MMMM" : "EEEE, MMMM d"
        let fullDate = df.string(from: day.date).capitalized

        let wrapLabel = isSpanish ? "FIN DE JORNADA:" : "WRAP:"
        let totalPagesLabel = isSpanish ? "TOTAL PÁGINAS:" : "TOTAL PAGES:"
        let totalTimeLabel = isSpanish ? "TIEMPO EST.:" : "EST. TIME:"
        let endDayPrefix = isSpanish ? "FIN DEL DÍA" : "END OF DAY"

        let wrapText = day.callSheet.wrapTime.isEmpty ? endTimeStr : day.callSheet.wrapTime
        let footerText = "-- \(endDayPrefix) #\(dayNumber) \(fullDate) -- \(wrapLabel) \(wrapText) -- \(totalPagesLabel) \(formattedEighths(day.totalDuration)) -- \(totalTimeLabel) \(formattedTimeHM(day.totalEstimatedTime)) --"
        drawTextCentered(footerText, in: rect, font: NSFont.boldSystemFont(ofSize: 8.5), color: NSColor(Color(hex: "374151")), context: context)

        yPosition -= rowH
    }

    // MARK: - Text Drawing Helpers

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor, context: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private static func drawBoundedText(_ text: String, at point: CGPoint, maxWidth: CGFloat, font: NSFont, color: NSColor, context: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

        if width <= maxWidth {
            context.textPosition = point
            CTLineDraw(line, context)
        } else {
            let tokenAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let token = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: tokenAttrs))
            if let truncated = CTLineCreateTruncatedLine(line, Double(maxWidth), .end, token) {
                context.textPosition = point
                CTLineDraw(truncated, context)
            } else {
                context.textPosition = point
                CTLineDraw(line, context)
            }
        }
    }

    private static func drawRightText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor, context: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let textSize = CTLineGetTypographicBounds(line, nil, nil, nil)
        context.textPosition = CGPoint(x: point.x - CGFloat(textSize), y: point.y)
        CTLineDraw(line, context)
    }

    private static func drawTextCentered(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, context: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let textSize = CTLineGetTypographicBounds(line, nil, nil, nil)
        let x = rect.midX - (CGFloat(textSize) / 2)
        let y = rect.midY - (font.pointSize / 3)
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }
}
