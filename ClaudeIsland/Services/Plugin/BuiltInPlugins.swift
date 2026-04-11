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

// MARK: - Stats Plugin

/// Wraps DailyReportCard as a plugin with a chart icon in the header.
final class StatsPlugin: NSObject, MioPlugin {
    var id: String { "stats" }
    var name: String { "Stats" }
    var icon: String { "chart.bar.fill" }
    var version: String { "1.0.0" }

    func activate() {}
    func deactivate() {}

    func makeView() -> NSView {
        // Will be populated with full stats view
        NSHostingView(rootView: StatsPluginView())
    }
}

/// Stats view — reuses AnalyticsCollector data directly.
private struct StatsPluginView: View {
    @ObservedObject private var analytics = AnalyticsCollector.shared
    @State private var mode: StatsMode = .day

    enum StatsMode { case day, week }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let week = analytics.thisWeek, week.hasActivity {
                    // Mode picker
                    HStack {
                        Spacer()
                        Picker("", selection: $mode) {
                            Text("日").tag(StatsMode.day)
                            Text("周").tag(StatsMode.week)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 80)
                    }

                    let day = week.days.last
                    let turns = mode == .day ? (day?.turnCount ?? 0) : week.turnCount
                    let focusMin = mode == .day ? (day?.focusMinutes ?? 0) : week.focusMinutes
                    let lines = mode == .day ? (day?.linesWritten ?? 0) : week.linesWritten

                    // Stats grid
                    HStack(spacing: 16) {
                        statItem(value: "\(turns)", label: "轮次")
                        statItem(value: formatDuration(focusMin), label: "专注时长")
                        statItem(value: "\(lines)", label: "代码行")
                    }

                    // Top project
                    if let projectName = day?.primaryProjectName {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0xCA/255, green: 0xFF/255, blue: 0x00/255))
                            Text(projectName)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                } else {
                    Text("No activity data yet")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .padding(12)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
    }
}

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
