#!/usr/bin/env bash
# 50-push-fail-no-rollback.sh — 推送失败后工作树不能被回滚（#18 第 4 条）
#
# 与 50-push-fail-keeps-commit 同一个场景（origin 指向不存在的本地路径 → push 必失败），
# 但这里只钉「工作树/磁盘状态」这一面，与「提交还在不在」分开断言：
#   * 归档文件仍然躺在 成品/模组/ 里，内容与原 jar 逐字节相同；
#   * 它已经被那次提交收进去了（在 HEAD 的树里，不是散落在工作树）；
#   * `git status` 干净 —— 没有被回滚成「已删除」或「未跟踪」；
#   * 事后无论再跑什么，目录内容都不再变化（没有延迟回滚 / 清理逻辑）。
#
# 「失败就回滚到推送前」是这类脚本最诱人的错误实现：它让退出码看着一样，
# 却把用户刚归档好的成品悄悄丢掉。所以这条必须与第 3 条分开存在。
# 全程离线：失败目标是沙箱里的本地路径。

CASE_NAME="50-push-fail-no-rollback"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"

deliver_run
assert_rc 0
assert_remote_ref main "$(git -C "$REPO" rev-parse HEAD)"
REMOTE_BEFORE_FAIL="$(git_remote_ref main)"

# 失败前把整棵树拍下来。
tree_snapshot

remote_break

make_jar dist/demo-1.2.4.jar demo 1.2.4 "示例交付" MIT
EXPECTED_NEW="$(naming_expected demo 1.2.4)" || fatal "夹具命名表里查不到 demo 1.2.4"
DEST_NEW="成品/模组/$EXPECTED_NEW"
SRC_HASH="$(sha256sum -- "$REPO/dist/demo-1.2.4.jar" | cut -d' ' -f1)"

deliver_run
CHECKED=$((CHECKED + 1))
if [ "$RC" -eq 0 ]; then
  fail "推送必然失败，deliver 却以 0 退出"
fi

# 1) 归档文件仍在盘上，且内容与原 jar 一致（不是被截断/被清掉）。
assert_file "$REPO/$DEST_NEW"
CHECKED=$((CHECKED + 1))
disk_hash="$(sha256sum -- "$REPO/$DEST_NEW" 2>/dev/null | cut -d' ' -f1)"
if [ "$disk_hash" != "$SRC_HASH" ]; then
  fail "推送失败后归档文件内容与原 jar 不一致：$SRC_HASH → ${disk_hash:-（文件不见了）}"
fi

# 2) 它在那次提交里 —— 是「已提交」而不是「工作树里没人管的散落文件」。
#    路径含中文，必须关掉 core.quotepath，否则 git 会把路径转义成 \345\210...。
CHECKED=$((CHECKED + 1))
if ! git -C "$REPO" -c core.quotepath=false ls-tree -r --name-only HEAD | grep -qxF "$DEST_NEW"; then
  fail "推送失败后 $DEST_NEW 不在 HEAD 的树里 —— 提交没建成或没把它收进去"
fi

# 3) 工作树干净：文件不是「未跟踪」也不是「已删除待提交」，说明没被回滚。
assert_git_clean

# 4) 再做一次指纹快照：新产物在里面；随后任何操作都不让内容变回去。
tree_snapshot
CHECKED=$((CHECKED + 1))
if ! hash_tree_lines "$REPO" "$TREE_EXCLUDE" | grep -qF " ./$DEST_NEW "; then
  fail "快照里找不到 $DEST_NEW —— 目录状态被回滚了"
fi

deliver_run --check
assert_rc 0
assert_tree_unchanged
assert_git_clean

# 远端始终没收到这个提交。
assert_remote_ref main "$REMOTE_BEFORE_FAIL"

harness_done
