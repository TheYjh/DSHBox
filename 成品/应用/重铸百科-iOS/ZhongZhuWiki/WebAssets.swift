//
//  WebAssets.swift
//  重铸百科 iOS
//
//  网页资源（index.html / data / assets / reference）以目录形式拷进 App Bundle 的
//  WebAssets/ 下，由 script/build_web_assets.py 从原始 APK 的 web.pack 里还原。
//

import Foundation

enum WebAssets {

    /// 优先用 App Bundle 里的 WebAssets；调试时允许用 Documents/WebAssets 覆盖，
    /// 方便不重装 App 就替换整套数据。
    static func locateRoot() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let documents = documents {
            let override = documents.appendingPathComponent("WebAssets", isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: override.path, isDirectory: &isDirectory),
               isDirectory.boolValue,
               FileManager.default.fileExists(atPath: override.appendingPathComponent("index.html").path) {
                return override
            }
        }

        if let bundled = Bundle.main.url(forResource: "WebAssets", withExtension: nil) {
            let index = bundled.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: index.path) {
                return bundled
            }
        }

        throw LocalHTTPServer.ServerError.invalidRoot("App 内未找到 WebAssets/index.html")
    }
}
