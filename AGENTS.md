# AGENTS.md

本仓库维护 DSH Desktop 的地图、Issue、工作流和其他协作能力。改动仓库结构前先读完。

## Agent skills

### Issue tracker

议题与规格说明以 GitHub Issues 存放，用 `gh` CLI 操作。See `docs/agents/issue-tracker.md`.

### Triage labels

五个分诊角色沿用默认标签名：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。See `docs/agents/triage-labels.md`.

### Domain docs

布局为 single-context：一个仓库共用一份根目录的 `GLOSSARY.md`，架构决定放 `docs/adr/`。See `docs/agents/domain.md`.

### 交付边界

Minecraft 模组与软件源码、数据、成品及其构建/交付说明位于公开仓库 `TheYjh/dsh-mods`。本仓库不再保存模组源码、模组成品、软件交付主副本或模组构建测试。

插件（不是模组）发布到另一个仓库 `TheYjh/dsh-plugins`，走 `bash deliver-plugin`，用 `bash tools/plugin-watch.sh` 可挂一个轮询式自动同步。操作手册与失败处置见 `docs/插件入库.md`。

## 工作区边界

DSHBox 是地图与协作仓库。其他 DSH 工作区不向本仓库写入；`插件工作区/`、`日常工作区/` 是未来其他工作区的产物接收区，内部结构由各自的 `AGENTS.md` 决定。底包、日志、截图、存档和构建中间物不入库。

## 历史规则

删除一律用普通前滚提交，永不使用 `filter-repo`/`filter-branch` 重写历史，永不 force push。旧内容必须仍能从 Git 历史取回。
