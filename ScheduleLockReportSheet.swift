// ScheduleLockReportSheet.swift
// Lists every character whose working days have changed since the schedule was locked —
// which days were added, which were removed — so a rearrangement doesn't silently shift
// someone's days without you noticing.

import SwiftUI

struct ScheduleLockReportSheet: View {
    let changes: [ScheduleLockChange]
    let lockedAt: Date?
    let onSelectDate: (Date) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedule Lock Changes").font(.title2).fontWeight(.bold)
                    if let lockedAt {
                        Text("Locked \(formattedDate(lockedAt)) · \(changes.count) actor\(changes.count == 1 ? "" : "s") affected")
                            .font(.subheadline).foregroundColor(changes.isEmpty ? .secondary : .orange)
                    } else {
                        Text("No lock is currently set").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            if lockedAt == nil {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "lock.open").font(.largeTitle).foregroundColor(.secondary)
                    Text("Lock the schedule from the Production menu to start tracking changes to actor working days.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Spacer()
                }
            } else if changes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.circle").font(.largeTitle).foregroundColor(.green)
                    Text("No actor working days have changed since the lock.")
                        .font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(changes) { change in
                            Button {
                                if let first = (change.addedDays + change.removedDays).min() {
                                    onSelectDate(first)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(change.actorDisplayName).fontWeight(.medium).foregroundColor(.primary)

                                    if !change.addedDays.isEmpty {
                                        changeRow(icon: "plus.circle.fill", color: .green,
                                                  label: "Added", dates: change.addedDays)
                                    }
                                    if !change.removedDays.isEmpty {
                                        changeRow(icon: "minus.circle.fill", color: .red,
                                                  label: "Removed", dates: change.removedDays)
                                    }
                                }
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Click to jump to the first changed date")
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
        .frame(width: 460, height: 480)
    }

    private func changeRow(icon: String, color: Color, label: String, dates: [Date]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.caption)
            Text("\(label): \(dates.map { formattedDate($0) }.joined(separator: ", "))")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
