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
                "Models/PrimaryLoadCatalog.swift",
                "Domain/DomainSnapshots.swift",
                "Domain/DecisionSuggester.swift",
                "Domain/ProgressionEngine.swift"
            ]
        ),
        .testTarget(
            name: "R3habDomainTests",
            dependencies: ["R3habDomain"],
            path: "Tests/R3habTests",
            sources: ["ProgressionEngineTests.swift"]
        )
    ]
)
