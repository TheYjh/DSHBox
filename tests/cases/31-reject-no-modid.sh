#!/usr/bin/env bash
# 31-reject-no-modid.sh — jar 缺 modId 必须拒绝（issue #16 第 2 条）
#
# 场景：META-INF/mods.toml 里没有 modId 行（harness 的 NO_MODID=1 变体）。
# modId 是归档路径与命名表查询的入口，读不到就只能失败，不能拿文件名顶替。
#
# 断言：
#   - 退出码 1
#   - 错误信息点出 modId（只断关键词，不钉整句标点）
#   - 成品/ 整棵树（排除 .git）一个字节都没变，模组清单.md 没被重写
#   - 不产生提交，工作树干净

CASE_NAME="31-reject-no-modid"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
make_jar "成品/模组/[自制-GOD-既有交付]demo-0.1.0.jar" demo 0.1.0 "既有交付" MIT
printf '# 模组清单\n\n> 哨兵：拒绝路径不得重写本文件。\n' > "$REPO/成品/文档/模组清单.md"
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置成品目录与清单" || fatal "夹具预置提交失败"

# 文件名里带 demo-1.0.0（deliver 的版本回退路径能读出来），但 mods.toml 缺 modId。
# 这样失败只可能来自「读不到 modId」。
NO_MODID=1 make_jar dist/demo-1.0.0.jar demo 1.0.0 "缺 modId" MIT

cp "$REPO/成品/文档/模组清单.md" "$SANDBOX/manifest.before" || fatal "无法备份夹具清单"
BEFORE_FILES="$(cd "$REPO" && find 成品/模组 -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)"
tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run "dist/demo-1.0.0.jar"

assert_rc 1
assert_contains "错误："
assert_contains "modId"
assert_contains "demo-1.0.0.jar"

assert_not_contains "已归档："
assert_not_contains "已生成：成品/文档/模组清单.md"
assert_not_contains "已提交："

assert_tree_unchanged
assert_content_same "$SANDBOX/manifest.before" "$REPO/成品/文档/模组清单.md"

CHECKED=$((CHECKED + 1))
AFTER_FILES="$(cd "$REPO" && find 成品/模组 -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)"
if [ "$AFTER_FILES" != "$BEFORE_FILES" ]; then
  fail "成品/模组 文件列表变了：期望 [$BEFORE_FILES]，实际 [$AFTER_FILES]"
fi

# 若有人让 modId 从未登记/缺省时回退到某个名字，这个目标名就会被建出来。
DEMO_TARGET="$(naming_expected demo 1.0.0)" || fatal "夹具命名表里查不到 demo"
assert_no_file "$REPO/成品/模组/$DEMO_TARGET"

assert_head_unchanged "$BEFORE_COMMITS"
assert_git_clean

harness_done
