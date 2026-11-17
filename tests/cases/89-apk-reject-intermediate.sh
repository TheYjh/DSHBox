#!/usr/bin/env bash
# 89-apk-reject-intermediate.sh — 未签名与中间产物不进成品目录（#11 第 4 条）
#
# 语义边界：入口不签名，只认已经签好的件。所以「未签名」「zipalign 之前的
# -unaligned」「apksigner 之前的 -unsigned」一律非零退出，且在写任何文件之前退出：
# 成品/应用 不新建目录、不落任何文件，连显式 OUT 也不产出。
#
# 断言（每种拒绝都单独验四件事）：
#   - 退出码非零
#   - 成品/应用 下零文件（目录都不建）
#   - 显式 OUT 指定的文件不存在
#   - 输出点名原因（未签名 / -unaligned / -unsigned）

CASE_NAME="89-apk-reject-intermediate"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/apk-harness.sh"

apk_init

# assert_rejected：一次拒绝路径的统一断言。参数：用例说明
assert_rejected() {
  local what="$1"
  assert_rc 1
  assert_no_app_files "$REPO"
  assert_no_file "$OUT_FILE"
  CHECKED=$((CHECKED + 1))
  [ ! -d "$REPO/成品/应用" ] || fail "$what：拒绝路径不该建出 成品/应用 目录"
}

# ---------- 未签名 ----------
make_unsigned_apk "$SANDBOX/入参/未签名.apk"
UNSIGNED="$SANDBOX/入参/未签名.apk"
OUT_FILE="$SANDBOX/指定/未签名.apk"
APK_ENV=("OUT=$OUT_FILE")
apk_run "$UNSIGNED"
assert_rejected "未签名"
assert_contains "校验未通过：未签名.apk 未签名"
assert_contains "*.SF 无，签名块 无"
assert_contains "本脚本不签名"

# ---------- -unaligned：结构上已签名，但文件名说明是中间产物 ----------
make_signed_apk "$SANDBOX/入参/重铸百科-1.4.0-unaligned.apk"
UNALIGNED="$SANDBOX/入参/重铸百科-1.4.0-unaligned.apk"
OUT_FILE="$SANDBOX/指定/unaligned.apk"
APK_ENV=("OUT=$OUT_FILE")
apk_run "$UNALIGNED"
assert_rejected "-unaligned"
assert_contains "zipalign 之前的中间产物"

# ---------- -unsigned：apksigner 之前的中间产物 ----------
make_signed_apk "$SANDBOX/入参/重铸百科-1.4.0-unsigned.apk"
UNSIGNED_NAME="$SANDBOX/入参/重铸百科-1.4.0-unsigned.apk"
OUT_FILE="$SANDBOX/指定/unsigned.apk"
APK_ENV=("OUT=$OUT_FILE")
apk_run "$UNSIGNED_NAME"
assert_rejected "-unsigned"
assert_contains "签名之前的中间产物"

# ---------- 不是 .apk：防止把随机文件塞进成品目录 ----------
make_signed_apk "$SANDBOX/入参/伪装.zip"
FAKE="$SANDBOX/入参/伪装.zip"
OUT_FILE="$SANDBOX/指定/伪装.zip"
APK_ENV=("OUT=$OUT_FILE")
apk_run "$FAKE"
assert_rc 1
assert_no_app_files "$REPO"
assert_no_file "$OUT_FILE"
assert_contains "不是 .apk 文件"

# ---------- 拒绝路径不许在默认根里留下半成品：再来一个合法件确认目录状态干净 ----------
CHECKED=$((CHECKED + 1))
[ ! -d "$REPO/成品/应用" ] || fail "四次拒绝后 成品/应用 不该存在"

harness_done
