#!/usr/bin/env bash
# 40-prune-report-only.sh — 默认只报告，不加 --prune 绝不删（issue #17 第 1、3 条）
#
# 场景：demo 有源码，先归档 1.0.0，再交付 1.1.0。旧版已被新版取代，
# 但它只能出现在「可清理」报告里；不加 --prune 时文件必须原样留在盘上，
# 最新一次提交里也不许出现删除。
#
# 断言：
#   - 输出里有「可清理的旧产物」段落与「仅报告，未删除（要删加 --prune）」
#   - 旧 jar 仍在、新 jar 落位、两份并存
#   - 归档那次提交没有删除任何文件（无删除提交）
#   - 再跑一次 --check：候选照样报告，整棵树（排除 .git）一个字节不变、无新提交

CASE_NAME="40-prune-report-only"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# 真实仓库里 成品/模组、成品/文档 已存在；夹具对齐。
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
# 有源码 = 可重建 = 才可能进清理候选（见 ADR 0001）。
fixture_source demo
make_jar dist/demo-1.0.0.jar demo 1.0.0 "示例交付" MIT
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置源码目录与 1.0.0 构建产物" || fatal "夹具预置提交失败"

OLD_NAME="$(naming_expected demo 1.0.0)" || fatal "夹具命名表里查不到 demo"
NEW_NAME="$(naming_expected demo 1.1.0)" || fatal "夹具命名表里查不到 demo"

# ---------- 场景一：正常交付 1.1.0，但不加 --prune ----------

deliver_run
assert_rc 0
assert_file "$REPO/成品/模组/$OLD_NAME"

# dist 里现在有 1.0.0 与 1.1.0；再跑一次默认交付，旧版被新版取代。
make_jar dist/demo-1.1.0.jar demo 1.1.0 "示例交付" MIT
COMMITS_BEFORE="$(git_count_commits)"

deliver_run
assert_rc 0

# 候选必须被报告出来（只断关键词，不钉整句标点）。
assert_contains "可清理的旧产物"
assert_contains "$OLD_NAME"
assert_contains "1.0.0 → 1.1.0"
assert_contains "仅报告，未删除"
assert_not_contains "已删除"

# 文件一个都没少：旧版留在盘上，新版落位，两份并存。
assert_file "$REPO/成品/模组/$OLD_NAME"
assert_file "$REPO/成品/模组/$NEW_NAME"
assert_content_same "$REPO/dist/demo-1.1.0.jar" "$REPO/成品/模组/$NEW_NAME"

# 这次交付产生了归档提交，但提交里不许有 D（删除）条目。
assert_head_increased "$COMMITS_BEFORE"
CHECKED=$((CHECKED + 1))
DELETED="$(git -C "$REPO" -c core.quotepath=false diff-tree --no-commit-id --name-status -r HEAD 2>/dev/null | awk '$1 ~ /^D/ {print $2}')"
if [ -n "$DELETED" ]; then
  fail "不加 --prune 的提交里不该有删除，实际删除了：$DELETED"
fi
assert_git_clean

# ---------- 场景二：再跑 --check，候选照样报告，但零改动 ----------

tree_snapshot
COMMITS_BEFORE="$(git_count_commits)"

deliver_run --check
assert_rc 0
assert_contains "可清理的旧产物"
assert_contains "1.0.0 → 1.1.0"
assert_contains "仅报告，未删除"
assert_not_contains "已删除"

assert_file "$REPO/成品/模组/$OLD_NAME"
assert_tree_unchanged
assert_head_unchanged "$COMMITS_BEFORE"
assert_git_clean

harness_done
