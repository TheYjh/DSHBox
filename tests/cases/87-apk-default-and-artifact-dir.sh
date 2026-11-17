#!/usr/bin/env bash
# 87-apk-default-and-artifact-dir.sh — APK 入口的默认落位与产物根覆盖（#11 第 1、2 条）
#
# 语义边界：不带 OUT 时落仓库里的 成品/应用/<原文件名>；
# 设了 DSHBOX_ARTIFACT_DIR 就落 $DSHBOX_ARTIFACT_DIR/应用/<原文件名>。
# 两种情况都保留原文件名（入口只搬不更名），且内容逐字节相同。
#
# 断言：
#   - 默认：退出码 0，成品/应用/<原文件名> 出现，内容与源 APK 一致
#   - DSHBOX_ARTIFACT_DIR：仓库内成品不新增，外部 <根>/应用/ 下出现同名同内容件
#   - 两次都打印「已落位」与「不进 git」的提示

CASE_NAME="87-apk-default-and-artifact-dir"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/apk-harness.sh"

apk_init
make_signed_apk "$SANDBOX/入参/重铸百科-1.4.0.apk"
SRC_APK="$SANDBOX/入参/重铸百科-1.4.0.apk"
APK_NAME="重铸百科-1.4.0.apk"

# ---------- 默认目标：仓库里的 成品/应用/ ----------
apk_run "$SRC_APK"
assert_rc 0
assert_file "$REPO/成品/应用/$APK_NAME"
assert_content_same "$SRC_APK" "$REPO/成品/应用/$APK_NAME"
assert_contains "已落位：成品/应用/$APK_NAME"
assert_contains "不进 git"
# 原件不动：入口是复制，不是搬运。
assert_file "$SRC_APK"

# ---------- DSHBOX_ARTIFACT_DIR：换默认成品根 ----------
EXTERNAL="$SANDBOX/外部成品"
APK_ENV=("DSHBOX_ARTIFACT_DIR=$EXTERNAL")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$EXTERNAL/应用/$APK_NAME"
assert_content_same "$SRC_APK" "$EXTERNAL/应用/$APK_NAME"
assert_contains "已落位：$EXTERNAL/应用/$APK_NAME"

# 仓库内只该有第一次那份（它还在），不能因为设了外部根又长出一份新的。
CHECKED=$((CHECKED + 1))
[ "$(app_dir_files "$REPO")" = "$APK_NAME" ] \
  || fail "仓库内 成品/应用 的内容不符，实际：[$(app_dir_files "$REPO")]"

harness_done
