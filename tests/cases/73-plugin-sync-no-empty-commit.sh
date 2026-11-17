#!/usr/bin/env bash
# 73-plugin-sync-no-empty-commit.sh — 内容不变的第二次同步不造空提交
#
# 场景：同一份插件工作区连续同步两次。
# 断言：
#   - 第二次输出三态全是 [不变]，且打印「插件仓库无变化，不产生提交。」；
#   - 提交数不变、HEAD 不变、整棵树指纹不变；
#   - 第二次也不再产生推送（远端 main 指向同一 commit，输出里没有「已推送」）；
#   - README 表格也不被重写（表格是派生物，没变化时不该动它）。

CASE_NAME="73-plugin-sync-no-empty-commit"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/plugin-harness.sh"

ph_init
ph_repo

fixture_plugin stable-plugin dsh-stable-plugin 1.0.0 "稳定插件，不该重复提交。"

ph_run
assert_rc 0
assert_contains "[新增] stable-plugin"
COMMITS_AFTER_FIRST="$(ph_count_commits)"
HEAD_AFTER_FIRST="$(ph_repo_head)"
REMOTE_AFTER_FIRST="$(ph_remote_main)"
README_AFTER_FIRST="$(ph_readme)"
tree_snapshot "$REPO" "./.git"

# 第二次：输入完全相同。
ph_run
assert_rc 0

assert_contains "[不变] stable-plugin"
assert_not_contains "[新增] stable-plugin"
assert_contains "插件仓库无变化，不产生提交。"

assert_head_unchanged "$COMMITS_AFTER_FIRST"
CHECKED=$((CHECKED + 1))
if [ "$(ph_repo_head)" != "$HEAD_AFTER_FIRST" ]; then
  fail "HEAD 变了：$HEAD_AFTER_FIRST → $(ph_repo_head)"
fi
# 没有新提交时也不该再推一次（远端本来就同步）。
assert_not_contains "已推送"
CHECKED=$((CHECKED + 1))
if [ "$(ph_remote_main)" != "$REMOTE_AFTER_FIRST" ]; then
  fail "远端 main 变了：$REMOTE_AFTER_FIRST → $(ph_remote_main)"
fi

assert_tree_unchanged
ph_assert_repo_clean

# README 表格未被重写（内容逐字节相同）。
CHECKED=$((CHECKED + 1))
if [ "$(ph_readme)" != "$README_AFTER_FIRST" ]; then
  fail "无变化时 README.md 被改写了"
fi

# 再跑一次 --check：依然是全 [不变] + 表格无变化。
ph_run --check
assert_rc 0
assert_contains "[不变] stable-plugin"
assert_contains "README 表格：无变化"

harness_done
