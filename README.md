# DSHBox

Minecraft **Forge 1.16.5** 自制模组的构建产物工作区与问题跟踪仓库。

本仓库同时被 DSH Desktop 的 deck 插件用作 ISSUE / 探索地图的后端（见 `docs/agents/workspace.yaml`）。

## 模组

`NAMING.md` 的模组登记表上有 5 个模组，`成品/模组/` 里也正好是这 5 个 jar（文件名由 `NAMING.md` 决定）。

| 模组 | modId | 版本 | 功能域 | 许可证 | 源码 |
|---|---|---|---|---|---|
| PokemonKey | `pokemonkey` | 1.1.1 | GOD | All rights reserved | 有 |
| 羁绊忍蛙与传说技能碟 | `bond_greninja` | 1.0.0 | GOD | MIT | 未入库 |
| 我的天哪忍蛙大人（智娃） | `ohmygod_greninja` | 1.1.0 | GOD | MIT | 有 |
| Command Keys | `commandkeys` | 1.0.2 | 工具 | MIT | 有 |
| IPN 精妙背包整理兼容 | `ipnbackpacksort` | 1.0.1 | 辅助 | MIT | 有 |

「源码」列说的是**这份源码在不在版本库里**，不是「作者手上有没有」：

- 前 4 个的 `mods/<modId>/src` 已入库（`git ls-files mods/` 能看到）。
- `bond_greninja` 的源码**只在作者本地工作区盘上、没有入库**。所以在新克隆的仓库里它没有
  `mods/bond_greninja/src`，按 `./deliver` 的判据（`has_source` 看的是磁盘）算**无源码产物**，
  清单里标 `无源码`，永不被自动清理——这是有意为之，不是漏登记。

功能域与版本号的权威来源是 `NAMING.md` 与各 jar 的元数据；面向用户的完整清单见
`成品/文档/模组清单.md`（由 `./deliver` 生成，不要手改）。

全部要求 `forge >= 36`、`minecraft [1.16.5,1.17)`。

### PokemonKey 指令

```
/pokemonkey  <玩家> <1-6> <属性|all> <0-252>   # 努力值 EV
/pokemonkey2 <玩家> <1-6> <属性|all> <0-31>    # 个体值 IV
```

属性别名：`hp` 血量、`wg` 物攻、`wf` 物防、`tg` 特攻、`tf` 特防、`speed` 速度，`all` 表示六项全设。需要 OP 权限等级 2。

## 三个入口

对外只有三个脚本入口，别的一律不用找：

| 入口 | 做什么 | 输入从哪来 |
|---|---|---|
| `bash build.sh <modId>` | 编译 `mods/<modId>/src` → `dist/<modId>-<ver>.jar`（**中性名，不带前缀**） | `MC_JAR`、`FORGE_JAR` 必填；pokemonkey 另需 `PIXELMON_JAR` |
| `bash deliver` | `dist/*.jar` 或显式路径 → `成品/模组/[自制-<域>-<描述>]<id>-<ver>.jar`，刷新清单、提交、推送 | 读 jar 的 `mods.toml` 拿 modId、MANIFEST 拿版本、查 `NAMING.md` 拿前缀 |
| `bash build-apk.sh <apk>` | 已签名 APK → `成品/应用/<原文件名>` | 外部 Android 工具链签好名；本脚本**不签名、不打包** |

**APK 不走 `./deliver`。** `./deliver` 只认 Forge 模组 jar（要 `modId` + `NAMING.md` 登记），
APK 没有这些元数据，硬塞进去只会被拒。要收 APK 就用 `build-apk.sh`。

## 目录

