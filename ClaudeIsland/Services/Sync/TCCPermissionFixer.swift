//
//  TCCPermissionFixer.swift
//  ClaudeIsland
//
//  Ad-hoc 签名的 Mio Island 每次升级 CDHash 都会变，macOS TCC 用
//  (Bundle ID + Designated Requirement) 做身份键，旧授权对新 CDHash 不生效。
//  用户原来得去系统设置删除 + 重加，这里把流程一键化。
//
//  tccutil reset 在 Sequoia 15.x 上不需要 admin 密码（已本地验证）。
//

import AppKit
import ApplicationServices
import Foundation
import os.log

enum TCCService: String {
    case accessibility = "Accessibility"
    case appleEvents = "AppleEvents"
}

@MainActor
enum TCCPermissionFixer {
    private static let logger = Logger(subsystem: "com.codeisland", category: "TCC")
    private static let bundleID = Bundle.main.bundleIdentifier ?? "com.codeisland.app"

    /// 重置指定 TCC 服务，然后触发原生授权弹窗。
    /// 返回 tccutil 退出码是否为 0；真正的授权是异步的，调用方应在稍后重新查询状态。
    @discardableResult
    static func resetAndRequest(_ service: TCCService) -> Bool {
        let didReset = runTccutilReset(service)
        switch service {
        case .accessibility:
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        case .appleEvents:
            triggerAutomationPrompt()
        }
        return didReset
    }

    private static func runTccutilReset(_ service: TCCService) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service.rawValue, bundleID]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            logger.info("tccutil reset \(service.rawValue, privacy: .public) exit=\(process.terminationStatus)")
            return process.terminationStatus == 0
        } catch {
            logger.error("tccutil reset failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 触发 Automation 授权弹窗：给 System Events 发一个无副作用的 AppleEvent。
    private static func triggerAutomationPrompt() {
        let script = NSAppleScript(source: #"tell application "System Events" to count processes"#)
        var err: NSDictionary?
        _ = script?.executeAndReturnError(&err)
    }
}
