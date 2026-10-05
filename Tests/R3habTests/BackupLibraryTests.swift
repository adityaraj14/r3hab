import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class BackupLibraryTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupLibraryTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A small backup file in the same shape as `ExportImportService.exportBackup`.
    private func backup(
        exportedAt: String,
        checkInDays: [String] = [],
        sessionDays: [String] = [],
        note: String = ""
    ) -> Data {
        let daily = checkInDays.map { #"{"date":"\#($0)T04:00:00Z","dayKey":"x"}"# }.joined(separator: ",")
        let sessions = sessionDays.map { #"{"date":"\#($0)T04:00:00Z","whatIDid":"Seated leg extension"}"# }
            .joined(separator: ",")
        let json = #"{"schemaVersion":6,"exportedAt":"\#(exportedAt)","note":"\#(note)","settings":{},"#
            + #""dailyCheckIns":[\#(daily)],"trainingSessions":[\#(sessions)]}"#
        return Data(json.utf8)
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    func testSummaryReadsCountsAndRange() throws {
        let data = backup(
            exportedAt: "2026-10-04T21:35:12Z",
            checkInDays: ["2026-09-28", "2026-10-03"],
            sessionDays: ["2026-09-30", "2026-09-27", "2026-10-02"]
        )
        let summary = try BackupSummary.read(data)
        XCTAssertEqual(summary.exportedAt, date("2026-10-04T21:35:12Z"))
        XCTAssertEqual(summary.sessionCount, 3)
        XCTAssertEqual(summary.checkInCount, 2)
        XCTAssertEqual(summary.firstDay, date("2026-09-27T04:00:00Z"))
        XCTAssertEqual(summary.lastDay, date("2026-10-03T04:00:00Z"))
        XCTAssertEqual(BackupCopy.counts(summary), "3 sessions, 2 check-ins")
    }

    func testEmptyBackupHasNoRange() throws {
        let summary = try BackupSummary.read(backup(exportedAt: "2026-10-04T21:35:12Z"))
        XCTAssertEqual(summary.sessionCount, 0)
        XCTAssertNil(summary.firstDay)
        XCTAssertNil(summary.lastDay)
        XCTAssertEqual(BackupCopy.range(summary), "No records")
        XCTAssertEqual(BackupCopy.counts(summary), "0 sessions, 0 check-ins")
    }

    func testSaveKeepsFileAndListsIt() throws {
        let library = try BackupLibrary(directory: dir)
        XCTAssertTrue(library.entries().isEmpty)
        let data = backup(exportedAt: "2026-10-04T21:35:12Z", sessionDays: ["2026-10-04"])
        let entry = try library.add(data)
        XCTAssertEqual(entry.url.lastPathComponent, "R3hab-backup-20261004T213512Z.json")
        XCTAssertEqual(entry.fileSize, data.count)
        XCTAssertEqual(try Data(contentsOf: entry.url), data)
        XCTAssertEqual(library.entries().map(\.id), [entry.id])
        XCTAssertEqual(try library.data(for: entry), data)
    }

    func testListIsNewestFirst() throws {
        let library = try BackupLibrary(directory: dir)
        try library.add(backup(exportedAt: "2026-10-02T10:00:00Z"))
        try library.add(backup(exportedAt: "2026-10-04T10:00:00Z"))
        try library.add(backup(exportedAt: "2026-10-03T10:00:00Z"))
        XCTAssertEqual(
            library.entries().map(\.summary.exportedAt),
            [date("2026-10-04T10:00:00Z"), date("2026-10-03T10:00:00Z"), date("2026-10-02T10:00:00Z")]
        )
    }

    func testDeleteRemovesFile() throws {
        let library = try BackupLibrary(directory: dir)
        let keep = try library.add(backup(exportedAt: "2026-10-02T10:00:00Z"))
        let gone = try library.add(backup(exportedAt: "2026-10-03T10:00:00Z"))
        try library.delete(gone)
        XCTAssertFalse(FileManager.default.fileExists(atPath: gone.url.path))
        XCTAssertEqual(library.entries().map(\.id), [keep.id])
    }

    /// A file from the file picker goes in the list. The same file again does not make a second row.
    func testImportedFileAddsToListOnce() throws {
        let library = try BackupLibrary(directory: dir)
        let picked = dir.deletingLastPathComponent().appendingPathComponent("picked-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: picked) }
        try backup(exportedAt: "2026-09-01T08:00:00Z", checkInDays: ["2026-08-30"]).write(to: picked)

        let first = try library.add(try Data(contentsOf: picked))
        let second = try library.add(try Data(contentsOf: picked))
        XCTAssertEqual(first.url, second.url)
        XCTAssertEqual(library.entries().count, 1)
        XCTAssertEqual(library.entries().first?.summary.checkInCount, 1)
    }

    func testSameSecondDifferentContentKeepsBoth() throws {
        let library = try BackupLibrary(directory: dir)
        let a = try library.add(backup(exportedAt: "2026-10-04T10:00:00Z", note: "a"))
        let b = try library.add(backup(exportedAt: "2026-10-04T10:00:00Z", note: "b"))
        XCTAssertNotEqual(a.url, b.url)
        XCTAssertEqual(b.url.lastPathComponent, "R3hab-backup-20261004T100000Z-2.json")
        XCTAssertEqual(library.entries().count, 2)
    }

    func testRejectsFileThatIsNotABackup() throws {
        let library = try BackupLibrary(directory: dir)
        XCTAssertThrowsError(try library.add(Data(#"{"hello":"world"}"#.utf8)))
        XCTAssertThrowsError(try library.add(Data()))
        XCTAssertTrue(library.entries().isEmpty)
        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(contents.isEmpty)
    }

    func testListSkipsUnreadableFiles() throws {
        let library = try BackupLibrary(directory: dir)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("broken.json"))
        try library.add(backup(exportedAt: "2026-10-04T10:00:00Z"))
        XCTAssertEqual(library.entries().count, 1)
    }

    func testCopyUsesSingularForOne() {
        XCTAssertEqual(BackupCopy.plural(1, "session"), "1 session")
        XCTAssertEqual(BackupCopy.restoredMessage(sessions: 1, checkIns: 2), "R3hab restored 1 session and 2 check-ins.")
    }

    /// Before a restore replaces data, the current backup is added to the list first.
    func testSafetyBackupKeepsCurrentDataInList() throws {
        let library = try BackupLibrary(directory: dir)
        let current = backup(exportedAt: "2026-10-05T12:00:00Z", sessionDays: ["2026-10-05"])
        let older = backup(exportedAt: "2026-10-03T12:00:00Z", sessionDays: ["2026-10-01"])
        let restoreTarget = try library.add(older)
        // Safety step: keep the current data, then the restore source is still there.
        let safety = try library.add(current)
        XCTAssertEqual(library.entries().count, 2)
        XCTAssertEqual(safety.summary.sessionCount, 1)
        XCTAssertEqual(try library.data(for: restoreTarget), older)
    }
}
