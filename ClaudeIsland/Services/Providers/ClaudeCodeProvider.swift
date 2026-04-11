//
//  ClaudeCodeProvider.swift
//  ClaudeIsland
//
//  Provider for Claude Code (Anthropic).
//  Wraps existing HookInstaller + HookSocketServer — no new logic, just lifecycle management.
//

import Foundation
import os.log

/// Claude Code provider — uses hook scripts installed into ~/.claude/settings.json.
/// Events arrive via HookSocketServer (Unix socket) which already calls SessionStore.
final class ClaudeCodeProvider: AgentProvider, @unchecked Sendable {
    let providerType: AgentProviderType = .claudeCode
    private(set) var isCollecting = false

    private let logger = Logger(subsystem: "com.codeisland", category: "ClaudeCodeProvider")

    func detectInstallation() async -> ProviderInstallationStatus {
        // Check if 'claude' binary exists in PATH
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        if FileManager.default.fileExists(atPath: claudeDir.path) {
            return .installed(version: nil)
        }
        return .notInstalled
    }

    func startCollecting() async throws {
        logger.info("Installing Claude Code hooks")
        HookInstaller.installIfNeeded()
        // HookSocketServer is already running (started in AppDelegate)
        // and routes events to SessionStore.process(.hookReceived)
        isCollecting = true
    }

    func stopCollecting() async {
        isCollecting = false
    }
}
