// swift-tools-version: 5.9
import PackageDescription

// SwiftData ships with the Apple SDK. The Linux domain build omits those files
// and the one test that opens a store. The iOS target still compiles them.
#if os(Linux)
let persistenceSources: [String] = []
let roundTripTests: [String] = []
#else
let persistenceSources = [
    "Models/AppSettings.swift",
    "Models/DailyCheckIn.swift",
    "Models/TrainingSession.swift",
    "Data/ModelMapping.swift",
    "Data/AppBootstrap.swift",
    "Data/ExportImport.swift",
]
let roundTripTests = ["BackupRestoreRoundTripTests.swift"]
#endif

let package = Package(
    name: "R3habDomain",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "R3habDomain", targets: ["R3habDomain"])
    ],
    targets: [
        .target(
            name: "R3habDomain",
            path: "R3hab",
            sources: [
                "Models/RehabEnums.swift",
                "Models/ResistanceSet.swift",
                "Models/InjuryCatalog.swift",
                "Models/PrimaryLoadCatalog.swift",
                "Data/BackupLibrary.swift",
                "Features/Session/SessionPresets.swift",
                "Features/Session/Prototypes/SessionPrototypePlan.swift",
                "Features/Session/Prototypes/GuidedCheckpoint.swift",
                "Domain/DomainSnapshots.swift",
                "Domain/ChartAggregates.swift",
                "Domain/ProgressInterpretation.swift",
                "Domain/DecisionSuggester.swift",
                "Domain/SessionEditorChrome.swift",
                "Domain/ProgressionEngine.swift",
                "Domain/TwelveWeekPlan.swift",
                "Domain/PlanSchedule.swift",
                "Domain/WarmupPlan.swift",
                "Domain/TodayPlanner.swift",
                "Domain/TodaySessionEntry.swift",
                "Domain/PendingQueue.swift",
                "Domain/SessionSpacing.swift",
                "Domain/WorkoutStreak.swift",
                "Domain/NotificationRoute.swift",
                "Domain/SessionUpsert.swift",
                "Domain/IncompleteRecords.swift"
            ] + persistenceSources
        ),
        .testTarget(
            name: "R3habDomainTests",
            dependencies: ["R3habDomain"],
            path: "Tests/R3habTests",
            sources: [
                "ChartAggregatesTests.swift",
                "DecisionSuggesterTests.swift",
                "ProgressInterpretationTests.swift",
                "ProgressionEngineTests.swift",
                "TwelveWeekPlanTests.swift",
                "PlanScheduleTests.swift",
                "SessionEditorChromeTests.swift",
                "SessionPrototypePlanTests.swift",
                "WarmupPlanTests.swift",
                "TodaySessionEntryTests.swift",
                "QLPathwayTests.swift",
                "GuidedCheckpointTests.swift",
                "SessionCompletionTests.swift",
                "NotificationRouteTests.swift",
                "TodayResolvePromptTests.swift",
                "BackupLibraryTests.swift",
                "TodayEveningPromptTests.swift",
                "SessionUpsertTests.swift",
                "IncompleteRecordsTests.swift",
                "MorningPainTests.swift"
            ] + roundTripTests
        )
    ]
)
