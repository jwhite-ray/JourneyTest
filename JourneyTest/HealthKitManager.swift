import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitManager {
    private let healthStore = HKHealthStore()

    private(set) var stepCount: Double = 0
    private(set) var distanceMiles: Double = 0
    private(set) var statusMessage: String?

    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)

    // Observer queries need a strong reference for the life of the app, per
    // Apple's HealthKit guidance, otherwise they can be torn down early.
    private var stepObserverQuery: HKObserverQuery?
    private var distanceObserverQuery: HKObserverQuery?
    private var isObservingUpdates = false
    private var hasRequestedAuthorization = false

    // Fires whenever a distance fetch completes, whether triggered by a
    // one-time query (launch, Refresh, foreground) or a background observer.
    // Lets callers (e.g. a SwiftData-backed journey total) react without
    // this class needing to know anything about persistence.
    var onDistanceUpdate: (() -> Void)?

    func requestAuthorization() {
        // Now that a single HealthKitManager is shared across every tab, each
        // tab's onAppear still calls this — guard so we don't re-request
        // authorization or kick off a duplicate fetchTodayTotals() per tab.
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true

        guard HKHealthStore.isHealthDataAvailable() else {
            statusMessage = "Health data isn't available on this device."
            return
        }

        let readTypes: Set<HKObjectType> = [stepType, distanceType]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.statusMessage = "Couldn't request Health access: \(error.localizedDescription)"
                    return
                }

                // Apple doesn't tell apps whether the user actually granted read
                // access to a given type — that's hidden for privacy reasons, so a
                // denied read permission looks identical to "no data recorded yet".
                // We just query and let the numbers (or lack of them) speak for
                // themselves rather than pretending we can detect denial directly.
                self.statusMessage = nil
                self.fetchTodayTotals()
                self.startObservingUpdates()
            }
        }
    }

    // Sets up an HKObserverQuery per type plus background delivery, so we
    // learn about new step/distance samples even while the app isn't open.
    // This only needs to run once per launch.
    func startObservingUpdates() {
        guard !isObservingUpdates else { return }
        isObservingUpdates = true

        stepObserverQuery = makeObserverQuery(for: stepType)
        distanceObserverQuery = makeObserverQuery(for: distanceType)

        enableBackgroundDelivery(for: stepType)
        enableBackgroundDelivery(for: distanceType)
    }

    private func makeObserverQuery(for quantityType: HKQuantityType) -> HKObserverQuery {
        let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, completionHandler, error in
            Task { @MainActor in
                if let error {
                    print("HealthKit observer error for \(quantityType.identifier): \(error.localizedDescription)")
                } else {
                    print("HealthKit observer fired for \(quantityType.identifier) — refreshing today's totals")
                    self?.fetchTodayTotals()
                }

                // Required: tells HealthKit we're done handling this update.
                // Skipping this can cause future background updates to stop arriving.
                completionHandler()
            }
        }

        healthStore.execute(query)
        return query
    }

    private func enableBackgroundDelivery(for quantityType: HKQuantityType) {
        healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { success, error in
            if let error {
                print("Failed to enable background delivery for \(quantityType.identifier): \(error.localizedDescription)")
            } else {
                print("Background delivery enabled for \(quantityType.identifier): \(success)")
            }
        }
    }

    func fetchTodayTotals() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        fetchSum(for: stepType, predicate: predicate, unit: .count()) { [weak self] total in
            self?.stepCount = total ?? 0
        }

        fetchSum(for: distanceType, predicate: predicate, unit: .mile()) { [weak self] total in
            self?.distanceMiles = total ?? 0
            self?.onDistanceUpdate?()
        }
    }

    // Distance walked/run between an arbitrary start date and now — used to
    // reconcile a persisted running total rather than "today only".
    func fetchDistance(since startDate: Date, completion: @escaping (Double) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        fetchSum(for: distanceType, predicate: predicate, unit: .mile()) { total in
            completion(total ?? 0)
        }
    }

    // Steps taken between an arbitrary start date and now — used to reconcile
    // a persisted running total rather than "today only".
    func fetchSteps(since startDate: Date, completion: @escaping (Int) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        fetchSum(for: stepType, predicate: predicate, unit: .count()) { total in
            completion(Int(total ?? 0))
        }
    }

    private func fetchSum(
        for quantityType: HKQuantityType,
        predicate: NSPredicate,
        unit: HKUnit,
        completion: @escaping (Double?) -> Void
    ) {
        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            Task { @MainActor in
                // For statistics queries, HealthKit represents "no samples
                // matched this predicate" as an .errorNoData error rather than
                // a nil sum. That's a normal, expected outcome (e.g. an empty
                // date range, or genuinely zero activity) — not a real failure,
                // so we treat it as zero instead of surfacing a scary message.
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    completion(0)
                    return
                }

                if let error {
                    self?.statusMessage = "Couldn't read Health data: \(error.localizedDescription)"
                    completion(nil)
                    return
                }
                completion(statistics?.sumQuantity()?.doubleValue(for: unit))
            }
        }

        healthStore.execute(query)
    }
}
