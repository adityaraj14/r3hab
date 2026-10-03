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
            return "Apple Health denied access to steps. Open Settings. Select Health. Select Data Access. Select R3hab."
        case .noData:
            return "Apple Health has no steps for that day."
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

    /// Shown before the system Health prompt (App Review 2.5.1).
    static let permissionExplanation =
        "R3hab reads only steps from Apple Health. R3hab never writes to Apple Health. The data stays on your iPhone."

    /// True until the system Health prompt has been shown once for steps.
    /// HealthKit hides whether read access was granted, so this is the only
    /// honest "connected" signal.
    static func needsAuthorizationPrompt() async -> Bool {
        guard isAvailable, let stepType else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: [stepType])
        return status != .unnecessary
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
            throw HealthKitStepsError.queryFailed("The date range is not valid.")
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
