//
//  AgentProviderType.swift
//  ClaudeIsland
//
//  Identifies which AI agent tool a session belongs to.
//  Adding a new provider only requires:
//    1. A new case here
//    2. A new entry in `metadata`
//    3. A runtime AgentProvider implementation
//  SessionStore reads ProviderMetadata only — no per-provider switches required.
//

import Foundation

/// Static, per-provider configuration consumed by SessionStore.
/// Adding a new provider type means filling out this struct, not editing SessionStore.
struct ProviderMetadata: Sendable {
    let displayName: String
    /// Whether chat history lives in a file we parse incrementally.
    let usesFileSync: Bool
    /// Whether terminal app can be inferred via process tree walk.
    let supportsProcessTree: Bool
    /// Whether the session attaches to a local terminal (vs remote/Discord/web).
    let hasLocalTerminal: Bool
    /// Hardcoded terminal-app label for non-process-tree providers.
    /// nil means "rely on process tree / hook hint".
    let defaultTerminalAppName: String?
    /// What backing transcript file (if any) carries chat history.
    let transcriptKind: TranscriptKind
}

/// How a provider's chat history is materialized.
enum TranscriptKind: Sendable, Equatable {
    /// No transcript file — chat history is pushed inline via HookEvent.message.
    case none
    /// Standard Claude Code JSONL under ~/.claude/projects/.
    case claudeJSONL
    /// Codex rollout JSONL whose path arrives in HookEvent.transcriptPath.
    case codexRollout
}

/// All supported AI agent provider types
enum AgentProviderType: String, Codable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex = "codex"
    case opencode = "opencode"
    case hermes = "hermes"

    /// Single source of truth for per-provider configuration.
    /// SessionStore reads this — never branches on the enum value.
    var metadata: ProviderMetadata {
        switch self {
        case .claudeCode:
            return ProviderMetadata(
                displayName: "Claude Code",
                usesFileSync: true,
                supportsProcessTree: true,
                hasLocalTerminal: true,
                defaultTerminalAppName: nil,
                transcriptKind: .claudeJSONL
            )
        case .codex:
            return ProviderMetadata(
                displayName: "Codex",
                usesFileSync: true,
                supportsProcessTree: false,
                hasLocalTerminal: true,
                defaultTerminalAppName: "Codex",
                transcriptKind: .codexRollout
            )
        case .opencode:
            return ProviderMetadata(
                displayName: "OpenCode",
                usesFileSync: false,
                supportsProcessTree: false,
                hasLocalTerminal: true,
                defaultTerminalAppName: "OpenCode",
                transcriptKind: .none
            )
        case .hermes:
            return ProviderMetadata(
                displayName: "Hermes",
                usesFileSync: false,
                supportsProcessTree: false,
                hasLocalTerminal: false,
                defaultTerminalAppName: "Hermes",
                transcriptKind: .none
            )
        }
    }

    // MARK: - Convenience accessors (kept for call-site brevity)

    var displayName: String { metadata.displayName }
    var usesFileSync: Bool { metadata.usesFileSync }
    var supportsProcessTree: Bool { metadata.supportsProcessTree }
    var hasLocalTerminal: Bool { metadata.hasLocalTerminal }

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
