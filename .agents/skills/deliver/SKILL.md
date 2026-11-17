---
name: deliver
description: 把构建产物归档进 成品/ 并提交推送。当用户要求"交付/归档/发布/把 jar 放进成品/上传仓库"，或刚构建出一个新 jar 时使用。
---

# 交付成品

本仓库的产物归档只有一条路：`./deliver`。不要手工 `cp` 进 `成品/`、不要手工编文件名。

## 操作

```bash
./deliver --check     # 先看计划：会归档什么、会清理什么，不改任何东西
./deliver             # 归档 → 生成清单 → commit → push
./deliver --overwrite # 目标已存在且内容不同时，允许覆盖（默认整批中止）
./deliver --prune     # 同上，并真删「有源码且被新版取代」的旧产物
./deliver --no-push   # 归档 + commit，不推送
```

不带参数时，`./deliver` 读 `dist/*.jar`；也可以显式传 jar 路径（`./deliver /path/x.jar`）——
这正是「把别处的 jar 收进来」的做法，仓库里没有 `--migrate` 这种东西。

## 它做了什么

1. 读 jar 的 `META-INF/mods.toml` 取 `modId`、`MANIFEST.MF` 取 `Implementation-Version`。
2. 查 `NAMING.md` 拿该 modId 的功能域与具体描述，拼成 `[自制-<功能域>-<描述>]<modId>-<版本>.jar`。
3. 按「内容 sha256 + 目标文件名」两键比对：目标不存在 = 新增、内容与名字都一样 = 不变、
   **目标存在但内容不同 = 冲突**。
4. 从 jar 元数据重新生成 `成品/文档/模组清单.md`（不要手改这个文件）。
5. `git add 成品` → commit（`chore(成品): 归档 <ids> 等 N 个产物`）→ push（失败重试两次，仍失败则保留本地提交并提示手动 push）。

## 前缀从哪来

**唯一权威是 `NAMING.md` 的模组登记表**，不是 `mods.toml`。

`mods.toml` 里**没有** `artifactName` 这种键，也不该有——Forge 不读自定义键，写了等于没人读，
只会让人以为改了它就能改名。要改前缀就只有一条路：改 `NAMING.md` 那一行的「功能域」或「具体描述」。
仓库**不提供**临时前缀覆盖的入口，也别自己造一个：

```bash
# 错：想靠命令行硬塞一个前缀
./deliver --prefix '[自制-工具-XXXXXXXX]'   # 没有这个开关
```

```diff
# 对：改 NAMING.md 登记表这一行的描述列
- | `commandkeys` | `工具` | `指令按键` | `mods/commandkeys/src` |
+ | `commandkeys` | `工具` | `指令绑定` | `mods/commandkeys/src` |
```

改完再 `./deliver`，目标文件名变了就算「变化」，会以新名落位并产生新提交。旧名字的文件**不会**被
自动删掉（同版本不算「被新版取代」，进不了清理候选）——它会留在 `成品/模组/` 里成为同一份内容的第二个名字。
确认不再需要它时，按纪律手工 `git rm` 提交，不要 `rm`。

## 冲突中止怎么办

看到 `[冲突]` + `错误：有 N 个目标文件已存在且内容不同`、退出码 1，说明**整批都没写入**（这是好事，
没有半套状态）。先别急着加 `--overwrite`，按原因选一条：

| 情况 | 做法 |
|---|---|
| 忘了改版本号，重建的 jar 覆盖了同名旧版 | 改 `MOD_VERSION` 重新构建，让目标名带新版本号——这才是正常发布 |
| 想改名字（描述/功能域变了） | 改 `NAMING.md` 那一行，目标名就不同了，不再是冲突 |
| 确实是同一个版本要修 bug 重发 | 这时才加 `--overwrite`。旧内容仍能从覆盖前的 commit `git show` 取回 |
| 只是想看看 | `--check` 会如实报告冲突详情（两边 sha256）但退 0、零改动 |

`--overwrite` 是「确认要替换」的显式授权，不是消除红字的快捷键。习惯性加上它，等于放弃了这条冲突保护。

## 硬规则

- **未在 `NAMING.md` 登记的 modId 会被拒绝归档。** 遇到这个错误，去 `NAMING.md` 补登记，不要在命令行硬塞一个前缀。
- **永远不要手工删除 `成品/模组/` 里的 jar。** 要删除只能 `git rm` 提交；要清理被取代的旧版用 `--prune`。
- **标着「无源码」的 jar 永不自动删。** 它们没有 `mods/<modId>/src`，删了就再也造不出来。
- **永不 force push、永不重写历史。** push 失败就重试，实在不行把本地提交留着并告诉用户手动 `git push`。
- **不要把源码、构建脚本、日志、截图、存档、底件放进 `成品/`。**

## 构建与归档是两件事

`build.sh` 只产出 `dist/<modId>-<版本>.jar`（无中文前缀）。前缀是 `./deliver` 归档时施加的，所以**不要**为了改前缀去改 `build.sh` 或 `mods.toml`。

`dist/` 是**验证产物**（中间文件），不入库，可随时删掉重建；它本身不是交付物。

本机缺 Forge/Pixelmon 的 jar 时 `build.sh` 跑不出成品，属已知缺口（见 `BUILD.md`），不要为此去装依赖。

## 这不是 APK 的入口

APK 走 `build-apk.sh`，不走 `./deliver`：`./deliver` 要求 `modId` + `NAMING.md` 登记，
APK 两样都没有。用户要收 APK 时给的不是这个 skill。
