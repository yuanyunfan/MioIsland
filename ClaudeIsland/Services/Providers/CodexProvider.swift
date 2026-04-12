//
//  CodexProvider.swift
//  ClaudeIsland
//
//  Provider for OpenAI Codex CLI.
//  Uses CodexHookInstaller to install hooks into ~/.codex/hooks.json.
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

    func detectInstallation() async -> ProviderInstallationStatus {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        if FileManager.default.fileExists(atPath: codexDir.path) {
            return .installed(version: nil)
        }
        return .notInstalled
    }

    func startCollecting() async throws {
        logger.info("Installing Codex hooks via CodexHookInstaller")
        CodexHookInstaller.installIfNeeded()
        isCollecting = CodexHookInstaller.isInstalled()
        if isCollecting {
            logger.info("Codex hooks installed successfully")
        } else {
            logger.warning("Codex hooks installation may have failed")
        }
    }

    func stopCollecting() async {
        CodexHookInstaller.uninstall()
        isCollecting = false
        logger.info("Codex hooks uninstalled")
    }
}
