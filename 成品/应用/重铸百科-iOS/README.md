# 重铸百科 · iOS 版

Pixelmon 9.1.12 / 9.1.13 · Minecraft 1.16.5 的离线图鉴，iPhone / iPad 原生 App。
内容与 Android 版「重铸百科 1.4.0」完全一致：1027 只宝可梦、947 个招式、309 个特性、
2784 个物品、53 篇指南、1407 个形态，另含 15,828 张图标与完整资料原件。

整体是「原生壳 + 本地网页」：Swift 起一个只监听 127.0.0.1 的静态服务，
WKWebView 打开 http://127.0.0.1:39471/index.html，网页本身沿用安卓版那一套，
不联网、不申请任何权限。

## 为什么资源要自己生成

网页数据 449 MB、74,904 个文件，塞不进 git 仓库，所以工程里只放源码。
原始数据在安卓安装包的 `assets/web.pack` 里，用脚本在本机解出来即可。

## 构建步骤

1. 准备原始 APK：`底包/重铸百科-1.4.0-UI修复版.apk.1`（76 MB，大文件不进 git，需要自己放到位）。
2. 在工程根目录解资源：

```bash
python3 script/build_web_assets.py
```

   脚本会自动在工程目录及各级上级目录的 `底包/` 里找 `*.apk` / `*.apk.1`；
   也可以显式指定：`--apk ../../../底包/重铸百科-1.4.0-UI修复版.apk.1`。
   输出到 `ZhongZhuWiki/WebAssets/`，约 449 MB，需几分钟、约 1 GB 空闲磁盘。

3. 用 Xcode 15 或更新版本打开 `ZhongZhuWiki.xcodeproj`。
4. 选中 ZhongZhuWiki target → Signing & Capabilities → 选自己的 Team，
   必要时把 Bundle Identifier `com.dshbox.zhongzhuwiki` 改成自己的。
5. 连上设备或选模拟器，⌘R 运行。上真机需要 iOS 15.0 或更新版本。

首次构建要把 449 MB 资源拷进 .app，比普通工程慢，属正常。

## 目录结构

```
重铸百科-iOS/
├── ZhongZhuWiki.xcodeproj/         Xcode 工程（含共享 scheme）
├── ZhongZhuWiki/
│   ├── AppDelegate.swift           启动：找资源 → 起服务 → 开窗口
│   ├── WebViewController.swift     WKWebView 容器、外链、下载、分享
│   ├── LocalHTTPServer.swift       127.0.0.1 上的极简静态服务
│   ├── WebAssets.swift             定位网页资源目录
│   ├── FailureViewController.swift 资源缺失时的兜底页
│   ├── Info.plist
│   ├── Assets.xcassets/            图标、强调色、启动背景色
│   ├── Patches/
│   │   └── ios.css                 iOS 适配样式，构建时被拷进 WebAssets
│   └── WebAssets/                  ← 脚本生成，不在 git 里
└── script/
    └── build_web_assets.py         从 APK 还原网页资源
```

## 和安卓版的差别

界面、内容、路由完全一致，只动了这些：

- **安全区**：全部用 `env(safe-area-inset-*)` 让开刘海、灵动岛和底部 Home 条；
  底部导航条高度吃掉安全区，内容区不再被遮。
- **输入框 16px**：iOS Safari/WebKit 对小于 16px 的输入框会在聚焦时强制放大页面，
  搜索框与下拉框统一提到 16px，并去掉原生外观。
- **按压反馈**：没有 hover，改为 `:active` 轻微缩放；行内链接保留系统长按菜单。
- **表格**：搬进安卓壳当年通过 `shouldInterceptRequest` 注入的那 26 条修补
  （窄屏缩字号、图标 label 不撑破单元格、属性计算器输入框宽度），
  否则在 iPhone 上属性表会横向撑开。
- **外链**：`target="_blank"` 和 about 页里的查证链接交给系统浏览器，不在 App 内开窗。
- **下载资料原件**：走 WKDownload，落盘到「文件 App → 我的 iPhone → 重铸百科 → 下载」，
  下载完弹系统分享面板，可以直接转存或发给别人。
- **收藏**：存在 WKWebView 的持久化数据仓（localStorage），杀进程、重启都在；
  删除 App 会一起清掉。
- **文案**：about 页里「参考 Android 1.0.3」「双击 index.html」「保存在浏览器本地存储」
  等安卓/桌面语境的说法，换成 iOS 的说法。

## 已知边界

- 只支持竖屏和横屏，不做 iPad 分屏专属布局（网页本身是响应式的，够用）。
- 本地服务固定从 39471 起试 6 个端口，全被占用才会启动失败（几乎不会发生）。
  端口固定是为了让 localStorage 的同源策略保持稳定 —— 换了端口，收藏会读不到。
- 资源缺失时 App 不闪退，会显示一页说明，提示跑上面的脚本。
- 网页资源 449 MB，从 App Store 分发时包体偏大，建议走 TestFlight 或自签名安装。

## 二次修改网页内容

改 `Patches/ios.css` 后重跑一次 `build_web_assets.py`（或直接把 css 拷进 WebAssets）；
改文案或结构就改脚本里的补丁表，重解一遍。`WebAssets/` 是生成物，不要手改也不要提交。
