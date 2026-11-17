#!/usr/bin/env bash
# build-apk.sh — 把**现成的**签名 APK 收进 成品/应用/。
#
# 这个脚本只做「接收 + 校验 + 落位」：**不签名、不打包、不反编译**，
# 也不依赖 apksigner / apktool / zipalign / aapt2 / gradle。
# 签名必须由构建 APK 的那一侧给出；这里只确认它确实带了签名。
#
# 用法：
#   bash build-apk.sh <apk>                      落 成品/应用/<原文件名>
#   DSHBOX_ARTIFACT_DIR=/path bash build-apk.sh <apk>
#                                                落 /path/应用/<原文件名>（改变默认成品根）
#   OUT=/path/x.apk bash build-apk.sh <apk>      显式文件目标（优先于一切默认）
#   OUT=/path/目录 bash build-apk.sh <apk>       显式目录目标，拼原文件名
#
# 校验（任一不成立就非零退出，且不写任何文件）：
#   - 是合法 zip、根上有 AndroidManifest.xml
#   - META-INF/ 下同时有 *.SF 与 *.RSA|*.DSA|*.EC（只查存在，不验签）
#   - 文件名不是 -unaligned / -unsigned 这类中间打包产物
#
# 纪律：APK 不入库（.gitignore 挡 成品/应用/*.apk），本脚本不碰 git。
#       目标已存在且内容不同 → 冲突，中止且不覆盖（与 ./deliver 同一套纪律）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${DSHBOX_ARTIFACT_DIR:-$ROOT/成品}/应用"

die() { echo "错误：$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        echo "未知选项：$1" >&2; exit 2 ;;
    *)
      [ -z "$INPUT" ] || die "一次只收一个 APK（多余入参：$1）"
      INPUT="$1"
      ;;
  esac
  shift
done

[ -n "$INPUT" ] || { sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }

SRC="$INPUT"
NAME="$(basename "$SRC")"
[ -f "$SRC" ] || die "找不到：$SRC"

# ---------- 文件名筛查：中间产物不许进成品目录 ----------
# -unaligned 是 zipalign 之前、-unsigned 是 apksigner 之前的产物，都不是可交付件。
STEM="${NAME%.apk}"
STEM_LC="$(printf '%s' "$STEM" | tr '[:upper:]' '[:lower:]')"
case "$STEM_LC" in
  *-unaligned) die "$NAME：这是 zipalign 之前的中间产物（-unaligned），不是成品 APK" ;;
  *-unsigned)  die "$NAME：这是签名之前的中间产物（-unsigned），不是成品 APK" ;;
esac
case "$NAME" in
  *.apk) : ;;
  *) die "$NAME：不是 .apk 文件，拒绝收进成品目录" ;;
esac

# ---------- 结构与签名校验 ----------
unzip -tq "$SRC" >/dev/null 2>&1 || die "$NAME：不是合法的 zip/apk"
ENTRIES="$(unzip -Z1 "$SRC" 2>/dev/null)" || die "$NAME：读不出 zip 目录"

printf '%s\n' "$ENTRIES" | grep -qx 'AndroidManifest.xml' \
  || die "$NAME：根上没有 AndroidManifest.xml，不是可安装的 APK"

HAS_SF=0
HAS_BLOCK=0
while IFS= read -r e; do
  u="$(printf '%s' "$e" | tr '[:lower:]' '[:upper:]')"
  case "$u" in
    META-INF/*.SF) HAS_SF=1 ;;
    META-INF/*.RSA|META-INF/*.DSA|META-INF/*.EC) HAS_BLOCK=1 ;;
  esac
done <<< "$ENTRIES"

if [ "$HAS_SF" -eq 0 ] || [ "$HAS_BLOCK" -eq 0 ]; then
  say "校验未通过：$NAME 未签名"
  say "  需要 META-INF/*.SF（清单）与 META-INF/*.RSA|*.DSA|*.EC（签名块）两者都在。"
  say "  现在：*.SF $([ "$HAS_SF" -eq 1 ] && echo 有 || echo 无)，签名块 $([ "$HAS_BLOCK" -eq 1 ] && echo 有 || echo 无)。"
  say "  本脚本不签名：请先用 apksigner 签好再交过来。"
  exit 1
fi

say "校验通过：$NAME（已签名；这里只查签名文件存在，不验签内容）"

# ---------- 目标位置：显式 OUT > DSHBOX_ARTIFACT_DIR > 仓库内 成品/应用 ----------
if [ -n "${OUT:-}" ]; then
  if [ -d "$OUT" ]; then
    TARGET="$OUT/$NAME"
  else
    case "$OUT" in
      */) TARGET="$OUT$NAME" ;;
      *)  TARGET="$OUT" ;;
    esac
  fi
  say "目标：显式 OUT"
else
  TARGET="$APP_DIR/$NAME"
fi

# 冲突判定放在任何写操作之前：目标存在但内容不同时不覆盖、不建目录。
if [ -e "$TARGET" ]; then
  if [ -f "$TARGET" ] && [ "$(sha256sum "$SRC" | cut -d' ' -f1)" = "$(sha256sum "$TARGET" | cut -d' ' -f1)" ]; then
    say "已存在（内容一致，未改动）：$TARGET"
    exit 0
  fi
  die "$TARGET 已存在且内容不同，拒绝覆盖。先确认旧件是否还要，再改名或手动移走旧件。"
fi

mkdir -p "$(dirname "$TARGET")"
cp -p "$SRC" "$TARGET"

# 输出里给仓库相对路径，便于和 ./deliver 的提示对齐；仓库外则给绝对路径。
case "$TARGET" in
  "$ROOT"/*) REL="${TARGET#"$ROOT"/}" ;;
  *)         REL="$TARGET" ;;
esac
say "已落位：$REL"
say "提示：APK 不进 git（.gitignore 挡住 成品/应用/*.apk），这是预期。"
