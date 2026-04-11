//
//  CodexProvider.swift
//  ClaudeIsland
//
//  Provider for OpenAI Codex CLI.
//  Wraps existing CodexHookInstallationManager — installs hooks into ~/.codex/hooks.json.
//  Events arrive via the same HookSocketServer as Claude Code (shared codeisland-state.py script).
//

import Foundation
import os.log

/// OpenAI Codex provider — uses hook scripts installed into ~/.codex/hooks.json.
/// The Python hook script (codeisland-state.py) auto-detects Codex via parent process name
/// and sets source="codex" in the HookEvent, which SessionStore uses for provider routing.
final class CodexProvider: AgentProvider, @unchecked Sendable {
    let providerType: AgentProviderType = .codex
    private(set) var isCollecting = false

    private let logger = Logger(subsystem: "com.codeisland", category: "CodexProvider")
    private let installManager = CodexHookInstallationManager()

    func detectInstallation() async -> ProviderInstallationStatus {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        if FileManager.default.fileExists(atPath: codexDir.path) {
            return .installed(version: nil)
        }
        return .notInstalled
    }

    func startCollecting() async throws {
        // Get the hook script path from the Claude Code installation
        let hookScriptPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/hooks/codeisland-state.py").path

        guard FileManager.default.fileExists(atPath: hookScriptPath) else {
            logger.warning("Hook script not found at \(hookScriptPath, privacy: .public), Claude Code provider must start first")
            return
        }

        logger.info("Installing Codex hooks")
        do {
            try installManager.install(hookScriptPath: hookScriptPath)
            isCollecting = true
        } catch {
            logger.error("Failed to install Codex hooks: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func stopCollecting() async {
        do {
            try installManager.uninstall()
        } catch {
            logger.error("Failed to uninstall Codex hooks: \(error.localizedDescription, privacy: .public)")
        }
        isCollecting = false
    }
}
