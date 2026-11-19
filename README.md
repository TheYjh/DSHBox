# DSHBox

DSH Desktop 的地图、Issue、工作流和其他技能仓库。

模组与软件已经迁移到公开仓库 [`TheYjh/dsh-mods`](https://github.com/TheYjh/dsh-mods)，其中保留了迁移前的完整 Git 历史。DSHBox 当前分支只维护协作后端和其他 DSH 能力；不要在这里重新添加模组源码、模组成品或软件交付主副本。

## 本仓库职责

- GitHub Issue 与规格说明后端：由 `docs/agents/workspace.yaml` 和 deck 工具管理。
- 探索地图、实施票、进度和协作流程。
- DSH 插件发布说明与 `TheYjh/dsh-plugins` 的同步入口。
- 仓库级术语、架构决定和 Agent 约定。

## 模组与软件仓库

模组源码、资源/数据、成品 jar、网页 UI 修复源码及其构建/交付说明位于 [`TheYjh/dsh-mods`](https://github.com/TheYjh/dsh-mods)。迁移采用普通前滚提交完成，没有重写历史或 force push；旧内容仍可从本仓库历史和新仓库历史追溯。

## 工作区边界

`插件工作区/` 与 `日常工作区/` 是其他 DSH 工作区的产物接收区，不属于本仓库内容。底包、日志、截图、存档和构建中间物也不应提交到本仓库。

## Issue 与规格

Issue/规格使用 GitHub Issues，操作约定见 `docs/agents/issue-tracker.md`；地图和进度使用 deck 工具。仓库结构和术语规则见 `AGENTS.md`、`GLOSSARY.md` 与 `docs/agents/`。
