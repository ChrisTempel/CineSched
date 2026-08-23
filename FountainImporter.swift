// FountainImporter.swift
// NSOpenPanel-driven import pipeline for .fountain / .md / .spmd screenplay
// files: reads the file, runs it through FountainParser + FountainPaginator on
// a background thread, and maps the result into [Scene] for the Boneyard.

import AppKit
import UniformTypeIdentifiers

// MARK: - FountainImportResult

struct FountainImportResult {
    let scenes:      [Scene]
    let totalPages:  Int
    let totalEighths: Int
    let castList:    [String]
    let warnings:    [String]
    let fileName:    String
}

// MARK: - FountainImportError

enum FountainImportError: LocalizedError {
    case unreadableEncoding(fileName: String)
    case invalidHighlandDocument(fileName: String, reason: String)
    case noScenesFound

    var errorDescription: String? {
        switch self {
        case .unreadableEncoding(let fileName):
            return "Couldn't read '\(fileName)' as UTF-8 text. Make sure it's a plain-text Fountain file."
        case .invalidHighlandDocument(let fileName, let reason):
            return "Couldn't read '\(fileName)': \(reason)."
        case .noScenesFound:
            return "No scene headings were found in this script."
        }
    }
}

// MARK: - FountainImporter

struct FountainImporter {

    static let supportedExtensions = ["fountain", "md", "spmd", "highland"]

    // MARK: - Open panel

    static func showOpenPanel(defaultDirectory: URL?, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title  = "Import Fountain Script"
        panel.prompt = "Import"
        var allowedTypes: [UTType] = []
        for ext in supportedExtensions {
            if let type = UTType(filenameExtension: ext) { allowedTypes.append(type) }
        }
        panel.allowedContentTypes     = allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        if let dir = defaultDirectory { panel.directoryURL = dir }
        panel.begin { response in
            DispatchQueue.main.async {
                guard response == .OK, let url = panel.url else { return }
                completion(url)
            }
        }
    }

    // MARK: - Import

    /// Reads and parses the file on a background thread; the completion
    /// handler always fires on the main thread.
    static func importScript(from url: URL, completion: @escaping (Result<FountainImportResult, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome: Result<FountainImportResult, Error>
            do {
                outcome = .success(try parseAndMap(url: url))
            } catch {
                outcome = .failure(error)
            }
            DispatchQueue.main.async { completion(outcome) }
        }
    }

    // MARK: - Parsing + mapping

    private static func parseAndMap(url: URL) throws -> FountainImportResult {
        let data = try Data(contentsOf: url)
        let text: String
        if url.pathExtension.lowercased() == "highland" {
            do {
                text = try HighlandArchiveReader.extractScreenplayText(from: data)
            } catch let error as HighlandArchiveReader.ReaderError {
                throw FountainImportError.invalidHighlandDocument(
                    fileName: url.lastPathComponent,
                    reason: error.errorDescription ?? "it's not a readable Highland document"
                )
            }
        } else {
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw FountainImportError.unreadableEncoding(fileName: url.lastPathComponent)
            }
            text = decoded
        }

        let parsed     = FountainParser.parse(text)
        let pagination = FountainPaginator.paginate(parsed.elements)
        guard !pagination.scenes.isEmpty else { throw FountainImportError.noScenesFound }

        var scenes: [Scene] = []
        var warnings: [String] = []
        var sceneNumberCounts: [String: Int]  = [:]   // scene number -> how many headings used it
        var speechCounts:      [String: Int]  = [:]   // normalized character name -> total lines spoken
        var projectCastOrder:  [String] = []
        var projectCastSeen:   Set<String> = []

        for (sceneIdx, scenePagination) in pagination.scenes.enumerated() {
            let headingElement = parsed.elements[scenePagination.sceneElementIndex]
            let nextHeadingIndex = sceneIdx + 1 < pagination.scenes.count
                ? pagination.scenes[sceneIdx + 1].sceneElementIndex
                : parsed.elements.count
            let sceneRange = (scenePagination.sceneElementIndex + 1)..<nextHeadingIndex

            var sceneCast: [String] = []
            var sceneCastSeen: Set<String> = []
            var hasActionOrDialogue = false

            for i in sceneRange {
                let element = parsed.elements[i]
                switch element.kind {
                case .character:
                    let name = FountainParser.normalizedCharacterName(element.text)
                    guard !name.isEmpty else { continue }
                    if sceneCastSeen.insert(name).inserted { sceneCast.append(name) }
                    if projectCastSeen.insert(name).inserted { projectCastOrder.append(name) }
                    speechCounts[name, default: 0] += 1
                case .action, .dialogue:
                    hasActionOrDialogue = true
                default:
                    break
                }
            }

            // Description: the first .action element right after the heading
            // (skipping blanks) — left empty, not warned about, if dialogue or
            // the next heading arrives first.
            var description = ""
            var lookIndex = scenePagination.sceneElementIndex + 1
            while lookIndex < nextHeadingIndex, parsed.elements[lookIndex].kind == .blank {
                lookIndex += 1
            }
            if lookIndex < nextHeadingIndex, parsed.elements[lookIndex].kind == .action {
                let actionText = parsed.elements[lookIndex].text
                description = actionText.count > 120 ? String(actionText.prefix(120)) : actionText
            }

            if !hasActionOrDialogue {
                warnings.append("Scene \(sceneIdx + 1) (\(headingElement.text)) has no action or dialogue.")
            }
            if let number = headingElement.sceneNumber {
                sceneNumberCounts[number, default: 0] += 1
            }

            let sceneNumberText = headingElement.sceneNumber ?? "\(sceneIdx + 1)"
            let dayNight: DayNightType = FinalDraftParser.TimeOfDay(from: headingElement.text) == .night ? .night : .day

            scenes.append(Scene(
                title:         headingElement.text,
                sceneNumber:   sceneNumberText,
                duration:      scenePagination.eighths,
                estimatedTime: TimeParser.estimatedMinutes(forEighths: scenePagination.eighths),
                dayNightType:  dayNight,
                cast:          sceneCast,
                summary:       description
            ))
        }

        for (number, count) in sceneNumberCounts where count > 1 {
            warnings.append("Scene number '\(number)' is used \(count) times — check for duplicates.")
        }
        for name in projectCastOrder where speechCounts[name] == 1 {
            warnings.append("'\(name)' speaks only once — possible typo?")
        }

        return FountainImportResult(
            scenes:      scenes,
            totalPages:  pagination.totalPages,
            totalEighths: pagination.totalEighths,
            castList:    projectCastOrder.sorted(),
            warnings:    warnings,
            fileName:    url.lastPathComponent
        )
    }
}
