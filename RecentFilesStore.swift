// RecentFilesStore.swift
// Tracks recently opened/saved project files for the File > Open Recent menu, and
// defines the notifications used to wire native macOS menu commands (built once, at
// the App level) to actions that live on ContentView's own state. WindowGroup-based
// SwiftUI apps don't have a built-in way for `.commands` to call directly into a
// specific window's view state, so commands post a notification and ContentView
// listens via `.onReceive` — the standard pattern for this.

import Foundation
import Combine

// MARK: - Notifications

extension Notification.Name {
    static let csNewProject          = Notification.Name("CineSched.newProject")
    static let csOpenProject         = Notification.Name("CineSched.openProject")
    static let csOpenRecentProject   = Notification.Name("CineSched.openRecentProject")   // object: URL
    static let csImportScript        = Notification.Name("CineSched.importScript")
    static let csSaveProject         = Notification.Name("CineSched.saveProject")
    static let csSaveProjectAs       = Notification.Name("CineSched.saveProjectAs")
    static let csExportSchedulePDF   = Notification.Name("CineSched.exportSchedulePDF")
    static let csExportDaysOutOfDays = Notification.Name("CineSched.exportDaysOutOfDays")
    static let csOpenProductionSetup = Notification.Name("CineSched.openProductionSetup")
}

// MARK: - Recent files

/// Persisted as security-scoped bookmarks in UserDefaults, not plain paths. CineSched is
/// sandboxed (see CineSched.entitlements), and a sandboxed app only has access to a
/// user-selected file for the lifetime of the process that opened it — a plain saved
/// path can't be reopened, or even checked for existence, in a later launch. A security-
/// scoped bookmark is macOS's actual mechanism for "remember this file across launches."
final class RecentFilesStore: ObservableObject {
    @Published private(set) var urls: [URL] = []

    private let key = "CineSchedRecentProjectBookmarks"
    private let maxCount = 10
    private var bookmarks: [Data] = []

    init() {
        bookmarks = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
        resolveAll()
    }

    func record(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }

        bookmarks.removeAll { existing in resolvedPath(existing) == url.path }
        bookmarks.insert(bookmark, at: 0)
        if bookmarks.count > maxCount { bookmarks = Array(bookmarks.prefix(maxCount)) }
        UserDefaults.standard.set(bookmarks, forKey: key)
        resolveAll()
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        bookmarks = []
        urls = []
    }

    /// Resolving a bookmark to a URL (for display purposes — the name shown in the menu)
    /// doesn't require an active security scope; that's only needed when actually reading
    /// the file's contents, which `loadProject(from:)` handles when a recent item is picked.
    private func resolveAll() {
        urls = bookmarks.compactMap { data in
            var isStale = false
            return try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                             relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
    }

    private func resolvedPath(_ bookmark: Data) -> String? {
        var isStale = false
        return (try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                          relativeTo: nil, bookmarkDataIsStale: &isStale))?.path
    }
}
