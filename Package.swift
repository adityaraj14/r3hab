// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "R3habDomain",
    platforms: [
        .macOS(.v13)
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
                "Features/Session/SessionPresets.swift",
                "Features/Session/Prototypes/SessionPrototypePlan.swift",
                "Features/Session/Prototypes/GuidedCheckpoint.swift",
                "Domain/DomainSnapshots.swift",
                "Domain/ChartAggregates.swift",
                "Domain/ProgressInterpretation.swift",
                "Domain/DecisionSuggester.swift",
                "Domain/SessionEditorChrome.swift",
                "Domain/ProgressionEngine.swift",
                "Domain/WarmupPlan.swift",
                "Domain/TodayPlanner.swift",
                "Domain/TodaySessionEntry.swift",
                "Domain/PendingQueue.swift",
                "Domain/SessionSpacing.swift",
                "Domain/WorkoutStreak.swift",
                "Domain/NotificationRoute.swift",
                "Domain/IncompleteRecords.swift"
            ]
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
                "SessionEditorChromeTests.swift",
                "SessionPrototypePlanTests.swift",
                "WarmupPlanTests.swift",
                "TodaySessionEntryTests.swift",
                "QLPathwayTests.swift",
                "GuidedCheckpointTests.swift",
                "SessionCompletionTests.swift",
                "NotificationRouteTests.swift",
                "TodayResolvePromptTests.swift",
                "IncompleteRecordsTests.swift"
            ]
        )
    ]
)
