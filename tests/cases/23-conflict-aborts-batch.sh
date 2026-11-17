#!/usr/bin/env bash
# 23-conflict-aborts-batch.sh — 目标文件名已存在但内容不同：默认整批中止（#12）
#
# #20 复核后，#12 只剩这一条语义：两键比对里的「目标存在、内容不同」既不是
# 新增、也不是不变，而是**冲突**。默认路径下它必须在任何写操作之前把整批拦下，
# 不能悄悄覆盖旧产物，也不能只跳过冲突项、把同批其他文件照常归档。
#
# 场景：
#   1. 正常归档 demo-1.2.3.jar
#   2. dist 里的同名 jar 被重建成不同内容（换 license），同批还多一个 demo-1.3.0.jar
#   3. 直接跑 deliver：退出码非零、整批中止
# 断言：成品/ 与工作树零改动、无新文件、无提交、旧产物内容未变、源 jar 仍在。

CASE_NAME="23-conflict-aborts-batch"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# 真实仓库里 成品/模组、成品/文档 常存；夹具照此预建。
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT
OLD_NAME="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
OLD_DEST="成品/模组/$OLD_NAME"

deliver_run
assert_rc 0
assert_file "$REPO/$OLD_DEST"
COMMITS_AFTER_FIRST="$(git_count_commits)"
OLD_HASH="$(sha256sum -- "$REPO/$OLD_DEST" | cut -d' ' -f1)"

# ---------- 同名不同内容 + 同批另一个新版本 ----------

# 给 demo 造出源码目录：这样 1.3.0 一旦落位，1.2.3 就成了「有源码、被新版取代」
# 的清理候选。整批中止时它不该出现在清理报告里 —— 新版本根本没落位。
fixture_source demo
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "fixture: 补源码目录"

make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" Apache-2.0
make_jar dist/demo-1.3.0.jar demo 1.3.0 "示例交付" MIT
NEW_NAME="$(naming_expected demo 1.3.0)" || fatal "夹具命名表里查不到 demo"
NEW_DEST="成品/模组/$NEW_NAME"

SRC_HASH="$(sha256sum -- "$REPO/dist/demo-1.2.3.jar" | cut -d' ' -f1)"
[ "$SRC_HASH" = "$OLD_HASH" ] && fatal "夹具没造出「内容不同」：新旧 jar 哈希相同"

COMMITS_BEFORE="$(git_count_commits)"
tree_snapshot
deliver_run

# 退出码非零：这是「拒绝执行」，不是「跳过一项继续」。
assert_rc 1

# 报告：三键里的第三态，点名哪个文件、目标是什么、为什么冲突、怎么解决。
assert_contains "[冲突] demo-1.2.3.jar  →  成品/模组/$OLD_NAME（目标已存在，内容不同）"
assert_contains "新增 1 个，未变 0 个，冲突 1 个"
assert_contains "冲突明细（目标文件名已存在，但内容与本次产物不同）："
assert_contains "本次产物 sha256：$SRC_HASH"
assert_contains "现目标文件   sha256：$OLD_HASH"
assert_contains "--overwrite"
assert_contains "整批中止"
assert_contains "未写入任何文件"

# 什么都没写：新版本也没跟着落位（整批 = 一个都不写）。
assert_not_contains "已归档："
assert_not_contains "已生成：成品/文档/模组清单.md"
assert_no_file "$REPO/$NEW_DEST"
# 整批中止时，同批那个「本可以归档」的新版本也不能算进清理候选。
assert_not_contains "可清理的旧产物（有源码、已被新版取代）"

# 旧产物原封不动，仍是原内容。
CHECKED=$((CHECKED + 1))
NOW_HASH="$(sha256sum -- "$REPO/$OLD_DEST" | cut -d' ' -f1)"
[ "$NOW_HASH" = "$OLD_HASH" ] || fail "冲突中止时旧产物被改写了：$OLD_HASH → $NOW_HASH"

# 源 jar 还在（拒绝不等于删除输入）。
assert_file "$REPO/dist/demo-1.2.3.jar"
assert_file "$REPO/dist/demo-1.3.0.jar"

# 成品/、工作树、提交数全部零改动。
assert_tree_unchanged
assert_head_unchanged "$COMMITS_BEFORE"
assert_git_clean

harness_done
