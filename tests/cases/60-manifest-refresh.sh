#!/usr/bin/env bash
# 60-manifest-refresh.sh — 清单随交付刷新、含当次归档的模组（issue #19 第 1 条）
#
# 场景：成品/文档/模组清单.md 是入库的派生物，每次 `./deliver` 都要重写它。
# 交付一个新 jar 之后，清单里必须能找到**当次归档**的模组（按 modId 和目标文件名
# 双向查），而且清单必须和 jar 在**同一个提交**里 —— 否则克隆仓库的人会看到
# 「有 jar 没清单」或「清单独自漂移」的中间状态。
#
# 断言：
#   - 退出码 0，输出含「已生成：成品/文档/模组清单.md」
#   - 清单里能找到刚归档的 modId 与目标文件名
#   - 最近一次提交同时改动了新 jar 与 成品/文档/模组清单.md
#   - 清单里该行的版本列等于 jar 元数据里的版本（清单是派生物，不许撒谎）

CASE_NAME="60-manifest-refresh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

harness_init
fixture_repo

# 真实仓库里 成品/模组、成品/文档 已存在，清单是已入库的派生物；夹具对齐。
mkdir -p "$REPO/成品/模组" "$REPO/成品/文档"
printf '# 模组清单\n\n> 哨兵：交付前的内容，交付后必须被重写。\n' > "$(manifest_path)"
git -C "$REPO" add -A || fatal "夹具 git add 失败"
git -C "$REPO" commit -q -m "fixture: 预置入库的空清单" || fatal "夹具预置提交失败"

EXPECTED="$(naming_expected demo 1.2.3)" || fatal "夹具命名表里查不到 demo"
make_jar dist/demo-1.2.3.jar demo 1.2.3 "示例交付" MIT

BEFORE_COMMITS="$(git_count_commits)"

deliver_run
assert_rc 0

assert_file "$REPO/成品/模组/$EXPECTED"
assert_file "$(manifest_path)"
assert_contains "已生成：成品/文档/模组清单.md"

# 哨兵被重写掉：清单是派生物，不是追加、不是手改。
MANIFEST_TEXT="$(cat "$(manifest_path)")"
assert_not_contains "哨兵" "$MANIFEST_TEXT"
# 表头存在（读者靠它理解每一列）。
assert_contains "| 文件 | modId | 版本 | 名称 | 许可证 | 源码 |" "$MANIFEST_TEXT"

# 当次归档的模组在清单里：modId 与目标文件名两条途径都要找得到。
assert_contains '`demo`' "$MANIFEST_TEXT"
assert_contains "\`$EXPECTED\`" "$MANIFEST_TEXT"

# 该行的版本列与 jar 元数据一致（从 jar 实际内容读，不写死 1.2.3）。
CHECKED=$((CHECKED + 1))
ROW_VER="$(awk -F'|' -v f="$EXPECTED" '
  /^\| *`/ {
    name = $2; gsub(/`/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", name)
    if (name == f) { col = $4; gsub(/^[ \t]+|[ \t]+$/, "", col); print col; found = 1; exit }
  }
  END { if (!found) exit 1 }' "$(manifest_path)")"
JAR_VER="$(unzip -p "$REPO/成品/模组/$EXPECTED" META-INF/MANIFEST.MF | sed -n 's/^Implementation-Version:[[:space:]]*\(.*\)$/\1/p' | head -1 | tr -d '\r')"
if [ -z "$ROW_VER" ] || [ "$ROW_VER" != "$JAR_VER" ]; then
  fail "清单版本列与 jar 元数据不一致：清单「${ROW_VER:-（无该行）}」 vs jar「$JAR_VER」"
fi

# 清单与 jar 在同一个提交里：一次交付 = 一个自洽的快照。
assert_head_increased "$BEFORE_COMMITS"
assert_last_commit_touches "成品/模组/$EXPECTED"
assert_last_commit_touches "成品/文档/模组清单.md"
assert_git_clean

harness_done
