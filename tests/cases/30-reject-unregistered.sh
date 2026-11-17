#!/usr/bin/env bash
# 30-reject-unregistered.sh — 未登记的 modId 必须拒绝（issue #16 第 1 条 / spec #14）
#
# 场景：jar 里的 modId 读得出来，但 NAMING.md 的模组登记表里没有它。
# 命名表是文件名唯一权威，脚本不许自己编前缀 —— 只能失败。
#
# 断言：
#   - 退出码 1（deliver 的 die 一律 exit 1）
#   - 错误信息说得清是「未在 NAMING.md 登记」并要求先登记（只断关键词，不钉整句标点）
#   - 成品/ 整棵树（排除 .git）一个字节都没变：没有新 jar，模组清单.md 没被重写
#   - 不产生提交，工作树干净

CASE_NAME="30-reject-unregistered"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# 真实仓库里 成品/模组、成品/文档 已存在，模组清单.md 是已入库的派生物。
# 夹具对齐这个状态：目录预建 + 一份带哨兵内容的清单 + 一份既有 jar，
# 这样断言的是「文件列表完全一致」，而不只是「目录恰好是空的」。
fixture_existing_delivery demo 0.1.0

# ghost 没有登记；它的元数据本身是完好的，失败必须来自「未登记」而不是「读不到元数据」。
make_jar dist/ghost-1.0.0.jar ghost 1.0.0 "未登记模组" MIT

cp "$REPO/成品/文档/模组清单.md" "$SANDBOX/manifest.before" || fatal "无法备份夹具清单"
BEFORE_FILES="$(mod_dir_files)"
tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run "dist/ghost-1.0.0.jar"

# die 用的是 exit 1；这里断具体数字，不写「非零」。
assert_rc 1
assert_contains "错误："
# 关键词而不是整句：措辞可以微调，但必须点出命名表与「登记」这件事。
assert_contains "NAMING.md"
assert_contains "登记"
assert_contains "ghost"

# 输出里不该出现任何「做了事」的痕迹。
assert_not_contains "已归档："
assert_not_contains "已生成：成品/文档/模组清单.md"
assert_not_contains "已提交："

# 整棵树零改动 —— 这一条同时覆盖「没新增 jar」与「模组清单.md 没被重写」。
assert_tree_unchanged
assert_content_same "$SANDBOX/manifest.before" "$REPO/成品/文档/模组清单.md"

# 成品/模组 下的文件列表与跑之前完全一致（逐名比对，失败时看得出多了什么）。
CHECKED=$((CHECKED + 1))
AFTER_FILES="$(mod_dir_files)"
if [ "$AFTER_FILES" != "$BEFORE_FILES" ]; then
  fail "成品/模组 文件列表变了：期望 [$BEFORE_FILES]，实际 [$AFTER_FILES]"
fi

# 不论谁给 ghost 编了个什么样的前缀、什么样的名字，成品/模组 里都不许出现它。
# 这里刻意不写死前缀（命名表是唯一权威，测试也不该假定脚本会编哪个），
# 只按 modId 出现在文件名里这一事实去查。
CHECKED=$((CHECKED + 1))
LEAKED="$(cd "$REPO" && find 成品 -type f -name '*ghost*' -printf '%p\n' | LC_ALL=C sort)"
if [ -n "$LEAKED" ]; then
  fail "未登记的 modId 不该落位任何产物，实际：$LEAKED"
fi

assert_head_unchanged "$BEFORE_COMMITS"
assert_git_clean

harness_done
