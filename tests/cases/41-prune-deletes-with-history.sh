#!/usr/bin/env bash
# 41-prune-deletes-with-history.sh — 加 --prune 才真删，且历史里取得回（issue #17 第 2、5 条）
#
# 场景：demo 有源码，已归档 1.0.0，再交付 1.1.0 并显式加 --prune。
# 旧 jar 必须消失、删除必须进提交，且被删文件仍能从 git 历史原样取回。
#
# 断言：
#   - 输出含「已启用 --prune」与「已删除（git rm）：<旧文件名>」
#   - 旧 jar 从工作树消失、新 jar 落位
#   - 产生新提交，删除动作被记进该提交（git log --diff-filter=D 能找到）
#   - 删除前的 commit 上 `git cat-file -e` / `git show <commit>:<path>` 仍能取回原内容，
#     且逐字节与删除前一致

CASE_NAME="41-prune-deletes-with-history"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
fixture_source demo
make_jar dist/demo-1.0.0.jar demo 1.0.0 "示例交付" MIT
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置源码目录与 1.0.0 构建产物" || fatal "夹具预置提交失败"

OLD_NAME="$(naming_expected demo 1.0.0)" || fatal "夹具命名表里查不到 demo"
NEW_NAME="$(naming_expected demo 1.1.0)" || fatal "夹具命名表里查不到 demo"
OLD_PATH="成品/模组/$OLD_NAME"

deliver_run
assert_rc 0
assert_file "$REPO/$OLD_PATH"

# 删除前留一份备份 + 记下「旧版还在」的那个 commit，稍后用它证明历史可回取。
cp "$REPO/$OLD_PATH" "$SANDBOX/pruned.jar" || fatal "无法备份待删 jar"
PREV_COMMIT="$(git -C "$REPO" rev-parse HEAD)"
COMMITS_BEFORE="$(git_count_commits)"

make_jar dist/demo-1.1.0.jar demo 1.1.0 "示例交付" MIT

deliver_run --prune
assert_rc 0

# 报告与执行：显式授权 + 真删。
assert_contains "可清理的旧产物"
assert_contains "已启用 --prune"
assert_contains "已删除（git rm）：$OLD_NAME"
assert_contains "$OLD_NAME"
assert_not_contains "仅报告，未删除"

# 工作树结果：旧版消失、新版落位。
assert_no_file "$REPO/$OLD_PATH"
assert_file "$REPO/成品/模组/$NEW_NAME"
assert_content_same "$REPO/dist/demo-1.1.0.jar" "$REPO/成品/模组/$NEW_NAME"

# 删除进了提交（历史只前滚）。
assert_head_increased "$COMMITS_BEFORE"
assert_last_commit_touches "$OLD_PATH"

CHECKED=$((CHECKED + 1))
DEL_COMMIT="$(git -C "$REPO" -c core.quotepath=false log --diff-filter=D --format=%H -1 -- "$OLD_PATH" 2>/dev/null)"
if [ -z "$DEL_COMMIT" ]; then
  fail "git log --diff-filter=D 找不到删除 $OLD_PATH 的提交"
fi

# 被删文件仍可从历史取回：删除前的 commit 上对象存在，且内容逐字节一致。
CHECKED=$((CHECKED + 1))
if ! git -C "$REPO" cat-file -e "$PREV_COMMIT:$OLD_PATH" 2>/dev/null; then
  fail "git cat-file -e 找不到 $PREV_COMMIT:$OLD_PATH —— 被删文件没能从历史取回"
fi

git -C "$REPO" show "$PREV_COMMIT:$OLD_PATH" > "$SANDBOX/restored.jar" 2>/dev/null || true
assert_content_same "$SANDBOX/pruned.jar" "$SANDBOX/restored.jar"

assert_git_clean

harness_done
