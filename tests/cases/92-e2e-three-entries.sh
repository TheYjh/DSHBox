#!/usr/bin/env bash
# 92-e2e-three-entries.sh — 三个入口串成一条链的端到端验证（#13 第 4 条验收）
#
# 前面每个用例各自锁一条行为（80~86 构建、10~25 归档与冲突、87~91 APK），
# 但它们从没在**同一个仓库里先后跑过**。#13 要证的就是「三个入口接得上」：
# 构建出的中性名产物能被归档成带前缀的成品、重复执行幂等、命名权威确实在
# NAMING.md、APK 走另一条入口且不进库。单测各自绿不代表这条链成立。
#
# 断言：
#   1. build.sh 产出 dist/demo-2.1.0.jar（中性名，dist/ 里没有带前缀的文件）
#   2. deliver --check 报告「新增 1 个」，整棵树零改动
#   3. deliver 归档成带前缀的名字、内容与 dist/ 产物逐字节相同、dist/ 原件仍在、一次提交
#   4. 重复跑 deliver → 「未变」，不产生新提交（幂等）
#   5. 改 NAMING.md 描述 → 新名字落位、旧名字留在原处（命名权威在 NAMING.md 的行为证据）
#   6. build-apk.sh 落 成品/应用/，DSHBOX_ARTIFACT_DIR 换根、显式 OUT 优先
#   7. APK 没被 git add、全程结束后工作树干净

CASE_NAME="92-e2e-three-entries"
# 复用 APK 夹具（make_signed_apk / apk_run），但它自带的 apk_init 会重造沙箱，
# 本用例已经用 harness_init + fixture_repo 建好了仓库，所以**不调用** apk_init，
# 只手工把 build-apk.sh 复制进夹具（apk-harness 会在第 27 行转手 source harness.sh）。
source "$(dirname "${BASH_SOURCE[0]}")/../lib/apk-harness.sh"

harness_init
fixture_repo
fixture_build_toolchain
fixture_build_mod demo

# 夹具准备：照真实仓库的样子补上成品目录、APK 入口副本与 .gitignore。
# 都放在第一个断言之前入库，免得后面的「工作树干净」被夹具自身绊倒。
cp "$REAL_BUILD_APK" "$REPO/build-apk.sh" || fatal "复制 build-apk.sh 失败：$REAL_BUILD_APK"
chmod +x "$REPO/build-apk.sh" 2>/dev/null || true
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
# 忽略规则照抄真实仓库的 `.gitignore`，而不是自己编一份——这样「dist/ 与 APK 不入库」
# 测的就是仓库里真实生效的规则，而不是夹具碰巧建对了一个规则。
cp "$DSHBOX_ROOT/.gitignore" "$REPO/.gitignore" || fatal "复制真实 .gitignore 失败"
fixture_build_commit "fixture: 成品目录、APK 入口与忽略规则"

# ---------- 1. 构建：产物是中性名，落在 dist/ ----------

BUILD_MOD_VERSION="2.1.0"
build_run demo
assert_rc 0
assert_file "$REPO/dist/demo-2.1.0.jar"

CHECKED=$((CHECKED + 1))
DIST_FILES="$(dist_dir_files)"
if [ "$DIST_FILES" != "demo-2.1.0.jar" ]; then
  fail "dist/ 期望只有中性名的 demo-2.1.0.jar，实际：[$DIST_FILES]"
fi
# 前缀属交付环节：构建侧一个带前缀的文件都不许有（这是 80 的语义，这里是链路证据）。
CHECKED=$((CHECKED + 1))
if ( cd "$REPO" && find dist -maxdepth 1 -name '*自制*' -printf '%f\n' | grep -q . ); then
  fail "dist/ 里出现了带前缀的产物——前缀只该由 deliver 施加"
fi
# dist/ 是中间文件：必须被真实的 .gitignore 挡住，否则 `git add -A` 会把验证产物收进库。
CHECKED=$((CHECKED + 1))
if ! git -C "$REPO" check-ignore -q "dist/demo-2.1.0.jar"; then
  fail "dist/ 产物没有被 .gitignore 挡住——验证产物不该进库"
fi

# ---------- 2. deliver --check：只报告，零改动 ----------

EXPECTED="$(naming_expected demo 2.1.0)" || fatal "夹具命名表里查不到 demo"
DEST="成品/模组/$EXPECTED"

tree_snapshot
BEFORE_COMMITS="$(git_count_commits)"

deliver_run --check
assert_rc 0
assert_contains "[新增] demo-2.1.0.jar  →  成品/模组/$EXPECTED"
assert_contains "新增 1 个"
assert_not_contains "已归档："

assert_no_file "$REPO/$DEST"
assert_tree_unchanged
assert_head_unchanged "$BEFORE_COMMITS"

# ---------- 3. deliver：归档成带前缀的名字，内容逐字节相同 ----------

