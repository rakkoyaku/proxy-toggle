import Foundation
import ServiceManagement

/// Run-at-logon support.
///
/// macOS 13+ has `SMAppService`, which registers the bundle itself and surfaces it in
/// System Settings › General › Login Items — the behaviour users expect. macOS 12 has no
/// such API, and even on 13+ registration can be refused, so a LaunchAgent plist in
/// ~/Library/LaunchAgents is kept as the fallback.
enum LoginItem {

    enum State {
        case disabled
        case enabled
        /// Registered, but the user still has to approve it in System Settings.
        case requiresApproval
    }

    enum Failure: LocalizedError {
        case launchAgent(String)

        var errorDescription: String? {
            switch self {
            case .launchAgent(let detail): return detail
            }
        }
    }

    private static let agentLabel = "local.proxytoggle.agent"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    private static var hasAgent: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    static var state: State {
        if hasAgent { return .enabled }
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled: return .enabled
            case .requiresApproval: return .requiresApproval
            default: return .disabled
            }
        }
        return .disabled
    }

    static func toggle() throws {
        if state == .disabled { try enable() } else { try disable() }
    }

    static func enable() throws {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                return
            } catch {
                // Fall through to the LaunchAgent below rather than leaving the user
                // with no way to start at logon.
            }
        }
        try writeAgent()
    }

    static func disable() throws {
        if #available(macOS 13.0, *), SMAppService.mainApp.status != .notRegistered {
            try? SMAppService.mainApp.unregister()
        }
        if hasAgent {
            try FileManager.default.removeItem(at: agentURL)
        }
    }

    /// Writes the plist only. Deliberately no `launchctl bootstrap`: the agent exists to
    /// start the app at the *next* login, and bootstrapping it now would spawn a second
    /// instance alongside the one the user is already looking at.
    private static func writeAgent() throws {
        guard let executable = Bundle.main.executableURL?.path else {
            throw Failure.launchAgent("実行ファイルのパスを取得できませんでした。")
        }

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
        ]

        let directory = agentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                      format: .xml,
                                                      options: 0)
        try data.write(to: agentURL, options: .atomic)
    }
}
