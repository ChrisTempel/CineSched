//
//  CineSchedApp.swift
//  CineSched
//
//  Created by Christopher Tempel on 7/15/25.
//

import SwiftUI

@main
struct CineSchedApp: App {
    @StateObject private var recentFiles = RecentFilesStore()
    @AppStorage("CineSchedDarkMode") private var isDarkMode: Bool = false

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recentFiles)
        }
        .commands {
            // File menu — New / Open / Open Recent / Import
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NotificationCenter.default.post(name: .csNewProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Open…") {
                    NotificationCenter.default.post(name: .csOpenProject, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    if recentFiles.urls.isEmpty {
                        Text("No Recent Projects")
                    } else {
                        ForEach(recentFiles.urls, id: \.self) { url in
                            Button(url.deletingPathExtension().lastPathComponent) {
                                NotificationCenter.default.post(name: .csOpenRecentProject, object: url)
                            }
                        }
                        Divider()
                        Button("Clear Menu") { recentFiles.clear() }
                    }
                }

                Divider()

                Button("Import Script…") {
                    NotificationCenter.default.post(name: .csImportScript, object: nil)
                }
            }

            // File menu — Save / Save As / Export
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .csSaveProject, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") {
                    NotificationCenter.default.post(name: .csSaveProjectAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Export Schedule to PDF…") {
                    NotificationCenter.default.post(name: .csExportSchedulePDF, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Export Days Out of Days…") {
                    NotificationCenter.default.post(name: .csExportDaysOutOfDays, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // A home for the one action that doesn't fit File/Edit/View
            CommandMenu("Production") {
                Button("Production Setup…") {
                    NotificationCenter.default.post(name: .csOpenProductionSetup, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            // View menu — Dark Mode, alongside the automatic Toggle Sidebar item
            CommandGroup(after: .toolbar) {
                Divider()
                Toggle("Dark Mode", isOn: $isDarkMode)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}
