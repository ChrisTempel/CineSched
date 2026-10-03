// ImportSummaryView.swift
// Post-import sheet shown after a Fountain script import completes: scene
// count, total pages/eighths, cast detected, and any parse warnings.

import SwiftUI

struct ImportSummaryView: View {
    let result: FountainImportResult
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Script Imported").font(.title2).fontWeight(.bold)
                    Text(result.fileName)
                        .font(.subheadline).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 24) {
                        statTile(icon: "film", value: "\(result.scenes.count)", label: "scenes")
                        statTile(icon: "doc.text", value: FountainPaginator.formatEighths(result.totalEighths), label: "pages")
                        statTile(icon: "number", value: "\(result.totalEighths)", label: "total 1/8ths")
                        statTile(icon: "person.2", value: "\(result.castList.count)", label: "cast")
                    }

                    Text("All \(result.scenes.count) scene\(result.scenes.count == 1 ? "" : "s") landed in the Boneyard, unscheduled. Time estimates are a rough guess from page count — edit before scheduling.")
                        .font(.caption).foregroundColor(.secondary)

                    if !result.castList.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cast Detected").font(.headline)
                            Text(result.castList.joined(separator: ", "))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                    }

                    if !result.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Warnings (\(result.warnings.count))")
                                .font(.headline).foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(result.warnings, id: \.self) { warning in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2).foregroundColor(.orange)
                                        Text(warning).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { onDismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 460, height: 460)
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(.accentColor)
            Text(value).font(.title3).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
