#!/usr/bin/env bash
# 70-plugin-sync-archive.sh — 自研插件被同步进插件仓库并产生一次提交
#
# 断言：
#   - 插件目录（含 lib/、locale/ 等子目录）整体复制进目标仓库，目录名用**源目录名**
#     而不是 package.json 的 name；
#   - node_modules / .profile-doctor / *.log 不复制（镜像过滤规则）；
#   - 输出有 [新增]，退出码 0，产生一次提交，提交信息是 chore(插件): 同步 …；
#   - 裸仓库 origin 的 main 前进到本地 HEAD（真的推上去了）；
#   - README 表格标记之间的表体被重建，含该插件的 name 与 description 首句。

CASE_NAME="70-plugin-sync-archive"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/plugin-harness.sh"

ph_init
ph_repo

# 造一个自研插件：package.json name=dsh-demo-plugin，但目录叫 demo-plugin。
fixture_plugin demo-plugin dsh-demo-plugin 0.1.0 \
  "把演示插件同步进仓库。第二句不该出现在表格里。" \
  "locale/zh.json" "cordis.patch.yml"

# 镜像过滤：这些都不该被复制过去。
mkdir -p "$SRC/demo-plugin/node_modules/left-pad" "$SRC/demo-plugin/.profile-doctor"
printf '不该被复制的依赖\n' > "$SRC/demo-plugin/node_modules/left-pad/index.js"
printf '不该被复制的运行态\n' > "$SRC/demo-plugin/.profile-doctor/state.json"
printf '不该被复制的日志\n' > "$SRC/demo-plugin/run.log"

BEFORE_COMMITS="$(ph_count_commits)"
REMOTE_BEFORE="$(ph_remote_main)"

ph_run
assert_rc 0

# 目录名 = 源目录名（demo-plugin），不是包名（dsh-demo-plugin）。
assert_file "$REPO/demo-plugin/package.json"
assert_file "$REPO/demo-plugin/lib/index.js"
assert_file "$REPO/demo-plugin/locale/zh.json"
assert_file "$REPO/demo-plugin/cordis.patch.yml"
assert_no_file "$REPO/dsh-demo-plugin"

# 过滤规则：这些不进仓库。
assert_no_file "$REPO/demo-plugin/node_modules"
assert_no_file "$REPO/demo-plugin/.profile-doctor"
assert_no_file "$REPO/demo-plugin/run.log"

# 内容逐字节一致。
assert_content_same "$SRC/demo-plugin/lib/index.js" "$REPO/demo-plugin/lib/index.js"
assert_content_same "$SRC/demo-plugin/package.json" "$REPO/demo-plugin/package.json"

assert_contains "[新增] demo-plugin（包 dsh-demo-plugin 0.1.0）"
assert_contains "已提交："
assert_contains "chore(插件): 同步 demo-plugin"
assert_contains "已推送：origin main"

assert_head_increased "$BEFORE_COMMITS"
ph_assert_last_commit_touches "demo-plugin/package.json"
ph_assert_repo_clean

# 推送真的发生了：远端 main 前进，且等于本地 HEAD。
CHECKED=$((CHECKED + 1))
if [ "$(ph_remote_main)" = "$REMOTE_BEFORE" ]; then
  fail "远端 main 没有前进（仍停在 $REMOTE_BEFORE）"
fi
ph_assert_remote_main "$(ph_repo_head)"

# README 表格：表头在位，行里能读到包名与 description 首句（不是整段）。
TABLE="$(ph_table_body)"
assert_contains "| 插件 | 包名 | 一句话 |" "$TABLE"
assert_contains "dsh-demo-plugin" "$TABLE"
assert_contains "把演示插件同步进仓库" "$TABLE"
assert_not_contains "第二句不该出现在表格里" "$TABLE"

# 表格之外的内容不能被脚本吃掉：README 原有的其他小节仍在。
assert_contains "## 各插件说明" "$(ph_readme)"

harness_done
