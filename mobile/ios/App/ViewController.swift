import UIKit
import WebKit

/// 全屏横屏 WKWebView 容器：
/// - 横屏锁定、隐藏状态栏、Home 指示条自动隐藏
/// - 禁用滚动 / 回弹 / 捏合缩放 / 长按菜单
/// - 加载打包进 App 的 www/index.html，完全离线
final class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    private var webView: WKWebView!

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 5 / 255, green: 6 / 255, blue: 10 / 255, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }
        view = webView

        let candidates = [
            Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www"),
            Bundle.main.url(forResource: "index", withExtension: "html"),
            Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "public")
        ]
        if let url = candidates.compactMap({ $0 }).first {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("<h1 style='color:#fff;font-family:sans-serif'>www/index.html missing</h1>", baseURL: nil)
        }
    }

    // 禁用长按菜单
    func webView(_ webView: WKWebView,
                 contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
                 completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        completionHandler(nil)
    }

    // 禁止跳转外部链接（离线游戏不应离开本地页面）
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
