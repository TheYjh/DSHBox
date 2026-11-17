#!/usr/bin/env bash
# 10-archive.sh — 正常归档（#15 第 1 条 / spec #14 User Story 7、9、10）
#
# 断言：
#   - dist/demo-1.2.3.jar 被归档成 成品/模组/[自制-<域>-<描述>]demo-1.2.3.jar
#   - 目标文件名由夹具 NAMING.md 推导（测试里不自带前缀常量）
#   - 退出码 0，输出含归档提示
#   - 归档文件内容与被归档的 jar 逐字节一致
#   - 产生一次提交，且该提交确实改动了归档路径

CASE_NAME="10-archive"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT

EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"

BEFORE_COMMITS="$(git_count_commits)"

deliver_run
assert_rc 0

assert_file "$REPO/$DEST"
assert_contains "已归档：成品/模组/$EXPECTED"
assert_contains "[自制-GOD-示例交付]demo-1.2.3.jar"

# 文件名必须符合命名表格式：前缀由域与描述拼出，不是测试里写死的常量。
CHECKED=$((CHECKED + 1))
if printf '%s' "$EXPECTED" | grep -Eq '^\[自制-[^-]+-.+\]demo-1\.2\.3\.jar$'; then
  :
else
  fail "归档文件名不符合 [自制-<域>-<描述>]<id>-<ver>.jar：$EXPECTED"
fi

# 未登记的 modId / 未登记的功能域都不该出现在这里：成品目录里只应有这一个 jar。
CHECKED=$((CHECKED + 1))
mapfile -t ARCHIVED < <(cd "$REPO" && find 成品/模组 -maxdepth 1 -name '*.jar' -printf '%f\n' | LC_ALL=C sort)
if [ "${#ARCHIVED[@]}" -ne 1 ] || [ "${ARCHIVED[0]}" != "$EXPECTED" ]; then
  fail "成品/模组 内容不符，期望只有 $EXPECTED，实际：${ARCHIVED[*]:-（空）}"
fi

assert_content_same "$REPO/dist/demo-1.2.3.jar" "$REPO/$DEST"
assert_head_increased "$BEFORE_COMMITS"
assert_last_commit_touches "成品/模组/$EXPECTED"
assert_git_clean
assert_contains "chore(成品): 归档 demo"

harness_done
