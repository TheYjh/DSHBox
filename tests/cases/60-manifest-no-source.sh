#!/usr/bin/env bash
# 60-manifest-no-source.sh — 清单标注无源码产物（issue #19 第 3、4 条）
#
# 规则出处：AGENTS.md「无源码产物是资产」——jar 没有对应 mods/<modId>/src 时，
# 删了就再也造不出来，清单里必须标 `无源码`，让读者知道这一行不能按源码重建。
#
# 场景：目录里同时有
#   - legacy：没有 mods/legacy/src 的 jar（无源码资产）
#   - demo  ：有 mods/demo/src 的 jar（本次入参，靠 deliver 归档）
# 断言「源码」列按**实际目录状态**推导：对每个 jar，看 mods/<modId>/src 在不在，
# 期望值就是它；逐行比对清单里的那一列。用例里不写死哪一行是什么。
#
# 断言：
#   - 无源码的 legacy 行标「无源码」
#   - 有源码的 demo 行标「有」
#   - 每一行的源码列都与 mods/<modId>/src 的实际存在性一致（不漂移）
#   - 变更后的清单被提交（派生清单跟着交付走）

CASE_NAME="60-manifest-no-source"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

printf 'demo|GOD|示例交付\nlegacy|辅助|历史遗留\n' | fixture_naming
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"

# demo 有源码（deliver 会归档它）；legacy 故意没有 mods/legacy/src。
fixture_source demo

LEGACY_NAME="$(naming_expected legacy 1.0.0)" || fatal "夹具命名表里查不到 legacy"
make_jar "成品/模组/$LEGACY_NAME" legacy 1.0.0 "历史遗留" MIT
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置无源码历史产物" || fatal "夹具预置提交失败"

# 硬前提：legacy 确实没有源码目录，demo 确实有。
# 否则这条用例测不到「无源码」这条分支，会假绿。
CHECKED=$((CHECKED + 1))
if [ -d "$REPO/mods/legacy/src" ]; then
  fail "前置条件不成立：mods/legacy/src 不该存在"
fi
CHECKED=$((CHECKED + 1))
if [ ! -d "$REPO/mods/demo/src" ]; then
  fail "前置条件不成立：mods/demo/src 应该存在"
fi

DELIVER_NAME="$(naming_expected demo 1.1.0)" || fatal "夹具命名表里查不到 demo"
make_jar dist/demo-1.1.0.jar demo 1.1.0 "示例交付" MIT

deliver_run
assert_rc 0
assert_contains "已生成：成品/文档/模组清单.md"
assert_file "$REPO/成品/模组/$LEGACY_NAME"
assert_file "$REPO/成品/模组/$DELIVER_NAME"

# 具体到两个关键行（错误信息最好读）。
CHECKED=$((CHECKED + 1))
LEGACY_SRC="$(manifest_source_of "$LEGACY_NAME")" || fail "清单里找不到无源码的 $LEGACY_NAME"
if [ "$LEGACY_SRC" != "无源码" ]; then
  fail "无源码产物的源码列应为「无源码」，实际是「$LEGACY_SRC」（$LEGACY_NAME）"
fi

CHECKED=$((CHECKED + 1))
DEMO_SRC="$(manifest_source_of "$DELIVER_NAME")" || fail "清单里找不到有源码的 $DELIVER_NAME"
if [ "$DEMO_SRC" != "有" ]; then
  fail "有源码产物的源码列应为「有」，实际是「$DEMO_SRC」（$DELIVER_NAME）"
fi

# 逐行对照：清单的源码列必须与 mods/<modId>/src 的实际存在性一致。
# 从清单自己的行推导，不写死行数与内容。
CHECKED=$((CHECKED + 1))
MISMATCH=""
while IFS='|' read -r name modid; do
  [ -n "$name" ] || continue
  actual="$(manifest_source_of "$name")" || { MISMATCH="$MISMATCH ${name}(清单缺行)"; continue; }
  if [ -d "$REPO/mods/$modid/src" ]; then
    expect="有"
  else
    expect="无源码"
  fi
  if [ "$actual" != "$expect" ]; then
    MISMATCH="$MISMATCH ${name}(列=$actual 实况=$expect)"
  fi
done < <(manifest_file_modid_pairs)
if [ -n "$MISMATCH" ]; then
  fail "清单源码列与实际源码状态不一致：$MISMATCH"
fi

# 清单是派生文件，跟着这次交付一起进提交。
assert_last_commit_touches "成品/文档/模组清单.md"
assert_last_commit_touches "成品/模组/$DELIVER_NAME"
assert_git_clean

harness_done
