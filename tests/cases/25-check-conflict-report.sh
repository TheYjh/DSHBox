#!/usr/bin/env bash
# 25-check-conflict-report.sh — `--check` 如实报告冲突，但仍一个字节不动（#12）
#
# 冲突在默认路径下会让整批中止、退出码非零（见 23）。`--check` 不一样：
# 它本来就读完就退，所以冲突在此只作为「计划里的第三态」如实列出，
# 退出码仍是 0 —— 否则 `--check` 就没法当「先看看会发生什么」用了。
# `--check --overwrite` 同理：报告里说清「会覆盖」，但它依然不写。
#
# 场景：已归档 demo-1.2.3.jar，dist 里的同名 jar 换成不同内容。

CASE_NAME="25-check-conflict-report"
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
OLD_HASH="$(sha256sum -- "$REPO/$DEST" | cut -d' ' -f1)"

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" Apache-2.0
SRC_HASH="$(sha256sum -- "$REPO/dist/demo-1.2.3.jar" | cut -d' ' -f1)"
[ "$SRC_HASH" = "$OLD_HASH" ] && fatal "夹具没造出「内容不同」：新旧 jar 哈希相同"

# ---------- --check：报告冲突，退出码 0，零改动 ----------

tree_snapshot
deliver_run --check
assert_rc 0

assert_contains "[冲突] demo-1.2.3.jar  →  成品/模组/$EXPECTED（目标已存在，内容不同）"
assert_contains "新增 0 个，未变 0 个，冲突 1 个"
assert_contains "冲突明细（目标文件名已存在，但内容与本次产物不同）："
assert_contains "本次产物 sha256：$SRC_HASH"
assert_contains "现目标文件   sha256：$OLD_HASH"
# --check 的处置分支必须点明「只报告」，不能让人以为它已经覆盖了。
assert_contains "--check：仅报告冲突，未改动任何文件"
assert_not_contains "已覆盖（--overwrite）："
assert_not_contains "已归档："
assert_not_contains "已生成：成品/文档/模组清单.md"

assert_tree_unchanged
assert_head_unchanged "$COMMITS_AFTER_FIRST"
assert_git_clean

# ---------- --check --overwrite：说清「会覆盖」，但依旧不写 ----------

tree_snapshot
deliver_run --check --overwrite
assert_rc 0

assert_contains "[冲突] demo-1.2.3.jar  →  成品/模组/$EXPECTED（目标已存在，内容不同）"
assert_contains "已启用 --overwrite"
assert_not_contains "已覆盖（--overwrite）：成品"

assert_tree_unchanged
assert_head_unchanged "$COMMITS_AFTER_FIRST"
assert_git_clean

# 旧产物仍原封不动 —— 两条 --check 都没碰过它。
CHECKED=$((CHECKED + 1))
NOW_HASH="$(sha256sum -- "$REPO/$DEST" | cut -d' ' -f1)"
[ "$NOW_HASH" = "$OLD_HASH" ] || fail "--check 期间旧产物被改写：$OLD_HASH → $NOW_HASH"

harness_done
