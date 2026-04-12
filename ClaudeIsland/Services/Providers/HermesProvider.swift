//
//  HermesProvider.swift
//  ClaudeIsland
//
//  Provider for Hermes Agent (Nous Research).
//  Dual-mode collection:
//    1. Gateway Hook: installs a hook into ~/.hermes/hooks/mio-island/ that sends events
//       to HookSocketServer via Unix socket (same path as Claude Code).
//    2. (Future) SSE: subscribe to Hermes API Server at port 8642 for real-time events.
//

import Foundation
import os.log

/// Hermes Agent provider — installs a Gateway Hook that sends events to our Unix socket.
/// The hook runs inside the Hermes process and maps agent:start/step/end to HookEvent format.
final class HermesProvider: AgentProvider, @unchecked Sendable {
    let providerType: AgentProviderType = .hermes
    private(set) var isCollecting = false

    private let logger = Logger(subsystem: "com.codeisland", category: "HermesProvider")

    private var hookDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/hooks/mio-island")
    }

    private var hermesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes")
    }

    func detectInstallation() async -> ProviderInstallationStatus {
        if FileManager.default.fileExists(atPath: hermesDir.path) {
            return .installed(version: nil)
        }
        return .notInstalled
    }

    func startCollecting() async throws {
        logger.info("Installing Hermes Gateway Hook")
        try installGatewayHook()
        isCollecting = true
    }

    func stopCollecting() async {
        removeGatewayHook()
        isCollecting = false
    }

    // MARK: - Gateway Hook Installation

    /// Install a Gateway Hook that sends events to our Unix socket
    private func installGatewayHook() throws {
        try FileManager.default.createDirectory(
            at: hookDir,
            withIntermediateDirectories: true
        )

        // HOOK.yaml — declares which events we listen to
        let yaml = """
        name: mio-island
        description: MioIsland agent activity monitor
        events:
          - agent:start
          - agent:step
          - agent:end
          - session:start
          - session:end
        """
        try yaml.write(
            to: hookDir.appendingPathComponent("HOOK.yaml"),
            atomically: true,
            encoding: .utf8
        )

        // handler.py — maps Hermes events to our HookEvent format and sends via Unix socket
        let handler = """
        import json
        import socket
        import os
        import time
        import uuid

        SOCKET_PATH = "/tmp/codeisland.sock"

        EVENT_MAP = {
            "agent:start": ("UserPromptSubmit", "processing"),
            "agent:step":  ("PreToolUse", "running_tool"),
            "agent:end":   ("Stop", "waiting_for_input"),
            "session:start": ("SessionStart", "waiting_for_input"),
            "session:end":   ("SessionEnd", "ended"),
        }


        def _send(state):
            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.settimeout(2)
                sock.connect(SOCKET_PATH)
                sock.sendall(json.dumps(state).encode("utf-8"))
                sock.close()
            except Exception:
                pass


        async def handle(event_type, context):
            mapped = EVENT_MAP.get(event_type)
            if not mapped:
                return

            event_name, status = mapped

            session_id = context.get("session_id") or f"hermes-{os.getpid()}-{int(time.time())}"
            cwd = context.get("cwd") or os.environ.get("MESSAGING_CWD") or os.getcwd()

            tool_name = None
            tool_input = None
            if event_type == "agent:step":
                tool_names = context.get("tool_names", [])
                tools = context.get("tools", [])
                if tool_names:
                    tool_name = tool_names[0]
                # Extract tool input parameters for richer display
                if tools and isinstance(tools[0], dict):
                    tool_data = tools[0]
                    tool_input = {}
                    # Extract input parameters (command, file_path, pattern, etc.)
                    inp = tool_data.get("input", {})
                    if isinstance(inp, dict):
                        for k in ("command", "description", "file_path", "path",
                                  "pattern", "query", "url", "content", "old_string",
                                  "new_string", "skill"):
                            v = inp.get(k)
                            if v:
                                tool_input[k] = str(v)[:500]
                    # Also include result if available (for completed tools)
                    result = tool_data.get("result", "")
                    if result:
                        tool_input["result"] = str(result)[:500]

            state = {
                "session_id": session_id,
                "cwd": cwd,
                "event": event_name,
                "status": status,
                "source": "hermes",
                "tool": tool_name,
                "tool_input": tool_input,
                "tool_use_id": str(uuid.uuid4())[:12] if tool_name else None,
                "pid": None,
                "tty": None,
                "message": context.get("message", "")[:500] if event_type == "agent:start" else
                           context.get("response", "")[:500] if event_type == "agent:end" else None,
            }

            _send(state)
        """
        try handler.write(
            to: hookDir.appendingPathComponent("handler.py"),
            atomically: true,
            encoding: .utf8
        )

        logger.info("Hermes Gateway Hook installed at \(self.hookDir.path, privacy: .public)")
    }

    /// Remove the Gateway Hook
    private func removeGatewayHook() {
        do {
            if FileManager.default.fileExists(atPath: hookDir.path) {
                try FileManager.default.removeItem(at: hookDir)
                logger.info("Hermes Gateway Hook removed")
            }
        } catch {
            logger.error("Failed to remove Hermes hook: \(error.localizedDescription, privacy: .public)")
        }
    }
}
