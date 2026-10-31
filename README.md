# DSHBox

Minecraft **Forge 1.16.5** 自制模组的构建产物工作区与问题跟踪仓库。

本仓库同时被 DSH Desktop 的 deck 插件用作 ISSUE / 探索地图的后端（见 `docs/agents/workspace.yaml`）。

## 模组

| 模组 | modId | 版本 | 端 | 许可证 | 说明 |
|---|---|---|---|---|---|
| Monkey Macros | `monkeymacros` | 1.0.1（另有 1.0.0） | 客户端 | MIT | 按键宏：在 Configured 配置界面配最多 12 条宏，每条绑定一个按键，按下后按顺序执行宏内的多条指令 |
| PokemonKey | `pokemonkey` | 1.1.0 | 服务端 | All rights reserved | 基于 Pixelmon Reforged 9.x，用指令直接设置队伍宝可梦的努力值（EV）与个体值（IV） |

两者都要求 `forge >= 36`、`minecraft [1.16.5,1.17)`。

### PokemonKey 指令

```
/pokemonkey  <玩家> <1-6> <属性|all> <0-252>   # 努力值 EV
/pokemonkey2 <玩家> <1-6> <属性|all> <0-31>    # 个体值 IV
```

属性别名：`hp` 血量、`wg` 物攻、`wf` 物防、`tg` 特攻、`tf` 特防、`speed` 速度，`all` 表示六项全设。需要 OP 权限等级 2。

## 目录

```
*.jar                 模组构建产物（随仓库走）
docs/agents/          deck 插件的工作区声明
saves/                存档（455MB，不入库）
jre11-Android.tar.xz  Android 上的 Java 11 运行时（22MB，不入库）
```

## 当前缺口

- **源码不在本仓库**：这里只有编译好的 jar，没有 Java 源码与 Gradle 构建脚本。
- **没有 CI**：jar 由本地手工构建，版本号与产物靠人工对齐。
- **许可证不一致**：`monkeymacros` 是 MIT，`pokemonkey` 是 All rights reserved。

## 安装

把需要的 jar 放进游戏实例的 `mods/` 目录。客户端模组（Monkey Macros）只需装在客户端；PokemonKey 是服务端指令模组，需要装在服务端，客户端若要单人使用也需安装。