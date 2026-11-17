# tests/lib/harness.sh — 夹具与断言库，被 tests/cases/*.sh source。
#
# 约定（见 BUILD.md 的「怎么跑测试」与票 #15）：
#   - 测试的唯一接缝是 `deliver` 的命令行边界：造一个临时仓库夹具、跑脚本、
#     断言输出 / 退出码 / 文件系统结果。不 source 脚本内部函数。
#   - 全程离线：夹具仓库的 origin 是 `git init --bare` 造出来的本地裸仓库。
#   - 夹具在本文件里自造，不复制真实 `成品/`，不依赖预置二进制夹具：
#     假 jar 由 `make_jar` 用 `zip` 现场蒸。
#   - 真实 `deliver` 只被**复制**进夹具（cp，不是符号链接），测试永远不改真实文件。

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSHBOX_ROOT="$(dirname "$TESTS_DIR")"
REAL_DELIVER="$DSHBOX_ROOT/deliver"

CASE_NAME="${CASE_NAME:-$(basename "${BASH_SOURCE[1]:-$0}" .sh)}"
FAILURES=0
SANDBOX=""
REPO=""
ORIGIN=""
OUT=""
RC=0
LAST_CMDLINE=""

# ---------- 输出与失败上下文 ----------

# fail <message...>：记一条断言失败，并打印足够的上下文（脚本输出、退出码、
# 目录快照、git 状态）。上下文只打一次，后续失败只打一行，避免刷屏。
fail() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL [%s] %s\n' "$CASE_NAME" "$*" >&2
  if [ "${CONTEXT_DUMPED:-0}" -eq 0 ]; then
    CONTEXT_DUMPED=1
    dump_context
  fi
}

CHECKED=0

dump_context() {
  {
    echo "--- 上下文（$CASE_NAME）---"
    if [ -n "$LAST_CMDLINE" ]; then echo "最后一条命令：$LAST_CMDLINE"; fi
    echo "退出码：${RC:-未设置}"
    if [ -n "$OUT" ] && [ -f "$OUT" ]; then
      echo "--- deliver 输出（尾部 60 行）---"
      tail -n 60 "$OUT"
      echo "--- deliver 输出结束 ---"
    fi
    if [ -n "$REPO" ] && [ -d "$REPO/.git" ]; then
      echo "--- git log --oneline -5 ---"
      git -C "$REPO" log --oneline -5 2>&1
      echo "--- git status --short ---"
      git -C "$REPO" status --short 2>&1
      echo "--- 成品/ 树 ---"
      ( cd "$REPO" && find 成品 -mindepth 0 -printf '%y %p\n' 2>&1 | LC_ALL=C sort )
    fi
  } >&2
}

fatal() {
  printf 'FATAL [%s] %s\n' "$CASE_NAME" "$*" >&2
  dump_context
  exit 1
}

# ---------- 夹具 ----------

