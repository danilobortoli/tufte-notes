// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TufteNotes",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "TufteNotes",
            path: "TufteNotes",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
