#!/usr/bin/env bash
# 50-push-fail-keeps-commit.sh — 推送失败：本地提交保留、非零退出、不回滚（#18 第 3 条）
#
# 场景：把夹具的 origin 指到一个**不存在的本地路径**（不删 origin —— 删了会走
#       「没有上游」的另一条分支），再造一个新产物逼脚本必须提交。
# 期望：push 三次都失败 → 退出码非零；那个提交仍留在 git log 里；
#       裸仓库的 main 一动不动（什么都没推上去）；工作树仍是干净的。
#
# deliver 在 push 失败时会 `sleep 2` / `sleep 4` 再重试，本用例会慢约 6 秒。
# 全程离线：失败目标是沙箱里的本地路径，不是 URL、不是域名。

CASE_NAME="50-push-fail-keeps-commit"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# 先正常交付一个版本，让远端有一个基准 commit。
make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
deliver_run
assert_rc 0
assert_remote_ref main "$(git -C "$REPO" rev-parse HEAD)"

BEFORE_FAIL="$(git_count_commits)"
REMOTE_BEFORE_FAIL="$(git_remote_ref main)" || fatal "读不到裸仓库的 main"

# 让 push 必然失败。
remote_break

# 新产物 → 脚本必须提交。
make_jar dist/demo-1.2.4.jar demo 1.2.4 "示例交付" MIT

deliver_run
# 非零退出：推送失败不能被当成成功。
CHECKED=$((CHECKED + 1))
if [ "$RC" -eq 0 ]; then
  fail "推送必然失败，deliver 却以 0 退出"
fi
assert_contains "推送失败（已重试 2 次）"
assert_contains "未回滚"

# 提交仍在：本地历史往前走了，且 HEAD 就是这次归档产生的提交。
assert_head_increased "$BEFORE_FAIL"
assert_contains "已提交："

CHECKED=$((CHECKED + 1))
subject="$(git -C "$REPO" log -1 --pretty=%s)"
case "$subject" in
  "chore(成品): 归档 "*) ;;
  *) fail "HEAD 的提交消息不像这次归档产生的：「$subject」" ;;
esac

# 裸仓库没收到任何东西：main 还停在失败前的位置。
assert_remote_ref main "$REMOTE_BEFORE_FAIL"

# 工作树干净：提交把该收的都收了，没有留下半截状态。
assert_git_clean

harness_done
