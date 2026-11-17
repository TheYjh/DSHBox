#!/usr/bin/env bash
# 91-apk-filename-preserved.sh — 原文件名原样保留（#11 第 1、3 条）
#
# 语义边界：入口只搬不收编 —— 不改名、不加前缀、不猜 modId。
# 成品目录里的名字必须和交过来的文件一模一样（中文、空格、点号、连字符都算），
# 这样交给 Android 构建者时文件名与它被签名时的名字对得上。
#
# 断言：
#   - 默认目标下：成品/应用/<原名>，逐名比对（不只看「有个文件」）
#   - OUT=<目录> 下：目录/<原名>，同样是原名
#   - 源目录里那个名字带空格与中文的件，落位后名字一个字符都不差

CASE_NAME="91-apk-filename-preserved"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/apk-harness.sh"

apk_init

# 名字里塞中文、空格、点号、连字符 —— 任何「顺手规范化」都会在这里露馅。
NAME='重铸百科 1.4.0-UI修复版.v2.apk'
make_signed_apk "$SANDBOX/入参/$NAME"
SRC_APK="$SANDBOX/入参/$NAME"

apk_run "$SRC_APK"
assert_rc 0

# 逐名比对：目录里只有这一个文件，且名字与入参完全一致。
CHECKED=$((CHECKED + 1))
[ "$(app_dir_files "$REPO")" = "$NAME" ] \
  || fail "成品/应用 的文件名不是原名，实际：[$(app_dir_files "$REPO")]，期望：[$NAME]"
assert_file "$REPO/成品/应用/$NAME"
assert_content_same "$SRC_APK" "$REPO/成品/应用/$NAME"

# OUT 是目录时同样只拼原名，不做任何清洗。
OUT_DIR="$SANDBOX/指定/目录"
mkdir -p "$OUT_DIR"
APK_ENV=("OUT=$OUT_DIR")
apk_run "$SRC_APK"
assert_rc 0
assert_file "$OUT_DIR/$NAME"

# 名字里不含任何「自制-…」交付前缀：APK 入口不走 NAMING.md 那套改名。
CHECKED=$((CHECKED + 1))
case "$NAME" in
  自制-*) : ;;
esac
PREFIXED="$(find "$OUT_DIR" "$REPO/成品/应用" -maxdepth 1 -type f -name '*自制*' 2>/dev/null | LC_ALL=C sort)"
[ -z "$PREFIXED" ] || fail "APK 入口不该给文件名加交付前缀，实际：$PREFIXED"

harness_done
