// FinalDraftParser.swift
// Parses Final Draft .fdx files, extracts scene information, and calculates page duration in eighths.

import Foundation

struct FinalDraftParser {
    
    enum TimeOfDay {
        case day
        case night
        case dawn
        case dusk
        case afternoon
        case unknown
        
        init(from text: String) {
            let lowercased = text.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            if lowercased.contains("dawn") || lowercased.contains("sunrise") || lowercased.contains("amanecer") || lowercased.contains("madrugada") || lowercased.contains("alba") {
                self = .dawn
            } else if lowercased.contains("dusk") || lowercased.contains("sunset") || lowercased.contains("twilight") || lowercased.contains("anochecer") || lowercased.contains("crepusculo") || lowercased.contains("ocaso") {
                self = .dusk
            } else if lowercased.contains("afternoon") || lowercased.contains("tarde") || lowercased.contains("atardecer") {
                self = .afternoon
            } else if lowercased.contains("night") || lowercased.contains("evening") || lowercased.contains("noche") || lowercased.contains("medianoche") {
                self = .night
            } else if lowercased.contains("day") || lowercased.contains("morning") || lowercased.contains("dia") || lowercased.contains("manana") {
                self = .day
            } else {
                self = .unknown
            }
        }
    }
    
    struct ParsedScene {
        let sceneNumber: String
        let location: String
        let timeOfDay: TimeOfDay
        let fullHeading: String
        var duration: Int             // In eighths of a page (e.g. 1 = 1/8, 8 = 1 page)
        var cast: [String] = []
        var summary: String = ""
    }
    
    /// Parse an FDX file and extract all scenes with automatic eighths calculation
    static func parseScenes(from url: URL) throws -> [ParsedScene] {
        let data = try Data(contentsOf: url)
        let parser = XMLParser(data: data)
        let delegate = FDXParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            if let error = parser.parserError {
                throw error
            }
            throw NSError(domain: "FinalDraftParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse FDX file"])
        }
        
        return delegate.finalizeScenes()
    }
    
    /// Extract scene components from a scene heading
    static func parseSceneHeading(_ heading: String) -> (number: String?, location: String, timeOfDay: TimeOfDay) {
        var workingHeading = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract scene number if present (e.g., "3.", "12A.", "5B.")
        var sceneNumber: String? = nil
        let numberPattern = #"^(\d+[A-Za-z]?)\.\s*"#
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           let match = regex.firstMatch(in: workingHeading, range: NSRange(workingHeading.startIndex..., in: workingHeading)) {
            if let range = Range(match.range(at: 1), in: workingHeading) {
                sceneNumber = String(workingHeading[range])
                if let fullRange = Range(match.range, in: workingHeading) {
                    workingHeading.removeSubrange(fullRange)
                }
            }
        }
        
        var location = workingHeading
        var timeOfDay = TimeOfDay.unknown
        
        let timePattern = #"[-–—./,\s]+\s*\b(day|night|morning|afternoon|evening|dusk|dawn|dia|día|noche|tarde|amanecer|anochecer|madrugada|alba|atardecer|crepusculo|crepúsculo|ocaso|medianoche)\b\.?\s*$"#
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: workingHeading, range: NSRange(workingHeading.startIndex..., in: workingHeading)),
           let fullMatchRange = Range(match.range, in: workingHeading),
           let timeWordRange = Range(match.range(at: 1), in: workingHeading) {
            let timeStr = String(workingHeading[timeWordRange])
            timeOfDay = TimeOfDay(from: timeStr)
            workingHeading.removeSubrange(fullMatchRange)
            location = workingHeading
        } else {
            let components = workingHeading.components(separatedBy: CharacterSet(charactersIn: "-–—"))
            if components.count >= 2 {
                location = components.dropLast().joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
                let timeString = components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                timeOfDay = TimeOfDay(from: timeString)
            } else {
                timeOfDay = TimeOfDay(from: workingHeading)
            }
        }
        
        location = location.trimmingCharacters(in: CharacterSet(charactersIn: " -–—.,/"))
        location = location.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (sceneNumber, location, timeOfDay)
    }
}

