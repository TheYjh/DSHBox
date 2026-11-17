#!/usr/bin/env bash
# 80-build-dist-neutral.sh — 构建产物留在 dist/，名字是中性的（#10 第 3 条）
#
# 分工边界：带中文前缀的最终文件名由 ./deliver 按 NAMING.md 施加，
# 构建只负责 dist/<modId>-<版本>.jar。构建脚本一旦自己加前缀，
# 就有了第二个命名源 —— 这里把边界钉死。
#
# 断言：
#   - 退出码 0
#   - 产物落在 dist/demo-0.3.0.jar（版本由 MOD_VERSION 决定）
#   - dist/ 里没有带 [自制-…] 前缀的文件
#   - 产物是合法 jar，且 MANIFEST 的 Implementation-Version 与目录名一致
#   - 成品/ 一个字节都没被碰（构建不写成品目录）

CASE_NAME="80-build-dist-neutral"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo
fixture_build_commit

BUILD_MOD_VERSION="0.3.0"
BEFORE_DIST="$(dist_dir_files)"
tree_snapshot

build_run demo
assert_rc 0

assert_file "$REPO/dist/demo-0.3.0.jar"
assert_contains "产物：$REPO/dist/demo-0.3.0.jar"

# 版本号进 MANIFEST 是 mods.toml 的 version="${file.jarVersion}" 能取到值的前提。
CHECKED=$((CHECKED + 1))
MARKER="$(unzip -p "$REPO/dist/demo-0.3.0.jar" META-INF/MANIFEST.MF 2>/dev/null | tr -d '\r' | grep -x 'Implementation-Version: 0.3.0')"
[ -n "$MARKER" ] || fail "产物的 MANIFEST 里没有 Implementation-Version: 0.3.0"

# 构建不许自己加前缀：前缀属于交付环节。
CHECKED=$((CHECKED + 1))
PREFIXED="$(cd "$REPO" && find dist -maxdepth 1 -type f -name '*自制*' -printf '%f\n' | LC_ALL=C sort)"
if [ -n "$PREFIXED" ]; then
  fail "构建产物不该带交付前缀（前缀由 deliver 施加），实际：$PREFIXED"
fi

# 成品/ 是交付环节的地盘，构建不碰。
assert_no_file "$REPO/成品/模组/[自制-GOD-示例交付]demo-0.3.0.jar"

CHECKED=$((CHECKED + 1))
AFTER_DIST="$(dist_dir_files)"
if [ "$AFTER_DIST" != "demo-0.3.0.jar" ]; then
  fail "dist/ 内容不符，期望只有 demo-0.3.0.jar，实际：[$AFTER_DIST]（跑前：[$BEFORE_DIST]）"
fi

harness_done
