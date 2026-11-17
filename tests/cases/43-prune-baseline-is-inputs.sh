#!/usr/bin/env bash
# 43-prune-baseline-is-inputs.sh — 比较基准是本次入参，不是整个成品目录（issue #17 第 4 条）
#
# deliver 的清理候选是拿「本次将要归档的目标名」去跟目录里已有的 jar 比，
# 而不是扫全目录找各 modId 的最大版本。所以：
#   - 目录里有 other 的 1.0.0 与 2.0.0 两份、other 也有源码，但本次入参里没有 other
#     → other 的旧版**一个候选都不产生**；
#   - 一个入参都没有（dist/ 为空）→ 即使目录里有更旧版本，也是零候选。
#
# 这条防的是将来有人「顺手」把候选判定改成「扫全目录按最大版本清」：那样 other-1.0.0
# 会在一次与它无关的交付里被删掉。
#
# 断言：
#   - 只交付 demo 时，候选段落里有 demo 的旧版、没有 other 的任何文件
#   - 没有新产物时输出「可清理的旧产物：无」，且不加 --prune 时文件全在
#   - 全程没有任何删除提交

CASE_NAME="43-prune-baseline-is-inputs"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

printf 'demo|GOD|示例交付\nother|工具|另一个模组\n' | fixture_naming
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
# 两个 modId 都有源码 —— 所以「other 不进候选」不是因为无源码，而是因为本次没给它的入参。
fixture_source demo
fixture_source other

DEMO_OLD="$(naming_expected demo 1.0.0)" || fatal "夹具命名表里查不到 demo"
OTHER_OLD="$(naming_expected other 1.0.0)" || fatal "夹具命名表里查不到 other"
OTHER_NEW="$(naming_expected other 2.0.0)" || fatal "夹具命名表里查不到 other"

# 成品目录里预置 other 的两代产物（旧 + 新）以及 demo 的旧版。
make_jar "成品/模组/$OTHER_OLD" other 1.0.0 "另一个模组" MIT
make_jar "成品/模组/$OTHER_NEW" other 2.0.0 "另一个模组" MIT
make_jar "成品/模组/$DEMO_OLD" demo 1.0.0 "示例交付" MIT
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置其他 modId 的两代产物" || fatal "夹具预置提交失败"

# 从「可清理的旧产物」到「不可再生资产」之间的正文切片。

# ---------- 场景一：本次只交付 demo 的更高版本 ----------

make_jar dist/demo-1.1.0.jar demo 1.1.0 "示例交付" MIT
DEMO_NEW="$(naming_expected demo 1.1.0)" || fatal "夹具命名表里查不到 demo"

# 硬前提：other 确实有源码、且旧版确实被同目录里的新版取代 ——
# 否则「other 不进候选」可能只是因为它本来就不符合条件。
CHECKED=$((CHECKED + 1))
if [ ! -d "$REPO/mods/other/src" ]; then
  fail "夹具里 other 应当有源码（否则测不出「基准是入参」这一点）"
fi

COMMITS_BEFORE="$(git_count_commits)"
deliver_run
assert_rc 0

CAND="$(candidate_section)"
CHECKED=$((CHECKED + 1))
case "$CAND" in
  *"$DEMO_OLD"*) : ;;
  *) fail "demo 的旧版应出现在候选里，实际候选段落：${CAND:-（空）}" ;;
esac
CHECKED=$((CHECKED + 1))
case "$CAND" in
  *"$OTHER_OLD"*) fail "本次没给 other 的入参，它的旧版不该进候选：$CAND" ;;
esac
CHECKED=$((CHECKED + 1))
case "$CAND" in
  *"$OTHER_NEW"*) fail "本次没给 other 的入参，它不该进候选：$CAND" ;;
esac

# 文件系统：other 的两代产物都原样在盘上。
assert_file "$REPO/成品/模组/$OTHER_OLD"
assert_file "$REPO/成品/模组/$OTHER_NEW"
assert_file "$REPO/成品/模组/$DEMO_OLD"
assert_file "$REPO/成品/模组/$DEMO_NEW"

CHECKED=$((CHECKED + 1))
DELETED="$(git -C "$REPO" -c core.quotepath=false diff-tree --no-commit-id --name-status -r HEAD 2>/dev/null | awk '$1 ~ /^D/ {print $2}')"
if [ -n "$DELETED" ]; then
  fail "默认交付里不该有删除，实际删除了：$DELETED"
fi

# ---------- 场景二：一个入参都不给（dist/ 为空）→ 零候选 ----------

rm -f "$REPO"/dist/*.jar

tree_snapshot
COMMITS_BEFORE="$(git_count_commits)"

deliver_run
assert_rc 0
assert_contains "没有新产物"
assert_contains "可清理的旧产物：无"

CAND="$(candidate_section)"
CHECKED=$((CHECKED + 1))
if printf '%s\n' "$CAND" | grep -q '→'; then
  fail "没有新产物时不该产生任何候选，实际候选段落：$CAND"
fi

# 目录里那些被「同 modId 更高版本」包围的旧版，一个都没被删。
assert_file "$REPO/成品/模组/$OTHER_OLD"
assert_file "$REPO/成品/模组/$DEMO_OLD"

# ---------- 场景三：没有新产物 + 加 --prune，仍然什么也不删 ----------

rm -f "$REPO"/dist/*.jar
tree_snapshot
COMMITS_BEFORE="$(git_count_commits)"

deliver_run --prune
assert_rc 0
assert_contains "可清理的旧产物：无"
assert_not_contains "已删除"
assert_file "$REPO/成品/模组/$OTHER_OLD"
assert_file "$REPO/成品/模组/$DEMO_OLD"
assert_tree_unchanged
assert_head_unchanged "$COMMITS_BEFORE"
assert_git_clean

harness_done
