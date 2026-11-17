# AGENTS.md

本仓库的完整约定。改动仓库结构、产物归档方式前先读完。

## Agent skills

### Issue tracker

议题与规格说明以 GitHub Issues 存放，用 `gh` CLI 操作。See `docs/agents/issue-tracker.md`.

### Triage labels

五个分诊角色沿用默认标签名：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。See `docs/agents/triage-labels.md`.

### Domain docs

布局为 single-context：一个仓库共用一份根目录的 `GLOSSARY.md`，架构决定放 `docs/adr/`。See `docs/agents/domain.md`.

### 交付 skill

归档成品的操作手册在 `.agents/skills/deliver/SKILL.md`。

插件（不是模组）发布到另一个仓库 `TheYjh/dsh-plugins`，走 `bash deliver-plugin`，用 `bash tools/plugin-watch.sh` 可挂一个轮询式自动同步。操作手册与失败处置见 `docs/插件入库.md`。

## 成品目录

`成品/` 是**用户可直接拿走的东西**，按类别分：

```
成品/模组/*.jar    最终模组 jar，入库
成品/应用/*.apk    签名 APK，不入库（.gitignore 挡住），只在盘上
成品/文档/*.md     面向用户的手写说明 + 自动生成的模组清单，入库
```

**不进 `成品/` 的东西**：源码、构建脚本、`dist/`、日志、截图、存档、底件（如 JRE）。

`成品/` 永远是主副本、永远是唯一被提交的地方。`DSHBOX_ARTIFACT_DIR` 只是在归档后**额外**复制一份到别处，不影响提交。

## 归档纪律

**一条命令交付**：`./deliver`。它会按 `NAMING.md` 把 `dist/*.jar` 改名归档进 `成品/模组/`、刷新 `成品/文档/模组清单.md`、提交并推送。

| 想做的事 | 命令 |
|---|---|
| 先看看会发生什么 | `./deliver --check` |
| 正常交付 | `./deliver` |
| 顺带清理已被取代的旧版 | `./deliver --prune` |
| 只归档不推送 | `./deliver --no-push` |

三条必须遵守的规则（理由见 `docs/adr/0001`）：

1. **历史只前滚。** 删除一律 `git rm` 提交，**永不** `filter-repo`/`filter-branch` 重写历史，**永不** force push。旧版永远能 `git show` 取回。
2. **自动删除需显式授权。** `./deliver` 默认只报告可清理项，不删任何东西。且只有「`mods/<modId>/src` 存在、且已被更高版本取代」的旧产物才可清理。
3. **无源码产物是资产。** jar 没有对应 `mods/<modId>/src` 时，删了就再也造不出来。这类文件永不自动删，清单里标 `无源码`。

## 新增模组时

1. 在 `NAMING.md` 的模组登记表加一行（modId / 功能域 / 具体描述 / 是否有源码）。功能域只能取已登记的枚举值；要新增功能域，先在「功能域」那节登记。
2. 未登记的 modId，`./deliver` 会拒绝归档而不是自己编前缀。

## 工作区边界

DSHBox 是仓库本体，它的 `成品/` 就在仓库根。**其他 DSH 工作区不向本仓库写入**，各自持有自己的 `成品/`；`插件工作区/`、`日常工作区/` 是未来其他工作区的产物接收区，内部结构由各自的 `AGENTS.md` 决定。
