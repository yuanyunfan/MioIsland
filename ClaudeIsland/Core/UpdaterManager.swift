import AppKit
import Combine
import Foundation
import Sparkle
import os.log

/// Thin wrapper around Sparkle's SPUStandardUpdaterController.
/// Provides observable state for SwiftUI views and a single shared instance.
///
/// 自动更新失败时，弹 fallback NSAlert 引导用户手动到 GitHub 下载 DMG，
/// 并预告 Gatekeeper 的"隐私与安全性 → 仍要打开"流程。这解决：
/// 1) Sparkle EdDSA 公钥 rotate 后老用户卡在旧版升不上来
/// 2) 未公证的 ad-hoc 签名首次打开被 Gatekeeper 拦截
@MainActor
final class UpdaterManager: NSObject, ObservableObject {
    static let shared = UpdaterManager()

    private static let logger = Logger(subsystem: "com.codeisland", category: "Updater")

    private var controller: SPUStandardUpdaterController!

    @Published var canCheckForUpdates = false

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Observe Sparkle's canCheckForUpdates KVO property
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdaterManager: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            handleUpdateError(error)
        }
    }

    @MainActor
    private func handleUpdateError(_ error: Error) {
        let ns = error as NSError
        Self.logger.error("Sparkle update error domain=\(ns.domain, privacy: .public) code=\(ns.code) desc=\(ns.localizedDescription, privacy: .public)")

        // 排除用户主动取消 / 没有新版本这种正常情况
        let ignoreCodes: Set<Int> = [
            1001, // SUNoUpdateError（没有更新，正常）
            4009, // SUInstallationCancelledError（用户取消安装）
            4001, // 用户取消下载
        ]
        if ignoreCodes.contains(ns.code) { return }

        showFallbackAlert()
    }

    @MainActor
    private func showFallbackAlert() {
        let isZh = L10n.isChinese
        let alert = NSAlert()
        alert.messageText = isZh ? "自动更新失败" : "Auto-update failed"
        alert.informativeText = isZh
            ? """
              升级链路需要手动同步一次。请按以下步骤：

              1. 点「下载最新版」到 GitHub 下载 DMG
              2. 拖入「应用程序」替换旧版
              3. 首次打开若被系统拦截，点「隐私设置」，在「隐私与安全性」页面最底部点「仍要打开」
              """
            : """
              The update chain needs to be re-synced manually.

              1. Tap "Download Latest" to download the DMG from GitHub.
              2. Drag it into Applications, replacing the old version.
              3. If macOS blocks the first launch, open "Privacy Settings" and click "Open Anyway" at the bottom of the page.
              """
        alert.alertStyle = .warning

        // 顺序：主按钮 firstButtonReturn
        alert.addButton(withTitle: isZh ? "下载最新版" : "Download Latest")
        alert.addButton(withTitle: isZh ? "隐私设置" : "Privacy Settings")
        alert.addButton(withTitle: isZh ? "取消" : "Cancel")

        // Alert 出现前把 app 激活到前台，否则 accessory policy 下用户可能看不到
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: "https://github.com/MioMioOS/MioIsland/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
}
