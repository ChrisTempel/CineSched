// SceneColorSettingsSheet.swift
// Lets the user override any of the industry-standard scene strip colors. Changes apply
// immediately everywhere Scene.stripColor is used — calendar, Stripboard, and both PDF
// exporters — since they all read from the same SceneColorSettings storage.

import SwiftUI

struct SceneColorSettingsSheet: View {
    let onDismiss: () -> Void

    @State private var colors: [SceneColorSlot: Color] = [:]

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Customize Scene Colors").font(.title2).fontWeight(.bold)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SceneColorSlot.allCases) { slot in
                        HStack(spacing: 10) {
                            ColorPicker("", selection: binding(for: slot), supportsOpacity: false)
                                .labelsHidden()
                            Text(slot.label)
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Reset All to Defaults") {
                    SceneColorSettings.resetToDefaults()
                    loadColors()
                }
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 480)
        .onAppear { loadColors() }
    }

    private func binding(for slot: SceneColorSlot) -> Binding<Color> {
        Binding<Color>(
            get: { colors[slot] ?? SceneColorSettings.color(for: slot) },
            set: { newColor in
                colors[slot] = newColor
                SceneColorSettings.setHex(newColor.hexString, for: slot)
            }
        )
    }

    private func loadColors() {
        for slot in SceneColorSlot.allCases {
            colors[slot] = SceneColorSettings.color(for: slot)
        }
    }
}
