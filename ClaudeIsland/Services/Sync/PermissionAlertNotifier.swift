//
//  PermissionAlertNotifier.swift
//  ClaudeIsland
//
//  Ad-hoc 签名升级后 TCC 权限静默失效，如果用户配过 CodeLight（iPhone 伴侣），
//  手机发消息到 Mac 的 Accessibility 路径会悄悄断掉。用户不查设置就不知道。
//
//  这里在启动、以及 app 每次激活时检测 AX 权限；只在"从有变没"时发通知，
//  避免反复打扰。
//

import AppKit
import ApplicationServices
import Foundation
import UserNotifications
import os.log

@MainActor
enum PermissionAlertNotifier {
    private static let logger = Logger(subsystem: "com.codeisland", category: "PermissionAlert")

    static let notificationCategory = "MIO_PERMISSION_LOST"
    static let openSettingsAction = "OPEN_SETTINGS"
    static let repairAction = "REPAIR_NOW"

    /// 记住当前 session 已经发过通知，避免同一次启动内反复弹。
    private static var hasNotifiedThisSession = false
    private static var hasRegisteredCategories = false
    private static var observerRegistered = false

    // MARK: - 入口

    /// AppDelegate 启动时调一次。
    /// 内部注册监听 app 激活事件 + 启动后做一次延迟检测。
    static func installAndCheck() {
        installActivationObserver()
        // 启动延迟：给 WindowManager 初始化留时间
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            evaluateAndNotify(reason: "launch")
        }
    }

    private static func installActivationObserver() {
        guard !observerRegistered else { return }
        observerRegistered = true
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                evaluateAndNotify(reason: "activation")
            }
        }
    }

    // MARK: - 判断 + 发通知

    private static func evaluateAndNotify(reason: String) {
        let serverUrl = UserDefaults.standard.string(forKey: "codelight-server-url") ?? ""
        let configured = !serverUrl.trimmingCharacters(in: .whitespaces).isEmpty
        let axNow = AXIsProcessTrusted()
        let axPrev = lastAXState()

        logger.debug("evaluate reason=\(reason, privacy: .public) configured=\(configured) axNow=\(axNow) axPrev=\(axPrev.rawValue, privacy: .public) sessionNotified=\(hasNotifiedThisSession)")

        // 先写回当前状态（不论是否发通知）
        storeAXState(axNow)

        guard configured else { return }
        guard !axNow else {
            // 权限已恢复，重置 session 节流位
            hasNotifiedThisSession = false
            return
        }
        // axNow == false
        // 发通知的触发条件：
        //  - 从 true → false 的过渡（用户刚关掉或升级后失效）
        //  - 或者本 session 尚未通知过且 lastAXState 不存在（首次启动就失效）
        let transitionedToFalse = (axPrev == .granted)
        let firstRunFailed = (axPrev == .unknown) && !hasNotifiedThisSession

        guard transitionedToFalse || firstRunFailed else { return }
        guard !hasNotifiedThisSession else { return }

        postNotification()
        hasNotifiedThisSession = true
    }

    // MARK: - UserDefaults 存取

    private enum AXStateMemory: String {
        case granted
        case denied
        case unknown
    }

    private enum UserDefaultsKeys {
        static let lastAXState = "mio.permissionAlert.lastAXState"
    }

    private static func lastAXState() -> AXStateMemory {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastAXState) ?? ""
        return AXStateMemory(rawValue: raw) ?? .unknown
    }

    private static func storeAXState(_ granted: Bool) {
        let state: AXStateMemory = granted ? .granted : .denied
        UserDefaults.standard.set(state.rawValue, forKey: UserDefaultsKeys.lastAXState)
    }

    // MARK: - 通知发送

    private static func registerCategoriesIfNeeded() {
        guard !hasRegisteredCategories else { return }
        hasRegisteredCategories = true
        let repair = UNNotificationAction(
            identifier: repairAction,
            title: L10n.isChinese ? "一键修复" : "Repair Now",
            options: [.foreground]
        )
        let openSettings = UNNotificationAction(
            identifier: openSettingsAction,
            title: L10n.isChinese ? "打开设置" : "Open Settings",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: notificationCategory,
            actions: [repair, openSettings],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private static func postNotification() {
        registerCategoriesIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = L10n.isChinese ? "Mio Island 权限失效" : "Mio Island Permission Expired"
        content.body = L10n.isChinese
            ? "辅助功能权限需要重新授权，点击一键修复（手机端消息转发依赖此权限）。"
            : "Accessibility permission needs to be re-granted. Tap to repair (required for iPhone message relay)."
        // 不发声 — 这是配置提示，不是紧急事件。
        content.categoryIdentifier = notificationCategory

        let request = UNNotificationRequest(
            identifier: "mio.permission.alert.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { err in
            if let err {
                Self.logger.error("Failed to post permission notification: \(err.localizedDescription, privacy: .public)")
            } else {
                Self.logger.info("Permission alert notification posted")
            }
        }
    }

    // MARK: - 响应点击

    static func handleResponse(actionIdentifier: String) {
        switch actionIdentifier {
        case repairAction:
            TCCPermissionFixer.resetAndRequest(.accessibility)
            SystemSettingsWindow.shared.show(initialTab: .cmuxConnection)
        case openSettingsAction, UNNotificationDefaultActionIdentifier:
            SystemSettingsWindow.shared.show(initialTab: .cmuxConnection)
        default:
            break
        }
    }
}
