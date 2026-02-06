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

        let configPath = context.package.directoryURL.appending(path: ".swift-format")
        let outputDirectory = context.pluginWorkDirectoryURL.appending(path: target.name)

        let script = """
        set -euo pipefail
        cd '\(escapeShell(target.directoryURL.path(percentEncoded: false)))'
        '\(escapeShell(swiftFormatPath.path(percentEncoded: false)))' lint \
          --configuration '\(escapeShell(configPath.path(percentEncoded: false)))' \
          --strict \
          --recursive \
          .
        """

        return [
            .prebuildCommand(
                displayName: "SwiftFormat lint (\(target.name))",
                executable: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-lc", script],
                outputFilesDirectory: outputDirectory)
        ]
    }
}

private func escapeShell(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "'\"'\"'")
}

private func resolveExecutable(named tool: String) -> URL? {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else {
        return nil
    }

    for directory in path.split(separator: ":") {
        let candidate = URL(fileURLWithPath: String(directory))
            .appending(path: tool)
        if FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) {
            return candidate
        }
    }

    return nil
}
