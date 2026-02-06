import Foundation
import PackagePlugin

@main
struct SwiftFormatLintPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            return []
        }

        let xcrunPath = "/usr/bin/xcrun"
        if !FileManager.default.isExecutableFile(atPath: xcrunPath) {
            return []
        }

        let configPath = context.package.directory.appending(".swift-format")
        let outputDirectory = context.pluginWorkDirectory.appending(target.name)

        let arguments = [
            "swift-format",
            "lint",
            "--configuration",
            configPath.string,
            "--strict",
            "--recursive",
            target.directory.string
        ]

        return [
            .prebuildCommand(
                displayName: "SwiftFormat lint (\(target.name))",
                executable: Path(xcrunPath),
                arguments: arguments,
                outputFilesDirectory: outputDirectory)
        ]
    }
}
