---
name: deliver
description: 把构建产物归档进 成品/ 并提交推送。当用户要求"交付/归档/发布/把 jar 放进成品/上传仓库"，或刚构建出一个新 jar 时使用。
---

# 交付成品

本仓库的产物归档只有一条路：`./deliver`。不要手工 `cp` 进 `成品/`、不要手工编文件名。

## 操作

```bash
./deliver --check    # 先看计划：会归档什么、会清理什么，不改任何东西
./deliver            # 归档 → 生成清单 → commit → push
./deliver --prune    # 同上，并真删「有源码且被新版取代」的旧产物
./deliver --no-push  # 归档 + commit，不推送
```

不带参数时，`./deliver` 读 `dist/*.jar`；也可以显式传 jar 路径。

## 它做了什么

1. 读 jar 的 `META-INF/mods.toml` 取 `modId`、`MANIFEST.MF` 取 `Implementation-Version`。
2. 查 `NAMING.md` 拿该 modId 的功能域与具体描述，拼成 `[自制-<功能域>-<描述>]<modId>-<版本>.jar`。
3. 按「内容 sha256 + 目标文件名」两键比对，只归档真正变化的。
4. 从 jar 元数据重新生成 `成品/文档/模组清单.md`（不要手改这个文件）。
5. `git add 成品` → commit（`chore(成品): 归档 <ids> 等 N 个产物`）→ push（失败重试两次，仍失败则保留本地提交并提示手动 push）。

## 硬规则

- **未在 `NAMING.md` 登记的 modId 会被拒绝归档。** 遇到这个错误，去 `NAMING.md` 补登记，不要在命令行硬塞一个前缀。
- **永远不要手工删除 `成品/模组/` 里的 jar。** 要删除只能 `git rm` 提交；要清理被取代的旧版用 `--prune`。
- **标着「无源码」的 jar 永不自动删。** 它们没有 `mods/<modId>/src`，删了就再也造不出来。
- **永不 force push、永不重写历史。** push 失败就重试，实在不行把本地提交留着并告诉用户手动 `git push`。
- **不要把源码、构建脚本、日志、截图、存档、底件放进 `成品/`。**

## 构建与归档是两件事

`build.sh` 只产出 `dist/<modId>-<版本>.jar`（无中文前缀）。前缀是 `./deliver` 归档时施加的，所以**不要**为了改前缀去改 `build.sh` 或 `mods.toml`。

本机缺 Forge/Pixelmon 的 jar 时 `build.sh` 跑不出成品，属已知缺口（见 `BUILD.md`），不要为此去装依赖。
