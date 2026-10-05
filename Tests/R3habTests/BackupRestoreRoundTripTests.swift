import XCTest
import SwiftData
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// Export → keep in the backup list → change the data → restore from the list.
/// Uses the same import path as the file picker (`ExportImportService.importBackup`, mode replace).
@MainActor
final class BackupRestoreRoundTripTests: XCTestCase {
    func testRestoreFromListReplacesCurrentData() throws {
        let container = try ModelContainer(
            for: AppSettings.self, DailyCheckIn.self, TrainingSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        _ = try AppBootstrap.ensureSettings(context: context)

        let calendar = Calendar.current
        let day1 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
        let day2 = calendar.date(byAdding: .day, value: 2, to: day1)!
        let checkIn = DailyCheckIn(date: day1, calendar: calendar)
        let kept1 = TrainingSession(
            date: day1, phase: .aFlareDeLoad, sessionType: .hsrStrength,
            whatIDid: "Seated leg extension", painDuring: 2, painAfter: 1, calendar: calendar
        )
        let kept2 = TrainingSession(
            date: day2, phase: .aFlareDeLoad, sessionType: .hsrStrength,
            whatIDid: "Seated leg extension", painDuring: 3, calendar: calendar
        )
        context.insert(checkIn)
        context.insert(kept1)
        context.insert(kept2)
        try context.save()

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupRoundTrip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = try BackupLibrary(directory: dir)
        let entry = try library.add(try ExportImportService.exportBackup(context: context))
        XCTAssertEqual(entry.summary.sessionCount, 2)
        XCTAssertEqual(entry.summary.checkInCount, 1)
        XCTAssertEqual(entry.summary.firstDay, day1)
        XCTAssertEqual(entry.summary.lastDay, day2)

        // Change the data after the backup.
        context.delete(kept2)
        context.delete(checkIn)
        let extra = TrainingSession(
            date: day2, phase: .aFlareDeLoad, sessionType: .hsrStrength,
            whatIDid: "Demo record", painDuring: 5, calendar: calendar
        )
        context.insert(extra)
        try context.save()

        let picked = try XCTUnwrap(library.entries().first)
        try ExportImportService.importBackup(data: try library.data(for: picked), mode: .replace, context: context)

        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(Set(sessions.map(\.id)), [kept1.id, kept2.id])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyCheckIn>()), 1)
        XCTAssertFalse(sessions.contains { $0.whatIDid == "Demo record" })
        XCTAssertEqual(sessions.first { $0.id == kept1.id }?.painDuring, 2)
    }
}
