//
//  BuiltInPlugins.swift
//  ClaudeIsland
//
//  Built-in "official" plugins that ship with the app. Users can
//  disable them (which hides them from the header) but the slot
//  stays visible in System Settings > Plugins so they can be
//  reinstalled with one click.
//

import AppKit
import SwiftUI

// MARK: - Pair iPhone Plugin

/// Shell plugin that opens QRPairingWindow when tapped.
final class PairPhonePlugin: NSObject, MioPlugin {
    var id: String { "pair-phone" }
    var name: String { "Pair iPhone" }
    var icon: String { "iphone" }
    var version: String { "1.0.0" }

    func activate() {}
    func deactivate() {}

    func makeView() -> NSView {
        NSHostingView(rootView: PairPhonePluginView())
    }
}

/// View that immediately opens the QR pairing window.
private struct PairPhonePluginView: View {
    @ObservedObject var syncManager = SyncManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.5))

            if syncManager.isEnabled {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Online")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            } else {
                Text("Not connected")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }

            Button("Open Pairing") {
                QRPairingWindow.shared.show()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Official Plugin Registry

/// Metadata for official plugins that ship with the app.
/// These always appear in the Plugins settings page, even when
/// disabled, so users can re-enable them with one click.
///
/// Two kinds of officials:
///   - Swift built-ins: factory creates the instance directly (e.g. Pair iPhone)
///   - Bundle-based: factory is nil; the plugin is shipped as a .bundle loaded
///     from disk. When disabled the slot stays; reinstall reloads from disk.
struct OfficialPluginInfo {
    let id: String
    let name: String
    let icon: String
    let version: String
    let factory: (() -> MioPlugin)?
}

enum OfficialPlugins {
    static let all: [OfficialPluginInfo] = [
        OfficialPluginInfo(
            id: "pair-phone",
            name: "Pair iPhone",
            icon: "iphone",
            version: "1.0.0",
            factory: { PairPhonePlugin() }
        ),
        // Stats is shipped as a .bundle plugin (source in mio-plugin-stats).
        // It lives in ~/.config/codeisland/plugins/stats.bundle after install.
        OfficialPluginInfo(
            id: "stats",
            name: "Stats",
            icon: "chart.bar.fill",
            version: "1.0.0",
            factory: nil
        ),
    ]

    static let ids: Set<String> = Set(all.map { $0.id })

    static func info(id: String) -> OfficialPluginInfo? {
        all.first { $0.id == id }
    }
}
