// FountainParser.swift
// Line-by-line state machine interpreter for the Fountain screenplay markup
// language (https://fountain.io/syntax). Deliberately zero SwiftUI/AppKit —
// plain Swift only — so it stays fully unit-testable in isolation and can be
// reused by both the importer and the paginator.

import Foundation

// MARK: - FountainElement

struct FountainElement: Equatable {
    enum Kind: Equatable {
        case sceneHeading
        case action
        case character
        case dialogue
        case parenthetical
        case transition
        case centered
        case lyric
        case pageBreak
        case blank
    }

    let kind: Kind
    let text: String          // cleaned display text, formatting markers removed
    let lineIndex: Int        // 0-based line number in the original source file

    /// Only set on `.sceneHeading` elements carrying a trailing `#...#` scene
    /// number, e.g. "INT. HOUSE - DAY #3A#".
    var sceneNumber: String? = nil

    /// Only set on `.character` elements — marks the second speaker of a
    /// dual-dialogue pair (the `^` suffix).
    var isDualDialogue: Bool = false

    init(kind: Kind, text: String, lineIndex: Int, sceneNumber: String? = nil, isDualDialogue: Bool = false) {
        self.kind = kind
        self.text = text
        self.lineIndex = lineIndex
        self.sceneNumber = sceneNumber
        self.isDualDialogue = isDualDialogue
    }
}

// MARK: - FountainParser

struct FountainParser {

    struct ParseResult {
        let elements: [FountainElement]
        let titlePage: [String: String]
    }

    static func parse(_ rawText: String) -> ParseResult {
        let stripped = stripBoneyardAndNotes(rawText)
        let lines = stripped
            .components(separatedBy: "\n")
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }

        let (titlePage, bodyStartIndex) = parseTitlePage(lines)

        var elements: [FountainElement] = []
        // Kind of the last *non-blank* element emitted — drives the dialogue/
        // parenthetical/character-cue continuation rules.
        var lastKind: FountainElement.Kind? = nil

        var i = bodyStartIndex
        while i < lines.count {
            let rawLine = lines[i]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // Blank line — always breaks whatever block preceded it.
            if trimmed.isEmpty {
                elements.append(FountainElement(kind: .blank, text: "", lineIndex: i))
                lastKind = nil
                i += 1
                continue
            }

            // Hard page break: "===" (three or more) on its own line.
            if isPageBreak(trimmed) {
                elements.append(FountainElement(kind: .pageBreak, text: "", lineIndex: i))
                lastKind = nil
                i += 1
                continue
            }

            // Leading "#...#" scene number immediately followed by a scene
            // heading (Highland-style, e.g. "#3A# INT. HOUSE - DAY") — checked
            // before the generic "#" section-heading rule below, since both
            // start with "#". A bare "# Some Note" with no closing "#" right
            // after a number, or one not followed by a recognized heading
            // prefix, still falls through to the section-heading rule as usual.
            if trimmed.hasPrefix("#") {
                let (strippedLeading, leadingNumber) = stripLeadingSceneNumber(trimmed)
                if leadingNumber != nil, isSceneHeadingPrefix(strippedLeading) {
                    let (heading, trailingNumber) = stripTrailingSceneNumber(strippedLeading)
                    elements.append(FountainElement(kind: .sceneHeading, text: heading, lineIndex: i, sceneNumber: trailingNumber ?? leadingNumber))
                    lastKind = .sceneHeading
                    i += 1
                    continue
                }
            }

            // Section headings (#) and synopses (=) are outline-only — the
            // Fountain spec excludes them from the printed/paginated document.
            if trimmed.hasPrefix("#") {
                i += 1
                continue
            }
            if trimmed.hasPrefix("=") {
                i += 1
                continue
            }

            // Forced scene heading: leading "." (but not the "..." ellipsis).
            if trimmed.hasPrefix("."), !trimmed.hasPrefix("..") {
                let (heading, sceneNumber) = extractSceneNumber(String(trimmed.dropFirst()))
                elements.append(FountainElement(kind: .sceneHeading, text: heading, lineIndex: i, sceneNumber: sceneNumber))
                lastKind = .sceneHeading
                i += 1
                continue
            }

            // Natural scene heading: INT./EXT./EST./I-E prefixes.
            if isSceneHeadingPrefix(trimmed) {
                let (heading, sceneNumber) = extractSceneNumber(trimmed)
                elements.append(FountainElement(kind: .sceneHeading, text: heading, lineIndex: i, sceneNumber: sceneNumber))
                lastKind = .sceneHeading
                i += 1
                continue
            }

            // Forced action: leading "!".
            if trimmed.hasPrefix("!") {
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                elements.append(FountainElement(kind: .action, text: text, lineIndex: i))
                lastKind = .action
                i += 1
                continue
            }

            // Centered text: >text< — checked before forced transition since
            // both share a leading ">".
            if trimmed.hasPrefix(">"), trimmed.hasSuffix("<"), trimmed.count > 1 {
                let inner = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                elements.append(FountainElement(kind: .centered, text: inner, lineIndex: i))
                lastKind = .centered
                i += 1
                continue
            }

            // Forced transition: leading ">".
            if trimmed.hasPrefix(">") {
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                elements.append(FountainElement(kind: .transition, text: text, lineIndex: i))
                lastKind = .transition
                i += 1
                continue
            }

            // Natural transition: ALL-CAPS line ending in "TO:".
            if isTransition(trimmed) {
                elements.append(FountainElement(kind: .transition, text: trimmed, lineIndex: i))
                lastKind = .transition
                i += 1
                continue
            }

            // Lyrics: leading "~".
            if trimmed.hasPrefix("~") {
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                elements.append(FountainElement(kind: .lyric, text: text, lineIndex: i))
                lastKind = .lyric
                i += 1
                continue
            }

            // Parenthetical: (...) following a character cue or dialogue.
            if trimmed.hasPrefix("("), trimmed.hasSuffix(")"),
               lastKind == .character || lastKind == .dialogue || lastKind == .parenthetical {
                elements.append(FountainElement(kind: .parenthetical, text: trimmed, lineIndex: i))
                lastKind = .parenthetical
                i += 1
                continue
            }

            // Forced character cue: leading "@".
            if trimmed.hasPrefix("@") {
                let (name, dual) = extractDualDialogueMarker(String(trimmed.dropFirst()))
                elements.append(FountainElement(kind: .character, text: name, lineIndex: i, isDualDialogue: dual))
                lastKind = .character
                i += 1
                continue
            }

            // Natural character cue: ALL-CAPS, preceded by a blank line (or start
            // of file), followed by dialogue or a parenthetical.
            if lastKind == nil, isCharacterCue(trimmed), hasFollowingContent(lines, from: i + 1) {
                let (name, dual) = extractDualDialogueMarker(trimmed)
                elements.append(FountainElement(kind: .character, text: name, lineIndex: i, isDualDialogue: dual))
                lastKind = .character
                i += 1
                continue
            }

            // Dialogue: continues after a character cue, parenthetical, or more dialogue.
            if lastKind == .character || lastKind == .parenthetical || lastKind == .dialogue {
                elements.append(FountainElement(kind: .dialogue, text: trimmed, lineIndex: i))
                lastKind = .dialogue
                i += 1
                continue
            }

            // Default: action.
            elements.append(FountainElement(kind: .action, text: trimmed, lineIndex: i))
            lastKind = .action
            i += 1
        }

