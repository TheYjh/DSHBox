#!/usr/bin/env bash
# 33-reject-unknown-domain.sh — 未登记的功能域必须拒绝（#10 第 2、5 条）
#
# 命名表的功能域是**闭合枚举**。登记了 modId 但写了个枚举外的域时，
# 若放行，前缀会变成 [自制-其它-xxx] 这类没人维护的名字 —— 每次都得靠人眼复核。
# 所以要在归档前拦住：要么用已登记的域，要么先把该域登记进枚举。
#
# 断言：
#   - 退出码 1
#   - 错误信息点名那个非法域，并要求先登记
#   - 成品/ 整棵树零改动（没有新 jar、清单没被重写）
#   - 不产生提交

CASE_NAME="33-reject-unknown-domain"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo
fixture_existing_delivery demo 0.1.0

# 把 demo 的功能域改成枚举外的值：modId 登记仍在，坏的是域。
naming_set_domain demo 其它 || fatal "改写夹具域名失败"
# 把命名表的改动入库：这条用例要断「deliver 拒绝时不产生提交且工作树干净」，
# 夹具自己留下的未提交改动会污染这个断言。
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 未登记的功能域" || fatal "夹具提交失败"
make_jar dist/demo-0.2.0.jar demo 0.2.0 "示例交付" MIT

BEFORE_FILES="$(mod_dir_files)"
tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run
assert_rc 1
assert_contains "错误："
assert_contains "其它"
assert_contains "功能域"
assert_contains "登记"

assert_not_contains "已归档："
assert_not_contains "已生成：成品/文档/模组清单.md"

assert_tree_unchanged

CHECKED=$((CHECKED + 1))
AFTER_FILES="$(mod_dir_files)"
if [ "$AFTER_FILES" != "$BEFORE_FILES" ]; then
  fail "成品/模组 文件列表变了：期望 [$BEFORE_FILES]，实际 [$AFTER_FILES]"
fi

assert_head_unchanged "$BEFORE_COMMITS"
assert_git_clean

harness_done
