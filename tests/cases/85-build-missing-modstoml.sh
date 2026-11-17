#!/usr/bin/env bash
# 85-build-missing-modstoml.sh — 缺 mods.toml 时构建必须失败（#10 第 5 条）
#
# modId 是归档时读元数据的唯一来源。一个没有 mods.toml 的模组能构建出 jar，
# 但那个 jar 到 deliver 手上会被拒（读不到 modId）—— 到那时才发现，
# 说明白跑了一次构建。失败要发生在打包之前。
#
# 断言：
#   - 退出码 1，信息点名 mods.toml
#   - dist/ 没有产物
#   - 目录名合法（demo）、依赖齐备：失败只可能来自缺元数据

CASE_NAME="85-build-missing-modstoml"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo
rm -f "$REPO/mods/demo/resources/META-INF/mods.toml"
fixture_build_commit

BEFORE_DIST="$(dist_dir_files)"

build_run demo
assert_rc 1
assert_contains "mods.toml"
assert_not_contains "产物："

CHECKED=$((CHECKED + 1))
if [ "$(dist_dir_files)" != "$BEFORE_DIST" ]; then
  fail "缺 mods.toml 时不该有产物，dist/ 变了"
fi

harness_done
