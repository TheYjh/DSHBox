#!/usr/bin/env bash
# 71-plugin-sync-skip-clone.sh — 自带 .git 的第三方克隆被跳过，且必须如实报告
#
# 场景：源目录里同时有自研插件和一份带 .git 的第三方克隆（whale-src 那种）。
# 断言：
#   - 第三方目录不出现在目标仓库里（连 assets 下的美术素材也不进）；
#   - 它不是被静默忽略：输出里有一行「[跳过] <目录>：自带 .git（第三方克隆），不自动入库」；
#   - 自研插件照常同步，提交信息只包含自研插件名；
#   - 再跑一次 --check 时跳过项仍然报告（跳过是稳定的判定，不是一次性副作用）。

CASE_NAME="71-plugin-sync-skip-clone"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/plugin-harness.sh"

ph_init
ph_repo

fixture_plugin mine-plugin dsh-mine-plugin 0.2.0 "自研插件，会入库。"
fixture_clone third-party-src dsh-third-party 0.9.0

# 硬前提：跳过判定必须建立在「真的有 .git」上。
CHECKED=$((CHECKED + 1))
[ -d "$SRC/third-party-src/.git" ] || fail "前置条件不成立：夹具里的第三方目录没有 .git"

ph_run
assert_rc 0

# 第三方目录整体不出现。
assert_no_file "$REPO/third-party-src"
assert_no_file "$REPO/third-party-src/package.json"
assert_no_file "$REPO/third-party-src/assets/art.png"

# 跳过必须被报告，而不是静默过滤。
assert_contains "[跳过] third-party-src：自带 .git（第三方克隆），不自动入库"
assert_contains "跳过 1 个"

# 自研插件照常入库，提交信息里不出现第三方目录名。
assert_file "$REPO/mine-plugin/package.json"
assert_contains "chore(插件): 同步 mine-plugin"

CHECKED=$((CHECKED + 1))
if grep -qF "chore(插件): 同步 mine-plugin,third-party-src" "$OUT"; then
  fail "提交信息把被跳过的第三方克隆也算进了同步列表"
fi

# 提交树里也确实没有它（防止「复制了又删掉」这种侥幸通过）。
CHECKED=$((CHECKED + 1))
if git -C "$REPO" ls-tree -r --name-only HEAD | grep -q '^third-party-src/'; then
  fail "HEAD 树里仍然有 third-party-src/ 的文件"
fi

# 幂等：--check 仍报告跳过项，且零改动。
ph_assert_repo_clean
tree_snapshot "$REPO" "./.git"
ph_run --check
assert_rc 0
assert_contains "[跳过] third-party-src"
assert_tree_unchanged

harness_done