```
成品/模组/*.jar        最终模组 jar，装进游戏 mods/（入库）
成品/应用/*.apk        签名 APK（.gitignore 挡住，不入库，只在盘上；入口 bash build-apk.sh <apk>）
成品/应用/重铸百科网页版-*/  网页版 UI 修复分发包（.zip 被 .gitignore 挡住；目录内的脚本入库）
成品/文档/*.md         面向用户的手写说明（安装/指令/更新日志）+ 自动生成的模组清单，入库
dist/*.jar            构建的验证产物（中间文件，不入库、不提交，用完可整目录删除）
mods/<modId>/src       Java 源码（从 jar 反编译恢复，见 BUILD.md）
mods/<modId>/resources mods.toml、语言文件、图标、pack.mcmeta
deliver                交付脚本：归档 → 生成清单 → 提交 → 推送
build.sh               构建脚本（javac + jar，不依赖 ForgeGradle）
build-apk.sh           APK 交付入口：接收已签名 APK → 校验 → 落 成品/应用/（不签名）
NAMING.md              jar 文件名的唯一权威来源（功能域闭合枚举）
GLOSSARY.md            本仓库术语
docs/adr/              架构决定
docs/agents/           deck 插件的工作区声明
BUILD.md               依赖、构建命令与当前状态
```

`成品/` 三个子目录的分工：**`成品/模组/` 是装进游戏的**，**`成品/应用/` 是 APK**，
**`成品/文档/` 是给人的说明**（其中 `模组清单.md` 是派生物，别手改）。
`dist/` 不是成品——它只是「构建出来了、还没归档」的中间验证产物，可以随时删掉重建；
真正的交付物永远是 `成品/`。

`成品/应用/` 的入口是 `bash build-apk.sh <apk>`：把**已经签好名**的 APK 收进
`成品/应用/`（原文件名原样保留），`DSHBOX_ARTIFACT_DIR` **换默认成品根**、显式 `OUT` 优先。
它只做接收 + 校验 + 落位，**不签名、不打包**；未签名与 `-unaligned`/`-unsigned` 中间产物会被拒绝。
细节见 `BUILD.md` 的「APK 交付入口」。

### 一个环境变量，两种语义

`DSHBOX_ARTIFACT_DIR` 在两个入口里的含义**不一样**，别混：

| 入口 | `DSHBOX_ARTIFACT_DIR` 的含义 |
|---|---|
| `./deliver` | **归档后额外复制一份**到 `$DSHBOX_ARTIFACT_DIR/模组/`。仓库内 `成品/模组/` 仍是主副本、仍照常入库；旁路副本不进版本库。 |
| `build-apk.sh` | **改默认成品根**：落 `$DSHBOX_ARTIFACT_DIR/应用/<原文件名>`，仓库内 `成品/应用/` 这次不再多出一份。 |

### 底件（不进 `成品/`，也不入库）

「底件」是产出成品用的原始材料：未签名的 APK 底包、整合包、JRE 之类的运行时或大文件。
它们**不进 `成品/`、不进版本库**，通常放在仓库外的本地目录（例如 `底包/`），
不是本仓库的内容。`成品/` 只放「用户可以直接拿走」的成品。

### 旧目录状态

历史上有过 `成品apk/`、`模组与其他文件/` 这两个「正式最终交付入口」的说法——**它们从来不存在**，
在全部 git 历史与磁盘上都没有过。仓库根曾经散装放过 jar，那些已在提交 `958131a` 里迁进
`成品/模组/`（历史里仍能 `git show` 取回）。

现在**没有迁移模式**，也**不打算有** `--migrate`：一次性迁移已经做完了；往后「把别处的 jar 收进来」
就是显式传路径给交付脚本：

```bash
./deliver /path/to/某处攒的/themod-1.0.0.jar
```

`成品/` 是唯一入口，别处没有第二个交付目录。

## 当前缺口

- **源码是从 jar 反编译恢复的**：逻辑一致，但最初的注释与写法已经丢失。
- **`bond_greninja` 的源码未入库**：新克隆里它是无源码产物，只能靠盘上的 jar。
- **本机缺 forge / pixelmon 的 jar**：`build.sh` 在这里还跑不出成品，见 `BUILD.md`。
- **没有 CI**：jar 靠本地手工构建，版本号与产物靠人工对齐。
- **许可证不一致**：`pokemonkey` 是 All rights reserved，其余模组是 MIT。

## 安装

把需要的 jar 放进游戏实例的 `mods/` 目录。客户端模组（Command Keys）只需装在客户端；PokemonKey 是服务端指令模组，需要装在服务端，客户端若要单人使用也需安装。详见 `成品/文档/安装.md`。
