# tests/lib/plugin-harness.sh — deliver-plugin 的夹具与断言库，被 tests/cases/7*.sh source。
#
# 设计约束（与 tests/lib/harness.sh 同一套纪律，但夹具互不污染）：
#   - 接缝只有命令行：把真实的 deliver-plugin **复制**进沙箱，用
#     DSHBOX_PLUGIN_SRC / DSHBOX_PLUGIN_REPO 指到夹具，不 source 脚本内部函数。
#   - 全程离线：目标仓库的 origin 是 `git init --bare` 造的本地裸仓库，
#     先塞一个带 README 表格标记的初始提交，再 clone 一份当「插件仓库」。
#   - 假插件工作区由 fixture_plugin 现场造：package.json + 若干文件，
#     不复制真实 插件工作区/（那里的内容会随开发变动）。
#   - 复用 tests/lib/harness.sh 的断言与失败上下文（fail/assert_*/harness_done），
#     但把 REPO / ORIGIN 重新指向插件夹具的目录。
#
# 用法（每个 case）：
#   CASE_NAME="70-..." source tests/lib/plugin-harness.sh
#   ph_init            # 沙箱 + 复制真实脚本
#   ph_repo            # 裸仓库 origin + 带标记 README 的初始提交 + clone
#   fixture_plugin ... # 造假插件
#   ph_run [args...]   # 跑 deliver-plugin
#   ...断言...
#   harness_done

set -uo pipefail

PH_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PH_ROOT="$(dirname "$PH_TESTS_DIR")"

# 复用既有断言与失败上下文；REPO / ORIGIN 会在 ph_init 里改成插件夹具的路径。
# shellcheck source=tests/lib/harness.sh
source "$PH_TESTS_DIR/lib/harness.sh"

REAL_DELIVER_PLUGIN="$PH_ROOT/deliver-plugin"
PH_SCRIPT=""
SRC=""
PLUGIN_SRC=""

# ph_init：建沙箱、把真实 deliver-plugin 复制进来、定义三个路径。
ph_init() {
  [ -f "$REAL_DELIVER_PLUGIN" ] || {
    echo "FATAL [${CASE_NAME:-?}] 找不到真实脚本：$REAL_DELIVER_PLUGIN" >&2
    exit 1
  }
  harness_init

  SRC="$SANDBOX/plugins"           # 假插件工作区（= DSHBOX_PLUGIN_SRC）
  PLUGIN_SRC="$SRC"
  REPO="$SANDBOX/plugin-repo"      # 目标插件仓库（= DSHBOX_PLUGIN_REPO）
  ORIGIN="$SANDBOX/plugin-origin.git"
  OUT="$SANDBOX/deliver-plugin.out"
  PH_SCRIPT="$SANDBOX/deliver-plugin"

  mkdir -p "$SRC" "$REPO"
  cp "$REAL_DELIVER_PLUGIN" "$PH_SCRIPT" || {
    echo "FATAL [${CASE_NAME:-?}] 复制 deliver-plugin 失败" >&2
    exit 1
  }
  chmod +x "$PH_SCRIPT" 2>/dev/null || true   # Android 挂载上不生效，调用一律 bash
  : > "$OUT"
}

# ph_repo：造「插件仓库」夹具。
#   - 裸仓库 origin，初始提交里有 README.md（带表格标记）、.gitignore、LICENSE；
#   - clone 到 $REPO，配好本地 user.name/email（本机全局没有）；
#   - 本地与远端同步，@{u} 存在，push 走成功路径。
ph_repo() {
  local seed="$SANDBOX/seed"
  mkdir -p "$seed"
  git -C "$seed" init -q -b main || fatal "seed git init 失败"
  git -C "$seed" config user.name "Plugin Sync Test"
  git -C "$seed" config user.email "plugin-sync@test.invalid"
  git -C "$seed" config commit.gpgsign false

  {
    printf '# 插件仓库（夹具）\n\n'
    printf '一句话介绍。\n\n'
    printf '<!-- plugins-table:begin -->\n'
    printf '| 插件 | 作用 | 一句话 |\n'
    printf '|---|---|---|\n'
    printf '<!-- plugins-table:end -->\n\n'
    printf '## 各插件说明\n\n占位。\n'
  } > "$seed/README.md"
  printf 'node_modules/\n*.log\n.DS_Store\n' > "$seed/.gitignore"
  printf 'MIT License（夹具）\n' > "$seed/LICENSE"

  git -C "$seed" add -A || fatal "seed git add 失败"
  git -C "$seed" commit -q -m "fixture: 插件仓库初始状态" || fatal "seed 首次提交失败"

  git init -q --bare --initial-branch=main "$ORIGIN" || fatal "创建裸仓库失败"
  git -C "$seed" remote add origin "$ORIGIN"
  git -C "$seed" push -q -u origin main || fatal "seed 首次推送失败"

  rmdir "$REPO" 2>/dev/null || rm -rf "$REPO"
  git clone -q "$ORIGIN" "$REPO" || fatal "克隆 target 仓库失败"
  git -C "$REPO" config user.name "Plugin Sync Test"
  git -C "$REPO" config user.email "plugin-sync@test.invalid"
  git -C "$REPO" config commit.gpgsign false
}

