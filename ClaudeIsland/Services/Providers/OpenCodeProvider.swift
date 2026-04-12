//
//  OpenCodeProvider.swift
//  ClaudeIsland
//
//  Provider for OpenCode (opencode.ai).
//  Installs a JS plugin into ~/.config/opencode/plugins/ that sends events
//  to HookSocketServer via Unix socket.
//
//  OpenCode events used:
//    - session.status (busy/idle)  → phase changes
//    - session.idle               → session completed
//    - session.created            → new session
//    - tool.execute.before/after  → tool tracking
//    - chat.message               → chat content
//

import Foundation
import os.log

/// OpenCode provider — installs a plugin that sends events to our Unix socket.
final class OpenCodeProvider: AgentProvider, @unchecked Sendable {
    let providerType: AgentProviderType = .opencode
    private(set) var isCollecting = false

    private let logger = Logger(subsystem: "com.codeisland", category: "OpenCodeProvider")

    private var pluginPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode/plugins/mio-island.js")
    }

    private var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode")
    }

    func detectInstallation() async -> ProviderInstallationStatus {
        // Check for ~/.opencode/ (OpenCode home) or ~/.config/opencode/
        let opencodeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".opencode")
        if FileManager.default.fileExists(atPath: opencodeDir.path) ||
           FileManager.default.fileExists(atPath: configDir.path) {
            return .installed(version: nil)
        }
        return .notInstalled
    }

    func startCollecting() async throws {
        logger.info("Installing OpenCode plugin")
        try installPlugin()
        isCollecting = true
    }

    func stopCollecting() async {
        removePlugin()
        isCollecting = false
    }

    // MARK: - Plugin Installation

    private func installPlugin() throws {
        let pluginsDir = configDir.appendingPathComponent("plugins")
        try FileManager.default.createDirectory(
            at: pluginsDir,
            withIntermediateDirectories: true
        )

        // JS plugin that hooks into OpenCode's event system and sends to our Unix socket
        let pluginCode = """
        import { createConnection } from "net"

        const SOCKET_PATH = "/tmp/codeisland.sock"

        function send(state) {
          try {
            const sock = createConnection(SOCKET_PATH)
            sock.on("error", () => {})
            sock.write(JSON.stringify(state))
            sock.end()
          } catch (_) {}
        }

        export const MioIslandPlugin = async ({ project, directory }) => {
          const cwd = directory || process.cwd()
          let currentSessionId = null

          return {
            event: async ({ event }) => {
              const type = event.type
              const props = event.properties || {}

              if (type === "session.created") {
                currentSessionId = props.info?.id || null
                send({
                  session_id: currentSessionId || `opencode-${Date.now()}`,
                  cwd,
                  event: "SessionStart",
                  status: "waiting_for_input",
                  source: "opencode",
                  tool: null,
                  tool_input: null,
                  tool_use_id: null,
                  pid: process.pid,
                  tty: null,
                })
              }

              if (type === "session.status") {
                const sid = props.sessionID || currentSessionId || `opencode-${Date.now()}`
                currentSessionId = sid
                const status = props.status
                if (status?.type === "busy") {
                  send({
                    session_id: sid,
                    cwd,
                    event: "UserPromptSubmit",
                    status: "processing",
                    source: "opencode",
                    tool: null,
                    tool_input: null,
                    tool_use_id: null,
                    pid: process.pid,
                    tty: null,
                  })
                }
              }

              if (type === "session.idle") {
                const sid = props.sessionID || currentSessionId || `opencode-${Date.now()}`
                send({
                  session_id: sid,
                  cwd,
                  event: "Stop",
                  status: "waiting_for_input",
                  source: "opencode",
                  tool: null,
                  tool_input: null,
                  tool_use_id: null,
                  pid: process.pid,
                  tty: null,
                })
              }

              if (type === "session.deleted") {
                const sid = props.info?.id || currentSessionId
                if (sid) {
                  send({
                    session_id: sid,
                    cwd,
                    event: "SessionEnd",
                    status: "ended",
                    source: "opencode",
                    tool: null,
                    tool_input: null,
                    tool_use_id: null,
                    pid: process.pid,
                    tty: null,
                  })
                }
              }

              if (type === "permission.updated") {
                const sid = currentSessionId || `opencode-${Date.now()}`
                send({
                  session_id: sid,
                  cwd,
                  event: "PermissionRequest",
                  status: "waiting_for_approval",
                  source: "opencode",
                  tool: props.tool || "unknown",
                  tool_input: null,
                  tool_use_id: props.id || null,
                  pid: process.pid,
                  tty: null,
                })
              }
            },

            "tool.execute.before": async (input, output) => {
              const sid = input.sessionID || currentSessionId || `opencode-${Date.now()}`
              send({
                session_id: sid,
                cwd,
                event: "PreToolUse",
                status: "running_tool",
                source: "opencode",
                tool: input.tool,
                tool_input: output.args ? { command: JSON.stringify(output.args).substring(0, 500) } : null,
                tool_use_id: input.callID,
                pid: process.pid,
                tty: null,
              })
            },

            "tool.execute.after": async (input, output) => {
              const sid = input.sessionID || currentSessionId || `opencode-${Date.now()}`
              send({
                session_id: sid,
                cwd,
                event: "PostToolUse",
                status: "processing",
                source: "opencode",
                tool: input.tool,
                tool_input: null,
                tool_use_id: input.callID,
                pid: process.pid,
                tty: null,
              })
            },

            "chat.message": async (input, output) => {
              const sid = input.sessionID || currentSessionId || `opencode-${Date.now()}`
              const text = output.parts
                ?.filter(p => p.type === "text")
                .map(p => p.text)
                .join("\\n")
                .substring(0, 500)
              if (text) {
                send({
                  session_id: sid,
                  cwd,
                  event: "UserPromptSubmit",
                  status: "processing",
                  source: "opencode",
                  tool: null,
                  tool_input: null,
                  tool_use_id: null,
                  pid: process.pid,
                  tty: null,
                  message: text,
                })
              }
            },
          }
        }
        """
        try pluginCode.write(to: pluginPath, atomically: true, encoding: .utf8)

        // Register plugin in opencode.jsonc if not already registered
        registerInConfig()

        logger.info("OpenCode plugin installed at \(self.pluginPath.path, privacy: .public)")
    }

    /// Register the plugin in opencode.jsonc
    private func registerInConfig() {
        let configPath = configDir.appendingPathComponent("opencode.jsonc")
        guard FileManager.default.fileExists(atPath: configPath.path),
              var content = try? String(contentsOf: configPath, encoding: .utf8) else { return }

        // Check if already registered
        if content.contains("mio-island") { return }

        // Add to plugin array: find "plugin": [ and insert
        if let range = content.range(of: "\"plugin\": [") {
            let insertPos = content.index(range.upperBound, offsetBy: 0)
            content.insert(contentsOf: "\n    \"./plugins/mio-island.js\",", at: insertPos)
            try? content.write(to: configPath, atomically: true, encoding: .utf8)
            logger.info("Registered mio-island plugin in opencode.jsonc")
        }
    }

    private func removePlugin() {
        do {
            if FileManager.default.fileExists(atPath: pluginPath.path) {
                try FileManager.default.removeItem(at: pluginPath)
                logger.info("OpenCode plugin removed")
            }
        } catch {
            logger.error("Failed to remove OpenCode plugin: \(error.localizedDescription, privacy: .public)")
        }
    }
}
