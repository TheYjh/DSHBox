#!/usr/bin/env bash
# 74-plugin-sync-mirror-delete.sh — 镜像语义：目标里多余的已存在文件被删掉
#
# 场景：插件先同步一次（带 lib/extra.js、docs/guide.md），然后源里删掉这两个文件。
# 断言：
#   - 第二次同步把目标仓库里对应文件删掉（工作树里真的没有了）；
#   - 删除进提交（HEAD 的 diff 里有 D），且旧内容仍能 git show 取回（历史只前滚）；
#   - commit 信息只列真正变化的插件；
#   - 源里没删的文件一个没少（不是「先清空再复制」的粗暴做法）。

CASE_NAME="74-plugin-sync-mirror-delete"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/plugin-harness.sh"

ph_init
ph_repo

fixture_plugin mirror-play dsh-mirror-play 0.1.0 "镜像删除夹具。" \
  "lib/extra.js" "docs/guide.md"

ph_run
assert_rc 0
assert_file "$REPO/mirror-play/lib/extra.js"
assert_file "$REPO/mirror-play/docs/guide.md"
PREV_COMMIT="$(ph_repo_head)"
assert_head_increased 1

# 记下旧内容，后面要断言「仍能从历史取回」。
git -C "$REPO" show "$PREV_COMMIT:mirror-play/lib/extra.js" > "$SANDBOX/old-extra.js" 2>/dev/null \
  || fail "取不回旧文件内容（前置条件不成立）"

# 源里删掉这两个文件（模拟迭代中重构掉的文件）。
rm -f "$SRC/mirror-play/lib/extra.js" "$SRC/mirror-play/docs/guide.md"
rmdir "$SRC/mirror-play/docs" 2>/dev/null || true

COMMITS_BEFORE="$(ph_count_commits)"
ph_run
assert_rc 0

assert_contains "[更新] mirror-play"
assert_contains "删除多余文件：mirror-play/lib/extra.js"
assert_contains "删除多余文件：mirror-play/docs/guide.md"
assert_contains "已删除（镜像）：mirror-play/lib/extra.js"

# 工作树里真的没有了。
assert_no_file "$REPO/mirror-play/lib/extra.js"
assert_no_file "$REPO/mirror-play/docs/guide.md"
# 空目录也收掉了（不留下空壳）。
assert_no_file "$REPO/mirror-play/docs"

# 没被删的文件一个不少。
assert_file "$REPO/mirror-play/lib/index.js"
assert_file "$REPO/mirror-play/package.json"

# 删除进了提交，并且能从历史取回（历史只前滚）。
assert_head_increased "$COMMITS_BEFORE"
ph_assert_last_commit_touches "mirror-play/lib/extra.js"

CHECKED=$((CHECKED + 1))
if git -C "$REPO" cat-file -e "$PREV_COMMIT:mirror-play/lib/extra.js" 2>/dev/null; then
  :
else
  fail "被删文件在旧 commit 上取不到了：$PREV_COMMIT:mirror-play/lib/extra.js"
fi
git -C "$REPO" show "$PREV_COMMIT:mirror-play/lib/extra.js" > "$SANDBOX/restored.js" 2>/dev/null || true
assert_content_same "$SANDBOX/old-extra.js" "$SANDBOX/restored.js"

# 提交信息只列真正变化的插件。
assert_contains "chore(插件): 同步 mirror-play"
ph_assert_repo_clean

harness_done
