#!/usr/bin/env bash
# 50-push-nochange-ahead.sh — 无变化但本地有未推送提交：仍必须推（#18 第 2 条）
#
# 场景：交付过一次（已推送）后，在夹具里额外造一个**只在本地**的提交（不推），
#       然后跑一次「input 完全相同、成品无变化」的 deliver。
# 期望：脚本看出 `@{u}..HEAD` 非空 —— 虽然没有新产物可归档，
#       但它必须把已经存在的本地提交推上去。裸仓库的 main 要更新到本地 HEAD。
#
# 为什么这条必须存在：如果把 deliver 里「无变化 → exit 0」写得粗一点，
# 用户上一次 push 失败积压的本地提交就永远推不出去了。
# 全程离线：origin 是 fixture_repo 造的沙箱裸仓库。

CASE_NAME="50-push-nochange-ahead"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"

# 第一次交付：提交并推送，此时本地与远端同步。
deliver_run
assert_rc 0
assert_contains "已推送：origin main"
assert_remote_ref main "$(git -C "$REPO" rev-parse HEAD)"

AFTER_FIRST="$(git_count_commits)"

# 造一个只在本地、没推上去的提交（空提交，不动工作树）。
fixture_commit_offline "fixture: 上次没推上去的提交"
HEAD_AHEAD="$(git -C "$REPO" rev-parse HEAD)"
assert_head_increased "$AFTER_FIRST"
# 之后的 deliver 不该再动本地历史：以「离线提交之后」的提交数为基准。
AHEAD_COUNT="$(git_count_commits)"
tree_snapshot

# 远端此刻还停在上一次交付的 commit 上 —— 前提成立，否则这条用例测不到东西。
CHECKED=$((CHECKED + 1))
if [ "$(git_remote_ref main)" = "$HEAD_AHEAD" ]; then
  fail "前置条件不成立：夹具里那个离线提交竟然已经在远端上了"
fi

# 第二次交付：input 完全相同，成品/ 无变化。
deliver_run
assert_rc 0

# 最关键的一条：没提交，但推了。
assert_contains "成品/ 无变化，不产生提交。"
assert_head_unchanged "$AHEAD_COUNT"
assert_contains "本地有 1 个未推送的提交。"
assert_contains "已推送：origin main"

# 且真的推上去了：裸仓库的 main 就是本地 HEAD。
assert_remote_ref main "$HEAD_AHEAD"

assert_tree_unchanged
assert_git_clean

harness_done
