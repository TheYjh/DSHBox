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

MOD="${1:?用法: $0 <modId>   （modId 即 mods/ 下的目录名，如 commandkeys）}"
case "$MOD" in
  */*|.*) echo "错误：模组标识不能含路径分隔符或以点开头：$MOD" >&2; exit 1 ;;
esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$ROOT/mods/$MOD/src"
RES_DIR="$ROOT/mods/$MOD/resources"

[[ -d "$SRC_DIR" ]] || { echo "没有 $SRC_DIR" >&2; exit 1; }
: "${MC_JAR:?需要 MC_JAR（1.16.5 客户端 jar）}"
: "${FORGE_JAR:?需要 FORGE_JAR（forge universal jar）}"

# ---------- 元数据自洽校验 ----------
# 交付文件名由 ./deliver 按 NAMING.md 施加，而 modId 从 jar 元数据读。
# 所以「目录名 == mods.toml 的 modId」是构建侧必须守住的不变式：
# 两者一旦不一致，构建出的 jar 会以另一个 modId 被归档，前缀与实际模组对不上。
MOD_TOML="$RES_DIR/META-INF/mods.toml"
[[ -f "$MOD_TOML" ]] || { echo "错误：$MOD 缺少 $MOD_TOML（modId 是归档时读元数据的唯一来源）" >&2; exit 1; }
TOML_MODID="$(sed -n 's/^[[:space:]]*modId[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$MOD_TOML" | head -1)"
[[ -n "$TOML_MODID" ]] || { echo "错误：$MOD_TOML 里读不到 modId" >&2; exit 1; }
[[ "$TOML_MODID" = "$MOD" ]] || {
  echo "错误：mods/$MOD/resources 的 mods.toml 声明 modId=\"$TOML_MODID\"，与目录名 $MOD 不符。" >&2
  echo "      交付时会按 jar 里的 modId 归档，名字和目录对不上会归档到别的模组名下。" >&2
  exit 1
}

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