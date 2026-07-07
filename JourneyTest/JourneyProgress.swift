import Foundation
import SwiftData

@Model
final class JourneyProgress {
    var totalDistance: Double
    var lastUpdated: Date

    init(totalDistance: Double = 0, lastUpdated: Date = .now) {
        self.totalDistance = totalDistance
        self.lastUpdated = lastUpdated
    }
}
