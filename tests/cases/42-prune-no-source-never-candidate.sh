#!/usr/bin/env bash
# 42-prune-no-source-never-candidate.sh — 无源码旧版永不进清理候选（issue #17 第 3 条）
#
# 这是本规格里风险最高的一条，**单独成一条用例，不与其他断言合并**。
# 场景：legacy 的 1.0.0 jar 已经在 成品/模组/ 里，但仓库里没有 mods/legacy/src
# （= 删了就再也造不出来）。之后交付同 modId 的更高版本 1.1.0：
# 按「版本被取代」它看似该清，按 ADR 0001 它一个字都不许删。
#
# 断言：
#   - 输出里**不出现**它作为可清理候选（候选段落整体为空）
#   - 它出现在「不可再生资产（无 mods/<modId>/src，永不自动删除）」段落里
#   - 加 --prune 后它**仍在**盘上，且内容没变

CASE_NAME="42-prune-no-source-never-candidate"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# legacy 要登记（否则归档新版本会被拒），但**不**建 mods/legacy/src。
printf 'demo|GOD|示例交付\nlegacy|工具|历史遗留\n' | fixture_naming

mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
LEGACY_OLD_NAME="$(naming_expected legacy 1.0.0)" || fatal "夹具命名表里查不到 legacy"
LEGACY_NEW_NAME="$(naming_expected legacy 1.1.0)" || fatal "夹具命名表里查不到 legacy"

# 直接摆进 成品/模组（模拟「历史上交付过、但源码早已丢失」），不经过 deliver。
make_jar "成品/模组/$LEGACY_OLD_NAME" legacy 1.0.0 "历史遗留" MIT
OLD_HASH="$(sha256sum -- "$REPO/成品/模组/$LEGACY_OLD_NAME" | cut -d' ' -f1)"
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置无源码旧产物" || fatal "夹具预置提交失败"

# 硬前提：确实没有源码目录，否则这条用例测的就不是「无源码」了。
CHECKED=$((CHECKED + 1))
if [ -d "$REPO/mods/legacy/src" ]; then
  fail "夹具不该有 mods/legacy/src —— 这条用例要测的正是无源码资产"
fi

make_jar dist/legacy-1.1.0.jar legacy 1.1.0 "历史遗留" MIT

deliver_run
assert_rc 0
assert_file "$REPO/成品/模组/$LEGACY_NEW_NAME"

# 候选段落必须为空。用 awk 把「可清理的旧产物」到「不可再生资产」之间的正文切出来，
# 只在这个切片里查 —— 因为同一个文件名会（且应该）出现在后面的不可再生资产段落里。
candidate_section() {
  awk '/^可清理的旧产物/ {f=1; next} /^不可再生资产/ {f=0} f' "$OUT"
}
CHECKED=$((CHECKED + 1))
CAND="$(candidate_section)"
case "$CAND" in
  *"$LEGACY_OLD_NAME"*) fail "无源码旧版不该出现在可清理候选里：$CAND" ;;
esac
case "$CAND" in
  *"1.0.0 → 1.1.0"*) fail "无源码旧版不该被标成「1.0.0 → 1.1.0」候选：$CAND" ;;
esac
assert_contains "可清理的旧产物：无"
assert_contains "不可再生资产"
assert_contains "[无源码] $LEGACY_OLD_NAME"

# 加 --prune 也不许删它。
deliver_run --prune
assert_rc 0
assert_not_contains "已删除"
assert_file "$REPO/成品/模组/$LEGACY_OLD_NAME"
assert_file "$REPO/成品/模组/$LEGACY_NEW_NAME"

# 旧文件一个字节都没变。
CHECKED=$((CHECKED + 1))
now_hash="$(sha256sum -- "$REPO/成品/模组/$LEGACY_OLD_NAME" | cut -d' ' -f1)"
if [ "$OLD_HASH" != "$now_hash" ]; then
  fail "无源码旧版内容被改动了：$OLD_HASH → $now_hash"
fi

assert_git_clean

harness_done
