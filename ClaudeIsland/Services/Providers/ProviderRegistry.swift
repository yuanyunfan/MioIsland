//
//  ProviderRegistry.swift
//  ClaudeIsland
//
//  Central registry for all AgentProviders.
//  Manages registration, auto-detection, and lifecycle of providers.
//

import Foundation
import os.log

/// Manages all registered AgentProviders and their lifecycles
@MainActor
final class ProviderRegistry {
    static let shared = ProviderRegistry()

    private let logger = Logger(subsystem: "com.codeisland", category: "Providers")
    private var providers: [AgentProviderType: AgentProvider] = [:]

    // MARK: - Registration

    /// Register a provider. Call this during app startup before `startAll()`.
    func register(_ provider: AgentProvider) {
        providers[provider.providerType] = provider
        logger.info("Registered provider: \(provider.providerType.displayName, privacy: .public)")
    }

    // MARK: - Lifecycle

    /// Detect installation status and start collecting for all installed providers.
    func startAll() async {
        for (type, provider) in providers {
            let status = await provider.detectInstallation()
            switch status {
            case .installed(let version):
                logger.info("Starting \(type.displayName, privacy: .public) (v\(version ?? "unknown", privacy: .public))")
                do {
                    try await provider.startCollecting()
                } catch {
                    logger.error("Failed to start \(type.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            case .notInstalled:
                logger.info("\(type.displayName, privacy: .public) not installed, skipping")
            case .unknown:
                logger.info("\(type.displayName, privacy: .public) status unknown, attempting start")
                do {
                    try await provider.startCollecting()
                } catch {
                    logger.debug("Could not start \(type.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// Stop all providers
    func stopAll() async {
        for (_, provider) in providers {
            await provider.stopCollecting()
        }
    }

    // MARK: - Queries

    /// Get a specific provider
    func provider(for type: AgentProviderType) -> AgentProvider? {
        providers[type]
    }

    /// All registered provider types
    var registeredTypes: [AgentProviderType] {
        Array(providers.keys).sorted { $0.rawValue < $1.rawValue }
    }

    /// Get status of all registered providers
    func allStatuses() async -> [(type: AgentProviderType, status: ProviderInstallationStatus, collecting: Bool)] {
        var result: [(type: AgentProviderType, status: ProviderInstallationStatus, collecting: Bool)] = []
        for (type, provider) in providers {
            let status = await provider.detectInstallation()
            result.append((type: type, status: status, collecting: provider.isCollecting))
        }
        return result.sorted { $0.type.rawValue < $1.type.rawValue }
    }
}
