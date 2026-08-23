// BannerInputSheet.swift
// Sheet to create and edit custom banner strips (Company Move, Meal Break, Notice, Custom Text).

import SwiftUI

struct BannerInputSheet: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Binding var isPresented: Bool
    let onSave: (Scene) -> Void

    @State private var bannerType: BannerType = .notice
    @State private var title: String = ""
    @State private var startTime: String = "12:00 PM"
    @State private var note: String = ""
    @State private var estimatedTime: String = "0:30"
    @State private var selectedColorHex: String = "8B5CF6" // Purple default

    let colorOptions: [(name: String, hex: String)] = [
        ("Indigo / Índigo", "6366F1"),
        ("Crimson / Carmesí", "EF4444"),
        ("Teal / Turquesa", "14B8A6"),
        ("Amber / Bronce", "D97706"),
        ("Violet / Violeta", "8B5CF6"),
        ("Charcoal / Carbón", "374151")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Add Notice / Banner Strip"))
                        .font(.title2).fontWeight(.bold)
                    Text(L("Insert custom move, notice, or note into the stripboard schedule"))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                // Banner Type Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Banner Type")).font(.subheadline).foregroundColor(.secondary)
                    Picker("", selection: $bannerType) {
                        ForEach(BannerType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: bannerType) { newType in
                        if title.isEmpty || title == placeholderForType {
                            title = defaultTitle(for: newType)
                        }
                    }
                }

                // Title / Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Title / Message")).font(.subheadline).foregroundColor(.secondary)
                    TextField(placeholderForType, text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack(spacing: 12) {
                    // Start Time of Day (e.g. 12:00 PM)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Start Time of Day (e.g. 12:00 PM)")).font(.subheadline).foregroundColor(.secondary)
                        TextField("e.g. 12:00 PM", text: $startTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Estimated Duration (e.g. 0:30 or 1h)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Duration (h:mm)")).font(.subheadline).foregroundColor(.secondary)
                        TextField("e.g. 0:30 or 1:00", text: $estimatedTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                // Note / Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Additional Notes")).font(.subheadline).foregroundColor(.secondary)
                    TextField(L("e.g. Equipment trucks depart at 01:00 PM"), text: $note)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Color Selection
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Banner Color")).font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        ForEach(colorOptions, id: \.hex) { option in
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorHex == option.hex ? 2.5 : 0)
                                )
                                .onTapGesture {
                                    selectedColorHex = option.hex
                                }
                        }
                    }
                }
            }
            .padding(20)

            Divider()

            // Actions
            HStack {
                Button(L("Cancel")) { isPresented = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button(L("Add Banner")) {
                    saveBanner()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 440)
        .onAppear {
            if title.isEmpty {
                title = defaultTitle(for: bannerType)
            }
        }
    }

    private var placeholderForType: String {
        switch bannerType {
        case .companyMove: return L("Company Move")
        case .mealBreak:   return L("Meal Break")
        case .notice:      return L("Notice")
        case .custom:      return L("Custom Banner")
        }
    }

    private func defaultTitle(for type: BannerType) -> String {
        switch type {
        case .companyMove: return L("Company Move")
        case .mealBreak:   return L("Meal Break")
        case .notice:      return L("Notice")
        case .custom:      return L("Custom Banner")
        }
    }

    private func saveBanner() {
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? defaultTitle(for: bannerType) : title.trimmingCharacters(in: .whitespaces)
        let cleanTime = startTime.trimmingCharacters(in: .whitespaces)

        var newBanner = Scene.createBanner(
            type: bannerType,
            title: finalTitle,
            note: note,
            estimatedTime: estimatedTime,
            colorHex: selectedColorHex
        )
        newBanner.summary = cleanTime.isEmpty ? note : cleanTime
        newBanner.bannerNote = cleanTime
        onSave(newBanner)
        isPresented = false
    }
}
