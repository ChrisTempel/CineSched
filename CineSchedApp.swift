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
    @AppStorage("CineSchedIncludeHoldInDOOD") private var includeHoldInDOOD: Bool = true
    @AppStorage("CineSchedShowCastRow") private var showCastOnCards: Bool = false
    @AppStorage("CineSchedShowEstTimeOnCards") private var showEstTimeOnCards: Bool = false
    @AppStorage("cinesched_app_language") private var appLanguage: AppLanguage = .english
    @AppStorage("CineSchedTheme") private var currentTheme: AppTheme = .blue

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recentFiles)
                .accentColor(currentTheme.primaryAccent(isDarkMode: isDarkMode))
        }
        .commands {
            // File menu — New / Open / Open Recent / Import
            CommandGroup(replacing: .newItem) {
                Button(L("New Project", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csNewProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button(L("Open…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csOpenProject, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu(L("Open Recent", lang: appLanguage)) {
                    if recentFiles.urls.isEmpty {
                        Text(L("No Recent Projects", lang: appLanguage))
                    } else {
                        ForEach(recentFiles.urls, id: \.self) { url in
                            Button(url.deletingPathExtension().lastPathComponent) {
                                NotificationCenter.default.post(name: .csOpenRecentProject, object: url)
                            }
                        }
                        Divider()
                        Button(L("Clear Menu", lang: appLanguage)) { recentFiles.clear() }
                    }
                }

                Divider()

                Button(L("Import Script…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csImportScript, object: nil)
                }
            }

            // Edit menu — Undo/Redo for structural schedule changes
            CommandGroup(replacing: .undoRedo) {
                Button(L("Undo", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csUndo, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button(L("Redo", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csRedo, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            // File menu — Save / Save As / Export
            CommandGroup(replacing: .saveItem) {
                Button(L("Save", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csSaveProject, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button(L("Save As…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csSaveProjectAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button(L("Export Schedule to PDF…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csExportSchedulePDF, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button(L("Export Strip Schedule to PDF…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csExportStripboardPDF, object: nil)
                }

                Button(L("Export Days Out of Days…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csExportDaysOutOfDays, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button(L("Export Scene Breakdowns…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csExportBreakdowns, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
            }

            // A home for the one action that doesn't fit File/Edit/View
            CommandMenu("Production") {
                Button(L("Production Setup…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csOpenProductionSetup, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button(L("Scan for Conflicts…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csScanForConflicts, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                Button(L("Breakdown Browser…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csOpenBreakdownBrowser, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Toggle(L("Include Hold Days in DOoD Report", lang: appLanguage), isOn: $includeHoldInDOOD)

                Divider()

                Button(L("Lock Schedule", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csLockSchedule, object: nil)
                }
                Button(L("Unlock Schedule", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csUnlockSchedule, object: nil)
                }
                Button(L("Schedule Lock Report…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csShowScheduleLockReport, object: nil)
                }
            }

            // View menu — Dark Mode, Theme, Color Legend & Language
            CommandGroup(after: .toolbar) {
                Divider()
                Toggle(L("Dark Mode", lang: appLanguage), isOn: $isDarkMode)
                    .keyboardShortcut("d", modifiers: [.command, .shift])

                Toggle(L("Show Cast in Calendar", lang: appLanguage), isOn: $showCastOnCards)
                Toggle(L("Show Estimated Time Instead of Page Count", lang: appLanguage), isOn: $showEstTimeOnCards)

                Menu(L("Theme", lang: appLanguage)) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button(currentTheme == theme ? "✓ \(theme.localizedName)" : theme.localizedName) {
                            currentTheme = theme
                        }
                    }
                }

                Button(L("Color Legend…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csShowColorLegend, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button(L("Customize Scene Colors…", lang: appLanguage)) {
                    NotificationCenter.default.post(name: .csShowSceneColorSettings, object: nil)
                }
            }
        }
    }
}
