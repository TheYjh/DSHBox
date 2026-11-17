#!/usr/bin/env bash
# 22-rename-is-change.sh — 内容相同但目标文件名不同：仍算变化（#15 第 4 条）
#
# 「同内容 + 同目标名」才算不变（见 21）。只要命名表让目标文件名变了，
# 即使 jar 一个字节没改，这次交付也必须落位并产生新提交 ——
# 否则改名会变成静默丢件。
#
# 场景：
#   1. 正常归档 demo-1.2.3.jar → 成品/模组/[自制-GOD-示例交付]demo-1.2.3.jar
#   2. 只改夹具 NAMING.md 的描述列（示例交付 → 示例改名），jar 不动
#   3. 再交付：新文件名落位、产生新提交；旧文件作为「无源码资产」留在原处

CASE_NAME="22-rename-is-change"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
OLD_NAME="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
OLD_DEST="成品/模组/$OLD_NAME"

deliver_run
assert_rc 0
assert_file "$REPO/$OLD_DEST"
COMMITS_AFTER_FIRST="$(git_count_commits)"
JAR_HASH="$(sha256sum -- "$REPO/dist/demo-1.2.3.jar" | cut -d' ' -f1)"

# ---------- 只改命名表的描述列，jar 与版本都不动 ----------

naming_set_desc demo "示例改名"

NEW_NAME="$(naming_expected demo 1.2.3)" || fatal "改名后夹具命名表里查不到 demo"
NEW_DEST="成品/模组/$NEW_NAME"

CHECKED=$((CHECKED + 1))
if [ "$NEW_NAME" = "$OLD_NAME" ]; then
  fail "改描述列之后目标文件名没变（$NEW_NAME）——夹具没造出「条目不同」的场景"
fi

# jar 内容确实没变：这条用例要证的正是「内容相同、名字不同」。
CHECKED=$((CHECKED + 1))
now_jar_hash="$(sha256sum -- "$REPO/dist/demo-1.2.3.jar" | cut -d' ' -f1)"
if [ "$now_jar_hash" != "$JAR_HASH" ]; then
  fail "改名场景里 jar 内容不该变：$JAR_HASH → $now_jar_hash"
fi

deliver_run
assert_rc 0

# 新文件名必须落位，且内容与原 jar 一致。
assert_file "$REPO/$NEW_DEST"
assert_content_same "$REPO/dist/demo-1.2.3.jar" "$REPO/$NEW_DEST"
assert_contains "已归档：成品/模组/$NEW_NAME"

# 这次是「新增」，不是「不变」——内容哈希相同但文件名不同，两键比对必须判为变化。
assert_contains "  新增 1 个，未变 0 个"

# 必须产生新提交，且该提交确实带上了新落位的文件。
assert_head_increased "$COMMITS_AFTER_FIRST"
assert_last_commit_touches "成品/模组/$NEW_NAME"
assert_git_clean

# 旧文件是无源码资产：deliver 不会自动删，只能留在原处（规则见 AGENTS.md / ADR 0001）。
assert_file "$REPO/$OLD_DEST"
# 断具体那一行（[无源码] <旧目标名>），而不是只断段落标题——标题是无条件打印的，
# 只断标题等于断了一条恒真式。
assert_contains "[无源码] $OLD_NAME"

# 顺带确认：这条路径没有走成「覆盖同名文件」，两个名字现在是并存的。
CHECKED=$((CHECKED + 1))
count="$(cd "$REPO" && find 成品/模组 -maxdepth 1 -name '*demo-1.2.3.jar' -printf 'x\n' | wc -l)"
if [ "$count" -ne 2 ]; then
  fail "期望成品/模组 里并存两份 demo-1.2.3.jar（旧名 + 新名），实际 $count 份"
fi

harness_done
