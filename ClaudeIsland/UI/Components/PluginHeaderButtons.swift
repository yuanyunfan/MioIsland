//
//  PluginHeaderButtons.swift
//  ClaudeIsland
//
//  Native SwiftUI buttons for loaded plugins in the instances header.
//  Each plugin gets an icon button based on its `icon` property.
//  Hover: fluorescent pink, scale up, hand cursor.
//

import SwiftUI

struct PluginHeaderButtons: View {
    let viewModel: NotchViewModel
    @ObservedObject private var manager = NativePluginManager.shared
    @State private var showOverflow = false

    private let maxVisible = 4

    private var visiblePlugins: [NativePluginManager.LoadedPlugin] {
        Array(manager.loadedPlugins.prefix(maxVisible))
    }

    private var overflowPlugins: [NativePluginManager.LoadedPlugin] {
        Array(manager.loadedPlugins.dropFirst(maxVisible))
    }

    var body: some View {
        // Visible icons
        ForEach(visiblePlugins) { plugin in
            PluginHeaderButton(plugin: plugin, viewModel: viewModel)
        }

        // Overflow "..." button when >4 plugins
        if !overflowPlugins.isEmpty {
            HeaderIconButton(icon: "ellipsis", hoverColor: Color(red: 0.6, green: 0.8, blue: 1.0)) {
                showOverflow.toggle()
            }
            .popover(isPresented: $showOverflow, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                VStack(spacing: 4) {
                    ForEach(overflowPlugins) { plugin in
                        Button {
                            showOverflow = false
                            viewModel.showPlugin(plugin.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: plugin.icon)
                                    .font(.system(size: 11))
                                    .frame(width: 16)
                                Text(plugin.name)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .frame(minWidth: 140)
                .background(Color(white: 0.15))
            }
        }
    }
}

private struct PluginHeaderButton: View {
    let plugin: NativePluginManager.LoadedPlugin
    let viewModel: NotchViewModel

    var body: some View {
        HeaderIconButton(icon: plugin.icon) {
            viewModel.showPlugin(plugin.id)
        }
    }
}

/// Reusable header icon button with hover effects.
/// Used for both plugin buttons and the settings gear.
struct HeaderIconButton: View {
    let icon: String
    var hoverColor: Color = Color(red: 1.0, green: 0.4, blue: 0.6) // fluorescent pink default
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isHovered ? hoverColor : .white.opacity(0.5))
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
