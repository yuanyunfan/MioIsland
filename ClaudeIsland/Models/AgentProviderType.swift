//
//  AgentProviderType.swift
//  ClaudeIsland
//
//  Identifies which AI agent tool a session belongs to.
//  Adding a new provider only requires a new case here + a Provider implementation.
//

import Foundation

/// All supported AI agent provider types
enum AgentProviderType: String, Codable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex = "codex"
    case opencode = "opencode"
    case hermes = "hermes"

    /// User-visible display name
    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .hermes: "Hermes"
        }
    }

    /// Whether this provider uses file-based chat history sync (JSONL parsing)
    var usesFileSync: Bool {
        switch self {
        case .claudeCode: true
        case .codex: true   // Codex uses its own rollout JSONL
        case .opencode: false  // Plugin pushes events directly
        case .hermes: false
        }
    }

    /// Whether this provider supports process-tree based terminal detection
    var supportsProcessTree: Bool {
        switch self {
        case .claudeCode: true
        case .codex: false
        case .opencode: false
        case .hermes: false
        }
    }

    /// Whether this provider runs in a local terminal (vs. remote/Discord/web)
    var hasLocalTerminal: Bool {
        switch self {
        case .claudeCode: true
        case .codex: true
        case .opencode: true
        case .hermes: false  // Hermes runs via Discord, no local terminal
        }
    }

    /// Infer provider type from HookEvent.source field
    /// Maintains backward compatibility: source==nil → claudeCode, source=="codex" → codex
    static func from(source: String?) -> AgentProviderType {
        guard let source else { return .claudeCode }
        switch source {
        case "codex": return .codex
        case "opencode": return .opencode
        case "hermes": return .hermes
        default: return .claudeCode
        }
    }
}
