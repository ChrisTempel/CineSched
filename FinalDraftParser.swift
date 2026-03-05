// FinalDraftParser.swift
// Parses Final Draft .fdx files and extracts scene information

import Foundation

struct FinalDraftParser {
    
    enum TimeOfDay {
        case day
        case night
        case unknown
        
        init(from text: String) {
            let lowercased = text.lowercased()
            if lowercased.contains("day") || lowercased.contains("morning") || lowercased.contains("afternoon") {
                self = .day
            } else if lowercased.contains("night") || lowercased.contains("evening") || lowercased.contains("dusk") || lowercased.contains("dawn") {
                self = .night
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
    }
    
    /// Parse an FDX file and extract all scenes
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
        
        return delegate.scenes
    }
    
    /// Extract scene components from a scene heading
    /// Examples:
    /// "3. EXT. WOODS - DAY" -> (number: "3", location: "EXT. WOODS", time: .day)
    /// "INT. BEDROOM - NIGHT" -> (number: nil, location: "INT. BEDROOM", time: .night)
    static func parseSceneHeading(_ heading: String) -> (number: String?, location: String, timeOfDay: TimeOfDay) {
        var workingHeading = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract scene number if present (e.g., "3.", "12A.", "5B.")
        var sceneNumber: String? = nil
        let numberPattern = #"^(\d+[A-Z]?)\.\s*"#
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           let match = regex.firstMatch(in: workingHeading, range: NSRange(workingHeading.startIndex..., in: workingHeading)) {
            if let range = Range(match.range(at: 1), in: workingHeading) {
                sceneNumber = String(workingHeading[range])
                // Remove the number from the heading
                if let fullRange = Range(match.range, in: workingHeading) {
                    workingHeading.removeSubrange(fullRange)
                }
            }
        }
        
        // Split by hyphen or dash to separate location from time
        let components = workingHeading.components(separatedBy: CharacterSet(charactersIn: "-–—"))
        
        var location = workingHeading
        var timeOfDay = TimeOfDay.unknown
        
        if components.count >= 2 {
            // Last component is typically the time of day
            location = components.dropLast().joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
            let timeString = components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            timeOfDay = TimeOfDay(from: timeString)
        } else {
            // No dash found, try to detect time in the full string
            timeOfDay = TimeOfDay(from: workingHeading)
            // If we found a time indicator, try to remove it from location
            if timeOfDay != .unknown {
                location = workingHeading.replacingOccurrences(of: #"\b(day|night|morning|afternoon|evening|dusk|dawn)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Clean up location (remove extra spaces)
        location = location.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (sceneNumber, location, timeOfDay)
    }
}

// MARK: - XML Parser Delegate

private class FDXParserDelegate: NSObject, XMLParserDelegate {
    var scenes: [FinalDraftParser.ParsedScene] = []
    
    private var currentElement = ""
    private var currentType = ""
    private var currentText = ""
    private var inSceneHeading = false
    private var inText = false
    private var textElements: [String] = []
    private var depth = 0  // Track nesting depth to ignore nested Paragraphs
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "Paragraph" {
            if !inSceneHeading {
                // This is a top-level Paragraph
                currentType = attributeDict["Type"] ?? ""
                
                if currentType == "Scene Heading" {
                    inSceneHeading = true
                    textElements = []
                }
            } else {
                // This is a nested Paragraph (inside SceneArcBeats) - ignore it
                depth += 1
            }
        } else if elementName == "Text" && inSceneHeading && depth == 0 {
            // Only collect Text if we're in a Scene Heading and NOT in a nested paragraph
            inText = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Text" && inText {
            if !currentText.isEmpty {
                textElements.append(currentText)
            }
            currentText = ""
            inText = false
        } else if elementName == "Paragraph" {
            if depth > 0 {
                // Closing a nested paragraph
                depth -= 1
            } else if inSceneHeading {
                // Closing the Scene Heading paragraph
                let rawHeading = textElements.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                let heading = rawHeading.uppercased()  // AUTO-CAPITALIZE
                
                if !heading.isEmpty {
                    let (number, location, timeOfDay) = FinalDraftParser.parseSceneHeading(heading)
                    let finalNumber = number ?? "\(scenes.count + 1)"
                    
                    let scene = FinalDraftParser.ParsedScene(
                        sceneNumber: finalNumber,
                        location: location,
                        timeOfDay: timeOfDay,
                        fullHeading: heading
                    )
                    
                    scenes.append(scene)
                }
                
                inSceneHeading = false
                currentType = ""
                textElements = []
            }
        }
        
        currentElement = ""
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML Parse Error: \(parseError.localizedDescription)")
    }
}
