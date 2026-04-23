//
//  AgentProvider.swift
//  ClaudeIsland
//
//  Protocol defining the interface for AI agent event collection.
//  Implement this protocol to add support for a new AI coding tool.
//
//  To add a new provider:
//  1. Add a case to AgentProviderType
//  2. Create a class conforming to AgentProvider
//  3. Register it in ProviderRegistry (AppDelegate)
//

import Foundation
import os.log

// MARK: - Installation Status

/// Whether a provider's underlying tool is installed on this machine
enum ProviderInstallationStatus: Sendable {
    case installed(version: String?)
    case notInstalled
    case unknown
}

// MARK: - Provider Protocol

/// Unified interface for all AI agent event collection.
///
/// Each provider is responsible for:
/// 1. Detecting whether its tool is installed
/// 2. Installing/uninstalling its listening mechanism (hooks, SSE, etc.)
/// 3. Converting tool-specific events into `HookEvent` and submitting to SessionStore
///
/// The provider does NOT need to manage SessionState — that's SessionStore's job.
/// All events flow through the existing `SessionStore.process(.hookReceived(event))` path.
protocol AgentProvider: AnyObject, Sendable {
    /// Provider type identifier
    var providerType: AgentProviderType { get }

    /// Whether this provider is currently collecting events
    var isCollecting: Bool { get }

    /// Check if the underlying tool is installed on this machine
    func detectInstallation() async -> ProviderInstallationStatus

    /// Start collecting events (install hooks / connect SSE / start polling)
    func startCollecting() async throws

    /// Stop collecting events (uninstall hooks / disconnect)
    func stopCollecting() async
}

// MARK: - Default Event Submission

extension AgentProvider {
    /// Static configuration for this provider (forwarded from the enum).
    /// Default implementation means provider classes don't have to re-declare it.
    var metadata: ProviderMetadata { providerType.metadata }

    /// Submit a HookEvent to SessionStore — the unified path for all providers.
    /// Providers construct a HookEvent with their `source` field set, then call this.
    func submitEvent(_ event: HookEvent) async {
        await SessionStore.shared.process(.hookReceived(event))
    }
}