// MARK: - XML Parser Delegate with Accurate Page/Eighths Calculation

private class FDXParserDelegate: NSObject, XMLParserDelegate {
    private var scenes: [FinalDraftParser.ParsedScene] = []
    private var currentSceneIndex: Int? = nil
    private var currentSceneLineCount: Double = 0.0
    private var currentSceneCharacters: Set<String> = []
    
    private var currentElement = ""
    private var currentType = ""
    private var currentText = ""
    private var inParagraph = false
    private var inText = false
    private var depth = 0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "Paragraph" {
            if inParagraph {
                // We're already inside a paragraph, so this is a nested one — Final
                // Draft represents DualDialogue blocks (two characters' dialogue side by
                // side) as a Paragraph containing further nested Paragraph children.
                // Track it via depth so its own end tag doesn't prematurely close the
                // OUTER paragraph we're still accumulating text for.
                depth += 1
            } else {
                inParagraph = true
                currentType = attributeDict["Type"] ?? "Action"
                currentText = ""
            }
        } else if elementName == "Text" && inParagraph && depth == 0 {
            inText = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Text" {
            inText = false
        } else if elementName == "Paragraph" {
            if depth > 0 {
                depth -= 1
            } else if inParagraph {
                let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                processParagraph(type: currentType, text: trimmed)
                inParagraph = false
                currentType = ""
                currentText = ""
            }
        }
        currentElement = ""
    }
    
    private func processParagraph(type: String, text: String) {
        if type == "Scene Heading" {
            // Finalize previous scene duration
            finalizeCurrentSceneDuration()
            
            let heading = text.uppercased()
            let (number, location, timeOfDay) = FinalDraftParser.parseSceneHeading(heading)
            let finalNumber = number ?? "\(scenes.count + 1)"
            
            let newScene = FinalDraftParser.ParsedScene(
                sceneNumber: finalNumber,
                location: location,
                timeOfDay: timeOfDay,
                fullHeading: heading,
                duration: 1, // Will be calculated dynamically
                cast: [],
                summary: ""
            )
            scenes.append(newScene)
            currentSceneIndex = scenes.count - 1
            currentSceneLineCount = 2.0 // Scene heading + blank line
            currentSceneCharacters = []
            return
        }
        
        guard currentSceneIndex != nil else { return }
        guard !text.isEmpty else { return }
        
        switch type {
        case "Action", "General":
            // ~58 characters per action line + 1 blank line above paragraph
            let lines = max(1.0, ceil(Double(text.count) / 58.0))
            currentSceneLineCount += lines + 1.0
            
        case "Character":
            let charName = cleanCharacterName(text)
            if !charName.isEmpty {
                currentSceneCharacters.insert(charName)
            }
            currentSceneLineCount += 2.0 // Character cue + blank line above
            
        case "Dialogue":
            // ~36 characters per dialogue line
            let lines = max(1.0, ceil(Double(text.count) / 36.0))
            currentSceneLineCount += lines
            
        case "Parenthetical":
            // ~32 characters per parenthetical line
            let lines = max(1.0, ceil(Double(text.count) / 32.0))
            currentSceneLineCount += lines
            
        case "Transition":
            currentSceneLineCount += 2.0 // Transition + blank line
            
        default:
            let lines = max(1.0, ceil(Double(text.count) / 58.0))
            currentSceneLineCount += lines + 0.5
        }
    }
    
    private func cleanCharacterName(_ raw: String) -> String {
        var s = raw.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove (V.O.), (O.S.), (CONT'D), etc.
        s = s.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func finalizeCurrentSceneDuration() {
        guard let idx = currentSceneIndex, idx < scenes.count else { return }
        // Standard screenplay page = ~54 lines
        let pages = currentSceneLineCount / 54.0
        let eighths = max(1, Int(round(pages * 8.0)))
        scenes[idx].duration = eighths
        scenes[idx].cast = Array(currentSceneCharacters).sorted()
    }
    
    func finalizeScenes() -> [FinalDraftParser.ParsedScene] {
        finalizeCurrentSceneDuration()
        return scenes
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML Parse Error: \(parseError.localizedDescription)")
    }
}
