#!/usr/bin/env bash
# 60-manifest-coverage.sh — 清单与成品目录双向一一对应（issue #19 第 2、5 条）
#
# 核心：清单是**遍历成品目录**生成的派生物。两个方向都必须成立，缺一个就会撒谎：
#   (a) 清单里每一行，都能在 成品/模组/ 找到同名文件（没有「文档写了但目录没有」）；
#   (b) 成品/模组/ 里每一个 .jar，都能在清单里找到对应行（没有「目录有但文档漏了」）。
#
# 场景刻意让**本次入参只有 demo 一个新 jar**，而目录里还有两个历史产物
# （other 有源码、legacy 无源码，都是之前交付进去的、本次没作为入参）。
# 如果将来有人把清单生成改成「只列本次入参」，(b) 立刻崩 —— 这正是要钉住的退化。
#
# 断言全部从**目录实际状态**推导：目录里有什么 jar、清单里有什么行，两边 diff 必须为空。
# 用例里没有写死清单内容，也没有写死模组数量。

CASE_NAME="60-manifest-coverage"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

printf 'demo|GOD|示例交付\nother|工具|另一个模组\nlegacy|辅助|历史遗留\n' | fixture_naming
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"

# other 有源码（可重建），legacy 故意没有（不可再生资产）。
fixture_source other

OTHER_OLD="$(naming_expected other 1.0.0)" || fatal "夹具命名表里查不到 other"
LEGACY_OLD="$(naming_expected legacy 1.0.0)" || fatal "夹具命名表里查不到 legacy"

# 直接摆进 成品/模组（模拟历史交付），不经过 deliver。
make_jar "成品/模组/$OTHER_OLD" other 1.0.0 "另一个模组" MIT
make_jar "成品/模组/$LEGACY_OLD" legacy 1.0.0 "历史遗留" MIT
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置两个历史产物（本次不是入参）" || fatal "夹具预置提交失败"

# 硬前提：本次入参只有一个 demo jar，两个历史产物不在 dist/ 里。
# 否则测不到「清单必须覆盖非入参的历史产物」这条语义。
make_jar dist/demo-1.1.0.jar demo 1.1.0 "示例交付" MIT
CHECKED=$((CHECKED + 1))
DIST_JARS="$(cd "$REPO" && find dist -maxdepth 1 -name '*.jar' -printf '%f\n' | LC_ALL=C sort)"
if [ "$DIST_JARS" != "demo-1.1.0.jar" ]; then
  fail "前置条件不成立：本次入参应只有 demo-1.1.0.jar，实际 [$DIST_JARS]"
fi

deliver_run
assert_rc 0
assert_contains "已生成：成品/文档/模组清单.md"
assert_file "$(manifest_path)"

# ---------- (a) 清单 → 目录：每一行都要有对应文件 ----------

CHECKED=$((CHECKED + 1))
MISSING=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  [ -f "$REPO/成品/模组/$name" ] || MISSING="$MISSING $name"
done < <(manifest_rows)
if [ -n "$MISSING" ]; then
  fail "清单里有行但成品目录找不到文件：$MISSING"
fi

# 反向也看一眼：清单行数不能是 0（否则上面的循环空转就绿了）。
CHECKED=$((CHECKED + 1))
ROW_COUNT="$(manifest_rows | grep -c . || true)"
if [ "${ROW_COUNT:-0}" -lt 1 ]; then
  fail "清单里一行数据都没有（成品目录里明明有 jar）"
fi

# ---------- (b) 目录 → 清单：每一个 jar 都要有对应行 ----------

CHECKED=$((CHECKED + 1))
UNLISTED=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  if ! manifest_rows | grep -qxF -- "$name"; then
    UNLISTED="$UNLISTED $name"
  fi
done < <(mod_dir_jars)
if [ -n "$UNLISTED" ]; then
  fail "成品目录里有 jar 但清单里没有对应行：$UNLISTED"
fi

# ---------- 双向 diff 必须为空（同一件事的显式形式） ----------

CHECKED=$((CHECKED + 1))
DIFF_OUT="$(diff -u <(mod_dir_jars) <(manifest_rows) || true)"
if [ -n "$DIFF_OUT" ]; then
  fail "成品目录与清单不是一一对应：
$DIFF_OUT"
fi

# ---------- 具体到本次归档的那个也必须对上（防止两边都空） ----------

DEMO_NEW="$(naming_expected demo 1.1.0)" || fatal "夹具命名表里查不到 demo"
assert_file "$REPO/成品/模组/$DEMO_NEW"
CHECKED=$((CHECKED + 1))
if ! manifest_rows | grep -qxF -- "$DEMO_NEW"; then
  fail "当次归档的 $DEMO_NEW 没进清单"
fi
# 两个历史产物也必须仍在清单里（它们不是本次入参，但目录里有）。
CHECKED=$((CHECKED + 1))
for n in "$OTHER_OLD" "$LEGACY_OLD"; do
  if ! manifest_rows | grep -qxF -- "$n"; then
    fail "目录里的历史产物 $n 没进清单 —— 清单不该只列本次入参"
  fi
done

# 清单变了就要进提交；清单和 jar 在同一个提交里（一次交付 = 一个自洽快照）。
assert_last_commit_touches "成品/文档/模组清单.md"
assert_last_commit_touches "成品/模组/$DEMO_NEW"
assert_git_clean

harness_done
