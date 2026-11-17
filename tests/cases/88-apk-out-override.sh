#!/usr/bin/env bash
# 88-apk-out-override.sh — 显式 OUT 优先于默认目标（#11 第 3、5 条）
#
# 语义边界：OUT 是文件路径时直接当目标；是已存在目录或以 / 结尾时拼原文件名。
# OUT 与 DSHBOX_ARTIFACT_DIR 同时给出时 OUT 赢 —— 后者是「默认根的替换」，
# 不是「额外的目的地」。
#
# 断言：
#   - OUT=文件：文件按那个名字落位，内容与源一致
#   - OUT 与 DSHBOX_ARTIFACT_DIR 并存：只有 OUT 生效，外部根下不出现任何东西
#   - OUT=目录：该目录下出现原文件名
#   - 三种情况默认 成品/应用 都没有被顺手写一份

CASE_NAME="88-apk-out-override"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/apk-harness.sh"

apk_init
make_signed_apk "$SANDBOX/入参/重铸百科-1.4.0.apk"
SRC_APK="$SANDBOX/入参/重铸百科-1.4.0.apk"
APK_NAME="重铸百科-1.4.0.apk"

# ---------- OUT 是文件路径 ----------
OUT_FILE="$SANDBOX/指定/改名后.apk"
mkdir -p "$(dirname "$OUT_FILE")"
APK_ENV=("OUT=$OUT_FILE")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$OUT_FILE"
assert_content_same "$SRC_APK" "$OUT_FILE"
assert_contains "目标：显式 OUT"
assert_contains "已落位：$OUT_FILE"
assert_no_app_files "$REPO"

# ---------- OUT 与 DSHBOX_ARTIFACT_DIR 并存：OUT 赢 ----------
OUT_FILE2="$SANDBOX/指定/再一份.apk"
EXTERNAL="$SANDBOX/外部成品"
mkdir -p "$(dirname "$OUT_FILE2")"
APK_ENV=("OUT=$OUT_FILE2" "DSHBOX_ARTIFACT_DIR=$EXTERNAL")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$OUT_FILE2"
assert_content_same "$SRC_APK" "$OUT_FILE2"
assert_no_file "$EXTERNAL/应用/$APK_NAME"
assert_no_app_files "$REPO"

# ---------- OUT 是目录：拼原文件名 ----------
OUT_DIR="$SANDBOX/指定/目录"
mkdir -p "$OUT_DIR"
APK_ENV=("OUT=$OUT_DIR")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$OUT_DIR/$APK_NAME"
assert_content_same "$SRC_APK" "$OUT_DIR/$APK_NAME"
assert_no_app_files "$REPO"

harness_done
