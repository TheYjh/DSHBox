#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_web_assets.py —— 从原始 Android APK 还原「重铸百科」的网页资源，
生成 iOS 工程需要的 WebAssets/ 目录。

为什么需要这一步
    网页资源一共 449 MB（74,904 个文件），不能塞进 git 仓库，
    所以工程里只放源码，资源在你自己的机器上从原始 APK 现解一遍。

用法
    python3 script/build_web_assets.py --apk /path/to/重铸百科-1.4.0-UI修复版.apk.1
    python3 script/build_web_assets.py --apk ../../../../底包/重铸百科-1.4.0-UI修复版.apk.1
    python3 script/build_web_assets.py --apk ... --out /tmp/WebAssets   # 只导到别处看看

不传 --apk 时会在工程目录、仓库根目录、上级目录里找 *.apk / *.apk.1。

输出结构
    ZhongZhuWiki/WebAssets/
        index.html          已改：viewport-fit=cover、引入 ios.css
        ios.css             从 ZhongZhuWiki/Patches/ios.css 拷来
        app.js              已打文案补丁
        style.css reading.css foods.js data/ assets/ reference/ ...
"""

import argparse
import os
import shutil
import struct
import sys
import zipfile
import zlib

PACK_MEMBER = "assets/web.pack"
PACK_MAGIC = b"PWPK1\n"

# ---------------------------------------------------------------- 文案补丁

# (原文, 新文案)。每一条都断言在 app.js 里恰好出现一次，
# 出现次数不对说明上游换了文案，宁可报错也不要静默漏改。
APP_JS_REPLACEMENTS = [
    (
        "参考重铸百科 Android 1.0.3",
        "重铸百科 iPhone / iPad 离线版",
    ),
    (
        "完整解压文件夹，双击 <code>index.html</code> 即可使用。",
        "打开 App 即可使用，不需要联网。",
    ),
    (
        "收藏保存在当前浏览器的本地存储中。",
        "收藏保存在本机，删除 App 会一起清掉。",
    ),
    (
        "数据文件未能加载。请完整解压文件夹，再打开 index.html。",
        "数据文件未能加载。请退出 App 后重新打开。",
    ),
    (
        "无法加载词条；请确认已经完整解压文件夹。",
        "无法加载词条；数据可能不完整，请重新安装 App。",
    ),
    (
        "收藏会保存在当前浏览器中，点击星标即可添加或取消。",
        "收藏会保存在本机，点击星标即可添加或取消。",
    ),
    (
        "浏览器不允许保存；本次打开期间仍可收藏",
        "本机存储不可用；本次打开期间仍可收藏",
    ),
    (
        "浏览器返回键可回到上一页",
        "从屏幕左缘向右滑可以回到上一页",
    ),
]

OLD_VIEWPORT = '<meta name="viewport" content="width=device-width, initial-scale=1">'
NEW_VIEWPORT = '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'
STYLE_LINK = '  <link rel="stylesheet" href="style.css">'
IOS_LINK = '  <link rel="stylesheet" href="ios.css">'


# ------------------------------------------------------------ web.pack 解析

class PackEntry(object):
    __slots__ = ("name", "offset", "size", "stored_size", "flag")

    def __init__(self, name, offset, size, stored_size, flag):
        self.name = name
        self.offset = offset
        self.size = size
        self.stored_size = stored_size
        self.flag = flag  # 1 = raw deflate, 0 = 原样存储


def parse_pack(data):
    """解析 web.pack 索引，返回 (version, [PackEntry])。

    格式（小端）：
        magic  PWPK1\n            6 字节
        <I     version
        <I     count
        循环 count 次：
            <H 名长 + UTF-8 文件名
            <Q 数据偏移
            <I 原始大小
            <I 存储大小
            <B flag
    """
    if not data.startswith(PACK_MAGIC):
        raise ValueError("不是 web.pack（开头不是 PWPK1）")

    pos = len(PACK_MAGIC)
    version, count = struct.unpack_from("<II", data, pos)
    pos += 8

    entries = []
    for _ in range(count):
        if pos + 2 > len(data):
            raise ValueError("索引被截断：读到第 %d 条时越过文件末尾" % len(entries))
        name_len = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        if name_len == 0 or pos + name_len > len(data):
            raise ValueError("索引损坏：第 %d 条文件名长度异常" % len(entries))
        name = data[pos:pos + name_len].decode("utf-8")
        pos += name_len

        offset, size, stored_size = struct.unpack_from("<QII", data, pos)
        pos += 16
        flag = data[pos]
        pos += 1

        if offset + stored_size > len(data):
            raise ValueError("索引损坏：%s 的数据越过文件末尾" % name)
        entries.append(PackEntry(name, offset, size, stored_size, flag))

    return version, entries


def extract_pack(data, entries, out_dir, verbose=True):
    """按索引把每个文件写到 out_dir。返回 (写入数, 跳过数)。"""
    written = 0
    skipped = 0
    total = len(entries)
    for index, entry in enumerate(entries):
        raw = data[entry.offset:entry.offset + entry.stored_size]
        try:
            payload = zlib.decompress(raw, -15) if entry.flag == 1 else raw
        except zlib.error as error:
            print("  ! 解压失败，跳过 %s：%s" % (entry.name, error), file=sys.stderr)
            skipped += 1
            continue

        if len(payload) != entry.size:
            print("  ! 大小不符，跳过 %s（索引 %d，实际 %d）"
                  % (entry.name, entry.size, len(payload)), file=sys.stderr)
            skipped += 1
            continue

        target = os.path.join(out_dir, entry.name.replace("/", os.sep))
        parent = os.path.dirname(target)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(target, "wb") as handle:
            handle.write(payload)
        written += 1

        if verbose and (index % 5000 == 0 or index == total - 1):
            print("  解包 %d / %d" % (index + 1, total))

    return written, skipped


# ---------------------------------------------------------------- 文本补丁

def read_text(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def write_text(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def patch_index_html(path):
    html = read_text(path)
    changed = []

    if NEW_VIEWPORT in html:
        pass
    elif OLD_VIEWPORT in html:
        html = html.replace(OLD_VIEWPORT, NEW_VIEWPORT, 1)
        changed.append("viewport-fit=cover")
    else:
        raise ValueError("index.html 里没找到预期的 viewport 声明，上游可能改版了")

    if 'href="ios.css"' not in html:
        if STYLE_LINK not in html:
            raise ValueError("index.html 里没找到 style.css 的引用行，上游可能改版了")
        html = html.replace(STYLE_LINK, STYLE_LINK + "\n" + IOS_LINK, 1)
        changed.append("引入 ios.css")

    write_text(path, html)
    return changed


def patch_app_js(path):
    js = read_text(path)
    changed = []

    for old, new in APP_JS_REPLACEMENTS:
        count = js.count(old)
        if count == 0:
            # 上游删掉了这段文案就跳过，不视为错误。
            continue
        if count != 1:
            raise ValueError("app.js 里「%s」出现 %d 次，预期 1 次" % (old, count))
        js = js.replace(old, new, 1)
        changed.append(new)

    write_text(path, js)
    return changed


# ---------------------------------------------------------------- 主流程

def find_apk(project_root):
    """在工程目录、仓库各级上级目录、当前目录里找 APK。"""
    candidates = [os.getcwd()]
    current = project_root
    for _ in range(4):
        candidates.append(current)
        candidates.append(os.path.join(current, "底包"))
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent

    for directory in candidates:
        if not os.path.isdir(directory):
            continue
        try:
            names = sorted(os.listdir(directory))
        except OSError:
            continue
        for name in names:
            if name.endswith(".apk") or name.endswith(".apk.1"):
                return os.path.join(directory, name)
    return None


def main():
    parser = argparse.ArgumentParser(
        description="从原始 Android APK 还原重铸百科的网页资源")
    parser.add_argument("--apk", help="原始 APK 路径（.apk 或 .apk.1）")
    parser.add_argument("--out", help="输出目录，默认 ZhongZhuWiki/WebAssets")
    parser.add_argument("--allow-existing",
                        action="store_true",
                        help="输出目录非空时仍然覆盖写入")
    args = parser.parse_args()

    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = args.out or os.path.join(project_root, "ZhongZhuWiki", "WebAssets")
    patches_dir = os.path.join(project_root, "ZhongZhuWiki", "Patches")

    apk_path = args.apk or find_apk(project_root)
    if not apk_path:
        print("找不到原始 APK。请用 --apk 指定：", file=sys.stderr)
        print("  python3 script/build_web_assets.py --apk /path/to/重铸百科-*.apk.1",
              file=sys.stderr)
        return 2
    if not os.path.isfile(apk_path):
        print("APK 不存在：%s" % apk_path, file=sys.stderr)
        return 2

    print("APK      %s" % apk_path)
    print("输出目录 %s" % out_dir)

    existing = []
    if os.path.isdir(out_dir):
        existing = [name for name in os.listdir(out_dir) if name != ".gitkeep"]
    if existing and not args.allow_existing:
        print("输出目录已有内容。确认要整体重解就加 --allow-existing。", file=sys.stderr)
        return 2

    print("\n[1/4] 从 APK 读取 web.pack ...")
    try:
        with zipfile.ZipFile(apk_path) as archive:
            pack = archive.read(PACK_MEMBER)
    except KeyError:
        print("APK 里没有 %s，确认这是重铸百科的安装包。" % PACK_MEMBER, file=sys.stderr)
        return 2
    print("      %.1f MB" % (len(pack) / 1024.0 / 1024.0))

    print("\n[2/4] 解析索引 ...")
    version, entries = parse_pack(pack)
    total_size = sum(entry.size for entry in entries)
    print("      格式版本 %d，%d 个文件，解压后 %.0f MB"
          % (version, len(entries), total_size / 1024.0 / 1024.0))

    print("\n[3/4] 解包（74,904 个文件，机械硬盘上要几分钟）...")
    os.makedirs(out_dir, exist_ok=True)
    written, skipped = extract_pack(pack, entries, out_dir)
    print("      写入 %d 个文件，跳过 %d 个" % (written, skipped))

    print("\n[4/4] 打补丁 ...")
    index_path = os.path.join(out_dir, "index.html")
    if not os.path.isfile(index_path):
        print("解包结果里没有 index.html，APK 可能不完整。", file=sys.stderr)
        return 1
    for item in patch_index_html(index_path):
        print("      index.html：%s" % item)

    css_source = os.path.join(patches_dir, "ios.css")
    if os.path.isfile(css_source):
        shutil.copyfile(css_source, os.path.join(out_dir, "ios.css"))
        print("      ios.css：已拷入")
    else:
        print("      警告：没有找到 %s" % css_source, file=sys.stderr)

    app_js_path = os.path.join(out_dir, "app.js")
    if os.path.isfile(app_js_path):
        for item in patch_app_js(app_js_path):
            print("      app.js：%s" % item)

    print("\n完成。用 Xcode 打开 ZhongZhuWiki.xcodeproj，直接构建即可。")
    return 0


if __name__ == "__main__":
    sys.exit(main())