        return ParseResult(elements: elements, titlePage: titlePage)
    }

    // MARK: - Character name normalization

    /// Strips the dual-dialogue `^` suffix and any `(V.O.)` / `(O.S.)`-style
    /// trailing extension, e.g. "JOHN (V.O.)^" -> "JOHN". Used when collecting
    /// a scene's cast so the same speaker doesn't appear twice under slightly
    /// different spellings.
    static func normalizedCharacterName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespaces)
        if name.hasSuffix("^") {
            name = String(name.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        if name.hasSuffix(")"), let openParen = name.range(of: "(", options: .backwards) {
            name = String(name[..<openParen.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    // MARK: - Boneyard / notes stripping

    /// Removes `/* ... */` boneyard blocks and `[[ ... ]]` notes at the
    /// character level — they may span multiple lines — before the line
    /// classifier ever sees the text. Newlines inside a stripped span are
    /// preserved so every other line's index still matches the source file.
    private static func stripBoneyardAndNotes(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                i += 2
                while i < chars.count, !(chars[i] == "*" && i + 1 < chars.count && chars[i + 1] == "/") {
                    if chars[i] == "\n" { result.append("\n") }
                    i += 1
                }
                i = min(i + 2, chars.count)
                continue
            }
            if chars[i] == "[", i + 1 < chars.count, chars[i + 1] == "[" {
                i += 2
                while i < chars.count, !(chars[i] == "]" && i + 1 < chars.count && chars[i + 1] == "]") {
                    if chars[i] == "\n" { result.append("\n") }
                    i += 1
                }
                i = min(i + 2, chars.count)
                continue
            }
            result.append(chars[i])
            i += 1
        }
        return result
    }

    // MARK: - Title page

    /// Title page fields are `Key: value` pairs at the very top of the file,
    /// ending at the first blank line. Indented continuation lines extend the
    /// most recent key's value (e.g. a multi-line "Contact:" block).
    private static func parseTitlePage(_ lines: [String]) -> (fields: [String: String], bodyStartIndex: Int) {
        guard let first = lines.first, isTitlePageKeyLine(first) else { return ([:], 0) }

        var fields: [String: String] = [:]
        var currentKey: String? = nil
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                break
            }
            if isTitlePageKeyLine(line) {
                guard let colonIdx = line.firstIndex(of: ":") else { break }
                let key = line[line.startIndex..<colonIdx].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
                currentKey = key
                fields[key] = value
            } else if let key = currentKey, line.first?.isWhitespace == true {
                let continuation = line.trimmingCharacters(in: .whitespaces)
                let existing = fields[key] ?? ""
                fields[key] = existing.isEmpty ? continuation : existing + "\n" + continuation
            } else {
                break
            }
            i += 1
        }
        return (fields, i)
    }

    private static func isTitlePageKeyLine(_ line: String) -> Bool {
        guard let colonIdx = line.firstIndex(of: ":") else { return false }
        let key = line[line.startIndex..<colonIdx]
        guard !key.isEmpty, key.first.map({ !$0.isWhitespace }) == true else { return false }
        guard key.allSatisfy({ $0.isLetter || $0 == " " }) else { return false }
        // Title-page keys ("Title:", "Draft date:") are conventionally not
        // ALL-CAPS — this keeps a leading "FADE IN:" / "CUT TO:" transition
        // from being mistaken for one.
        guard key != key.uppercased() else { return false }
        return true
    }

    // MARK: - Scene headings

    private static let sceneHeadingPrefixes = [
        "INT./EXT.", "INT/EXT.", "EXT./INT.", "I/E.",
        "INT.", "EXT.", "EST.",
        "INT./EXT ", "INT/EXT ", "EXT./INT ", "I/E ",
        "INT ", "EXT ", "EST ",
    ]

    private static func isSceneHeadingPrefix(_ line: String) -> Bool {
        let upper = line.uppercased()
        for prefix in sceneHeadingPrefixes where upper.hasPrefix(prefix) { return true }
        return upper == "INT" || upper == "EXT" || upper == "I/E" || upper == "EST"
    }

    /// Strips a trailing "#...#" scene number — the common Fountain/Final Draft
    /// convention, e.g. "INT. HOUSE - DAY #3A#" -> ("INT. HOUSE - DAY", "3A").
    private static func stripTrailingSceneNumber(_ text: String) -> (text: String, sceneNumber: String?) {
        guard text.hasSuffix("#"), let lastHash = text.range(of: "#", options: .backwards) else {
            return (text, nil)
        }
        let beforeLast = text[..<lastHash.lowerBound]
        guard let firstHash = beforeLast.range(of: "#", options: .backwards) else {
            return (text, nil)
        }
        let number = String(text[text.index(after: firstHash.lowerBound)..<lastHash.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return (text, nil) }
        let rest = String(text[..<firstHash.lowerBound]).trimmingCharacters(in: .whitespaces)
        return (rest, number)
    }

    /// Strips a leading "#...#" scene number — some tools (Highland) put the
    /// marker before the heading instead of after it, e.g.
    /// "#3A# INT. HOUSE - DAY" -> ("INT. HOUSE - DAY", "3A").
    private static func stripLeadingSceneNumber(_ text: String) -> (text: String, sceneNumber: String?) {
        guard text.hasPrefix("#") else { return (text, nil) }
        let afterFirst = text.index(after: text.startIndex)
        guard let secondHash = text.range(of: "#", range: afterFirst..<text.endIndex) else {
            return (text, nil)
        }
        let number = String(text[afterFirst..<secondHash.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return (text, nil) }
        let rest = String(text[secondHash.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (rest, number)
    }

    /// Extracts a "#...#" scene number from either end of a heading line —
    /// trailing takes priority in the rare case a line somehow has both.
    private static func extractSceneNumber(_ heading: String) -> (text: String, sceneNumber: String?) {
        let trimmed = heading.trimmingCharacters(in: .whitespaces)
        let trailing = stripTrailingSceneNumber(trimmed)
        if trailing.sceneNumber != nil { return trailing }
        let leading = stripLeadingSceneNumber(trimmed)
        if leading.sceneNumber != nil { return leading }
        return (trimmed, nil)
    }

    // MARK: - Transitions

    private static func isTransition(_ line: String) -> Bool {
        guard line == line.uppercased(), line.hasSuffix("TO:") else { return false }
        return line.contains(where: { $0.isLetter })
    }

    // MARK: - Page breaks

    private static func isPageBreak(_ line: String) -> Bool {
        line.count >= 3 && line.allSatisfy { $0 == "=" }
    }

    // MARK: - Character cues

    private static func isCharacterCue(_ line: String) -> Bool {
        guard line.contains(where: { $0.isLetter }) else { return false }
        return line == line.uppercased()
    }

    /// A character cue must be followed by content (dialogue or a
    /// parenthetical) — not by a blank line or end of file.
    private static func hasFollowingContent(_ lines: [String], from index: Int) -> Bool {
        guard index < lines.count else { return false }
        return !lines[index].trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func extractDualDialogueMarker(_ raw: String) -> (name: String, isDual: Bool) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("^") {
            return (String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces), true)
        }
        return (trimmed, false)
    }
}
