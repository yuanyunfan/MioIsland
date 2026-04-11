//
//  BuiltInPlugins.swift
//  ClaudeIsland
//
//  Built-in "plugins" that wrap existing features as plugin entries.
//  They register with NativePluginManager so they appear in the
//  header icon bar like any other plugin.
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
        // Opens pairing window; the view itself is minimal
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