# fixture_plugin <目录名> <包名> <版本> <描述> [额外相对路径...]：
# 在假插件工作区里造一个自研插件目录。额外的相对路径都会被写成带内容的小文件，
# 用来测镜像复制与镜像删除。
fixture_plugin() {
  local name="$1" pkg="$2" ver="$3" desc="$4"
  shift 4
  local dir="$SRC/$name"
  mkdir -p "$dir/lib"
  {
    printf '{\n'
    printf '  "name": "%s",\n' "$pkg"
    printf '  "version": "%s",\n' "$ver"
    printf '  "description": "%s",\n' "$desc"
    printf '  "main": "lib/index.js"\n'
    printf '}\n'
  } > "$dir/package.json"
  printf '// %s 入口（夹具）\n' "$pkg" > "$dir/lib/index.js"
  local rel
  for rel in "$@"; do
    mkdir -p "$dir/$(dirname "$rel")"
    printf '夹具内容：%s/%s\n' "$name" "$rel" > "$dir/$rel"
  done
}

# fixture_clone <目录名> [包名] [版本]：造一个自带 .git 的「第三方克隆」。
fixture_clone() {
  local name="$1" pkg="${2:-dsh-third-party}" ver="${3:-0.9.0}"
  local dir="$SRC/$name"
  mkdir -p "$dir/assets"
  printf '{\n  "name": "%s",\n  "version": "%s",\n  "description": "第三方插件。"\n}\n' \
    "$pkg" "$ver" > "$dir/package.json"
  printf '美术素材（夹具）\n' > "$dir/assets/art.png"
  git -C "$dir" init -q -b main || fatal "第三方克隆夹具 init 失败"
  git -C "$dir" config user.name "Upstream"
  git -C "$dir" config user.email "upstream@test.invalid"
  git -C "$dir" add -A && git -C "$dir" commit -q -m "upstream: 初始提交" \
    || fatal "第三方克隆夹具提交失败"
}

# ph_run [args...]：跑真实 deliver-plugin 的副本，环境变量指向夹具。
ph_run() {
  LAST_CMDLINE="DSHBOX_PLUGIN_SRC=$SRC DSHBOX_PLUGIN_REPO=$REPO bash deliver-plugin $*"
  local rc=0
  (
    cd "$SANDBOX" || exit 1
    DSHBOX_PLUGIN_SRC="$SRC" DSHBOX_PLUGIN_REPO="$REPO" bash "$PH_SCRIPT" "$@"
  ) >"$OUT" 2>&1 || rc=$?
  RC=$rc
  return 0
}

# ph_watch_run [args...]：同一个夹具下跑真实 tools/plugin-watch.sh 的副本（可选，用于 --once）。
ph_watch_run() {
  local script="$PH_ROOT/tools/plugin-watch.sh" rc=0
  [ -f "$script" ] || fatal "找不到 $script"
  LAST_CMDLINE="DSHBOX_PLUGIN_SRC=$SRC DSHBOX_PLUGIN_REPO=$REPO bash tools/plugin-watch.sh $*"
  (
    cd "$SANDBOX" || exit 1
    DSHBOX_PLUGIN_SRC="$SRC" DSHBOX_PLUGIN_REPO="$REPO" \
      DSHBOX_PLUGIN_WATCH_INTERVAL=1 bash "$script" "$@"
  ) >"$OUT" 2>&1 || rc=$?
  RC=$rc
  return 0
}

# ph_repo_head：目标仓库 HEAD。
ph_repo_head() { git -C "$REPO" rev-parse HEAD 2>/dev/null; }

# ph_count_commits：目标仓库提交数。
ph_count_commits() { git -C "$REPO" rev-list --count HEAD 2>/dev/null; }

# ph_remote_main：裸仓库 origin 上 main 指向的 commit。
ph_remote_main() { git -C "$ORIGIN" rev-parse --verify -q refs/heads/main 2>/dev/null; }

# ph_assert_remote_main：远端 main 与给定 commit 一致。
ph_assert_remote_main() {
  local want="$1" now
  CHECKED=$((CHECKED + 1))
  now="$(ph_remote_main)"
  [ "$now" = "$want" ] && return 0
  fail "裸仓库 origin 的 main 期望 ${want}，实际 ${now:-（空）}"
}

# ph_assert_repo_clean：目标仓库工作树干净。
ph_assert_repo_clean() {
  CHECKED=$((CHECKED + 1))
  local dirty
  dirty="$(git -C "$REPO" status --porcelain 2>/dev/null)"
  [ -z "$dirty" ] && return 0
  fail "期望插件仓库工作树干净，实际：$dirty"
}

# ph_assert_last_commit_touches <路径>：最近一次提交改动了该路径。
ph_assert_last_commit_touches() {
  CHECKED=$((CHECKED + 1))
  local files
  files="$(git -C "$REPO" -c core.quotepath=false diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)"
  case "$files" in
    *"$1"*) return 0 ;;
  esac
  fail "最近一次提交没有改动 $1；实际改动：${files:-（空）}"
}

# ph_readme：目标仓库 README 全文。
ph_readme() { cat "$REPO/README.md" 2>/dev/null || true; }

# ph_table_body：README 里两个标记之间的表体（不含标记行）。
ph_table_body() {
  awk -v b='<!-- plugins-table:begin -->' -v e='<!-- plugins-table:end -->' '
    $0 == b { f = 1; next }
    $0 == e { f = 0 }
    f' "$REPO/README.md" 2>/dev/null
}
