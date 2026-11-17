#!/usr/bin/env bash
# 50-push-nochange-synced.sh — 无变化且远端已同步：不提交、也不推送（#18 第 1 条）
#
# 场景：归档过一次（那次把提交推到了裸仓库），再跑一遍完全相同的 deliver。
# 期望：本地不产生新提交，**远端 ref 也一动不动**。
# 这条钉的是推送侧的语义，不是 21 的「幂等提交」——21 只看本地 HEAD，
# 这里额外要求 `git -C "$ORIGIN" rev-parse main` 前后相同：
# 脚本只要在没变化时仍然 push 一次，远端 ref 不变也说明不了问题，
# 所以同时要求输出里不出现推送动作的措辞。
# 全程离线：origin 是 fixture_repo 造的沙箱裸仓库。

CASE_NAME="50-push-nochange-synced"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"

# 第一次交付：提交并推送。
deliver_run
assert_rc 0
assert_file "$REPO/$DEST"
assert_contains "已推送：origin main"

AFTER_FIRST="$(git_count_commits)"
HEAD_AFTER_FIRST="$(git -C "$REPO" rev-parse HEAD)"
REMOTE_AFTER_FIRST="$(git_remote_ref main)" || fatal "读不到裸仓库的 main"

# 第一次就把本地状态推上去了：远端 main 必须等于本地 HEAD。
assert_remote_ref main "$HEAD_AFTER_FIRST"

tree_snapshot

# 第二次交付：输入完全相同。
deliver_run
assert_rc 0

# 本地：没有新提交。
assert_contains "成品/ 无变化，不产生提交。"
assert_head_unchanged "$AFTER_FIRST"

# 推送侧：既然没有新提交，就没有任何东西该被推。
# 输出里不该出现「已推送」，也不该出现「本地有 N 个未推送的提交」。
assert_not_contains "已推送：origin"
assert_not_contains "本地有 "

# 远端：ref 一动不动，仍指向第一次交付的那个 commit。
assert_remote_ref main "$REMOTE_AFTER_FIRST"

assert_tree_unchanged
assert_git_clean

harness_done
