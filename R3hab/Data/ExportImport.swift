import Foundation
import SwiftData
import UniformTypeIdentifiers

enum ExportImportError: LocalizedError {
    case unsupportedSchema(Int)
    case decodeFailed
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let v):
            return "Unsupported backup version \(v). Update the app."
        case .decodeFailed:
            return "Could not read this backup file."
        case .emptyFile:
            return "Backup file is empty."
        }
    }
}

enum ImportMode: String, CaseIterable, Identifiable {
    case replace
    case merge
    var id: String { rawValue }
    var title: String { self == .replace ? "Replace all data" : "Merge with existing" }
    var detail: String {
        switch self {
        case .replace: return "Wipes check-ins and sessions, then restores from the file."
        case .merge: return "Updates matching days/sessions; keeps local-only rows."
        }
    }
}

struct R3habBackupDTO: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var settings: SettingsDTO
    var dailyCheckIns: [DailyDTO]
    var trainingSessions: [SessionDTO]
}

struct SettingsDTO: Codable {
    var currentPhase: String
    var phaseChangedAt: Date
    var phaseAPainThreshold: Int
    var phaseAStableDaysRequired: Int
    var stepNearNormalMin: Int
    var stepBaselineTypical: Int
    var amReminderHour: Int
    var amReminderMinute: Int
    var pmReminderHour: Int
    var pmReminderMinute: Int
    var notificationsEnabled: Bool
    var protocolRevision: String
}

struct DailyDTO: Codable {
    var dayKey: String
    var date: Date
    var restingPainAM: Int?
    var morningStiffness: Int?
    var dailyPainPM: Int?
    var lowerBackPainAM: Int?
    var lowerBackPainPM: Int?
    var steps: Int?
    var phase: String
    var notes: String
    var declineSquatL: Int?
    var declineSquatR: Int?
}

struct SessionDTO: Codable {
    var id: UUID
    var date: Date
    var phase: String
    var type: String
    var whatIDid: String
    var painDuring: Int
    var painAfter: Int
    var sets: Int?
    var reps: Int?
    var loadKg: Double?
    var holdSeconds: Int?
    var response24h: String
    var decision: String?
    var notes: String
    var snoozedUntil: Date?
    var snoozeUsed: Bool
    var resolvedAt: Date?
    var createdAt: Date
}

enum ExportImportService {
    /// v2 adds lower-back AM/PM pain. v3 adds structured resistance (sets/reps/load/hold).
    static let schemaVersion = 3
    static let minimumSupportedSchemaVersion = 1
    static let utType = UTType.json

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @MainActor
    static func exportBackup(context: ModelContext) throws -> Data {
        let settings = try AppBootstrap.ensureSettings(context: context)
        let checkIns = try context.fetch(FetchDescriptor<DailyCheckIn>(sortBy: [SortDescriptor(\.date)]))
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>(sortBy: [SortDescriptor(\.date)]))

