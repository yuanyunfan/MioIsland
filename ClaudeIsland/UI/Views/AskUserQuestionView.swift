//
//  AskUserQuestionView.swift
//  ClaudeIsland
//
//  Interactive UI for answering AskUserQuestion prompts from Claude Code.
//  Sends the selected option index to the terminal via AppleScript / cmux.
//

import SwiftUI

struct AskUserQuestionView: View {
    let session: SessionState
    let context: QuestionContext
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    @State private var customText: String = ""
    @State private var hoveredIndex: Int? = nil
    @State private var isSending: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(session.projectName)
                    .notchFont(11, weight: .semibold)
                    .notchSecondaryForeground()
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Questions + options
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(context.questions.enumerated()), id: \.offset) { _, question in
                        questionBlock(question: question)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 4)

            // Custom text input
            customInputBar
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // Jump to terminal — bottom, full width
            jumpToTerminalButton
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Question Block

    @ViewBuilder
    private func questionBlock(question: QuestionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.question)
                .notchFont(12, weight: .semibold)
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 2)

            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                optionRow(index: index + 1, option: option, optionCount: question.options.count)
            }
        }
    }

    private func optionRow(index: Int, option: QuestionOption, optionCount: Int) -> some View {
        Button {
            guard !isSending else { return }
            isSending = true
            DebugLogger.log("AskUser", "Option \(index) tapped: \(option.label)")
            Task { await approveAndSendOption(index: index) }
        } label: {
            HStack(spacing: 8) {
                Text("\(index)")
                    .notchFont(10, weight: .bold)
                    .foregroundColor(TerminalColors.amber)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TerminalColors.amber.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                        .notchFont(11, weight: .medium)
                        .foregroundColor(.white.opacity(0.85))

                    if let desc = option.description, !desc.isEmpty {
                        Text(desc)
                            .notchFont(9, weight: .regular)
                            .foregroundColor(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .notchFont(8)
                    .foregroundColor(.white.opacity(hoveredIndex == index ? 0.5 : 0.15))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hoveredIndex == index ? TerminalColors.amber.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                hoveredIndex == index ? TerminalColors.amber.opacity(0.2) : Color.white.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredIndex = isHovered ? index : nil
        }
    }

    // MARK: - Custom Input

    private var customInputBar: some View {
        HStack(spacing: 6) {
            TextField("Type your answer...", text: $customText)
                .textFieldStyle(.plain)
                .notchFont(11)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .onSubmit { submitCustomText() }

            Button {
                submitCustomText()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(
                        customText.isEmpty || isSending
                            ? Color.white.opacity(0.15)
                            : TerminalColors.amber
                    )
            }
            .buttonStyle(.plain)
            .disabled(customText.isEmpty || isSending)
        }
    }

    // MARK: - Jump to Terminal

    private var jumpToTerminalButton: some View {
        Button {
            Task { await TerminalJumper.shared.jump(to: session) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .notchFont(10)
                Text("Jump to Terminal")
                    .notchFont(10, weight: .medium)
            }
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Terminal Sending

    /// Navigate to the option using arrow keys and press Enter.
    /// Claude Code's AskUserQuestion uses an arrow-key navigation UI
    /// (↑/↓ to navigate, Enter to select), not numbered input.
    /// Default cursor position is on option 1 (index=1).
    private func approveAndSendOption(index: Int) async {
        let cwd = session.cwd
        let downPresses = index - 1

        // Send arrow-down (N-1) times using CSI B
        for i in 0..<downPresses {
            let ok = performGhosttyAction("csi:B", cwd: cwd)
            DebugLogger.log("AskUser", "Arrow down \(i+1): \(ok)")
        }

        if downPresses > 0 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Press Enter — try multiple formats
        let enterOk = performGhosttyAction("text:\\r", cwd: cwd)
        DebugLogger.log("AskUser", "Enter (text:\\r): \(enterOk)")

        if !enterOk {
            // Fallback: try text:\n
            let ok2 = performGhosttyAction("text:\\n", cwd: cwd)
            DebugLogger.log("AskUser", "Enter (text:\\n): \(ok2)")
        }
    }

    private func submitCustomText() {
        guard !customText.isEmpty, !isSending else { return }
        isSending = true
        let text = customText
        let optionCount = context.questions.first?.options.count ?? 0
        DebugLogger.log("AskUser", "Custom text: \(text)")
        Task {
            let cwd = session.cwd
            for _ in 0..<optionCount {
                performGhosttyAction("csi:B", cwd: cwd)
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            performGhosttyAction("text:\\r", cwd: cwd)
            try? await Task.sleep(nanoseconds: 500_000_000)
            // Type the custom text + Enter
            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            performGhosttyAction("text:\(escaped)\\r", cwd: cwd)
        }
    }

    /// Execute a Ghostty action on the cmux terminal matching the session's cwd.
    @discardableResult
    private func performGhosttyAction(_ action: String, cwd: String) -> Bool {
        let escapedCwd = cwd.replacingOccurrences(of: "\"", with: "\\\"")
        // Use osascript with explicit result capture
        let script = """
        tell application "cmux"
            set targetTerm to (first terminal whose working directory is "\(escapedCwd)")
            set result to (perform action "\(action)" on targetTerm)
            return result as text
        end tell
        """
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DebugLogger.log("AskUser", "perform action '\(action)' → exit=\(process.terminationStatus) output='\(output)'")
            return process.terminationStatus == 0 && output == "true"
        } catch {
            DebugLogger.log("AskUser", "perform action '\(action)' error: \(error)")
            return false
        }
    }

    private func runAppleScript(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
