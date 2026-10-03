// CalendarEventInputSheet.swift
// Sheet for adding and editing custom agenda events in the Calendar View.

import SwiftUI

struct CalendarEventInputSheet: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Binding var isPresented: Bool
    var initialEvent: Scene? = nil
    let onSave: (Scene) -> Void

    @State private var title: String = ""
    @State private var timeString: String = "10:00 AM"
    @State private var selectedColorHex: String = "6366F1" // Indigo default

    let colorOptions: [(name: String, hex: String)] = [
        ("Indigo / Índigo", "6366F1"),
        ("Teal / Turquesa", "14B8A6"),
        ("Amber / Bronce", "D97706"),
        ("Rose / Rosa", "F43F5E"),
        ("Violet / Violeta", "8B5CF6"),
        ("Emerald / Esmeralda", "10B981")
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(initialEvent != nil ? L("Edit Calendar Event") : L("Add Calendar Event"), systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("Event Title / Subject"))
                    .font(.caption).fontWeight(.semibold)
                TextField(L("e.g. Cast Table Read, Fitting, Scout"), text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("Time (Optional)"))
                    .font(.caption).fontWeight(.semibold)
                TextField(L("e.g. 10:00 AM, 02:30 PM"), text: $timeString)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("Event Badge Color"))
                    .font(.caption).fontWeight(.semibold)
                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.hex) { option in
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorHex == option.hex ? 2.5 : 0)
                            )
                            .onTapGesture {
                                selectedColorHex = option.hex
                            }
                            .help(option.name)
                    }
                }
            }

            Divider()

            HStack {
                Button(L("Cancel")) {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(initialEvent != nil ? L("Save Changes") : L("Add Event")) {
                    let cleanTitle = title.trimmingCharacters(in: .whitespaces)
                    guard !cleanTitle.isEmpty else { return }
                    var eventScene = Scene.createCalendarEvent(
                        title: cleanTitle,
                        time: timeString.trimmingCharacters(in: .whitespaces),
                        colorHex: selectedColorHex
                    )
                    if let existing = initialEvent {
                        eventScene.id = existing.id
                    }
                    onSave(eventScene)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            if let ev = initialEvent {
                self.title = ev.bannerTitle.isEmpty ? ev.title : ev.bannerTitle
                self.timeString = ev.summary
                self.selectedColorHex = ev.bannerColorHex.isEmpty ? "6366F1" : ev.bannerColorHex
            }
        }
    }
}
