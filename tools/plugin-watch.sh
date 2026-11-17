#!/usr/bin/env bash
# tools/plugin-watch.sh — 插件工作区的轮询式 watcher：内容变了就调 deliver-plugin。
#
#   bash tools/plugin-watch.sh            一直轮询（默认 5 秒一轮）
#   bash tools/plugin-watch.sh --once     只比对一轮就退（便于测试/一次性使用）
#
# 环境变量：
#   DSHBOX_PLUGIN_WATCH_INTERVAL   轮询间隔秒数，默认 5
#   DSHBOX_PLUGIN_SRC              插件源目录，透传给 deliver-plugin
#   DSHBOX_PLUGIN_REPO             插件目标仓库，透传给 deliver-plugin
#
# 为什么是轮询：本机容器里没有 cron、systemd、inotifywait、fswatch、entr
# （`command -v` 全部失败），inotify 这条路走不通，只能定时比对内容指纹。
#
# 指纹规则与 deliver-plugin 完全一致：跳过自带 .git 的第三方克隆，
# 跳过 node_modules / .profile-doctor / *.log，其余文件按「相对路径 + 内容 sha256」。
# 指纹变化后先 debounce 2 秒再同步，避免编辑器连续写文件时同步到半个状态。
#
# 日志追加到 $ROOT/.plugin-sync.log（已在 .gitignore 里）。
# 同步失败不会退出循环（下一轮还能重试），但每轮失败都会在日志里留一行。

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELIVER_PLUGIN="$ROOT/deliver-plugin"
SRC="${DSHBOX_PLUGIN_SRC:-$ROOT/插件工作区}"
REPO="${DSHBOX_PLUGIN_REPO:-/root/share/dsh-plugins}"
INTERVAL="${DSHBOX_PLUGIN_WATCH_INTERVAL:-5}"
LOG="$ROOT/.plugin-sync.log"
DEBOUNCE=2

ONCE=0
case "${1:-}" in
  --once) ONCE=1 ;;
  -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  '') : ;;
  *) echo "未知选项：$1" >&2; exit 2 ;;
esac

die() { echo "错误：$*" >&2; exit 1; }
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

[ -f "$DELIVER_PLUGIN" ] || die "找不到 $DELIVER_PLUGIN"
[ -d "$SRC" ] || die "找不到插件源目录：$SRC（用 DSHBOX_PLUGIN_SRC 指定）"
case "$INTERVAL" in
  ''|*[!0-9]*) die "DSHBOX_PLUGIN_WATCH_INTERVAL 必须是正整数秒：$INTERVAL" ;;
esac
[ "$INTERVAL" -ge 1 ] || die "DSHBOX_PLUGIN_WATCH_INTERVAL 至少为 1：$INTERVAL"

# 指纹：只看会被同步的插件（第三方克隆跳过），因此它等于 deliver-plugin 的输入指纹。
fingerprint() {
  (
    cd "$SRC" || return 1
    find . -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | LC_ALL=C sort \
      | while IFS= read -r name; do
          [ -n "$name" ] || continue
          [ -e "$name/.git" ] && continue          # 第三方克隆：不跟踪
          (
            cd "$name" || exit 0
            find . -mindepth 1 \
              \( -name .git -o -name node_modules -o -name .profile-doctor -o -name '*.log' \) -prune \
              -o -type f -printf '%P\n' \
              | LC_ALL=C sort \
              | while IFS= read -r rel; do
                  printf '%s/%s\t%s\n' "$name" "$rel" "$(sha256sum -- "$rel" | cut -d' ' -f1)"
                done
          )
        done
  ) | sha256sum | cut -d' ' -f1
}

# 收到 INT/TERM：明确退出一行，不留下半截状态。
STOP=0
on_signal() {
  STOP=1
  printf '\nplugin-watch：收到停止信号，退出。\n'
  log "收到停止信号，退出"
  exit 0
}
trap on_signal INT TERM

sync_once() {   # 跑一次 deliver-plugin，把输出也记进日志；返回它的退出码
  local rc=0
  ( cd "$ROOT" && bash "$DELIVER_PLUGIN" ) >> "$LOG" 2>&1 || rc=$?
  return "$rc"
}

log "watcher 启动：src=$SRC repo=$REPO interval=${INTERVAL}s"
printf 'plugin-watch：监视 %s（每 %s 秒比对一次），日志 %s\n' "$SRC" "$INTERVAL" "$LOG"

LAST="$(fingerprint)"
printf 'plugin-watch：初始指纹 %s\n' "$LAST"
log "初始指纹 $LAST"

if [ "$ONCE" -eq 1 ]; then
  # --once：立刻同步一轮就退。不做「变化了才同步」的判定——一次性调用
  # 没有基线可比，强行比对只会永远不触发。退出码沿用 deliver-plugin 的。
  printf 'plugin-watch：--once，同步一轮后退出\n'
  log "--once：同步一轮"
  rc=0
  sync_once || rc=$?
  if [ "$rc" -eq 0 ]; then
    log "--once 同步成功"
    printf 'plugin-watch：同步完成（退出码 0）\n'
  else
    log "--once 同步失败（退出码 $rc）"
    printf 'plugin-watch：同步失败（退出码 %s）\n' "$rc" >&2
  fi
  exit "$rc"
fi

while [ "$STOP" -eq 0 ]; do
  sleep "$INTERVAL"
  [ "$STOP" -eq 0 ] || break
  NOW="$(fingerprint)"
  if [ "$NOW" = "$LAST" ]; then continue; fi

  # debounce：等编辑动作落定，再取一次指纹确认稳定。
  sleep "$DEBOUNCE"
  [ "$STOP" -eq 0 ] || break
  STABLE="$(fingerprint)"
  LAST="$STABLE"

  printf 'plugin-watch：检测到变化（%s），开始同步\n' "$STABLE"
  log "检测到变化：$NOW → $STABLE"
  if sync_once; then
    log "同步成功"
    printf 'plugin-watch：同步完成\n'
  else
    rc=$?
    log "同步失败（退出码 $rc），下一轮继续重试"
    printf 'plugin-watch：同步失败（退出码 %s），已记入日志，下一轮继续\n' "$rc"
  fi
done
