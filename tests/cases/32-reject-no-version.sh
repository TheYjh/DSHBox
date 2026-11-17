#!/usr/bin/env bash
# 32-reject-no-version.sh — jar 缺版本号必须拒绝（issue #16 第 3 条）
#
# 场景：MANIFEST.MF 没有 Implementation-Version，且文件名也解析不出版本
# （harness 的 NO_VERSION=1 变体 + 文件名 dist/demo.jar）。
# deliver 的版本读取有一条「从文件名 -<ver>.jar 回退」的路径；这个用例就是把
# 回退路径也堵死 —— 两处都读不到时必须失败，不能编一个版本号出来。
#
# 断言：
#   - 退出码 1
#   - 错误信息点出「版本」（只断关键词，不钉整句标点）
#   - 成品/ 整棵树（排除 .git）一个字节都没变，模组清单.md 没被重写
#   - 不产生提交，工作树干净

CASE_NAME="32-reject-no-version"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
make_jar "成品/模组/[自制-GOD-既有交付]demo-0.1.0.jar" demo 0.1.0 "既有交付" MIT
printf '# 模组清单\n\n> 哨兵：拒绝路径不得重写本文件。\n' > "$REPO/成品/文档/模组清单.md"
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置成品目录与清单" || fatal "夹具预置提交失败"

# 文件名 demo.jar 不含 -<ver>，MANIFEST 也没有 Implementation-Version：
# 元数据与文件名两条来源都读不出版本。
NO_VERSION=1 make_jar dist/demo.jar demo 0 "缺版本号" MIT

cp "$REPO/成品/文档/模组清单.md" "$SANDBOX/manifest.before" || fatal "无法备份夹具清单"
BEFORE_FILES="$(cd "$REPO" && find 成品/模组 -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)"
tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run "dist/demo.jar"

assert_rc 1
assert_contains "错误："
assert_contains "版本"
assert_contains "demo.jar"

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

# 文件名里读不出版本，任何「编出来的版本」落位都会让成品/模组 多出一个文件；
# 上面逐名比对已经覆盖。这里再钉一次：不该出现 demo 的任何新版本名。
CHECKED=$((CHECKED + 1))
UNEXPECTED="$(cd "$REPO" && find 成品/模组 -maxdepth 1 -type f -name '*demo-1*.jar' -printf '%f\n' | LC_ALL=C sort)"
if [ -n "$UNEXPECTED" ]; then
  fail "缺版本号时不该落位任何 demo-1* 产物，实际：$UNEXPECTED"
fi

assert_head_unchanged "$BEFORE_COMMITS"
assert_git_clean

harness_done
