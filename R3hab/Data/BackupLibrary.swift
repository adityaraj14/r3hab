import Foundation

/// What a backup file holds, read from its content.
struct BackupSummary: Equatable, Sendable {
    /// When the backup was made (the file's `exportedAt`).
    var exportedAt: Date
    var sessionCount: Int
    var checkInCount: Int
    /// First and last day of the records. Nil when the backup has no records.
    var firstDay: Date?
    var lastDay: Date?

    /// Reads only the keys the list needs. Throws when the data is not an R3hab backup.
    static func read(_ data: Data) throws -> BackupSummary {
        let peek = try BackupLibrary.decoder.decode(Peek.self, from: data)
        let days = peek.dailyCheckIns.map(\.date) + peek.trainingSessions.map(\.date)
        return BackupSummary(
            exportedAt: peek.exportedAt,
            sessionCount: peek.trainingSessions.count,
            checkInCount: peek.dailyCheckIns.count,
            firstDay: days.min(),
            lastDay: days.max()
        )
    }

    private struct Peek: Decodable {
        var schemaVersion: Int
        var exportedAt: Date
        var dailyCheckIns: [Dated]
        var trainingSessions: [Dated]
    }

    private struct Dated: Decodable {
        var date: Date
    }
}

/// Backups that R3hab keeps on this iPhone, one JSON file each, in
/// Application Support/Backups. R3hab does not upload them.
/// There is no limit on the number of files.
struct BackupLibrary {
    struct Entry: Identifiable, Equatable {
        var url: URL
        var summary: BackupSummary
        var fileSize: Int
        var id: String { url.lastPathComponent }
    }

    let directory: URL

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// The app's library. Makes the folder if it is not there.
    static func app(fileManager: FileManager = .default) throws -> BackupLibrary {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try BackupLibrary(directory: support.appendingPathComponent("Backups", isDirectory: true))
    }

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Keeps a copy of a backup: a new export, or a file from the file picker.
    /// The same file a second time does not make a second row.
    @discardableResult
    func add(_ data: Data) throws -> Entry {
        let summary = try BackupSummary.read(data)
        let base = Self.fileStem(for: summary.exportedAt)
        var index = 1
        while true {
            let name = index == 1 ? "\(base).json" : "\(base)-\(index).json"
            let url = directory.appendingPathComponent(name)
            if let existing = try? Data(contentsOf: url) {
                if existing == data { return Entry(url: url, summary: summary, fileSize: data.count) }
                index += 1
                continue
            }
            try data.write(to: url, options: .atomic)
            return Entry(url: url, summary: summary, fileSize: data.count)
        }
    }

    /// Newest first. A file that R3hab cannot read is not in the list.
    func entries() -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let summary = try? BackupSummary.read(data) else { return nil }
                return Entry(url: url, summary: summary, fileSize: data.count)
            }
            .sorted { a, b in
                if a.summary.exportedAt != b.summary.exportedAt {
                    return a.summary.exportedAt > b.summary.exportedAt
                }
                return a.id > b.id
            }
    }

    func data(for entry: Entry) throws -> Data {
        try Data(contentsOf: entry.url)
    }

    func delete(_ entry: Entry) throws {
        try FileManager.default.removeItem(at: entry.url)
    }

    /// "R3hab-backup-20261004T213512Z". UTC, so the name does not change with the time zone.
    static func fileStem(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "R3hab-backup-%04d%02d%02dT%02d%02d%02dZ",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0
        )
    }
}

/// Backup list text. ASD-STE100: short sentences, one instruction each.
enum BackupCopy {
    static let listTitle = "Backups"
    static let emptyTitle = "No backups"
    static let emptyBody = "Export a backup in Settings. R3hab keeps a copy of each backup here."
    static let listFooter = "R3hab keeps each backup on this iPhone. R3hab does not send backups to a cloud service. Tap a backup to restore it. To delete a backup, swipe left."
    static let restoreTitle = "Restore this backup?"
    static let restoreButton = "Restore"

    static func restoreMessage(_ summary: BackupSummary) -> String {
        "This replaces the current data. R3hab removes all current check-ins and sessions. "
            + "Then R3hab restores \(counts(summary)) and the settings from this backup. "
            + "You cannot undo this. To keep the current data, export a backup first."
    }

    static func restoredMessage(sessions: Int, checkIns: Int) -> String {
        "R3hab restored \(plural(sessions, "session")) and \(plural(checkIns, "check-in"))."
    }

    /// "3 sessions, 14 check-ins"
    static func counts(_ summary: BackupSummary) -> String {
        "\(plural(summary.sessionCount, "session")), \(plural(summary.checkInCount, "check-in"))"
    }

    /// "Records from Sep 20, 2026 to Oct 4, 2026"
    static func range(_ summary: BackupSummary) -> String {
        guard let first = summary.firstDay, let last = summary.lastDay else { return "No records" }
        let a = first.formatted(date: .abbreviated, time: .omitted)
        let b = last.formatted(date: .abbreviated, time: .omitted)
        return a == b ? "Records from \(a)" : "Records from \(a) to \(b)"
    }

    static func made(_ summary: BackupSummary) -> String {
        summary.exportedAt.formatted(date: .abbreviated, time: .shortened)
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n == 1 ? "" : "s")"
    }
}
