import Foundation
import SwiftData

@Model
final class JourneyProgress {
    // Fake total distance for the current placeholder journey. Shared so every
    // screen that shows progress (map, HealthKit debug) agrees on the same goal.
    static let totalJourneyDistance: Double = 100
    // Real step goal for the map journey — kept separate from totalDistance so
    // the map's progress reflects actual synced HealthKit steps, not a mile ratio.
    static let totalJourneySteps: Int = 5_000

    var totalDistance: Double = 0
    var lastUpdated: Date = Date.now
    // When this journey began. Steps toward totalJourneySteps are counted
    // live from HealthKit starting here, rather than accumulated locally,
    // so the map always agrees with HealthKit's own total.
    var startDate: Date = Date.now

    init(totalDistance: Double = 0, lastUpdated: Date = .now, startDate: Date = .now) {
        self.totalDistance = totalDistance
        self.lastUpdated = lastUpdated
        self.startDate = startDate
    }

    // Finds the single persisted journey record, creating it (and saving
    // immediately) on first use if none exists yet. Shared by every screen
    // that reads/writes journey progress so there's exactly one get-or-create
    // implementation instead of divergent copies per view.
    static func current(from journeyProgresses: [JourneyProgress], in modelContext: ModelContext) -> JourneyProgress {
        if let existing = journeyProgresses.first {
            return existing
        }
        let created = JourneyProgress()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }
}
