// FountainPaginator.swift
// Converts a flat list of FountainElements into per-scene page counts. This is
// the scheduling-critical component: 1/8ths are the primary currency a 1st AD
// budgets shoot days against, so the numbers here need to be reliable enough
// to use without manually re-measuring the page. Deliberately zero SwiftUI/
// AppKit — plain Swift only — so it stays independently unit-testable.

import Foundation

struct FountainPaginator {

    // MARK: - Page model

    static let linesPerPage: Int = 56
    static let linesPerEighth: Int = 7   // linesPerPage / 8

    private static let actionCharWidth = 60
    private static let dialogueCharWidth = 35

    // MARK: - Results

    struct ScenePagination {
        /// Index into the elements array of this scene's `.sceneHeading` element.
        let sceneElementIndex: Int
        let rawLines: Int
        let eighths: Int
        let startPage: Int
        let endPage: Int
    }

    struct Result {
        let scenes: [ScenePagination]
        let totalLines: Int
        let totalPages: Int
        /// Sum of every scene's own (already rounded-up) eighths — this, not a
        /// document-wide line count divided back down, is the number that
        /// matters for scheduling: a 1st AD budgets days against the sum of
        /// each scene's own 1/8th.
        let totalEighths: Int
    }

    // MARK: - Per-element line cost

    static func lineCost(for element: FountainElement) -> Int {
        switch element.kind {
        case .sceneHeading:     return 2
        case .action:            return wrappedLines(element.text, charWidth: actionCharWidth)
        case .blank:             return 1
        case .character:         return 1
        case .parenthetical:     return 1
        case .dialogue:          return wrappedLines(element.text, charWidth: dialogueCharWidth)
        case .transition:        return 1
        case .pageBreak:         return 0   // handled specially — flushes to the next page boundary
        case .lyric, .centered:  return 1
        }
    }

    private static func wrappedLines(_ text: String, charWidth: Int) -> Int {
        max(1, Int(ceil(Double(text.count) / Double(charWidth))))
    }

    // MARK: - Dual dialogue: side-by-side columns, not stacked

    /// A `.character` element plus everything that belongs to its speech
    /// (parentheticals/dialogue) up to the next blank line or unrelated element.
    private struct DialogueBlock {
        let startIndex: Int
        let endIndex: Int   // inclusive
        let cost: Int
    }

    private static func dialogueBlocks(in elements: [FountainElement]) -> [DialogueBlock] {
        var blocks: [DialogueBlock] = []
        var i = 0
        while i < elements.count {
            guard elements[i].kind == .character else { i += 1; continue }
            var j = i + 1
            var cost = lineCost(for: elements[i])
            while j < elements.count, elements[j].kind == .parenthetical || elements[j].kind == .dialogue {
                cost += lineCost(for: elements[j])
                j += 1
            }
            blocks.append(DialogueBlock(startIndex: i, endIndex: j - 1, cost: cost))
            i = j
        }
        return blocks
    }

    /// Dual dialogue prints in two side-by-side columns, so the pair's combined
    /// height is the taller column, not the sum of both. This returns a per-
    /// element cost override table so the second (`^`-marked) speaker's block
    /// only contributes whatever overage it has beyond the first speaker's block.
    private static func dualDialogueOverrides(_ elements: [FountainElement]) -> [Int: Int] {
        var overrides: [Int: Int] = [:]
        let blocks = dialogueBlocks(in: elements)
        guard blocks.count > 1 else { return overrides }
        for idx in 1..<blocks.count {
            let block = blocks[idx]
            guard elements[block.startIndex].isDualDialogue else { continue }
            let previous = blocks[idx - 1]
            // Only pair genuinely adjacent blocks (allow at most one element —
            // typically a blank line — between them).
            guard block.startIndex - previous.endIndex <= 2 else { continue }
            let overage = max(0, block.cost - previous.cost)
            for i in block.startIndex...block.endIndex { overrides[i] = 0 }
            overrides[block.startIndex] = overage
        }
        return overrides
    }

    // MARK: - Pagination

    static func paginate(_ elements: [FountainElement]) -> Result {
        let overrides = dualDialogueOverrides(elements)
        var blockByStart: [Int: DialogueBlock] = [:]
        for block in dialogueBlocks(in: elements) { blockByStart[block.startIndex] = block }

        func cost(_ index: Int) -> Int { overrides[index] ?? lineCost(for: elements[index]) }

        var currentPageLine = 0
        var currentPage = 1
        var totalLines = 0

        var scenes: [ScenePagination] = []
        var sceneStartIndex: Int? = nil
        var sceneRawLines = 0
        var sceneStartPage = 1

        func flushScene(endPage: Int) {
            guard let start = sceneStartIndex else { return }
            let eighths = max(1, Int(ceil(Double(sceneRawLines) / Double(linesPerEighth))))
            scenes.append(ScenePagination(
                sceneElementIndex: start, rawLines: sceneRawLines, eighths: eighths,
                startPage: sceneStartPage, endPage: endPage
            ))
        }

        func addLines(_ n: Int) {
            guard n > 0 else { return }
            sceneRawLines += n
            totalLines += n
            currentPageLine += n
            while currentPageLine >= linesPerPage {
                currentPageLine -= linesPerPage
                currentPage += 1
            }
        }

        var i = 0
        while i < elements.count {
            let element = elements[i]

            if element.kind == .sceneHeading {
                flushScene(endPage: currentPage)
                sceneStartIndex = i
                sceneRawLines = 0
                sceneStartPage = currentPage
            }

            if element.kind == .pageBreak {
                if currentPageLine > 0 {
                    addLines(linesPerPage - currentPageLine)   // flush to the next boundary; addLines rolls the page over
                }
                i += 1
                continue
            }

            // Don't break inside dialogue: if this block would straddle a page
            // boundary but fits whole on a fresh page, advance the break to
            // before the character cue instead (MORE/CONTINUED-style behavior).
            if element.kind == .character, let block = blockByStart[i] {
                let blockCost = (block.startIndex...block.endIndex).reduce(0) { $0 + cost($1) }
                if currentPageLine > 0, currentPageLine + blockCost > linesPerPage, blockCost <= linesPerPage {
                    addLines(linesPerPage - currentPageLine)
                }
            }

            addLines(cost(i))
            i += 1
        }
        flushScene(endPage: currentPage)

        let totalEighths = scenes.reduce(0) { $0 + $1.eighths }
        let totalPages = totalLines > 0 ? Int(ceil(Double(totalLines) / Double(linesPerPage))) : 0

        return Result(scenes: scenes, totalLines: totalLines, totalPages: totalPages, totalEighths: totalEighths)
    }

    // MARK: - Display formatting

    /// Formats an eighths value as industry-standard page notation, e.g. "2/8",
    /// "1 3/8" — never as a decimal.
    static func formatEighths(_ eighths: Int) -> String {
        let fullPages = eighths / 8
        let remainder = eighths % 8
        if fullPages == 0 { return "\(remainder)/8" }
        if remainder == 0 { return "\(fullPages)" }
        return "\(fullPages) \(remainder)/8"
    }
}
