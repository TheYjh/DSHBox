#!/usr/bin/env python3
"""把「重铸百科 UI 修复版」APK 里的 UI 模板打到网页版上。

背景：UI 修复版 APK 与网页版 1.4.0 的 74904 个网页资源逐字节相同，
修复不是改文件，而是 MainActivity 在运行时注入（PATCH_CSS + 改写 viewport）。
网页版没有壳，所以这里把注入内容落成真实文件：

  1. 拷一份原始网页资源
  2. 放入 ui-fix.css
  3. 在 index.html 的 reading.css 之后插入 <link rel="stylesheet" href="ui-fix.css">

用法：
    python3 apply_ui_fix.py <原始网页目录> <输出目录>
    python3 apply_ui_fix.py /tmp/zh/apkweb ./build/重铸百科网页版-UI修复
"""

import argparse
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CSS_NAME = "ui-fix.css"

LINK_AFTER = '<link rel="stylesheet" href="reading.css">'
LINK_NEW = '<link rel="stylesheet" href="ui-fix.css">'


def patch_index(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        html = f.read()

    if LINK_NEW in html:
        print("  index.html 已含 ui-fix.css，跳过")
        return False

    if LINK_AFTER not in html:
        # 原文件是 CRLF，链接标签本身不含换行，按标签匹配即可
        raise SystemExit(
            "index.html 里找不到 %s，无法定位插入点；请手动在 reading.css 之后引入 ui-fix.css"
            % LINK_AFTER
        )

    html = html.replace(LINK_AFTER, LINK_AFTER + "\r\n  " + LINK_NEW, 1)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(html)
    print("  index.html 已插入 ui-fix.css")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src", help="原始网页资源目录（含 index.html / reading.css）")
    ap.add_argument("dst", help="输出目录，必须不存在或为空")
    args = ap.parse_args()

    src = os.path.abspath(args.src)
    dst = os.path.abspath(args.dst)

    if not os.path.isfile(os.path.join(src, "index.html")):
        raise SystemExit("%s 下没有 index.html，不像是网页版资源目录" % src)
    if os.path.exists(dst) and os.listdir(dst):
        raise SystemExit("输出目录 %s 已存在且非空" % dst)

    css_src = os.path.join(HERE, CSS_NAME)
    if not os.path.isfile(css_src):
        raise SystemExit("缺少 %s" % css_src)

    print("复制资源 %s -> %s" % (src, dst))
    shutil.copytree(src, dst, dirs_exist_ok=True)

    print("放入 %s" % CSS_NAME)
    shutil.copy2(css_src, os.path.join(dst, CSS_NAME))

    patch_index(os.path.join(dst, "index.html"))

    print("完成。打开 %s/index.html 即可。" % dst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
