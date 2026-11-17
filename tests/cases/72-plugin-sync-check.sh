#!/usr/bin/env bash
# 72-plugin-sync-check.sh — --check 只报告，一个字节都不改
#
# 场景：目标仓库里已经有一份更早的插件（内容与源不同），另有一个插件是新增。
# 断言：
#   - --check 退出码 0；
#   - 报告里同时出现 [新增] / [更新] / [不变] 三态，以及「将删除的多余文件」；
#   - 整棵目标仓库（排除 .git）的哈希指纹前后完全一致；
#   - 提交数不变、工作树干净、远端 main 不动；
#   - README 表格如果会变，报告要说明（本夹具里表格确实会变）。
#   - 目标仓库不存在时 --check 也不克隆（只报告「按首次同步」的计划）。

CASE_NAME="72-plugin-sync-check"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/plugin-harness.sh"

ph_init
ph_repo

# three 个插件：alpha 会更新、beta 会新增、gamma 不变（目标里已有一模一样的）。
fixture_plugin alpha dsh-alpha-plugin 0.2.0 "会被更新的插件。" "lib/extra.js"
fixture_plugin beta dsh-beta-plugin 0.1.0 "会被新增的插件。"
fixture_plugin gamma dsh-gamma-plugin 0.3.0 "内容一致、应当不变。"

# 直接摆出目标仓库的「旧状态」（不经 deliver-plugin，避免测到自己的同步结果）：
#   - alpha：旧版本 package.json + 源里已删除的 legacy/old.js；
#   - gamma：与源逐字节相同 → 必须是 [不变]；
#   - beta：不存在 → 必须是 [新增]。
mkdir -p "$REPO/alpha/lib" "$REPO/alpha/legacy" "$REPO/gamma/lib"
printf '{\n  "name": "dsh-alpha-plugin",\n  "version": "0.1.0",\n  "description": "旧版本。"\n}\n' \
  > "$REPO/alpha/package.json"
printf '// 旧入口\n' > "$REPO/alpha/lib/index.js"
printf '源里已经删掉的旧文件\n' > "$REPO/alpha/legacy/old.js"
cp -p "$SRC/gamma/package.json" "$REPO/gamma/package.json"
cp -p "$SRC/gamma/lib/index.js" "$REPO/gamma/lib/index.js"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "fixture: 旧状态（alpha 旧版 + 多余文件，beta 不存在，gamma 一致）"

# 硬前提：gamma 确实一致（否则它不会显示 [不变]，这条用例会测偏）。
CHECKED=$((CHECKED + 1))
if ! diff -r -q "$SRC/gamma" "$REPO/gamma" >/dev/null 2>&1; then
  fail "前置条件不成立：gamma 的源与目标并不一致"
fi
# 硬前提：beta 确实不在目标里。
CHECKED=$((CHECKED + 1))
[ ! -e "$REPO/beta" ] || fail "前置条件不成立：beta 已存在于目标仓库"

BEFORE_COMMITS="$(ph_count_commits)"
BEFORE_HEAD="$(ph_repo_head)"
BEFORE_REMOTE="$(ph_remote_main)"
tree_snapshot "$REPO" "./.git"

ph_run --check
assert_rc 0

# 三态都要出现。
assert_contains "[更新] alpha"
assert_contains "[新增] beta"
assert_contains "[不变] gamma"
# 镜像语义的待删清单也要报告。
assert_contains "删除多余文件：alpha/legacy/old.js"
# README 表格会变这件事也要报告。
assert_contains "README 表格：将重建"
assert_contains "--check：仅报告，未改动任何文件。"

# 零改动：整棵树、提交数、HEAD、远端 ref 全部不动。
assert_tree_unchanged
assert_head_unchanged "$BEFORE_COMMITS"
CHECKED=$((CHECKED + 1))
if [ "$(ph_repo_head)" != "$BEFORE_HEAD" ]; then
  fail "HEAD 被改动了：$BEFORE_HEAD → $(ph_repo_head)"
fi
CHECKED=$((CHECKED + 1))
if [ "$(ph_remote_main)" != "$BEFORE_REMOTE" ]; then
  fail "远端 main 被改动了：$BEFORE_REMOTE → $(ph_remote_main)"
fi
ph_assert_repo_clean

# 旧文件仍在（--check 不删）。
assert_file "$REPO/alpha/legacy/old.js"
assert_no_file "$REPO/beta"

# 目标仓库不存在时，--check 也不该顺手克隆。
GHOST="$SANDBOX/ghost-repo"
CHECKED=$((CHECKED + 1))
if [ -e "$GHOST" ]; then fail "前置条件不成立：$GHOST 已存在"; fi
LAST_CMDLINE="DSHBOX_PLUGIN_REPO=$GHOST bash deliver-plugin --check（目标不存在）"
RC=0
DSHBOX_PLUGIN_SRC="$SRC" DSHBOX_PLUGIN_REPO="$GHOST" bash "$PH_SCRIPT" --check > "$OUT" 2>&1 || RC=$?
assert_rc 0
assert_contains "[新增] alpha"
CHECKED=$((CHECKED + 1))
[ ! -e "$GHOST" ] || fail "--check 竟然创建/克隆了目标仓库：$GHOST"

harness_done
