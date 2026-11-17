#!/usr/bin/env bash
# 86-build-modid-regex.sh — 模组标识不许把路径拼出仓库（#10 第 5 条）
#
# build.sh 用 $MOD 拼出 SRC_DIR/RES_DIR。若不管，`bash build.sh ../etc` 会把
# 路径指到仓库外，`bash build.sh .hidden` 这类也会撞上非常规目录。
# 这类输入只可能来自打错或恶意调用，要在拼路径之前就拒绝。
#
# 断言：
#   - 含路径分隔符的标识 → 退出码 1、信息说清不允许
#   - 以点开头的标识 → 同上
#   - 两者都不读依赖变量（在 MOD 校验处就退出），也不会碰 dist/

CASE_NAME="86-build-modid-regex"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo
fixture_build_commit

BEFORE_DIST="$(dist_dir_files)"

build_run "../etc"
assert_rc 1
assert_contains "错误："
assert_contains "路径分隔符"

build_run ".hidden"
assert_rc 1
assert_contains "错误："
assert_contains "点开头"

CHECKED=$((CHECKED + 1))
if [ "$(dist_dir_files)" != "$BEFORE_DIST" ]; then
  fail "非法标识不该产生任何产物，dist/ 变了"
fi

harness_done