        let dto = R3habBackupDTO(
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            settings: SettingsDTO(
                currentPhase: settings.currentPhaseRaw,
                phaseChangedAt: settings.phaseChangedAt,
                phaseAPainThreshold: settings.phaseAPainThreshold,
                phaseAStableDaysRequired: settings.phaseAStableDaysRequired,
                stepNearNormalMin: settings.stepNearNormalMin,
                stepBaselineTypical: settings.stepBaselineTypical,
                amReminderHour: settings.amReminderHour,
                amReminderMinute: settings.amReminderMinute,
                pmReminderHour: settings.pmReminderHour,
                pmReminderMinute: settings.pmReminderMinute,
                notificationsEnabled: settings.notificationsEnabled,
                protocolRevision: settings.protocolRevision
            ),
            dailyCheckIns: checkIns.map {
                DailyDTO(
                    dayKey: $0.dayKey,
                    date: $0.date,
                    restingPainAM: $0.restingPainAM,
                    morningStiffness: $0.morningStiffness,
                    dailyPainPM: $0.dailyPainPM,
                    lowerBackPainAM: $0.lowerBackPainAM,
                    lowerBackPainPM: $0.lowerBackPainPM,
                    steps: $0.steps,
                    phase: $0.phaseRaw,
                    notes: $0.notes,
                    declineSquatL: $0.declineSquatL,
                    declineSquatR: $0.declineSquatR
                )
            },
            trainingSessions: sessions.map {
                SessionDTO(
                    id: $0.id,
                    date: $0.date,
                    phase: $0.phaseRaw,
                    type: $0.typeRaw,
                    whatIDid: $0.whatIDid,
                    painDuring: $0.painDuring,
                    painAfter: $0.painAfter,
                    sets: $0.sets,
                    reps: $0.reps,
                    loadKg: $0.loadKg,
                    holdSeconds: $0.holdSeconds,
                    response24h: $0.response24hRaw,
                    decision: $0.decisionRaw,
                    notes: $0.notes,
                    snoozedUntil: $0.snoozedUntil,
                    snoozeUsed: $0.snoozeUsed,
                    resolvedAt: $0.resolvedAt,
                    createdAt: $0.createdAt
                )
            }
        )
        return try makeEncoder().encode(dto)
    }

    @MainActor
    static func importBackup(data: Data, mode: ImportMode, context: ModelContext) throws {
        guard !data.isEmpty else { throw ExportImportError.emptyFile }
        let backup: R3habBackupDTO
        do {
            backup = try makeDecoder().decode(R3habBackupDTO.self, from: data)
        } catch {
            throw ExportImportError.decodeFailed
        }
        guard (minimumSupportedSchemaVersion...schemaVersion).contains(backup.schemaVersion) else {
            throw ExportImportError.unsupportedSchema(backup.schemaVersion)
        }

        let settings = try AppBootstrap.ensureSettings(context: context)
        applySettings(backup.settings, to: settings)

        switch mode {
        case .replace:
            try replaceAll(backup: backup, context: context)
        case .merge:
            try merge(backup: backup, context: context)
        }
        try context.save()
    }

    private static func applySettings(_ dto: SettingsDTO, to settings: AppSettings) {
        settings.currentPhaseRaw = dto.currentPhase
        settings.phaseChangedAt = dto.phaseChangedAt
        settings.phaseAPainThreshold = dto.phaseAPainThreshold
        settings.phaseAStableDaysRequired = dto.phaseAStableDaysRequired
        settings.stepNearNormalMin = dto.stepNearNormalMin
        settings.stepBaselineTypical = dto.stepBaselineTypical
        settings.amReminderHour = dto.amReminderHour
        settings.amReminderMinute = dto.amReminderMinute
        settings.pmReminderHour = dto.pmReminderHour
        settings.pmReminderMinute = dto.pmReminderMinute
        settings.notificationsEnabled = dto.notificationsEnabled
        settings.protocolRevision = dto.protocolRevision
    }

    private static func replaceAll(backup: R3habBackupDTO, context: ModelContext) throws {
        let existingDaily = try context.fetch(FetchDescriptor<DailyCheckIn>())
        let existingSessions = try context.fetch(FetchDescriptor<TrainingSession>())
        for d in existingDaily { context.delete(d) }
        for s in existingSessions { context.delete(s) }
        for d in backup.dailyCheckIns {
            context.insert(makeDaily(from: d))
        }
        for s in backup.trainingSessions {
            context.insert(makeSession(from: s))
        }
    }

    private static func merge(backup: R3habBackupDTO, context: ModelContext) throws {
        let existingDaily = try context.fetch(FetchDescriptor<DailyCheckIn>())
        var dailyByKey: [String: DailyCheckIn] = [:]
        for d in existingDaily { dailyByKey[d.dayKey] = d }

        for dto in backup.dailyCheckIns {
            if let local = dailyByKey[dto.dayKey] {
                updateDaily(local, from: dto)
            } else {
                context.insert(makeDaily(from: dto))
            }
        }

        let existingSessions = try context.fetch(FetchDescriptor<TrainingSession>())
        var sessionById: [UUID: TrainingSession] = [:]
        for s in existingSessions { sessionById[s.id] = s }

        for dto in backup.trainingSessions {
            if let local = sessionById[dto.id] {
                updateSession(local, from: dto)
            } else {
                context.insert(makeSession(from: dto))
            }
        }
    }

    private static func makeDaily(from dto: DailyDTO) -> DailyCheckIn {
        let row = DailyCheckIn(date: dto.date, phase: RehabPhase(rawValue: dto.phase) ?? .aFlareDeLoad)
        updateDaily(row, from: dto)
        return row
    }

    private static func updateDaily(_ row: DailyCheckIn, from dto: DailyDTO) {
        row.date = Calendar.current.startOfDay(for: dto.date)
        row.dayKey = dto.dayKey.isEmpty ? DailyCheckIn.dayKey(for: row.date) : dto.dayKey
        row.restingPainAM = dto.restingPainAM
        row.morningStiffness = dto.morningStiffness
        row.dailyPainPM = dto.dailyPainPM
        row.lowerBackPainAM = dto.lowerBackPainAM
        row.lowerBackPainPM = dto.lowerBackPainPM
        row.steps = dto.steps
        row.phaseRaw = dto.phase
        row.notes = dto.notes
        row.declineSquatL = dto.declineSquatL
        row.declineSquatR = dto.declineSquatR
        row.updatedAt = Date()
    }

    private static func makeSession(from dto: SessionDTO) -> TrainingSession {
        let s = TrainingSession(
            id: dto.id,
            date: dto.date,
            phase: RehabPhase(rawValue: dto.phase) ?? .aFlareDeLoad,
            sessionType: SessionType(rawValue: dto.type) ?? .other,
            whatIDid: dto.whatIDid,
            painDuring: dto.painDuring,
            painAfter: dto.painAfter
        )
        updateSession(s, from: dto)
        return s
    }

    private static func updateSession(_ s: TrainingSession, from dto: SessionDTO) {
        s.date = Calendar.current.startOfDay(for: dto.date)
        s.phaseRaw = dto.phase
        s.typeRaw = dto.type
        s.whatIDid = dto.whatIDid
        s.painDuring = dto.painDuring
        s.painAfter = dto.painAfter
        s.sets = dto.sets
        s.reps = dto.reps
        s.loadKg = dto.loadKg
        s.holdSeconds = dto.holdSeconds
        s.response24hRaw = dto.response24h
        s.decisionRaw = dto.decision
        s.notes = dto.notes
        s.snoozedUntil = dto.snoozedUntil
        s.snoozeUsed = dto.snoozeUsed
        s.resolvedAt = dto.resolvedAt
        s.createdAt = dto.createdAt
        s.updatedAt = Date()
    }
}