deliver_run
assert_rc 0
assert_file "$REPO/$DEST"
assert_contains "已归档：成品/模组/$EXPECTED"
# deliver 是改名不是重新打包：归档件与 dist/ 原件的 sha256 必须相同。
assert_content_same "$REPO/dist/demo-2.1.0.jar" "$REPO/$DEST"
# 验证产物留在 dist/：它和成品是两份，删了也不影响成品（这就是「中间文件」的性质）。
assert_file "$REPO/dist/demo-2.1.0.jar"

assert_head_increased "$BEFORE_COMMITS"
assert_last_commit_touches "$DEST"
assert_git_clean
# 清单是派生物，这次交付必须把它一并刷新，且新成品在里面有一行。
assert_contains "$EXPECTED" "$(cat "$(manifest_path)")"

COMMITS_AFTER_ARCHIVE="$(git_count_commits)"

# ---------- 4. 重复执行幂等：未变、不产生新提交 ----------

deliver_run
assert_rc 0
assert_contains "新增 0 个，未变 1 个"
assert_head_unchanged "$COMMITS_AFTER_ARCHIVE"
assert_git_clean

# ---------- 5. 命名权威在 NAMING.md：改描述 → 新名落位、旧名留存 ----------

naming_set_desc demo "示例改名"
RENAMED="$(naming_expected demo 2.1.0)" || fatal "改名后夹具命名表里查不到 demo"
NEW_DEST="成品/模组/$RENAMED"

CHECKED=$((CHECKED + 1))
if [ "$RENAMED" = "$EXPECTED" ]; then
  fail "改描述列之后目标文件名没变（$RENAMED）——夹具没造出改名场景"
fi

deliver_run
assert_rc 0
assert_file "$REPO/$NEW_DEST"
assert_content_same "$REPO/dist/demo-2.1.0.jar" "$REPO/$NEW_DEST"
# 内容哈希相同、只有名字变了，仍算变化：这是「前缀来自 NAMING.md」的直接证据。
assert_contains "新增 1 个"
assert_head_increased "$COMMITS_AFTER_ARCHIVE"
# 旧名不会被顺手删掉（deliver 默认只报告、不删；这里连报告都没进——同版本不算被取代）。
assert_file "$REPO/$DEST"
assert_git_clean

# ---------- 6. build-apk.sh：默认落位 / DSHBOX_ARTIFACT_DIR 换根 / OUT 优先 ----------

make_signed_apk "$SANDBOX/入参/重铸百科-1.4.0.apk"
SRC_APK="$SANDBOX/入参/重铸百科-1.4.0.apk"
APK_NAME="重铸百科-1.4.0.apk"

apk_run "$SRC_APK"
assert_rc 0
assert_file "$REPO/成品/应用/$APK_NAME"
assert_content_same "$SRC_APK" "$REPO/成品/应用/$APK_NAME"

EXTERNAL="$SANDBOX/外部成品"
APK_ENV=("DSHBOX_ARTIFACT_DIR=$EXTERNAL")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$EXTERNAL/应用/$APK_NAME"

# OUT 与 DSHBOX_ARTIFACT_DIR 并存：OUT 赢，外部根下一个文件都不该出现。
OUT_FILE="$SANDBOX/发布/显式.apk"
APK_ENV=("DSHBOX_ARTIFACT_DIR=$SANDBOX/不该用到" "OUT=$OUT_FILE")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$OUT_FILE"
assert_content_same "$SRC_APK" "$OUT_FILE"
assert_no_file "$SANDBOX/不该用到/应用/$APK_NAME"
APK_ENV=()

# ---------- 7. APK 不进库，全程结束时工作树干净 ----------

CHECKED=$((CHECKED + 1))
TRACKED_APK="$(git -C "$REPO" ls-files "成品/应用" 2>/dev/null)"
if [ -n "$TRACKED_APK" ]; then
  fail "APK 不该被 git add，实际入库：$TRACKED_APK"
fi
# 文件确实在盘上（上面的 assert_file 已经证过），但被 .gitignore 挡住了——
# 这两条合起来才是「不入库但交付成功」，缺一条都可能被忽略规则掩盖成假绿。
CHECKED=$((CHECKED + 1))
if ! git -C "$REPO" check-ignore -q "成品/应用/$APK_NAME"; then
  fail "成品/应用/$APK_NAME 没有被 .gitignore 挡住——「APK 不入库」的假设不成立"
fi
assert_git_clean

# 模组链与 APK 链互不干扰：成品/模组 里只有 demo 改名前后那两份，APK 一个都没混进来。
CHECKED=$((CHECKED + 1))
MOD_FILES="$(mod_dir_jars)"
EXPECTED_MOD_FILES="$(printf '%s\n%s\n' "$RENAMED" "$EXPECTED" | LC_ALL=C sort)"
if [ "$MOD_FILES" != "$EXPECTED_MOD_FILES" ]; then
  fail "成品/模组 期望改名前后两份 demo jar，实际：[$MOD_FILES]"
fi

harness_done
