//
//  MessageRelay.swift
//  ClaudeIsland
//
//  Bridges SessionStore events to CodeLight Server.
//  Subscribes to session state changes and relays them upstream.
//

import Combine
import Foundation
import os.log

/// Relays session events from SessionStore to the CodeLight Server.
@MainActor
final class MessageRelay {

    static let logger = Logger(subsystem: "com.codeisland", category: "MessageRelay")

    private let connection: ServerConnection
    private var cancellables = Set<AnyCancellable>()
    private var aliveTimers: [String: Timer] = [:]
    private var knownSessionIds = Set<String>()

    init(connection: ServerConnection) {
        self.connection = connection
    }

    /// Start relaying session events to the server.
    /// Call after server connection is established.
    func startRelaying() {
        SessionStore.shared.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.handleSessionsUpdate(sessions)
            }
            .store(in: &cancellables)

        Self.logger.info("Message relay started")
    }

    func stopRelaying() {
        cancellables.removeAll()
        aliveTimers.values.forEach { $0.invalidate() }
        aliveTimers.removeAll()
        Self.logger.info("Message relay stopped")
    }

    // MARK: - Session State Processing

    private func handleSessionsUpdate(_ sessions: [SessionState]) {
        for session in sessions {
            let sessionId = session.sessionId

            // New session detected — create on server
            if !knownSessionIds.contains(sessionId) {
                knownSessionIds.insert(sessionId)
                Task { await createServerSession(session) }
                startAliveTimer(for: sessionId)
            }

            // Relay status based on phase
            relaySessionStatus(session)

            // Handle ended sessions
            if session.phase == .ended {
                connection.sendSessionEnd(sessionId: sessionId)
                stopAliveTimer(for: sessionId)
                knownSessionIds.remove(sessionId)
            }
        }

        // Clean up sessions that disappeared
        let activeIds = Set(sessions.map(\.sessionId))
        for id in knownSessionIds.subtracting(activeIds) {
            connection.sendSessionEnd(sessionId: id)
            stopAliveTimer(for: id)
            knownSessionIds.remove(id)
        }
    }

    private func relaySessionStatus(_ session: SessionState) {
        // Build metadata from current session state
        let metadata: [String: Any] = [
            "path": session.cwd,
            "title": session.projectName,
            "phase": session.phase.rawValue,
            "toolName": session.toolTracker.currentToolName ?? "",
        ]

        guard let metadataJson = try? JSONSerialization.data(withJSONObject: metadata),
              let metadataString = String(data: metadataJson, encoding: .utf8) else { return }

        // Send as metadata update (version 0 = always overwrite for now)
        connection.updateMetadata(sessionId: session.sessionId, metadata: metadataString, expectedVersion: 0)
    }

    // MARK: - Server Session Management

    private func createServerSession(_ session: SessionState) async {
        let metadata: [String: Any] = [
            "path": session.cwd,
            "title": session.projectName,
        ]

        guard let metadataJson = try? JSONSerialization.data(withJSONObject: metadata),
              let metadataString = String(data: metadataJson, encoding: .utf8) else { return }

        do {
            _ = try await connection.createSession(
                tag: session.sessionId,
                metadata: metadataString
            )
            Self.logger.info("Created server session for \(session.sessionId)")
        } catch {
            Self.logger.error("Failed to create server session: \(error)")
        }
    }

    // MARK: - Alive Timer

    private func startAliveTimer(for sessionId: String) {
        stopAliveTimer(for: sessionId)
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.connection.sendAlive(sessionId: sessionId)
        }
        aliveTimers[sessionId] = timer
    }

    private func stopAliveTimer(for sessionId: String) {
        aliveTimers[sessionId]?.invalidate()
        aliveTimers.removeValue(forKey: sessionId)
    }
}
