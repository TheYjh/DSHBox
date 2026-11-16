#!/usr/bin/env bash
# 构建 Forge 1.16.5 模组 jar。
#
# 这个工程不用 ForgeGradle/MDK：源码直接对着 SRG 名（生产名）的 1.16.5 客户端 jar 编译，
# 所以只需要把依赖 jar 丢进 classpath。依赖靠下面的环境变量给。
#
#   MC_JAR       必填  1.16.5 客户端 jar（SRG 名），来自 Mojang 版本清单 downloads.client
#   FORGE_JAR    必填  forge-1.16.5-36.x-universal.jar
#   PIXELMON_JAR 可选  pokemonkey 需要
#   EXTRA_JARS   可选  冒号分隔的其它依赖（如 configured）
#
# 用法：
#   MC_JAR=/path/client-1.16.5.jar FORGE_JAR=/path/forge-universal.jar ./build.sh commandkeys
#   MC_JAR=... FORGE_JAR=... PIXELMON_JAR=... ./build.sh pokemonkey
set -euo pipefail

MOD="${1:?用法: $0 <commandkeys|pokemonkey>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$ROOT/mods/$MOD/src"
RES_DIR="$ROOT/mods/$MOD/resources"

[[ -d "$SRC_DIR" ]] || { echo "没有 $SRC_DIR" >&2; exit 1; }
: "${MC_JAR:?需要 MC_JAR（1.16.5 客户端 jar）}"
: "${FORGE_JAR:?需要 FORGE_JAR（forge universal jar）}"

CP="$MC_JAR:$FORGE_JAR"
for v in "${PIXELMON_JAR:-}" "${EXTRA_JARS:-}"; do
  [[ -n "$v" ]] && CP="$CP:$v"
done

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

mkdir -p "$ROOT/dist" "$OUT_DIR/classes"
echo "== 编译 $MOD =="
# --release 8：1.16.5 跑在 Java 8 上
javac --release 8 -encoding UTF-8 -Xlint:-options \
  -cp "$CP" -d "$OUT_DIR/classes" \
  $(find "$SRC_DIR" -name '*.java')

echo "== 打包 =="
cp -r "$RES_DIR/." "$OUT_DIR/classes/"

# mods.toml 里写的是 version="${file.jarVersion}"，Forge 从 jar 清单的
# Implementation-Version 取这个值，所以版本号必须在这一步写进 MANIFEST。
VERSION="${MOD_VERSION:-0.0.0-dev}"
cat > "$OUT_DIR/MANIFEST.MF" <<EOF
Manifest-Version: 1.0
Implementation-Title: $MOD
Implementation-Version: $VERSION
EOF

TARGET="$ROOT/dist/$MOD-$VERSION.jar"
jar --create --file "$TARGET" --manifest "$OUT_DIR/MANIFEST.MF" -C "$OUT_DIR/classes" .
echo "产物：$TARGET"