import SwiftUI

struct ContentView: View {
    @State private var distanceTraveled: Double = 0   // miles, fake for now
    let totalJourneyDistance: Double = 100              // fake total distance

    @State private var healthKitManager = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

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
                distanceTraveled = min(distanceTraveled + 5, totalJourneyDistance)
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
}

#Preview {
    ContentView()
}
