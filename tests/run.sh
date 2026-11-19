#!/usr/bin/env bash
# tests/run.sh — 插件同步回归测试的唯一入口。
#
#   bash tests/run.sh              # 跑全部用例
#   bash tests/run.sh 70-archive   # 只跑匹配的用例（glob 作用于 cases/<文件> 与去掉扩展名后的名字）
#
# 每个 case 是独立进程（独立 bash + 自己的临时夹具仓库），互不影响。
# 任一 case 失败 → 整体非零退出。全程离线：夹具的 origin 是本地裸仓库，
# 真实 git 配置与真实远端都不会被触碰。
#
# 模组构建与交付（build.sh / deliver / build-apk.sh）的回归测试已随内容迁移到
# TheYjh/dsh-mods；本仓库只保留插件同步（deliver-plugin、tools/plugin-watch.sh）的用例。

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES_DIR="$TESTS_DIR/cases"
HARNESS="$TESTS_DIR/lib/harness.sh"

if [ ! -f "$HARNESS" ]; then
  echo "错误：缺少 $HARNESS" >&2
  exit 2
fi
if [ ! -f "$TESTS_DIR/../deliver-plugin" ]; then
  echo "错误：找不到 $TESTS_DIR/../deliver-plugin（测试必须针对真实的插件同步脚本）" >&2
  exit 2
fi
if [ ! -f "$TESTS_DIR/lib/plugin-harness.sh" ]; then
  echo "错误：缺少 $TESTS_DIR/lib/plugin-harness.sh（插件用例的夹具库）" >&2
  exit 2
fi

PATTERN="${1:-}"
shopt -s nullglob
ALL=("$CASES_DIR"/*.sh)
shopt -u nullglob

if [ ${#ALL[@]} -eq 0 ]; then
  echo "错误：$CASES_DIR 下没有用例" >&2
  exit 2
fi

SELECTED=()
for f in "${ALL[@]}"; do
  base="$(basename "$f" .sh)"
  if [ -z "$PATTERN" ]; then
    SELECTED+=("$f")
    continue
  fi
  # shellcheck disable=SC2053
  if [[ "$base" == $PATTERN || "$(basename "$f")" == $PATTERN ]]; then
    SELECTED+=("$f")
  fi
done

if [ ${#SELECTED[@]} -eq 0 ]; then
  echo "错误：没有用例匹配「$PATTERN」" >&2
  echo "可用用例：" >&2
  for f in "${ALL[@]}"; do echo "  $(basename "$f" .sh)" >&2; done
  exit 2
fi

echo "== DSHBox 插件同步测试 =="
echo "测试目录：$TESTS_DIR"
echo "用例数：${#SELECTED[@]}"
echo

PASS=0
FAIL=0
FAILED_NAMES=()

for f in "${SELECTED[@]}"; do
  base="$(basename "$f" .sh)"
  echo "--- $base ---"
  if CASE_NAME="$base" bash "$f"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$base")
  fi
  echo
done

echo "=============================="
if [ "$FAIL" -eq 0 ]; then
  echo "通过 $PASS，失败 $FAIL"
  exit 0
fi
echo "通过 $PASS，失败 $FAIL"
echo "失败用例：${FAILED_NAMES[*]}"
exit 1
