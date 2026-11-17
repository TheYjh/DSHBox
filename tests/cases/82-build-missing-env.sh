#!/usr/bin/env bash
# 82-build-missing-env.sh — 缺依赖 jar 时必须在编译前失败（#10 第 5 条）
#
# 这条锁的是「错误信息说清缺什么」。依赖靠环境变量传，一旦没传，
# javac 会报一堆莫名其妙的符号找不到 —— 比直接说「需要 MC_JAR」难查得多。
#
# 断言：
#   - 缺 MC_JAR → 退出码非零，信息点名 MC_JAR，无产物
#   - 缺 FORGE_JAR → 退出码非零，信息点名 FORGE_JAR，无产物
#   - 两种情况都不写 dist/

CASE_NAME="82-build-missing-env"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo
fixture_build_commit

BEFORE_DIST="$(dist_dir_files)"

BUILD_MC_JAR=""
build_run demo
assert_rc 1
assert_contains "MC_JAR"
assert_not_contains "产物："
CHECKED=$((CHECKED + 1))
if [ "$(dist_dir_files)" != "$BEFORE_DIST" ]; then
  fail "缺 MC_JAR 时不该有产物，dist/ 变了"
fi

# 恢复 MC_JAR，改成缺 FORGE_JAR，确认第二个依赖也被单独守住。
BUILD_MC_JAR="$SANDBOX/deps/mc.jar"
BUILD_FORGE_JAR=""
build_run demo
assert_rc 1
assert_contains "FORGE_JAR"
assert_not_contains "产物："
CHECKED=$((CHECKED + 1))
if [ "$(dist_dir_files)" != "$BEFORE_DIST" ]; then
  fail "缺 FORGE_JAR 时不该有产物，dist/ 变了"
fi

harness_done