# harness_init：建沙箱（mktemp -d）+ trap 清理。REPO 位于沙箱内，
# 并显式断言沙箱在 /tmp 下 —— 防止路径写错、误伤真实仓库。
harness_init() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/dshbox-test.XXXXXX")" || fatal "无法创建临时目录"
  case "$SANDBOX" in
    /tmp/*|/var/tmp/*) : ;;
    *) fatal "临时目录不在 /tmp 下：$SANDBOX（拒绝继续，防止误伤真实仓库）" ;;
  esac
  REPO="$SANDBOX/repo"
  ORIGIN="$SANDBOX/origin.git"
  OUT="$SANDBOX/deliver.out"
  trap 'rm -rf "$SANDBOX"' EXIT
  : > "$OUT"
}

# fixture_naming：从 stdin 读 `modId|功能域|描述` 行，写夹具 NAMING.md。
# 表行格式与真实 NAMING.md 一致，deliver 的 naming_lookup 才认。
fixture_naming() {
  local file="$REPO/NAMING.md"
  {
    cat <<'HEAD'
# 命名表（测试夹具）

`成品/模组/` 中 jar 文件名的唯一权威来源。格式：

```
[自制-<功能域>-<具体描述>]<modId>-<版本>.jar
```

## 功能域（闭合枚举）

| 功能域 | 含义 |
|---|---|
| `GOD` | 改变游戏核心数值/规则 |
| `辅助` | 改善操作或兼容性 |
| `工具` | 提供新命令、新界面 |

## 模组登记

| modId | 功能域 | 具体描述 | 源码 |
|---|---|---|---|
HEAD
    local line modId domain desc
    while IFS='|' read -r modId domain desc; do
      [ -n "${modId:-}" ] || continue
      printf '| `%s` | `%s` | `%s` | `mods/%s/src` |\n' "$modId" "$domain" "$desc" "$modId"
    done
  } > "$file"
}

# fixture_source <modId>：造 mods/<modId>/src/（=「有源码」）。deliver 用
# 「源码目录是否存在」判断可不可重建，所以这个目录决定 prune 行为。
# 里面放一个占位文件：git 不跟踪空目录，没有文件的话夹具提交会直接失败
# （"nothing to commit"），「有源码」这个状态也就进不了任何一次提交。
fixture_source() {
  local dir="$REPO/mods/$1/src"
  mkdir -p "$dir"
  [ -f "$dir/Placeholder.java" ] || printf '// 测试夹具占位\n' > "$dir/Placeholder.java"
}

# naming_set_desc <modId> <新描述>：改夹具命名表的「具体描述」列。
# 用来让目标文件名变化而 jar 内容不变（#15 第 4 条断言 / #16 两键比对）。
naming_set_desc() {
  local id="$1" desc="$2" f="$REPO/NAMING.md"
  awk -v id="$id" -v d="$desc" '
    BEGIN { FS = "|"; OFS = "|" }
    {
      if ($0 ~ /^\| *`/ && index($2, "`" id "`") > 0) { $4 = "`" d "`" }
      print
    }' "$f" > "$f.new" || return 1
  mv "$f.new" "$f"
}

# fixture_repo：在沙箱里造一个能直接跑 deliver 的夹具仓库。
#   - git init（本地 user.name/user.email：本机全局没有）
#   - 夹具命名表（默认登记 demo）与真实 deliver 的副本
#   - 首次提交
#   - 本地裸仓库 origin + push -u，使 @{u} 存在、推送走成功路径
fixture_repo() {
  mkdir -p "$REPO"
  git -C "$REPO" init -q -b main || fatal "git init 失败"
  git -C "$REPO" config user.name "DSHBox Test"
  git -C "$REPO" config user.email "test@dshbox.invalid"
  git -C "$REPO" config commit.gpgsign false

  printf 'demo|GOD|示例交付\n' | fixture_naming
  cp "$REAL_DELIVER" "$REPO/deliver" || fatal "复制 deliver 失败：$REAL_DELIVER"
  chmod +x "$REPO/deliver" 2>/dev/null || true   # Android 挂载上不生效，调用一律 bash

  printf '# 测试夹具\n' > "$REPO/README.md"
  printf '# 术语表（夹具）\n' > "$REPO/GLOSSARY.md"
  # 真实仓库里 dist/ 是构建输出、不入库；夹具照做，否则断言工作树干净时会被它绊倒。
  printf 'dist/\n' > "$REPO/.gitignore"
  git -C "$REPO" add -A || fatal "夹具 git add 失败"
  git -C "$REPO" commit -q -m "fixture: 初始夹具" || fatal "夹具首次提交失败"

  git init -q --bare "$ORIGIN" || fatal "创建裸仓库失败"
  git -C "$REPO" remote add origin "$ORIGIN"
  git -C "$REPO" push -q -u origin main || fatal "夹具首次推送失败"
}

# ---------- 推送相关夹具（#18） ----------

# fixture_commit_offline [message]：在夹具里造一个**只在本地**的提交（默认空提交），
# 不推送 —— 模拟「上一次 push 失败，提交留在本地」的状态。
# 用 --allow-empty 是为了不动工作树：后续 deliver 仍应判定「成品/ 无变化」，
# 这样才测得到「没有新产物、但有未推送提交，仍要把它们推上去」这条语义。
fixture_commit_offline() {
  git -C "$REPO" commit -q --allow-empty -m "${1:-fixture: 离线本地提交}" \
    || fatal "夹具离线提交失败"
}

# remote_break：把夹具的 origin 指到一个**不存在的本地路径**，让 push 必然失败。
# 保留 remote 本身（不删 origin —— 删了 deliver 会走「没有上游」的另一条分支），
# 路径落在沙箱里，全程离线，不碰任何 URL 或域名。
remote_break() {
  git -C "$REPO" remote set-url origin "$SANDBOX/nonexistent/never-a-repo.git" \
    || fatal "把 origin 指向不存在的路径失败"
}

# git_remote_ref <ref>：直接读夹具裸仓库上的 ref（不联网、不用 fetch）。
# 推送是否真的发生，以裸仓库的 ref 为准，不看脚本自己打印了什么。
git_remote_ref() {
  git -C "$ORIGIN" rev-parse --verify -q "$1" 2>/dev/null
}

# assert_remote_ref <ref> <期望 commit>：裸仓库上的那个 ref 正好指向这个 commit。
assert_remote_ref() {
  local ref="$1" want="$2" now
  CHECKED=$((CHECKED + 1))
  now="$(git_remote_ref "$ref")"
  [ "$now" = "$want" ] && return 0
  fail "裸仓库 origin 的 $ref 期望 ${want}，实际 ${now:-（空）}"
}

# ---------- 假 jar ----------

# make_jar <outpath> <modId> <version> [display] [license]
# 假 jar 只要 META-INF/mods.toml + META-INF/MANIFEST.MF 就够 deliver 读元数据。
# 变体：NO_MODID=1 省略 modId；NO_VERSION=1 省略 Implementation-Version
# （此时 deliver 会从文件名 -<ver>.jar 回退，所以那种夹具要给带版本号的文件名）。
make_jar() {
  local out="$1" modid="$2" version="$3"
  local display="${4:-示例显示名}" license="${5:-MIT}"
  local stage abs
  stage="$(mktemp -d "$SANDBOX/jar.XXXXXX")" || fatal "无法创建 jar 暂存目录"
  case "$out" in
    /*) abs="$out" ;;
    *)  abs="$REPO/$out" ;;
  esac
  mkdir -p "$stage/META-INF" "$(dirname "$abs")"

  {
    printf 'Manifest-Version: 1.0\r\n'
    [ "${NO_VERSION:-0}" = 1 ] || printf 'Implementation-Version: %s\r\n' "$version"
    printf '\r\n'
  } > "$stage/META-INF/MANIFEST.MF"

  {
    printf 'modLoader="javafml"\n'
    printf 'loaderVersion="[36,)"\n'
    printf 'license="%s"\n' "$license"
    printf '\n'
    printf '[[mods]]\n'
    [ "${NO_MODID:-0}" = 1 ] || printf 'modId="%s"\n' "$modid"
    printf 'version="${file.jarVersion}"\n'
    printf 'displayName="%s"\n' "$display"
  } > "$stage/META-INF/mods.toml"

  rm -f "$abs"
  ( cd "$stage" && zip -q -r -X "$abs" META-INF ) || fatal "zip 失败：$abs"
  rm -rf "$stage"
}

# ---------- 预置「真实仓库」状态 ----------

# fixture_existing_delivery <modId> <版本>：把夹具摆成真实仓库的样子 ——
# 成品/模组 与 成品/文档 已存在、里面有一份更早的交付、清单是入库的派生物。
# 拒绝路径用例靠它把断言写成「文件列表逐名一致」，而不只是「目录恰好是空的」。
fixture_existing_delivery() {
  local id="$1" ver="$2" name
  mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
  name="$(naming_expected "$id" "$ver")" || fatal "夹具命名表里查不到 $id"
  make_jar "成品/模组/$name" "$id" "$ver" "示例交付" MIT
  printf '# 模组清单\n\n> 哨兵：拒绝路径不得重写本文件。\n' > "$REPO/成品/文档/模组清单.md"
  git -C "$REPO" add -A || fatal "夹具 git add 失败"
  git -C "$REPO" commit -q -m "fixture: 预置成品目录与清单" || fatal "夹具预置提交失败"
}

# ---------- 跑 deliver ----------

# deliver_run [args...]：在夹具仓库里跑真实 deliver 的副本。
# 捕获 stdout+stderr 到 $OUT，退出码到 $RC（不让 set -e 之类的机制中断测试）。
deliver_run() {
  LAST_CMDLINE="bash ./deliver $*"
  local rc=0
  ( cd "$REPO" && bash ./deliver "$@" ) >"$OUT" 2>&1 || rc=$?
  RC=$rc
  return 0
}

# ---------- 断言 ----------

assert_rc() {
  local want="$1"
  CHECKED=$((CHECKED + 1))
  [ "$RC" -eq "$want" ] && return 0
  fail "期望退出码 $want，实际 $RC"
}

assert_file() {
  CHECKED=$((CHECKED + 1))
  [ -f "$1" ] && return 0
  fail "期望文件存在：$1"
}

assert_no_file() {
  CHECKED=$((CHECKED + 1))
  [ ! -e "$1" ] && return 0
  fail "期望文件不存在：$1"
}

# candidate_section：把 deliver 输出里「可清理的旧产物」到「不可再生资产」之间的
# 正文切出来，供清理相关断言用。必须切片——同一个文件名可能（且应该）出现在
# 后面的不可再生资产段落里，直接在整份输出里查会把正确实现判红。
candidate_section() {
  awk '/^可清理的旧产物/ {f=1; next} /^不可再生资产/ {f=0} f' "$OUT"
}

# 默认的 haystack 是上一次 deliver_run 的输出**正文**（$OUT 是文件路径，
# 断言永远比对内容而不是路径 —— 早期版本在这里踩过一次坑）。
assert_contains() {
  local needle="$1" haystack="${2-}"
  CHECKED=$((CHECKED + 1))
  [ -n "${2+x}" ] || haystack="$(cat "$OUT" 2>/dev/null || true)"
  case "$haystack" in
    *"$needle"*) return 0 ;;
  esac
  fail "输出里找不到：$needle"
}

assert_not_contains() {
  local needle="$1" haystack="${2-}"
  CHECKED=$((CHECKED + 1))
  [ -n "${2+x}" ] || haystack="$(cat "$OUT" 2>/dev/null || true)"
  case "$haystack" in
    *"$needle"*) fail "输出里不应出现：$needle" ;;
  esac
}

# hash_tree <dir>：整棵目录的 sha256 指纹（文件名 + 类型 + 内容哈希）。
# 用于 `--check` 前后比对：任何增删改都会改指纹。
# hash_tree_lines <dir> [exclude]：逐行列出「类型 路径 [内容哈希]」，已排序。
hash_tree_lines() {
  local dir="$1" exclude="${2:-}"
  (
    cd "$dir" 2>/dev/null || return 1
    if [ -n "$exclude" ]; then
      find . -mindepth 1 -path "$exclude" -prune -o -printf '%y %p\n'
    else
      find . -mindepth 1 -printf '%y %p\n'
    fi | LC_ALL=C sort | while IFS= read -r line; do
      local kind="${line%% *}" path
      path="${line#* }"
      if [ "$kind" = d ]; then
        printf 'd %s\n' "$path"
      else
        printf '%s %s %s\n' "$kind" "$path" "$(sha256sum -- "$path" 2>/dev/null | cut -d' ' -f1)"
      fi
    done
  )
}

hash_tree() {
  hash_tree_lines "$@" | sha256sum | cut -d' ' -f1
}

# tree_snapshot [dir]：给整棵树拍一张哈希指纹快照（默认 $REPO，排除 .git）。
# 与 assert_tree_unchanged 成对使用；后面那次必须用同一组 dir/exclude，
# 否则 .git 里的提交、ref 更新都会被算成「目录被改动」。
tree_snapshot() {
  TREE_DIR="${1:-$REPO}"
  TREE_EXCLUDE="${2-./.git}"
  TREE_BEFORE_FILE="$SANDBOX/tree.before"
  hash_tree_lines "$TREE_DIR" "$TREE_EXCLUDE" >"$TREE_BEFORE_FILE"
  TREE_BEFORE="$(sha256sum "$TREE_BEFORE_FILE" | cut -d' ' -f1)"
}

# assert_tree_unchanged：与最近一次 tree_snapshot 比对整棵目录（内容 + 结构）。
assert_tree_unchanged() {
  CHECKED=$((CHECKED + 1))
  local after now
  after="$(hash_tree "$TREE_DIR" "$TREE_EXCLUDE")"
  if [ "$TREE_BEFORE" = "$after" ]; then
    return 0
  fi
  fail "目录内容被改动了：$TREE_DIR（before=$TREE_BEFORE after=$after）"
  now="$(mktemp)"
  hash_tree_lines "$TREE_DIR" "$TREE_EXCLUDE" >"$now" 2>/dev/null || true
  {
    printf '  指纹差异（- 改动前，+ 改动后）：\n'
    diff -u "$TREE_BEFORE_FILE" "$now" | sed -n '3,40p' | sed 's/^/    /' || true
  } >&2
  rm -f "$now"
}

assert_git_clean() {
  CHECKED=$((CHECKED + 1))
  local dirty
  dirty="$(git -C "$REPO" status --porcelain 2>/dev/null)"
  [ -z "$dirty" ] && return 0
  fail "期望工作树干净，实际有未提交改动：$dirty"
}

git_count_commits() { git -C "$REPO" rev-list --count HEAD 2>/dev/null; }

assert_head_unchanged() {
  local before="$1" now
  CHECKED=$((CHECKED + 1))
  now="$(git_count_commits)"
  [ "$now" = "$before" ] && return 0
  fail "期望提交数不变（$before），实际 $now"
}

assert_head_increased() {
  local before="$1" now
  CHECKED=$((CHECKED + 1))
  now="$(git_count_commits)"
  [ -n "$now" ] && [ "$now" -gt "$before" ] && return 0
  fail "期望提交数增加（before=$before），实际 $now"
}

# assert_last_commit_touches <path>：最近一次提交改动了这个路径。
assert_last_commit_touches() {
  CHECKED=$((CHECKED + 1))
  local files
  # core.quotepath=false：否则中文路径会被转义成 \346\210\220...，断言永远对不上。
  files="$(git -C "$REPO" -c core.quotepath=false diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)"
  case "$files" in
    *"$1"*) return 0 ;;
  esac
  fail "最近一次提交没有改动 $1；实际改动：${files:-（空）}"
}

assert_content_same() {
  local ha hb
  CHECKED=$((CHECKED + 1))
  if [ ! -f "$1" ] || [ ! -f "$2" ]; then
    fail "内容比对缺少文件：$1 或 $2"
    return 1
  fi
  ha="$(sha256sum -- "$1" | cut -d' ' -f1)"
  hb="$(sha256sum -- "$2" | cut -d' ' -f1)"
  [ "$ha" = "$hb" ] && return 0
  fail "文件内容不一致：$1($ha) vs $2($hb)"
  return 1
}

# ---------- 收尾 ----------

harness_done() {
  if [ "$FAILURES" -eq 0 ]; then
    printf 'PASS %s（%d 条断言）\n' "$CASE_NAME" "$CHECKED"
    exit 0
  fi
  printf 'FAIL %s（%d 条断言失败，共 %d 条）\n' "$CASE_NAME" "$FAILURES" "$CHECKED" >&2
  exit 1
}

# naming_lookup_fixture <modId>：从夹具 NAMING.md 查「功能域|描述」，未登记返回非零。
# 与 deliver 的 naming_lookup 用同一套表行约定，但读的是夹具文件——
# 期望文件名必须由夹具命名表推导，不能在测试里写死前缀。
naming_lookup_fixture() {
  awk -F'|' -v id="$1" '
    $0 ~ /^\| *`/ {
      for (i = 2; i <= 4; i++) { gsub(/`/, "", $i); gsub(/^[ \t]+|[ \t]+$/, "", $i) }
      if ($2 == id) { print $3 "|" $4; exit }
    }' "$REPO/NAMING.md"
}

# naming_expected <modId> <version>：按夹具命名表的域与描述拼出目标文件名。
naming_expected() {
  local id="$1" ver="$2" reg domain desc
  reg="$(naming_lookup_fixture "$id")"
  [ -n "$reg" ] || { echo "（未登记：$id）"; return 1; }
  domain="${reg%%|*}"
  desc="${reg#*|}"
  printf '[自制-%s-%s]%s-%s.jar' "$domain" "$desc" "$id" "$ver"
}

# ---------- 模组清单（#19，纯新增） ----------
#
# 清单是 `deliver` 从 jar 元数据生成的派生物，表头固定为：
#   | 文件 | modId | 版本 | 名称 | 许可证 | 源码 |
# 下面几个函数只做「从清单里抽取事实」，断言的期望值一律来自目录与 jar 的
# 实际状态，用例里不写死清单内容。

# manifest_path：派生清单的路径。
manifest_path() { printf '%s' "$REPO/成品/文档/模组清单.md"; }

# manifest_rows：抽出「文件」列（去掉反引号），按 C 排序。
# 只认数据行（以 `| \`` 开头），表头与分隔行自动跳过。
manifest_rows() {
  awk -F'|' '/^\| *`/ {
    gsub(/`/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2)
    if ($2 != "") print $2
  }' "$(manifest_path)" | LC_ALL=C sort
}

# manifest_source_of <文件名>：该行「源码」列的原文（有 / 无源码）。
# 找不到这一行时返回非零，避免「查不到」被当成空串蒙混过去。
manifest_source_of() {
  awk -F'|' -v f="$1" '
    /^\| *`/ {
      name = $2; gsub(/`/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (name == f) {
        col = $7; gsub(/`/, "", col); gsub(/^[ \t]+|[ \t]+$/, "", col)
        print col; found = 1; exit
      }
    }
    END { if (!found) exit 1 }' "$(manifest_path)"
}

# mod_dir_files：成品/模组 下实际存在的文件名，按 C 排序（从目录推导，不写死）。
# 拒绝路径要断言「文件列表逐名不变」，用这个；只要 jar 时用 mod_dir_jars。
mod_dir_files() {
  ( cd "$REPO" && find "成品/模组" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort )
}

# mod_dir_jars：成品/模组 下实际存在的 jar 文件名，按 C 排序。
mod_dir_jars() {
  ( cd "$REPO" && find "成品/模组" -maxdepth 1 -type f -name '*.jar' -printf '%f\n' | LC_ALL=C sort )
}

# manifest_file_modid_pairs：每行输出「文件名<US>modId」，供需要行内两列配对的断言用。
manifest_file_modid_pairs() {
  awk -F'|' '/^\| *`/ {
    name = $2; gsub(/`/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", name)
    id = $3; gsub(/`/, "", id); gsub(/^[ \t]+|[ \t]+$/, "", id)
    if (name != "") printf "%s|%s\n", name, id
  }' "$(manifest_path)"
}
