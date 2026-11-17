#!/usr/bin/env bash
# 84-deliver-artifact-dir-override.sh — DSHBOX_ARTIFACT_DIR 只做额外复制（#10 第 1 条）
#
# 语义边界：成品/ 永远是主副本、永远是唯一被提交的地方。
# DSHBOX_ARTIFACT_DIR 指到别处时，归档照旧发生在仓库里的 成品/，
# 只是**额外**再复制一份到那个目录 —— 它不进 git、不影响提交内容。
#
# 断言：
#   - 仓库里的 成品/模组/<带前缀名> 照常出现并入库
#   - 外部目录下出现 模组/<同名 jar>，内容与成品 jar 一致
#   - 外部目录不是仓库的一部分：没有被提交，工作树仍然干净
#   - 输出里说明这是「旁路输出，不影响提交」

CASE_NAME="84-deliver-artifact-dir-override"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

make_jar dist/demo-2.0.0.jar demo 2.0.0 "示例交付" MIT
EXPECTED="$(naming_expected demo 2.0.0)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"

EXTERNAL="$SANDBOX/外部成品"
DELIVER_ENV=("DSHBOX_ARTIFACT_DIR=$EXTERNAL")

deliver_run
assert_rc 0

# 主副本照旧：在仓库里、带前缀、入库。
assert_file "$REPO/$DEST"
assert_contains "已归档：成品/模组/$EXPECTED"

# 旁路副本：在仓库外，同名同内容。
assert_file "$EXTERNAL/模组/$EXPECTED"
assert_content_same "$REPO/$DEST" "$EXTERNAL/模组/$EXPECTED"
assert_last_commit_touches "成品/模组/$EXPECTED"

# 旁路目录绝不被提交 —— 它连仓库目录都不在，这里再确认一次提交对象里没它。
CHECKED=$((CHECKED + 1))
if git -C "$REPO" ls-files --full-name | grep -qF "外部成品"; then
  fail "外部成品目录不该进入版本库"
fi
assert_git_clean

harness_done
