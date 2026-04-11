//
//  CrushProvider.swift
//  ClaudeIsland
//
//  Provider for Crush (formerly OpenCode) by Charm.
//  Collects events via SSE subscription to Crush's built-in HTTP API over Unix socket.
//
//  Crush exposes: /tmp/crush-{uid}.sock
//    GET /v1/workspaces                     → list workspaces
//    GET /v1/workspaces/{id}/events         → SSE event stream
//    GET /v1/workspaces/{id}/agent          → agent status
//

import Foundation
import os.log

/// Crush provider — discovers running Crush instances and subscribes to their SSE event streams.
final class CrushProvider: AgentProvider, @unchecked Sendable {
    let providerType: AgentProviderType = .crush
    private(set) var isCollecting = false

    private let logger = Logger(subsystem: "com.codeisland", category: "CrushProvider")
    private var sseClients: [String: SSEClient] = [:]  // socketPath → client
    private var discoveryTimer: DispatchSourceTimer?
    private let discoveryQueue = DispatchQueue(label: "com.codeisland.crush.discovery")

    func detectInstallation() async -> ProviderInstallationStatus {
        // Check if crush binary exists by looking for config dir
        let crushDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".crush")
        if FileManager.default.fileExists(atPath: crushDir.path) {
            return .installed(version: nil)
        }
        // Also check for any existing sockets
        if !findCrushSockets().isEmpty {
            return .installed(version: nil)
        }
        return .notInstalled
    }

    func startCollecting() async throws {
        logger.info("Starting Crush event collection")
        startDiscovery()
        isCollecting = true
    }

    func stopCollecting() async {
        discoveryTimer?.cancel()
        discoveryTimer = nil
        for (_, client) in sseClients {
            client.disconnect()
        }
        sseClients.removeAll()
        isCollecting = false
    }

    // MARK: - Instance Discovery

    /// Periodically scan /tmp/ for crush-*.sock files
    private func startDiscovery() {
        // Initial scan
        scanForInstances()

        // Schedule periodic re-scan every 5 seconds
        let timer = DispatchSource.makeTimerSource(queue: discoveryQueue)
        timer.schedule(deadline: .now() + 5, repeating: 5.0)
        timer.setEventHandler { [weak self] in
            self?.scanForInstances()
        }
        timer.resume()
        discoveryTimer = timer
    }

    private func scanForInstances() {
        let sockets = findCrushSockets()

        // Connect to new sockets
        for socketPath in sockets {
            guard sseClients[socketPath] == nil else { continue }
            logger.info("Discovered Crush instance: \(socketPath, privacy: .public)")
            connectToInstance(socketPath: socketPath)
        }

        // Clean up stale connections
        let staleKeys = sseClients.keys.filter { !sockets.contains($0) }
        for key in staleKeys {
            logger.info("Crush instance gone: \(key, privacy: .public)")
            sseClients[key]?.disconnect()
            sseClients.removeValue(forKey: key)
        }
    }

    private func findCrushSockets() -> [String] {
        let uid = getuid()
        let pattern = "/tmp/crush-\(uid).sock"
        if FileManager.default.fileExists(atPath: pattern) {
            return [pattern]
        }
        // Also scan for any crush-*.sock
        let tmpDir = "/tmp"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: tmpDir) else { return [] }
        return contents
            .filter { $0.hasPrefix("crush-") && $0.hasSuffix(".sock") }
            .map { "\(tmpDir)/\($0)" }
    }

    // MARK: - SSE Connection

    private func connectToInstance(socketPath: String) {
        // First, get the list of workspaces, then subscribe to each
        // For simplicity, subscribe to the default workspace events
        let client = SSEClient(
            target: .unixSocket(path: socketPath, urlPath: "/v1/workspaces/default/events"),
            logger: Logger(subsystem: "com.codeisland", category: "CrushSSE")
        )

        client.onEvent = { [weak self] eventType, data in
            self?.handleCrushEvent(socketPath: socketPath, eventType: eventType, data: data)
        }

        client.onDisconnect = { [weak self] in
            self?.logger.info("Crush SSE disconnected: \(socketPath, privacy: .public)")
        }

        client.connect()
        sseClients[socketPath] = client
    }

    // MARK: - Event Mapping

    /// Map Crush SSE events to HookEvent for SessionStore
    private func handleCrushEvent(socketPath: String, eventType: String, data: String) {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }

        // Extract common fields
        let payloadType = json["type"] as? String ?? eventType
        let payload = json["payload"] as? [String: Any] ?? json

        // Map Crush events to HookEvent
        let mapped = mapCrushEvent(payloadType: payloadType, payload: payload, socketPath: socketPath)
        guard let hookEvent = mapped else { return }

        Task { await submitEvent(hookEvent) }
    }

    private func mapCrushEvent(payloadType: String, payload: [String: Any], socketPath: String) -> HookEvent? {
        // Generate a stable session ID from the socket path
        let sessionId = "crush-\(socketPath.hashValue)"
        let cwd = payload["cwd"] as? String
            ?? payload["path"] as? String
            ?? FileManager.default.currentDirectoryPath

        switch payloadType {
        // Agent lifecycle events
        case "agent_event":
            let state = payload["state"] as? String ?? ""
            switch state {
            case "busy":
                return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "UserPromptSubmit", status: "processing")
            case "ready", "idle":
                return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "Stop", status: "waiting_for_input")
            case "completed":
                return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "Stop", status: "waiting_for_input")
            default:
                return nil
            }

        // Session events
        case "session":
            let action = payload["action"] as? String ?? ""
            switch action {
            case "created":
                return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "SessionStart", status: "waiting_for_input")
            case "deleted":
                return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "SessionEnd", status: "ended")
            default:
                return nil
            }

        // Message events (tool calls)
        case "message":
            let action = payload["action"] as? String ?? ""
            let parts = payload["parts"] as? [[String: Any]] ?? []
            for part in parts {
                let partType = part["type"] as? String ?? ""
                if partType == "tool_call" {
                    let toolName = part["name"] as? String ?? "unknown"
                    let toolId = part["id"] as? String ?? UUID().uuidString
                    if action == "created" {
                        return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "PreToolUse", status: "running_tool", tool: toolName, toolUseId: toolId)
                    } else if action == "updated" {
                        return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "PostToolUse", status: "processing", tool: toolName, toolUseId: toolId)
                    }
                }
            }
            return nil

        // Permission events
        case "permission_request":
            let toolName = payload["tool_name"] as? String ?? "unknown"
            let toolId = payload["id"] as? String ?? UUID().uuidString
            return makeHookEvent(sessionId: sessionId, cwd: cwd, event: "PermissionRequest", status: "waiting_for_approval", tool: toolName, toolUseId: toolId)

        default:
            return nil
        }
    }

    private func makeHookEvent(
        sessionId: String,
        cwd: String,
        event: String,
        status: String,
        tool: String? = nil,
        toolUseId: String? = nil
    ) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: cwd,
            event: event,
            status: status,
            pid: nil,
            tty: nil,
            tool: tool,
            toolInput: nil,
            toolUseId: toolUseId,
            notificationType: nil,
            message: nil,
            source: "crush"
        )
    }
}
