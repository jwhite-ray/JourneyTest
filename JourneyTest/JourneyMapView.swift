import SwiftUI
import SwiftData

// A fixed waypoint along the journey path, expressed as a fraction (0...1)
// of the background image's width/height so it stays correct at any size.
struct JourneyWaypoint {
    let steps: Int
    let x: Double
    let y: Double
}

struct JourneyMapView: View {
    static let totalSteps = JourneyProgress.totalJourneySteps

    // Placeholder path across the map, one waypoint every 1,000 steps.
    // Retune these once real map art is in place.
    static let waypoints: [JourneyWaypoint] = [
        JourneyWaypoint(steps: 0, x: 0.10, y: 0.85),
        JourneyWaypoint(steps: 1_000, x: 0.28, y: 0.65),
        JourneyWaypoint(steps: 2_000, x: 0.45, y: 0.78),
        JourneyWaypoint(steps: 3_000, x: 0.60, y: 0.50),
        JourneyWaypoint(steps: 4_000, x: 0.78, y: 0.60),
        JourneyWaypoint(steps: 5_000, x: 0.90, y: 0.20),
    ]

    let totalJourneyDistance = JourneyProgress.totalJourneyDistance

    @State private var healthKitManager = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var journeyProgresses: [JourneyProgress]

    // Cached locally for display only — the source of truth is always the
    // live HealthKit query in refreshStepsWalked(), never a persisted delta.
    @State private var stepsWalked: Int = 0

    private var distanceTraveled: Double {
        journeyProgresses.first?.totalDistance ?? 0
    }

    private var startDate: Date? {
        journeyProgresses.first?.startDate
    }

    private var progress: Double {
        guard Self.totalSteps > 0 else { return 0 }
        return min(max(Double(stepsWalked) / Double(Self.totalSteps), 0), 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Journey to the Volcano")
                    .font(.title2.bold())

                GeometryReader { geometry in
                    ZStack {
                        background

                        ForEach(Array(Self.waypoints.enumerated()), id: \.offset) { _, waypoint in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 8, height: 8)
                                .position(
                                    x: waypoint.x * geometry.size.width,
                                    y: waypoint.y * geometry.size.height
                                )
                        }

                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                            .position(markerPosition(in: geometry.size))
                    }
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Text("\(stepsWalked) / \(Self.totalSteps) steps")
                    .font(.headline)

                Text(String(format: "%.1f / %.0f mi traveled", distanceTraveled, totalJourneyDistance))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let startDate {
                    Text("Started \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            healthKitManager.requestAuthorization()
            refreshStepsWalked()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshStepsWalked()
            }
        }
    }

    // Finds the single persisted journey record, creating it (with a fresh
    // startDate) on first use if none exists yet.
    private func currentJourney() -> JourneyProgress {
        if let existing = journeyProgresses.first {
            return existing
        }
        let created = JourneyProgress()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    // Asks HealthKit directly for steps since the journey's startDate, so the
    // displayed total always matches HealthKit's own truth — no local
    // accumulation to drift out of sync.
    private func refreshStepsWalked() {
        let journey = currentJourney()
        healthKitManager.fetchSteps(since: journey.startDate) { total in
            stepsWalked = min(total, Self.totalSteps)
        }
    }

    @ViewBuilder
    private var background: some View {
        if UIImage(named: "JourneyMapBackground") != nil {
            Image("JourneyMapBackground")
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.brown.opacity(0.6), .green.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func markerPosition(in size: CGSize) -> CGPoint {
        let point = Self.interpolatedPosition(progress: progress)
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    // Finds the two waypoints progress falls between and linearly interpolates,
    // so the marker glides smoothly instead of jumping from point to point.
    static func interpolatedPosition(progress: Double) -> (x: Double, y: Double) {
        guard let first = waypoints.first else { return (0, 0) }
        guard waypoints.count > 1 else { return (first.x, first.y) }

        let clamped = min(max(progress, 0), 1)
        let segmentCount = waypoints.count - 1
        let scaled = clamped * Double(segmentCount)
        let index = min(Int(scaled), segmentCount - 1)
        let segmentProgress = scaled - Double(index)

        let start = waypoints[index]
        let end = waypoints[index + 1]

        let x = start.x + (end.x - start.x) * segmentProgress
        let y = start.y + (end.y - start.y) * segmentProgress
        return (x, y)
    }
}

#Preview {
    JourneyMapView()
        .modelContainer(for: JourneyProgress.self, inMemory: true)
}
