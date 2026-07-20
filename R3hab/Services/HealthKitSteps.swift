import Foundation
import HealthKit

enum HealthKitStepsError: LocalizedError {
    case notAvailable
    case unauthorized
    case noData
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Health is not available on this device."
        case .unauthorized:
            return "Steps access was denied. Enable it in Settings → Health → Data Access → R3hab."
        case .noData:
            return "No step data found for that day yet."
        case .queryFailed(let msg):
            return msg
        }
    }
}

/// Read step count from Apple Health (Watch / iPhone).
enum HealthKitSteps {
    private static let store = HKHealthStore()
    private static var stepType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .stepCount)
    }

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request read-only access to step count.
    static func requestAuthorization() async throws {
        guard isAvailable, let stepType else { throw HealthKitStepsError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    /// Sum of steps for a local calendar day (start-of-day → next day).
    static func steps(on day: Date, calendar: Calendar = .current) async throws -> Int {
        guard isAvailable, let stepType else { throw HealthKitStepsError.notAvailable }

        let status = store.authorizationStatus(for: stepType)
        // Note: for read types, status can be `.sharingDenied` or `.notDetermined`.
        // After deny, queries return empty — we still attempt and map to errors.

        if status == .notDetermined {
            try await requestAuthorization()
        }

        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitStepsError.queryFailed("Invalid date range.")
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    cont.resume(throwing: HealthKitStepsError.queryFailed(error.localizedDescription))
                    return
                }
                guard let sum = stats?.sumQuantity() else {
                    cont.resume(throwing: HealthKitStepsError.noData)
                    return
                }
                let value = Int(sum.doubleValue(for: HKUnit.count()).rounded())
                cont.resume(returning: max(0, value))
            }
            store.execute(query)
        }
    }
}
