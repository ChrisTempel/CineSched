// ConflictReportSheet.swift
// Lists every scene where a scheduled character's actor is marked unavailable in
// Production Setup. Conflicts are also detected continuously in the background (the
// affected scene strips turn red on the calendar as soon as a conflict exists) — this
// sheet is for pulling up the full list on demand, e.g. before locking a schedule.

import SwiftUI

struct ConflictReportSheet: View {
    let conflicts: [ScheduleConflict]
    let onSelectDate: (Date) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedule Conflicts").font(.title2).fontWeight(.bold)
                    Text(conflicts.isEmpty
                         ? "No conflicts found"
                         : "\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s") found")
                        .font(.subheadline).foregroundColor(conflicts.isEmpty ? .secondary : .red)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            if conflicts.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.circle").font(.largeTitle).foregroundColor(.green)
                    Text("Nobody scheduled against their own unavailable dates.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(30)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(conflicts) { conflict in
                            Button { onSelectDate(conflict.date) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formattedDate(conflict.date)).fontWeight(.medium)
                                        Text("\(conflict.actorDisplayName) — \(conflict.sceneTitle)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                }
                                .padding(.vertical, 8).padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Close") { onDismiss() }.buttonStyle(.bordered)
            }
            .padding(16)
        }
        .frame(width: 420, height: 460)
    }
}
