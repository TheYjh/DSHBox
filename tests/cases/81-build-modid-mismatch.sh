#!/usr/bin/env bash
# 81-build-modid-mismatch.sh — 目录名与 mods.toml 的 modId 不符时必须失败（#10 第 5 条）
#
# 为什么这是硬约束：交付时 ./deliver 从 jar 元数据读 modId、按 NAMING.md 查前缀。
# 目录叫 demo 而 mods.toml 声明 ghost 时，构建出的 jar 会被归档到 ghost 名下，
# 用户名下的文件名与实际模组对不上。失败要发生在产物落盘之前。
#
# 断言：
#   - 退出码 1
#   - 错误信息同时点名两个 modId，并说明「会归档到别的模组名下」
#   - 没有产物落进 dist/（构建在打包前就退出）
#   - 失败发生在写 dist/ 之前，成品/ 也没被动过

CASE_NAME="81-build-modid-mismatch"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo ghost      # 目录 demo，mods.toml 却写 ghost
fixture_build_commit

BUILD_MOD_VERSION="0.3.0"
BEFORE_DIST="$(dist_dir_files)"

build_run demo
assert_rc 1

assert_contains "错误："
assert_contains "ghost"
assert_contains "demo"
assert_contains "不符"
assert_not_contains "产物："

# 关键：坏元数据不许产出任何东西，否则下游 deliver 会把它当成合法输入。
CHECKED=$((CHECKED + 1))
AFTER_DIST="$(dist_dir_files)"
if [ "$AFTER_DIST" != "$BEFORE_DIST" ]; then
  fail "元数据不一致时不该有产物，dist/ 变了：期望 [$BEFORE_DIST]，实际 [$AFTER_DIST]"
fi

assert_no_file "$REPO/dist/demo-0.3.0.jar"

harness_done
