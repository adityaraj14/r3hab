import Foundation
import HealthKit

enum HealthKitStepsError: Error {
    case notAvailable
    case unauthorized
    case noData
    case queryFailed
}

/// Read-only step count from Apple Health. Nothing here writes health data,
/// and nothing requests permission except `requestAuthorization`.
enum HealthKitSteps {
    private static let store = HKHealthStore()
    private static var stepType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .stepCount)
    }

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// True only when the system Health sheet has not been shown for steps.
    static func needsAuthorizationPrompt() async -> Bool {
        guard isAvailable, let stepType else { return false }
        guard let status = try? await store.statusForAuthorizationRequest(toShare: [], read: [stepType]) else {
            return false
        }
        return status == .shouldRequest
    }

    static func requestAuthorization() async throws {
        guard isAvailable, let stepType else { throw HealthKitStepsError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    /// Sum of steps for a local calendar day. Does not request permission.
    static func steps(on day: Date, calendar: Calendar = .current) async throws -> Int {
        guard isAvailable, let stepType else { throw HealthKitStepsError.notAvailable }
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitStepsError.queryFailed
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    let denied = (error as? HKError).map { hk in
                        hk.code == .errorAuthorizationDenied || hk.code == .errorAuthorizationNotDetermined
                    } ?? false
                    continuation.resume(throwing: denied ? HealthKitStepsError.unauthorized : HealthKitStepsError.queryFailed)
                    return
                }
                guard let sum = stats?.sumQuantity() else {
                    continuation.resume(throwing: HealthKitStepsError.noData)
                    return
                }
                let value = Int(sum.doubleValue(for: HKUnit.count()).rounded())
                continuation.resume(returning: max(0, value))
            }
            store.execute(query)
        }
    }
}

/// Home's step line. `refresh` never shows the system prompt. `allowAndLoad` asks once.
@MainActor
final class TodayStepsReader: ObservableObject {
    @Published private(set) var state: TodayStepsState = .notAsked
    private var requesting = false

    func refresh() async {
        guard HealthKitSteps.isAvailable else {
            state = .unavailable
            return
        }
        if await HealthKitSteps.needsAuthorizationPrompt() {
            state = .notAsked
            return
        }
        await load()
    }

    func allowAndLoad() async {
        guard state == .notAsked, !requesting else { return }
        requesting = true
        defer { requesting = false }
        guard HealthKitSteps.isAvailable else {
            state = .unavailable
            return
        }
        do {
            try await HealthKitSteps.requestAuthorization()
        } catch {
            state = .unavailable
            return
        }
        if await HealthKitSteps.needsAuthorizationPrompt() {
            state = .notAsked
            return
        }
        await load()
    }

    private func load() async {
        do {
            let count = try await HealthKitSteps.steps(on: Date())
            state = .count(count)
        } catch HealthKitStepsError.noData {
            state = .count(0)
        } catch {
            state = .unavailable
        }
    }
}
