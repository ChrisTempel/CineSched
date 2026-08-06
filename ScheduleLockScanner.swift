// ScheduleLockScanner.swift
// Compares the current schedule against a locked baseline (see ScheduleLock in
// Models.swift) and reports which characters' working days have changed since — added
// days, removed days, or both. The schedule itself is never restricted by a lock; this
// only flags what moved.

import Foundation

struct ScheduleLockChange: Identifiable {
    let id = UUID()
    let character: String
    let actorDisplayName: String
    let addedDays: [Date]      // now working, wasn't at lock time
    let removedDays: [Date]    // was working at lock time, isn't now
}

struct ScheduleLockScanner {

    /// Character name -> the set of start-of-day dates they're currently scheduled to
    /// work, based purely on which scenes list them in cast.
    static func currentWorkingDays(shootDays: [ShootDay]) -> [String: Set<Date>] {
        let cal = Calendar.current
        var result: [String: Set<Date>] = [:]
        for day in shootDays {
            let start = cal.startOfDay(for: day.date)
            for scene in day.scenes {
                for character in scene.cast {
                    let key = character.trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty else { continue }
                    result[key, default: []].insert(start)
                }
            }
        }
        return result
    }

    /// Empty if there's no active lock, or if nothing has changed since it was set.
    static func changes(shootDays: [ShootDay], productionInfo: ProductionInfo) -> [ScheduleLockChange] {
        guard let lock = productionInfo.scheduleLock else { return [] }
        let current = currentWorkingDays(shootDays: shootDays)

        // Every character name that appears on either side of the comparison, so a
        // character removed entirely from the schedule still shows up as "all days removed"
        // rather than silently disappearing from the report.
        var allCharacters = Set(current.keys)
        for key in lock.workingDays.keys { allCharacters.insert(key) }

        var changes: [ScheduleLockChange] = []
        for character in allCharacters.sorted() {
            let lockedDays = Set(lock.workingDays[character] ?? [])
            let currentDays = current[character] ?? []
            guard lockedDays != currentDays else { continue }

            let added = currentDays.subtracting(lockedDays).sorted()
            let removed = lockedDays.subtracting(currentDays).sorted()
            guard !added.isEmpty || !removed.isEmpty else { continue }

            let displayName = productionInfo.castList.first {
                $0.characterName.trimmingCharacters(in: .whitespaces)
                    .caseInsensitiveCompare(character) == .orderedSame
            }?.displayString ?? character

            changes.append(ScheduleLockChange(
                character: character, actorDisplayName: displayName,
                addedDays: added, removedDays: removed
            ))
        }
        return changes.sorted { $0.actorDisplayName < $1.actorDisplayName }
    }

    /// Every date touched by any change — added or removed — for badging on the calendar.
    static func changedDates(_ changes: [ScheduleLockChange]) -> Set<Date> {
        var dates: Set<Date> = []
        for change in changes {
            dates.formUnion(change.addedDays)
            dates.formUnion(change.removedDays)
        }
        return dates
    }
}
