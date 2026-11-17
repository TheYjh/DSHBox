#!/usr/bin/env bash
# 24-conflict-overwrite.sh — 只有显式 --overwrite 才允许覆盖内容不同的目标（#12）
#
# 冲突的默认结局是整批中止（见 23）。这是一条显式的破例开关：带上 --overwrite，
# 同一个场景才允许把旧文件换成新内容，并且旧内容必须仍能从 git 历史取回
# （历史只前滚，见 docs/adr/0001）。
#
# 场景：
#   1. 正常归档 demo-1.2.3.jar(MIT)
#   2. dist 里的同名 jar 换成不同内容（换 license）
#   3. deliver --overwrite：这次才归档

CASE_NAME="24-conflict-overwrite"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"

deliver_run
assert_rc 0
assert_file "$REPO/$DEST"
COMMITS_AFTER_FIRST="$(git_count_commits)"
PREV_COMMIT="$(git -C "$REPO" rev-parse HEAD)"
OLD_HASH="$(sha256sum -- "$REPO/$DEST" | cut -d' ' -f1)"

# ---------- 同名不同内容 ----------

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" Apache-2.0
SRC_HASH="$(sha256sum -- "$REPO/dist/demo-1.2.3.jar" | cut -d' ' -f1)"
[ "$SRC_HASH" = "$OLD_HASH" ] && fatal "夹具没造出「内容不同」：新旧 jar 哈希相同"

deliver_run --overwrite
assert_rc 0

# 报告侧仍然把冲突讲清楚，只是处置分支变成「将覆盖」。
assert_contains "[冲突] demo-1.2.3.jar  →  成品/模组/$EXPECTED（目标已存在，内容不同）"
assert_contains "已启用 --overwrite"
assert_not_contains "整批中止"

# 落位：目标文件现在与源逐字节相同，且确实换掉了旧内容。
assert_contains "已覆盖（--overwrite）：成品/模组/$EXPECTED"
assert_file "$REPO/$DEST"
assert_content_same "$REPO/dist/demo-1.2.3.jar" "$REPO/$DEST"
CHECKED=$((CHECKED + 1))
NOW_HASH="$(sha256sum -- "$REPO/$DEST" | cut -d' ' -f1)"
[ "$NOW_HASH" = "$SRC_HASH" ] || fail "覆盖后内容不是新产物：期望 $SRC_HASH，实际 $NOW_HASH"

# 覆盖进了提交，且旧内容仍能从覆盖前的那个 commit 取回（历史只前滚）。
assert_head_increased "$COMMITS_AFTER_FIRST"
assert_last_commit_touches "$DEST"
git -C "$REPO" show "$PREV_COMMIT:$DEST" > "$SANDBOX/old-from-history.jar" 2>/dev/null \
  || true
assert_file "$SANDBOX/old-from-history.jar"
CHECKED=$((CHECKED + 1))
HIST_HASH="$(sha256sum -- "$SANDBOX/old-from-history.jar" 2>/dev/null | cut -d' ' -f1)"
[ "$HIST_HASH" = "$OLD_HASH" ] \
  || fail "覆盖前的旧内容没能从历史取回：期望 $OLD_HASH，实际 $HIST_HASH"

assert_git_clean

harness_done
