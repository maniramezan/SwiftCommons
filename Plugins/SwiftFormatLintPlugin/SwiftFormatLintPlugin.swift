import Foundation
import PackagePlugin

@main
struct SwiftFormatLintPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            return []
        }

        guard let swiftFormatPath = resolveExecutable(named: "swift-format") else {
            return []
        }

        let configPath = context.package.directory.appending(".swift-format")
        let outputDirectory = context.pluginWorkDirectory.appending(target.name)

        let arguments = [
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
                executable: swiftFormatPath,
                arguments: arguments,
                outputFilesDirectory: outputDirectory)
        ]
    }
}

private func resolveExecutable(named tool: String) -> Path? {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else {
        return nil
    }

    for directory in path.split(separator: ":") {
        let candidate = URL(fileURLWithPath: String(directory))
            .appendingPathComponent(tool)
            .path
        if FileManager.default.isExecutableFile(atPath: candidate) {
            return Path(candidate)
        }
    }

    return nil
}
