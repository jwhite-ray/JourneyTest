import SwiftUI
import SwiftData

struct ContentView: View {
    let totalJourneyDistance: Double = 100              // fake total distance

    @State private var healthKitManager = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var journeyProgresses: [JourneyProgress]

    private var distanceTraveled: Double {
        journeyProgresses.first?.totalDistance ?? 0
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Journey to the Volcano")
                .font(.title)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .offset(x: progressFraction * (geometry.size.width - 20))
                }
            }
            .frame(height: 20)
            .padding(.horizontal)

            Text("\(Int(distanceTraveled)) / \(Int(totalJourneyDistance)) miles")

            Button("Simulate Walking 5 Miles") {
                let journey = currentJourney()
                journey.totalDistance = min(journey.totalDistance + 5, totalJourneyDistance)
                journey.lastUpdated = Date()
                try? modelContext.save()
            }

            Divider()

            VStack(spacing: 12) {
                Text("Today's Activity")
                    .font(.headline)

                if let statusMessage = healthKitManager.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("\(Int(healthKitManager.stepCount)) steps")
                    Text(String(format: "%.2f mi walked/run", healthKitManager.distanceMiles))
                }

                Button("Refresh") {
                    healthKitManager.fetchTodayTotals()
                }
            }
        }
        .padding()
        .onAppear {
            // SwiftData's @Query has already loaded any saved journey by this
            // point, so the UI shows the persisted total immediately. Then we
            // reconcile with HealthKit in case background updates were missed
            // while the app was closed.
            healthKitManager.onDistanceUpdate = { syncJourneyProgress() }
            healthKitManager.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Catch-up query: whenever the app comes to the foreground, do a
            // fresh fetch so the displayed totals are accurate even if a
            // background observer update was missed or delayed.
            if newPhase == .active {
                healthKitManager.fetchTodayTotals()
            }
        }
    }

    var progressFraction: Double {
        distanceTraveled / totalJourneyDistance
    }

    // Finds the single persisted journey record, creating it on first launch.
    private func currentJourney() -> JourneyProgress {
        if let existing = journeyProgresses.first {
            return existing
        }
        let created = JourneyProgress()
        modelContext.insert(created)
        return created
    }

    // Called whenever HealthKit reports an updated distance value (from a
    // one-time query or a background observer). Adds only the distance
    // accrued since the journey was last reconciled, so the running total
    // accumulates across days instead of resetting like "today's" distance.
    private func syncJourneyProgress() {
        let journey = currentJourney()
        let since = journey.lastUpdated

        healthKitManager.fetchDistance(since: since) { delta in
            journey.totalDistance = min(journey.totalDistance + delta, totalJourneyDistance)
            journey.lastUpdated = Date()
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JourneyProgress.self, inMemory: true)
}
