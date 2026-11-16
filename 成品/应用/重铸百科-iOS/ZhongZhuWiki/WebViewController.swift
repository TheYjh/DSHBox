//
//  WebViewController.swift
//  重铸百科 iOS
//
//  只有一个 WKWebView。宿主侧要做的事：
//  1. 用持久化数据仓（收藏存在 localStorage，必须能跨启动保留）；
//  2. 本地 http://127.0.0.1 留在 App 内，其余链接交给系统浏览器；
//  3. target=_blank 的新窗口也交给系统浏览器，而不是被静默丢弃；
//  4. 「下载资料原件」走 WKDownload，落盘后弹分享面板；
//  5. 支持左右滑动返回上一页（页面本身用 location.hash 路由）。
//

import UIKit
import WebKit

final class WebViewController: UIViewController {

    private let startURL: URL
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObservation: NSKeyValueObservation?
    /// 下载任务 → 保存位置，用于在完成回调里找回落盘文件。
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    init(startURL: URL) {
        self.startURL = startURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xF7 / 255.0, green: 0xF8 / 255.0, blue: 0xF2 / 255.0, alpha: 1.0)
        configureWebView()
        configureProgressView()
        loadStartPage()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - 构建

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()

        // 关键：默认数据仓，收藏（localStorage）才会跨启动保留。
        configuration.websiteDataStore = .default()

        // 页面里没有音视频，但保留内联播放免得以后加内容时要重新签名。
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // 让 <a target="_blank"> 走 createWebViewWith，由我们交给系统浏览器。
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.bounces = true
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.backgroundColor = UIColor(red: 0xF7 / 255.0, green: 0xF8 / 255.0, blue: 0xF2 / 255.0, alpha: 1.0)
        webView.isOpaque = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        self.webView = webView
    }

    private func configureProgressView() {
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 0x27 / 255.0, green: 0x67 / 255.0, blue: 0x4E / 255.0, alpha: 1.0)
        progressView.trackTintColor = .clear
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
        progressView.isHidden = true
        self.progressView = progressView

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressView.isHidden = progress >= 1.0
            self.progressView.setProgress(progress, animated: true)
        }
    }

    private func loadStartPage() {
        webView.load(URLRequest(url: startURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
    }

    // MARK: - 工具

    private func isLocal(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost"
    }

    private func openExternally(_ url: URL) {
        guard url.scheme == "http" || url.scheme == "https" else {
            UIApplication.shared.open(url)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func downloadDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("下载", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// 文件名要落进沙盒，做一次保守清洗。
    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        let cleaned = name.components(separatedBy: invalid).joined(separator: "_")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "资料原件" : trimmed
    }

    private func presentShare(for fileURL: URL) {
        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY,
                                                                    width: 1, height: 1)
        present(activity, animated: true)
    }

    private func showLoadFailure(_ message: String) {
        let alert = UIAlertController(title: "页面打不开", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.loadStartPage()
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        // 服务刚起时偶发的连接重置，重试一次即可。
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost {
            showLoadFailure("本地数据服务没有响应，请退出 App 后重新打开。")
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // 本地服务：始终放行。带 download 属性的链接交给 WebKit 转成下载。
        if isLocal(url) || url.scheme == "about" || url.scheme == "data" || url.scheme == "blob" {
            if #available(iOS 14.5, *), navigationAction.shouldPerformDownload {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
            return
        }

        // 页面初始加载若不是本地地址（理论上不会发生），也放行一次，避免白屏。
        if navigationAction.navigationType == .other && navigationAction.targetFrame?.isMainFrame == true
            && webView.url == nil {
            decisionHandler(.allow)
            return
        }

        // 其余（外链、mailto、tel）交给系统。
        if navigationAction.targetFrame == nil {
            // target=_blank 会先到这里，iOS 上 navigationAction.targetFrame 为 nil。
            openExternally(url)
            decisionHandler(.cancel)
            return
        }

        openExternally(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        // 无法直接渲染的类型一律走下载；能渲染的照常打开。
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
        if let name = navigationAction.request.url?.lastPathComponent {
            downloadDestinations[ObjectIdentifier(download)] =
                downloadDirectory().appendingPathComponent(sanitize(name))
        }
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
        if let name = navigationResponse.response.url?.lastPathComponent {
            downloadDestinations[ObjectIdentifier(download)] =
                downloadDirectory().appendingPathComponent(sanitize(name))
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    /// <a target="_blank">：不要在 App 里开新窗口，交给系统浏览器。
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            openExternally(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        present(alert, animated: true)
    }
}

// MARK: - WKDownloadDelegate

extension WebViewController: WKDownloadDelegate {

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let directory = downloadDirectory()
        let destination = directory.appendingPathComponent(sanitize(suggestedFilename))
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        downloadDestinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let fileURL = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        presentShare(for: fileURL)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
        let alert = UIAlertController(title: "下载失败",
                                      message: "\(error.localizedDescription)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
