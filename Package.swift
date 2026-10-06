// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CommentsPluginCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CommentsPluginCore",
            path: "CommentsPluginExtension",
            exclude: ["SourceEditorCommand.swift", "SourceEditorExtension.swift",
                      "Info.plist", "CommentsPluginExtension.entitlements"],
            sources: ["CommentToggle.swift"]
        ),
        .testTarget(name: "CommentsPluginCoreTests", dependencies: ["CommentsPluginCore"])
    ],
    swiftLanguageModes: [.v5]
)
