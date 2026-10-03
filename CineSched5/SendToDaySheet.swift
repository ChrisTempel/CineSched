// SendToDaySheet.swift
// A day picker for the calendar's "Send to Day…" context menu action — lets a
// selection be moved to a day that isn't currently scrolled into view, instead
// of dragging a strip up or down a long schedule. Uses the same graphical
// month-calendar control as the native date pickers elsewhere in the app.

import SwiftUI

struct SendToDaySheet: View {
    let shootDays:  [ShootDay]
    let sceneCount: Int
    let onSelect: (UUID) -> Void
    let onCancel: () -> Void

    @State private var selectedDate: Date

    init(shootDays: [ShootDay], sceneCount: Int, onSelect: @escaping (UUID) -> Void, onCancel: @escaping () -> Void) {
        self.shootDays  = shootDays
        self.sceneCount = sceneCount
        self.onSelect   = onSelect
        self.onCancel   = onCancel
        _selectedDate = State(initialValue: shootDays.first?.date ?? Date())
    }

    private var dateRange: ClosedRange<Date> {
        guard let first = shootDays.first?.date, let last = shootDays.last?.date else {
            let now = Date()
            return now...now
        }
        return first...last
    }

    private var matchedDay: ShootDay? {
        let cal = Calendar.current
        return shootDays.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send to Day")
                        .font(.title2).fontWeight(.bold)
                    Text("\(sceneCount) scene\(sceneCount == 1 ? "" : "s") selected")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            DatePicker(
                "",
                selection: $selectedDate,
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(16)

            if let day = matchedDay {
                Text(day.scenes.isEmpty
                     ? "No scenes currently scheduled that day"
                     : "\(day.scenes.count) scene\(day.scenes.count == 1 ? "" : "s") already scheduled that day")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }

            Divider()

            HStack {
                Button("Cancel") { onCancel() }.buttonStyle(.bordered)
                Spacer()
                Button("Send") {
                    if let day = matchedDay { onSelect(day.id) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(matchedDay == nil)
            }
            .padding(16)
        }
        .frame(width: 340, height: 430)
    }
}
