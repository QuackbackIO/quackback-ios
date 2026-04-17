#if canImport(UIKit)
import UIKit

public enum Quackback {
    private static var config: QuackbackConfig?
    private static var wvManager: QuackbackWebView?
    private static var launcher: LauncherButton?
    private static var panel: PanelController?
    private static let emitter = EventEmitter()
    private static var isShowing = false
    private static var pendingIdentify: String?
    private static var serverThemeColor: UIColor?
    private static var themeFetched = false
    private static var launcherRevealFallback: DispatchWorkItem?
    private static let launcherRevealFallbackDelay: TimeInterval = 1.5

    public static func configure(_ config: QuackbackConfig, identity: Identity? = nil) {
        self.config = config
        fetchTheme(instanceUrl: config.instanceUrl)
        if let identity { applyIdentity(identity) }
    }

    public static func identify() { enqueue(JSBridge.identifyAnonymousCommand()) }
    public static func identify(ssoToken: String) { enqueue(JSBridge.identifyCommand(ssoToken: ssoToken)) }
    public static func identify(userId: String, email: String, name: String? = nil, avatarURL: String? = nil) {
        enqueue(JSBridge.identifyCommand(userId: userId, email: email, name: name, avatarURL: avatarURL))
    }
    public static func logout() { enqueue(JSBridge.logoutCommand()) }

    /// Attach session metadata to feedback submitted through the widget.
    /// Pass `nil` as a value to remove a previously-set key.
    public static func metadata(_ patch: [String: String?]) {
        enqueue(JSBridge.metadataCommand(patch))
    }

    private static func applyIdentity(_ identity: Identity) {
        switch identity {
        case .user(let id, let email, let name, let avatarURL):
            identify(userId: id, email: email, name: name, avatarURL: avatarURL)
        case .ssoToken(let token): identify(ssoToken: token)
        }
    }

    public static func open(view: OpenView? = nil, title: String? = nil, board: String? = nil) {
        guard let config else { return }
        ensureWV(config)
        wvManager?.execute(JSBridge.openCommand(view: view, title: title, board: board))
        presentPanel()
    }
    public static func close() { dismissPanel() }

    public static func showLauncher() {
        guard let config, launcher == nil else { return }
        let color = resolveColor(config: config)
        let btn = LauncherButton(position: config.placement, color: color, foreground: defaultForeground)
        btn.addTarget(self, action: #selector(launcherTapped), for: .touchUpInside)
        if let w = keyWindow { btn.install(in: w) }; launcher = btn
        if themeFetched {
            btn.reveal()
        } else {
            let work = DispatchWorkItem { launcher?.reveal() }
            launcherRevealFallback = work
            DispatchQueue.main.asyncAfter(deadline: .now() + launcherRevealFallbackDelay, execute: work)
        }
    }
    public static func hideLauncher() { launcher?.removeFromSuperview(); launcher = nil }

    @discardableResult
    public static func on(_ event: QuackbackEvent, handler: @escaping @Sendable ([String: Any]) -> Void) -> EventToken {
        emitter.on(event, handler: handler)
    }
    public static func off(_ token: EventToken) { emitter.off(token) }

    public static func destroy() {
        dismissPanel(); hideLauncher(); wvManager?.tearDown(); wvManager = nil
        emitter.removeAll(); config = nil; pendingIdentify = nil; serverThemeColor = nil
        themeFetched = false
        launcherRevealFallback?.cancel(); launcherRevealFallback = nil
    }

    // MARK: - Private

    // Quackback brand defaults — used before the server theme fetch completes
    // or if it fails. Amber-400 (#facc15) text on black.
    private static let defaultColor = UIColor.black
    private static let defaultForeground = UIColor(red: 250/255, green: 204/255, blue: 21/255, alpha: 1)

    private static func resolveColor(config: QuackbackConfig) -> UIColor {
        return serverThemeColor ?? defaultColor
    }

    private static func fetchTheme(instanceUrl: URL) {
        let url = instanceUrl.appendingPathComponent("api/widget/config.json")
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let color: UIColor? = {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let theme = json["theme"] as? [String: Any] else { return nil }
                return parseHex(theme["lightPrimary"] as? String)
            }()
            DispatchQueue.main.async {
                if let color {
                    serverThemeColor = color
                    launcher?.backgroundColor = color
                }
                themeFetched = true
                launcher?.reveal()
                launcherRevealFallback?.cancel()
                launcherRevealFallback = nil
            }
        }.resume()
    }

    private static func ensureWV(_ config: QuackbackConfig) {
        guard wvManager == nil else { return }
        let m = QuackbackWebView(config: config); m.delegate = Delegate.shared; wvManager = m
    }
    private static func enqueue(_ js: String) {
        if wvManager?.webView != nil { wvManager?.execute(js) } else { pendingIdentify = js }
    }
    private static func presentPanel() {
        guard !isShowing, let wvManager else { return }
        let pc = PanelController(webViewManager: wvManager)
        pc.onDismiss = { isShowing = false; launcher?.setOpen(false) }
        guard let top = topVC else { return }
        top.present(pc, animated: true); isShowing = true; launcher?.setOpen(true); panel = pc
    }
    private static func dismissPanel() {
        panel?.dismiss(animated: true); panel = nil; isShowing = false; launcher?.setOpen(false)
    }
    @objc private static func launcherTapped() { isShowing ? close() : open() }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
    }
    private static var topVC: UIViewController? {
        var vc = keyWindow?.rootViewController; while let p = vc?.presentedViewController { vc = p }; return vc
    }
    private static func parseHex(_ hex: String?) -> UIColor? {
        guard let hex, hex.hasPrefix("#"), hex.count == 7 else { return nil }
        var rgb: UInt64 = 0; Scanner(string: String(hex.dropFirst())).scanHexInt64(&rgb)
        return UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }

    private final class Delegate: QuackbackWebViewDelegate {
        static let shared = Delegate()
        func webViewDidReceiveEvent(_ event: QuackbackEvent, data: [String: Any]) {
            if event == .close { dismissPanel() }; emitter.emit(event, data: data)
        }
        func webViewDidBecomeReady() {
            if let js = pendingIdentify { wvManager?.execute(js); pendingIdentify = nil }
        }
    }
}
#else
import Foundation

public enum Quackback {
    private static var config: QuackbackConfig?
    private static let emitter = EventEmitter()

    public static func configure(_ config: QuackbackConfig, identity: Identity? = nil) { self.config = config }
    public static func identify() {}
    public static func identify(ssoToken: String) {}
    public static func identify(userId: String, email: String, name: String? = nil, avatarURL: String? = nil) {}
    public static func logout() {}
    public static func metadata(_ patch: [String: String?]) {}
    public static func open(view: OpenView? = nil, title: String? = nil, board: String? = nil) {}
    public static func close() {}
    public static func showLauncher() {}
    public static func hideLauncher() {}
    @discardableResult
    public static func on(_ event: QuackbackEvent, handler: @escaping @Sendable ([String: Any]) -> Void) -> EventToken {
        emitter.on(event, handler: handler)
    }
    public static func off(_ token: EventToken) { emitter.off(token) }
    public static func destroy() { emitter.removeAll(); config = nil }
}
#endif
