// ProjectStore.swift
// Handles all project persistence: auto-save, manual save/load, and the
// FileDocument wrapper used by the native file importer/exporter.

import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - ProjectFile (FileDocument for JSON import/export)

struct ProjectFile: FileDocument {
    static var readableContentTypes: [UTType] = [.json]
    var projectData: ProjectData

    init(allScenes: [Scene], shootDays: [ShootDay], projectTitle: String = "Untitled Movie") {
        self.projectData = ProjectData(
            allScenes: allScenes,
            shootDays: shootDays,
            projectTitle: projectTitle
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // Try current format first, fall back to legacy
        do {
            self.projectData = try Self.decode(data)
        } catch {
            let legacy = try JSONDecoder().decode(LegacyProjectData.self, from: data)
            self.projectData = ProjectData(
                allScenes: legacy.allScenes,
                shootDays: legacy.shootDays,
                projectTitle: "Imported Project"
            )
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Self.encode(projectData)
        return FileWrapper(regularFileWithContents: data)
    }

    // MARK: - Shared encode/decode helpers

    static func encode(_ projectData: ProjectData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .formatted(isoDateFormatter)
        return try encoder.encode(projectData)
    }

    /// Tries formatted-date decoder first, then plain decoder for backwards compatibility.
    static func decode(_ data: Data) throws -> ProjectData {
        let formattedDecoder = JSONDecoder()
        formattedDecoder.dateDecodingStrategy = .formatted(isoDateFormatter)
        if let result = try? formattedDecoder.decode(ProjectData.self, from: data) { return result }
        return try JSONDecoder().decode(ProjectData.self, from: data)
    }

    private static var isoDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }
}

// MARK: - Auto-save / UserDefaults persistence

extension ContentView {

    /// Marks the project as having unsaved changes. The actual save is triggered
    /// by .onChange(of: hasUnsavedChanges) in ContentView with a Task/sleep debounce,
    /// so rapid edits (e.g. typing a title) only result in one save after the user pauses.
    func markDirty() {
        hasUnsavedChanges = true
    }

    func saveDefaultProject() {
        let projectData = ProjectData(
            allScenes: allScenes,
            shootDays: shootDays,
            projectTitle: projectTitle,
            isShiftModeEnabled: isShiftModeEnabled,
            createdDate: projectCreatedDate,
            productionInfo: productionInfo
        )
        do {
            let data = try ProjectFile.encode(projectData)
            UserDefaults.standard.set(data, forKey: "SavedProject")
            print("Auto-saved project to UserDefaults")
        } catch {
            print("Failed to auto-save project: \(error)")
        }
    }

    func loadDefaultProject() {
        guard let data = UserDefaults.standard.data(forKey: "SavedProject") else {
            print("No saved project found in UserDefaults")
            return
        }
        applyLoadedData(from: data, source: "UserDefaults")
    }

    // MARK: - Manual save (native NSSavePanel)

    func showNativeSaveDialog() {
        let panel = NSSavePanel()
        panel.title              = "Save CineSched Project"
        panel.prompt             = "Save"
        panel.nameFieldLabel     = "Project Name:"
        panel.nameFieldStringValue = sanitizeFilename(projectTitle.isEmpty ? "MovieSchedule" : projectTitle)
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden  = false
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            panel.directoryURL = docs
        }
        panel.begin { [self] response in
            DispatchQueue.main.async {
                guard response == .OK, let url = panel.url else { return }
                self.saveProjectDirectly(to: url)
            }
        }
    }

    func saveProjectDirectly(to url: URL) {
        let projectData = ProjectData(
            allScenes: allScenes,
            shootDays: shootDays,
            projectTitle: projectTitle,
            isShiftModeEnabled: isShiftModeEnabled,
            createdDate: projectCreatedDate,
            productionInfo: productionInfo
        )
        do {
            let data = try ProjectFile.encode(projectData)
            try data.write(to: url)
            alertMessage = "Schedule saved successfully to: \(url.lastPathComponent)"
            showingAlert = true
            print("Saved to: \(url.path)")
        } catch {
            alertMessage = "Failed to save schedule: \(error.localizedDescription)"
            showingAlert = true
            print("Save error: \(error)")
        }
    }

    // MARK: - Load from file

