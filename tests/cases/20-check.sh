#!/usr/bin/env bash
# 20-check.sh — `--check` 只报告、零改动（#15 第 2 条 / spec #14 User Story 8）
#
# 断言：
#   - --check 报告「会归档什么」（[新增] + 由夹具命名表推导出的目标文件名）
#   - --check 之后整棵工作树（排除 .git）的哈希指纹与之前**完全一致**
#   - 成品里没多出 jar，没产生提交，工作树干净
#   - 场景二：已经归档过、dist 里的同版本 jar 内容又变了，--check 仍然一个字节不动

CASE_NAME="20-check"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# 真实仓库里 成品/模组、成品/文档 已存在；夹具照此预建，
# 避免把 deliver 开头的 mkdir -p 误算成「--check 改了东西」。
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"

tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run --check
assert_rc 0
assert_contains "归档计划（内容哈希 + 文件名两键比对）"
assert_contains "[新增] demo-1.2.3.jar  →  成品/模组/$EXPECTED"
assert_contains "--check：仅报告，未改动任何文件。"
assert_not_contains "已归档："

assert_no_file "$REPO/成品/模组/$EXPECTED"
assert_tree_unchanged
assert_head_unchanged "$BEFORE_COMMITS"
assert_git_clean

# ---------- 场景二：已归档过一次，dist 被重建为「同版本、不同内容」 ----------

deliver_run
assert_rc 0
assert_file "$REPO/成品/模组/$EXPECTED"
assert_content_same "$REPO/dist/demo-1.2.3.jar" "$REPO/成品/模组/$EXPECTED"

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" Apache-2.0
tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run --check
assert_rc 0
assert_contains "[冲突] demo-1.2.3.jar"
assert_not_contains "已归档："
assert_not_contains "已覆盖（--overwrite）："
assert_tree_unchanged
assert_head_unchanged "$BEFORE_COMMITS"
assert_git_clean

harness_done
