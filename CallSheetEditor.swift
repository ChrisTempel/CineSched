// CallSheetEditor.swift
// Per-day call sheet editor — opened by clicking a date header in the calendar.
// Handles locations (add/remove), general call time, cast (auto-pulled, editable),
// and a free-form notes field.

import SwiftUI

struct CallSheetEditor: View {
    @Binding var shootDay: ShootDay
    let productionInfo: ProductionInfo
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onExportPDF: (ShootDay) -> Void

    // Local editing state
    @State private var callTime:     String = ""
    @State private var locations:    [Location] = []
    @State private var castList:     [String] = []
    @State private var castIsEdited: Bool = false
    @State private var notes:        String = ""

    // New location entry
    @State private var newLocationName:    String = ""
    @State private var newLocationAddress: String = ""
    @State private var showingAddLocation: Bool = false

    // New cast entry
    @State private var newCastMember: String = ""

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Call Sheet")
                        .font(.title2).fontWeight(.bold)
                    Text(formattedDate(shootDay.date))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 16)

            Divider()

            // MARK: Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // General Call Time
                    sectionHeader("General Call Time", icon: "clock")
                    TextField("e.g. 7:00 AM", text: $callTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Divider()

                    // Locations
                    sectionHeader("Locations", icon: "mappin.and.ellipse")
                    if locations.isEmpty {
                        Text("No locations added yet.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(locations.enumerated()), id: \.element.id) { index, loc in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption).foregroundColor(.secondary)
                                    .frame(width: 16, alignment: .trailing)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc.name.isEmpty ? "Unnamed Location" : loc.name)
                                        .fontWeight(.medium)
                                    if !loc.address.isEmpty {
                                        Text(loc.address)
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    locations.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    // Add location
                    if showingAddLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Location name (e.g. Owen's Farmhouse)", text: $newLocationName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Address (optional)", text: $newLocationAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            HStack {
                                Button("Cancel") {
                                    newLocationName    = ""
                                    newLocationAddress = ""
                                    showingAddLocation = false
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                Button("Add Location") {
                                    guard !newLocationName.isEmpty else { return }
                                    locations.append(Location(name: newLocationName, address: newLocationAddress))
                                    newLocationName    = ""
                                    newLocationAddress = ""
                                    showingAddLocation = false
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newLocationName.isEmpty)
                            }
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
                    } else {
                        Button {
                            showingAddLocation = true
                        } label: {
                            Label("Add Location", systemImage: "plus.circle")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }

                    Divider()

                    // Cast
                    HStack {
                        sectionHeader("Cast", icon: "person.2")
                        Spacer()
                        if castIsEdited {
                            Button("Reset to Auto") {
                                castList     = shootDay.allCast
                                castIsEdited = false
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                        } else {
                            Text("Auto-pulled from scenes")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }

                    if castList.isEmpty {
                        Text("No cast assigned to scenes on this day.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(castList.enumerated()), id: \.offset) { index, member in
                            HStack {
                                Text(member)
                                Spacer()
                                Button {
                                    castList.remove(at: index)
                                    castIsEdited = true
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }

                    // Add cast member manually
                    HStack {
                        TextField("Add cast member", text: $newCastMember)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button {
                            let trimmed = newCastMember.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            castList.append(trimmed)
                            newCastMember = ""
                            castIsEdited  = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(newCastMember.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Divider()

                    // Notes
                    sectionHeader("Notes", icon: "note.text")
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .font(.body)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .cornerRadius(4)
                    Text("Use this for props, special gear, late arrivals, permit info, etc.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(24)
            }

            Divider()

            // MARK: Footer buttons
            HStack(spacing: 12) {
                Button("Export PDF") {
                    saveToDay()
                    onExportPDF(shootDay)
                }
                .buttonStyle(.bordered)
                .help("Export call sheet as PDF")

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveToDay()
                    onSave()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .frame(width: 560, height: 700)
        .onAppear { populateFields() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundColor(.primary)
    }

    private func populateFields() {
        callTime  = shootDay.callSheet.generalCallTime
        locations = shootDay.callSheet.locations
        notes     = shootDay.callSheet.notes

        if let override = shootDay.callSheet.castOverride {
            castList     = override
            castIsEdited = true
        } else {
            // Use resolved cast (with actor lookup) as the starting point
            castList     = shootDay.callSheet.resolvedCast(from: shootDay.scenes, productionInfo: productionInfo)
            castIsEdited = false
        }
    }

    private func saveToDay() {
        shootDay.callSheet.generalCallTime = callTime
        shootDay.callSheet.locations       = locations
        shootDay.callSheet.notes           = notes
        shootDay.callSheet.castOverride    = castIsEdited ? castList : nil
    }
}
