# DSHBox 协作术语

本仓库是 DSH Desktop 的地图、Issue、工作流和其他协作能力仓库。模组与软件的源码、数据、成品和构建/交付说明位于 `TheYjh/dsh-mods`，本表不再定义模组交付流程。

## Language

**地图**:

DSH Desktop 中用于探索、拆分和跟踪工作范围的顶层 Issue 及其子票关系。
_Avoid_: 普通任务列表

**规格**:

描述目标、边界、验收标准和实现约束的 Issue，供后续实施票引用。
_Avoid_: 临时讨论

**协作后端**:

由 `docs/agents/workspace.yaml` 声明并由 deck 工具使用的 GitHub Issue 数据源。
_Avoid_: 本地缓存

**工作区**:

一个独立的 DSH 工作目录，各自持有自己的协作或产物边界。DSHBox 只维护地图和协作内容；模组与软件工作区位于 `TheYjh/dsh-mods`。
_Avoid_: 随意共享目录

**前滚删除**:

通过普通 Git 提交删除当前分支中的内容，不改写历史、不 force push；旧内容仍可从历史提交恢复。
_Avoid_: 历史清理
