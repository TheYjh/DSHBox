# tests/lib/apk-harness.sh — build-apk.sh 的夹具与断言库，被 tests/cases/87-*.sh / 88-*.sh source。
#
# 设计约束（与 tests/lib/harness.sh 同一套纪律）：
#   - 接缝只有命令行：把真实的 build-apk.sh **复制**进沙箱，用
#     `bash ./build-apk.sh ...` 调用，不 source 脚本内部函数。
#   - 假 APK 由 `zip` 现场蒸：一个含 AndroidManifest.xml 与
#     META-INF/X.SF + META-INF/X.RSA 的最小 zip 就是「已签名」；
#     去掉 META-INF 就是「未签名」。不需要真 apk、不需要签名工具。
#   - 复用 tests/lib/harness.sh 的断言与失败上下文（fail/assert_*/harness_done）。
#   - 这里不建 git 仓库：APK 入口不碰 git（APK 也进不了库），
#     用例要断言的是「落位在哪、有没有落位」，不是提交。
#
# 用法（每个 case）：
#   CASE_NAME="87-..." source tests/lib/apk-harness.sh
#   apk_init                      # 沙箱 + 复制真实脚本
#   make_signed_apk x.apk         # 蒸夹具（或 make_unsigned_apk）
#   apk_run x.apk                 # 跑入口
#   ...断言...
#   harness_done

set -uo pipefail

AH_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AH_ROOT="$(dirname "$AH_TESTS_DIR")"

# shellcheck source=tests/lib/harness.sh
source "$AH_TESTS_DIR/lib/harness.sh"

REAL_BUILD_APK="$AH_ROOT/build-apk.sh"
APK_ENV=()   # apk_run 额外注入的环境变量（NAME=value）

# apk_init：建沙箱（/tmp，由 harness_init 保证）并把真实 build-apk.sh 复制进
# 夹具根 —— 脚本用 BASH_SOURCE 定位仓库根，所以复制品会把产物落在夹具里，
# 真实仓库的 成品/应用/ 一个字节都不会被碰。
apk_init() {
  harness_init
  mkdir -p "$REPO"
  [ -f "$REAL_BUILD_APK" ] || fatal "找不到真实脚本：$REAL_BUILD_APK"
  cp "$REAL_BUILD_APK" "$REPO/build-apk.sh" || fatal "复制 build-apk.sh 失败：$REAL_BUILD_APK"
  chmod +x "$REPO/build-apk.sh" 2>/dev/null || true   # Android 挂载上不生效，调用一律 bash
}

# make_signed_apk <outpath>：蒸一个「已签名」的假 APK。
# 判据只依赖 META-INF 下同时有 *.SF 与 *.RSA（见票面），所以这是最小合法形状。
make_signed_apk() {
  local out="$1" stage
  stage="$(mktemp -d "$SANDBOX/apk.XXXXXX")" || fatal "无法创建 apk 暂存目录"
  mkdir -p "$stage/META-INF" "$(dirname "$out")"
  printf '<?xml version="1.0" encoding="utf-8"?>\n<manifest package="test.fixture" />\n' \
    > "$stage/AndroidManifest.xml"
  printf 'Manifest-Version: 1.0\r\nCreated-By: test fixture\r\n\r\n' \
    > "$stage/META-INF/MANIFEST.MF"
  printf 'Signature-Version: 1.0\r\nSHA-256-Digest-Manifest: 00\r\n\r\n' \
    > "$stage/META-INF/FIXTURE.SF"
  printf 'fixture-signature-block\n' > "$stage/META-INF/FIXTURE.RSA"
  rm -f "$out"
  ( cd "$stage" && zip -q -r -X "$out" AndroidManifest.xml META-INF ) || fatal "zip 失败：$out"
  rm -rf "$stage"
}

# make_unsigned_apk <outpath>：结构对、但没有 META-INF 的未签名 APK。
make_unsigned_apk() {
  local out="$1" stage
  stage="$(mktemp -d "$SANDBOX/apk.XXXXXX")" || fatal "无法创建 apk 暂存目录"
  mkdir -p "$(dirname "$out")"
  printf '<?xml version="1.0" encoding="utf-8"?>\n<manifest package="test.fixture" />\n' \
    > "$stage/AndroidManifest.xml"
  printf 'classes-placeholder\n' > "$stage/classes.dex"
  rm -f "$out"
  ( cd "$stage" && zip -q -r -X "$out" AndroidManifest.xml classes.dex ) || fatal "zip 失败：$out"
  rm -rf "$stage"
}

# apk_run [args...]：在夹具根跑真实 build-apk.sh 的副本。
# DSHBOX_ARTIFACT_DIR / OUT 由 APK_ENV 注入；未注入时用 env 的当前值（都不设）。
apk_run() {
  LAST_CMDLINE="bash ./build-apk.sh $*"
  local rc=0
  ( cd "$REPO" && env "${APK_ENV[@]}" bash ./build-apk.sh "$@" ) >"$OUT" 2>&1 || rc=$?
  RC=$rc
  return 0
}

# app_dir_files [dir]：成品应用目录下实际存在的文件名（默认仓库内 成品/应用），
# 按 C 排序。目录不存在时输出空 —— 拒绝路径要的就是这个。
app_dir_files() {
  ( cd "${1:-$REPO}" && find "成品/应用" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | LC_ALL=C sort )
}

# assert_no_app_files [dir]：默认成品应用目录里一个文件都没有（拒绝路径的判据）。
assert_no_app_files() {
  local files
  CHECKED=$((CHECKED + 1))
  files="$(app_dir_files "${1:-$REPO}")"
  [ -z "$files" ] && return 0
  fail "成品/应用 下不该有文件，实际：$files"
}
