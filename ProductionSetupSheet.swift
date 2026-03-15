// ProductionSetupSheet.swift
// Project-wide production info — company, director, contact number, cast, and crew.
// Filled in once per project; opened from the toolbar.

import SwiftUI

struct ProductionSetupSheet: View {
    @Binding var productionInfo: ProductionInfo
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @State private var companyName:   String = ""
    @State private var directorName:  String = ""
    @State private var contactNumber: String = ""
    @State private var castList:      [CastMember] = []
    @State private var crew:          [CrewMember] = []

    // New cast entry
    @State private var newActorName:     String = ""
    @State private var newCharacterName: String = ""

    // New crew entry
    @State private var newCrewName: String = ""
    @State private var newCrewRole: String = ""

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Production Setup")
                        .font(.title2).fontWeight(.bold)
                    Text("These details appear on every call sheet")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Production details
                    Group {
                        Label("Production Details", systemImage: "building.2")
                            .font(.headline)
                        LabeledField("Production Company", placeholder: "e.g. Tempel Films",   text: $companyName)
                        LabeledField("Director",           placeholder: "e.g. Chris Tempel",   text: $directorName)
                        LabeledField("Contact Number",     placeholder: "e.g. 555-867-5309",   text: $contactNumber)
                    }

                    Divider()

                    // Cast list
                    Label("Cast", systemImage: "star")
                        .font(.headline)
                    Text("Enter each actor and the character they play. Scene strips use character names — the app will look up the actor automatically.")
                        .font(.caption).foregroundColor(.secondary)

                    if castList.isEmpty {
                        Text("No cast added yet.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(castList.enumerated()), id: \.element.id) { index, member in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.actorName.isEmpty ? "Unnamed Actor" : member.actorName)
                                        .fontWeight(.medium)
                                    if !member.characterName.isEmpty {
                                        Text(member.characterName)
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    castList.remove(at: index)
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

                    // Add cast member
                    HStack(spacing: 8) {
                        TextField("Actor name", text: $newActorName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Character name", text: $newCharacterName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button {
                            let actor = newActorName.trimmingCharacters(in: .whitespaces)
                            let character = newCharacterName.trimmingCharacters(in: .whitespaces)
                            guard !actor.isEmpty || !character.isEmpty else { return }
                            castList.append(CastMember(actorName: actor, characterName: character))
                            newActorName     = ""
                            newCharacterName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            newActorName.trimmingCharacters(in: .whitespaces).isEmpty &&
                            newCharacterName.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                    }

                    Divider()

                    // Crew list
                    Label("Crew", systemImage: "person.3")
                        .font(.headline)

                    if crew.isEmpty {
                        Text("No crew added yet.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(Array(crew.enumerated()), id: \.element.id) { index, member in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name.isEmpty ? "Unnamed" : member.name)
                                        .fontWeight(.medium)
                                    if !member.role.isEmpty {
                                        Text(member.role)
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    crew.remove(at: index)
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

                    // Add crew member
                    HStack(spacing: 8) {
                        TextField("Name", text: $newCrewName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Role (e.g. DP)", text: $newCrewRole)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 160)
                        Button {
                            let name = newCrewName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            crew.append(CrewMember(name: name, role: newCrewRole.trimmingCharacters(in: .whitespaces)))
                            newCrewName = ""
                            newCrewRole = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(newCrewName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save") {
                    productionInfo.companyName   = companyName
                    productionInfo.directorName  = directorName
                    productionInfo.contactNumber = contactNumber
                    productionInfo.castList      = castList
                    productionInfo.crew          = crew
                    onSave()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .frame(width: 560, height: 680)
        .onAppear {
            companyName   = productionInfo.companyName
            directorName  = productionInfo.directorName
            contactNumber = productionInfo.contactNumber
            castList      = productionInfo.castList
            crew          = productionInfo.crew
        }
    }
}

// MARK: - Small helper view for labeled text fields

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    init(_ label: String, placeholder: String, text: Binding<String>) {
        self.label       = label
        self.placeholder = placeholder
        self._text       = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}