    func loadProject(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "Unable to access the selected file."
            showingAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            applyLoadedData(from: data, source: url.lastPathComponent)
        } catch {
            alertMessage = "Failed to load project: \(error.localizedDescription)"
            showingAlert = true
            print("Load error: \(error)")
        }
    }

    // MARK: - Apply loaded data to state

    /// Decodes project data and updates all state variables.
    /// Tries current format → plain decoder → legacy format in sequence.
    private func applyLoadedData(from data: Data, source: String) {
        // Helper closure applied when a ProjectData is successfully decoded
        func apply(_ loaded: ProjectData) {
            allScenes          = loaded.allScenes
            shootDays          = loaded.shootDays
            projectTitle       = loaded.projectTitle
            isShiftModeEnabled = loaded.isShiftModeEnabled ?? false
            projectCreatedDate = loaded.createdDate
            productionInfo     = loaded.productionInfo ?? ProductionInfo()
            if let first = shootDays.first?.date, let last = shootDays.last?.date {
                startDate = first
                endDate   = last
            }
            print("Loaded project '\(loaded.projectTitle)' from \(source)")
        }

        if let loaded = try? ProjectFile.decode(data) {
            apply(loaded)
            return
        }
        if let legacy = try? JSONDecoder().decode(LegacyProjectData.self, from: data) {
            allScenes    = legacy.allScenes
            shootDays    = legacy.shootDays
            projectTitle = "Loaded Project"
            isShiftModeEnabled = false
            if let first = shootDays.first?.date, let last = shootDays.last?.date {
                startDate = first
                endDate   = last
            }
            print("Loaded legacy project from \(source)")
            return
        }
        alertMessage = "Failed to decode project file."
        showingAlert = true
        print("Failed to decode data from \(source)")
    }

    // MARK: - Appearance preference

    func saveAppearancePreference() {
        UserDefaults.standard.set(isDarkMode, forKey: "CineSchedDarkMode")
    }

    func loadAppearancePreference() {
        if UserDefaults.standard.object(forKey: "CineSchedDarkMode") != nil {
            isDarkMode = UserDefaults.standard.bool(forKey: "CineSchedDarkMode")
        } else {
            isDarkMode = false
        }
    }

    // MARK: - Utilities

    func clearAllScenes() {
        allScenes.removeAll()
        for i in shootDays.indices {
            shootDays[i].scenes    = []
            shootDays[i].callSheet = CallSheetData()
        }
        projectTitle       = "Untitled Movie"
        productionInfo     = ProductionInfo()
        projectCreatedDate = Date()
        markDirty()
    }

    func sanitizeFilename(_ name: String) -> String {
        name.components(separatedBy: .init(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    // MARK: - File open panels

    func showJSONOpenPanel() {
        let panel = NSOpenPanel()
        panel.title                = "Load CineSched Project"
        panel.prompt               = "Load"
        panel.allowedContentTypes  = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [self] response in
            DispatchQueue.main.async {
                guard response == .OK, let url = panel.url else { return }
                self.loadProject(from: url)
            }
        }
    }

    func showFDXOpenPanel() {
        let panel = NSOpenPanel()
        panel.title                = "Import Final Draft Script"
        panel.prompt               = "Import"
        panel.allowedContentTypes  = [.init(importedAs: "com.finaldraft.fdx"), .xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [self] response in
            DispatchQueue.main.async {
                guard response == .OK, let url = panel.url else { return }
                self.importFDXScript(from: url)
            }
        }
    }

    func importFDXScript(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "Unable to access the selected file."
            showingImportAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let parsed = try FinalDraftParser.parseScenes(from: url)
            guard !parsed.isEmpty else {
                importMessage = "No scenes found in the script."
                showingImportAlert = true
                return
            }
            var count = 0
            for ps in parsed {
                let type: DayNightType = ps.timeOfDay == .night ? .night : .day
                allScenes.append(Scene(
                    title:         "\(ps.sceneNumber). \(ps.location)",
                    duration:      1,
                    estimatedTime: 15,
                    dayNightType:  type
                ))
                count += 1
            }
            markDirty()
            importMessage = "Imported \(count) scene\(count == 1 ? "" : "s") from '\(url.lastPathComponent)'.\n\nScenes added to Boneyard with default values (1/8 page, 15 min). Edit before scheduling."
            showingImportAlert = true
        } catch {
            importMessage = "Failed to import script: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }

    // MARK: - PDF exports (NSSavePanel)

    func showSchedulePDFSavePanel() {
        guard let pdfData = PDFExporter.generatePDF(
            shootDays: shootDays,
            projectTitle: projectTitle,
            allScenes: allScenes,
            startDate: startDate,
            endDate: endDate
        ) else {
            alertMessage = "Failed to generate schedule PDF."
            showingAlert = true
            return
        }
        showPDFSavePanel(
            data: pdfData,
            defaultName: sanitizeFilename("\(projectTitle.isEmpty ? "MovieSchedule" : projectTitle)_Calendar")
        )
    }

    func showCallSheetPDFSavePanel(for day: ShootDay) {
        guard let pdfData = CallSheetExporter.generatePDF(
            shootDay: day,
            productionInfo: productionInfo,
            projectTitle: projectTitle
        ) else {
            alertMessage = "Failed to generate call sheet PDF."
            showingAlert = true
            return
        }
        showPDFSavePanel(
            data: pdfData,
            defaultName: sanitizeFilename("CallSheet_\(formattedDate(day.date))")
        )
    }

    private func showPDFSavePanel(data: Data, defaultName: String) {
        let panel = NSSavePanel()
        panel.title              = "Export PDF"
        panel.prompt             = "Export"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes  = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden    = false
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            panel.directoryURL = docs
        }
        panel.begin { [self] response in
            DispatchQueue.main.async {
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url)
                    self.alertMessage = "PDF exported to: \(url.lastPathComponent)"
                    self.showingAlert = true
                } catch {
                    self.alertMessage = "Failed to export PDF: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
}
