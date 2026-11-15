# DSHBox

Minecraft **Forge 1.16.5** 自制模组的构建产物工作区与问题跟踪仓库。

本仓库同时被 DSH Desktop 的 deck 插件用作 ISSUE / 探索地图的后端（见 `docs/agents/workspace.yaml`）。

## 模组

5 个模组当前都可分发，最终文件在 `成品/模组/`（文件名由 `NAMING.md` 决定）。其中 3 个没有源码，jar 是唯一实体。

| 模组 | modId | 版本 | 功能域 | 许可证 | 源码 |
|---|---|---|---|---|---|
| Monkey Macros | `monkeymacros` | 1.0.1 | 辅助 | MIT | 有 |
| PokemonKey | `pokemonkey` | 1.1.1 | GOD | All rights reserved | 有 |
| IPN 精妙背包整理兼容 | `ipnbackpacksort` | 1.0.1 | 辅助 | MIT | 无 |
| 我的天哪忍蛙大人（智娃） | `ohmygod_greninja` | 1.1.0 | GOD | MIT | 无 |
| Command Keys | `commandkeys` | 1.0.2 | 工具 | MIT | 无 |

功能域与版本号的权威来源是 `NAMING.md` 与各 jar 的元数据；面向用户的完整清单见 `成品/文档/模组清单.md`（由 `./deliver` 生成，不要手改）。

全部要求 `forge >= 36`、`minecraft [1.16.5,1.17)`。

### PokemonKey 指令

```
/pokemonkey  <玩家> <1-6> <属性|all> <0-252>   # 努力值 EV
/pokemonkey2 <玩家> <1-6> <属性|all> <0-31>    # 个体值 IV
```

属性别名：`hp` 血量、`wg` 物攻、`wf` 物防、`tg` 特攻、`tf` 特防、`speed` 速度，`all` 表示六项全设。需要 OP 权限等级 2。

## 目录

```
成品/模组/*.jar        最终模组 jar（用户直接安装，入库）
成品/应用/*.apk        签名 APK（不入库，仅在盘上）
成品/文档/             安装/指令/更新日志 + 自动生成的模组清单
mods/<modId>/src       Java 源码（从 jar 反编译恢复，见 BUILD.md）
mods/<modId>/resources mods.toml、语言文件、图标、pack.mcmeta
deliver                交付脚本：归档 → 提交 → 推送
NAMING.md              jar 文件名的唯一权威来源（功能域闭合枚举）
GLOSSARY.md            本仓库术语
docs/adr/              架构决定
docs/agents/           deck 插件的工作区声明
build.sh               构建脚本（javac + jar，不依赖 ForgeGradle）
BUILD.md               依赖、构建命令与当前状态
saves/                 存档（455MB，不入库）
```

**构建产物不再放仓库根**：根目录和 `dist/` 里不应有 jar。交付用 `./deliver`，细节见 `AGENTS.md`。

## 当前缺口

- **源码是从 jar 反编译恢复的**：逻辑一致，但最初的注释与写法已经丢失。
- **本机缺 forge / pixelmon 的 jar**：`build.sh` 在这里还跑不出成品，见 `BUILD.md`。
- **没有 CI**：jar 靠本地手工构建，版本号与产物靠人工对齐。
- **许可证不一致**：`monkeymacros` 是 MIT，`pokemonkey` 是 All rights reserved。

## 安装

把需要的 jar 放进游戏实例的 `mods/` 目录。客户端模组（Monkey Macros）只需装在客户端；PokemonKey 是服务端指令模组，需要装在服务端，客户端若要单人使用也需安装。