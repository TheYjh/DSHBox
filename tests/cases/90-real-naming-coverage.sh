#!/usr/bin/env bash
# 90-real-naming-coverage.sh — 真实仓库的命名登记必须齐备（#10 第 2 条）
#
# 这条用例与其他用例不同：它**读**真实仓库（不写、不提交、不在里面跑 deliver），
# 检查的是一个跨文件的静态不变式 —— 有源码的模组，其 modId 必须：
#   1. 与目录名一致（mods.toml 的 modId == mods/<目录名>）
#   2. 在 NAMING.md 的模组登记表里有一行
#   3. 功能域是枚举内的值，具体描述非空
#
# 为什么值得单独锁：其他用例都在夹具里造数据，永远看不到真实命名表漏登一行。
# 漏登不会立刻报错 —— 只有等你真去交付那个模组时 deliver 才会拒绝。
# 把它变成测试，是为了在「加了个新模组忘了登记」的当下就红。
#
# 断言：
#   - 至少有一个模组目录（防止 glob 写错导致空循环冒充通过）
#   - 每个模组的 modId、登记行、功能域、描述全部齐备
#   - 反方向：表里的每一行也要对得上版本库（源码列写 mods/<id>/src 就必须真入库；
#     只在本地盘上的目录不能谎称入库）

CASE_NAME="90-real-naming-coverage"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init   # 只为拿到 fail/assert 这套记账；不建夹具仓库

NAMING_REAL="$DSHBOX_ROOT/NAMING.md"
MODS_REAL="$DSHBOX_ROOT/mods"

assert_file "$NAMING_REAL"

# 读真实命名表的枚举与登记行。与 deliver 用同一套表行约定。
enum_domains() {
  awk '
    /^## / { sec = ($0 ~ /功能域/); next }
    sec && /^\| *`/ {
      line = $0
      sub(/^\| */, "", line); sub(/ *\|.*/, "", line); gsub(/`/, "", line)
      if (line != "") print line
    }' "$NAMING_REAL"
}

registered_domain() {
  awk -F'|' -v id="$1" '
    $0 ~ /^\| *`/ {
      for (i = 2; i <= 4; i++) { gsub(/`/, "", $i); gsub(/^[ \t]+|[ \t]+$/, "", $i) }
      if ($2 == id) { print $3; exit }
    }' "$NAMING_REAL"
}

registered_desc() {
  awk -F'|' -v id="$1" '
    $0 ~ /^\| *`/ {
      for (i = 2; i <= 4; i++) { gsub(/`/, "", $i); gsub(/^[ \t]+|[ \t]+$/, "", $i) }
      if ($2 == id) { print $4; exit }
    }' "$NAMING_REAL"
}

DOMAINS="$(enum_domains)"
CHECKED=$((CHECKED + 1))
if [ -z "$DOMAINS" ]; then
  fail "从 $NAMING_REAL 读不到功能域枚举（表结构变了？）"
fi

shopt -s nullglob
MOD_DIRS=("$MODS_REAL"/*/)
shopt -u nullglob

CHECKED=$((CHECKED + 1))
if [ "${#MOD_DIRS[@]}" -eq 0 ]; then
  fail "在 $MODS_REAL 下没找到任何模组目录"
fi

for d in "${MOD_DIRS[@]}"; do
  id="$(basename "$d")"
  toml="$d/resources/META-INF/mods.toml"

  CHECKED=$((CHECKED + 1))
  if [ ! -f "$toml" ]; then
    fail "模组 $id 缺 resources/META-INF/mods.toml（deliver 会读不到 modId）"
    continue
  fi

  declared="$(sed -n 's/^[[:space:]]*modId[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$toml" | head -1)"
  CHECKED=$((CHECKED + 1))
  if [ "$declared" != "$id" ]; then
    fail "模组 $id：mods.toml 声明 modId=\"$declared\"，与目录名不符（构建会被 build.sh 拒绝，交付也会归档到别的名下）"
  fi

  domain="$(registered_domain "$id")"
  CHECKED=$((CHECKED + 1))
  if [ -z "$domain" ]; then
    fail "模组 $id 未在 NAMING.md 的模组登记表里登记（deliver 会拒绝归档）"
    continue
  fi

  CHECKED=$((CHECKED + 1))
  if ! printf '%s\n' "$DOMAINS" | grep -qxF -- "$domain"; then
    fail "模组 $id 的功能域「$domain」不在 NAMING.md 的功能域枚举里（deliver 会拒绝归档）"
  fi

  CHECKED=$((CHECKED + 1))
  if [ -z "$(registered_desc "$id")" ]; then
    fail "模组 $id 在 NAMING.md 的「具体描述」列为空（拼不出交付文件名）"
  fi
done

# 反方向：命名表的每一行也必须对得上**版本库里**的事实。
# 只查「磁盘上的 mods/ → 表里有行」是不够的——磁盘上有、库里没有的目录（未跟踪）
# 会让表格写下一个在新克隆里并不存在的源码路径。表格是入库文件，要按新克隆的事实写，
# 所以这里用 git ls-files 判「在不在库里」，而不是 test -d 判「盘上有没有」。
for id in $(awk '
  /^## / { sec = ($0 ~ /模组登记/); next }
  sec && /^\| *`/ {
    gsub(/`/, "", $0)
    n = split($0, c, "|")
    id = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", id)
    if (id != "") print id
  }' "$NAMING_REAL"); do
  src_cell="$(awk -F'|' -v id="$id" '
    $0 ~ /^\| *`/ {
      for (i = 2; i <= 5; i++) { gsub(/`/, "", $i); gsub(/^[ \t]+|[ \t]+$/, "", $i) }
      if ($2 == id) { print $5; exit }
    }' "$NAMING_REAL")"

  CHECKED=$((CHECKED + 1))
  if [ -z "$src_cell" ]; then
    fail "NAMING.md 里 $id 的「源码」列为空（不知道该模组有没有源码）"
    continue
  fi

  # 列的取值只有两种：`mods/<id>/src`（声称已入库）或「未入库」。
  case "$src_cell" in
    未入库*)
      # 声称未入库：库里就真不该有它的源码，否则是过时的悲观描述。
      CHECKED=$((CHECKED + 1))
      if git -C "$DSHBOX_ROOT" ls-files --error-unmatch "mods/$id/src" >/dev/null 2>&1; then
        fail "NAMING.md 说 $id 的源码未入库，但 mods/$id/src 已经在版本库里了（描述过期，改成 mods/$id/src）"
      fi
      ;;
    mods/*/src)
      CHECKED=$((CHECKED + 1))
      if ! git -C "$DSHBOX_ROOT" ls-files "mods/$id/src" | grep -q .; then
        fail "NAMING.md 说 $id 的源码在 mods/$id/src，但版本库里没有（磁盘上有也可能只是未跟踪；表是入库文件，得按新克隆写）"
      fi
      ;;
    *)
      CHECKED=$((CHECKED + 1))
      fail "NAMING.md 里 $id 的「源码」列是「$src_cell」：只允许 mods/<modId>/src 或「未入库」"
      ;;
  esac
done

harness_done
