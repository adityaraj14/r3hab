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
                "Domain/DomainSnapshots.swift",
                "Domain/ChartAggregates.swift",
                "Domain/ProgressInterpretation.swift",
                "Domain/DecisionSuggester.swift",
                "Domain/SessionEditorChrome.swift",
                "Domain/ProgressionEngine.swift",
                "Domain/TodayPlanner.swift",
                "Domain/TodaySessionEntry.swift"
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
                "TodaySessionEntryTests.swift",
                "QLPathwayTests.swift"
            ]
        )
    ]
)
