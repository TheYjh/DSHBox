#!/usr/bin/env bash
# 21-same-no-commit.sh — 同内容同文件名：不产生新提交（#15 第 3 条）
#
# 场景：已经归档过一次，再跑一遍完全相同的 deliver（dist 里还是那个 jar）。
# 期望：这次什么都不用做 —— 成品/ 无变化，`git rev-list --count HEAD` 前后相等。
# 这是「幂等性」这道门：交付脚本只要在没变化时仍然提交，这个用例就红。

CASE_NAME="21-same-no-commit"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"

# 第一次交付：真正产生一次提交。
deliver_run
assert_rc 0
assert_file "$REPO/$DEST"

AFTER_FIRST="$(git_count_commits)"
DEST_HASH_AFTER_FIRST="$(sha256sum -- "$REPO/$DEST" | cut -d' ' -f1)"
tree_snapshot

# 第二次交付：输入完全相同，什么都不该发生。
deliver_run
assert_rc 0

# [不变] 打的是目标文件名（成品侧的名字），带前后缀，不是 dist 里的源名。
assert_contains "[不变] $EXPECTED（内容与文件名均一致）"
assert_not_contains "[新增] demo-1.2.3.jar"
assert_contains "成品/ 无变化，不产生提交。"

assert_head_unchanged "$AFTER_FIRST"
assert_tree_unchanged
assert_git_clean

# 归档文件本身也没被重写（内容哈希不变）。
CHECKED=$((CHECKED + 1))
now_hash="$(sha256sum -- "$REPO/$DEST" 2>/dev/null | cut -d' ' -f1)"
if [ "$now_hash" != "$DEST_HASH_AFTER_FIRST" ]; then
  fail "重复交付后归档文件内容变了：$DEST_HASH_AFTER_FIRST → ${now_hash:-（文件不见了）}"
fi

# 再跑一次 --check：同样不产生提交。
BEFORE_CHECK="$(git_count_commits)"
deliver_run --check
assert_rc 0
assert_head_unchanged "$BEFORE_CHECK"
assert_git_clean

harness_done
