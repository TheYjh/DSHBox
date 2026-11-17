#!/usr/bin/env bash
# 83-build-then-deliver.sh — 从构建到归档的端到端路径（#10 第 1、3、6 条）
#
# 这是整张票的主干：开发者先构建，再从统一成品目录拿到带前缀的最终 jar。
# 单独测构建、单独测归档都不足以证明这条链路真的接上了 ——
# 这条用例让两者在同一个仓库里先后跑，断言最终落位的是**同一个 jar 内容**。
#
# 断言：
#   - 构建产物落 dist/demo-0.4.0.jar（中性名）
#   - 不带参数跑 deliver：把它归档成 成品/模组/[自制-<域>-<描述>]demo-0.4.0.jar
#   - 归档内容与 dist/ 里的产物逐字节一致（deliver 是改名，不是重新打包）
#   - 验证 jar 仍在 dist/ 里（归档不搬走原件）
#   - 一次提交，工作树干净，改动触达归档路径

CASE_NAME="83-build-then-deliver"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo
fixture_build_commit

BUILD_MOD_VERSION="0.4.0"
build_run demo
assert_rc 0
assert_file "$REPO/dist/demo-0.4.0.jar"

EXPECTED="$(naming_expected demo 0.4.0)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"
BEFORE_COMMITS="$(git_count_commits)"

# 无参数 = 从 dist/*.jar 取输入，这正是开发者的默认路径。
deliver_run
assert_rc 0

assert_file "$REPO/$DEST"
assert_contains "已归档：成品/模组/$EXPECTED"
assert_content_same "$REPO/dist/demo-0.4.0.jar" "$REPO/$DEST"

# 验证 jar 必须留在 dist/：它和成品 jar 是两份，前者供本地复核。
assert_file "$REPO/dist/demo-0.4.0.jar"

# 成品目录里只该有这一个 jar，且它带前缀、带 modId、带版本号。
CHECKED=$((CHECKED + 1))
mapfile -t ARCHIVED < <(mod_dir_jars)
if [ "${#ARCHIVED[@]}" -ne 1 ] || [ "${ARCHIVED[0]}" != "$EXPECTED" ]; then
  fail "成品/模组 期望只有 $EXPECTED，实际：${ARCHIVED[*]:-（空）}"
fi

assert_head_increased "$BEFORE_COMMITS"
assert_last_commit_touches "成品/模组/$EXPECTED"
assert_git_clean

harness_done
