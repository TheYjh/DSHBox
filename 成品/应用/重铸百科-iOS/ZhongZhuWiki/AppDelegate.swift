//
//  AppDelegate.swift
//  重铸百科 iOS
//
//  启动顺序：先把网页资源目录准备好 → 起本地 HTTP 服务 → 建窗口装载 WKWebView。
//  服务起不来时进一个纯 Swift 的故障页，而不是白屏，方便用户把错误信息发回来。
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var server: LocalHTTPServer?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        do {
            let root = try WebAssets.locateRoot()
            let server = try LocalHTTPServer(rootDirectory: root)
            let port = try server.start()
            self.server = server
            guard let url = URL(string: "http://127.0.0.1:\(port)/index.html") else {
                throw LocalHTTPServer.ServerError.listenFailed(0)
            }
            window.rootViewController = WebViewController(startURL: url)
        } catch {
            window.rootViewController = FailureViewController(message: "\(error.localizedDescription)")
        }

        window.makeKeyAndVisible()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        server?.stop()
    }
}
