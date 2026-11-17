# 构建说明

模组都**不用 ForgeGradle / MDK**（`NAMING.md` 登记了几个就能构建几个，目前 5 个）。做法是直接对「SRG 生产名」的 Minecraft 1.16.5 客户端 jar 编译：Minecraft 官方发布的 client jar 里类名就是 `func_71410_x`、`field_71439_g` 这种 SRG 名，Forge 在运行时把方法名映射回来。所以只要有依赖 jar，`javac` + `jar` 两条命令就能出成品。

代价是源码里写的也是 SRG 名（`Minecraft.func_71410_x()` 而不是 `Minecraft.getInstance()`），可读性差一些，但不需要几十兆的 Gradle 环境。

## 依赖

| 变量 | 是否必填 | 说明 |
|---|---|---|
| `MC_JAR` | 必填 | 1.16.5 客户端 jar（SRG 名）。Mojang 版本清单 `https://launchermeta.mojang.com/mc/game/version_manifest.json` → 1.16.5 的 json → `downloads.client.url` |
| `FORGE_JAR` | 必填 | `forge-1.16.5-36.x-universal.jar`（提供 `net.minecraftforge.*`） |
| `PIXELMON_JAR` | 只有 pokemonkey 需要 | Pixelmon Reforged 9.x |
| `EXTRA_JARS` | 可选 | 冒号分隔，如 Configured `[1.5,)` |

## 命令

```bash
# 脚本在 Android 存储挂载上，chmod +x 不生效，所以用 bash 显式调用
MC_JAR=/path/client-1.16.5.jar \
FORGE_JAR=/path/forge-1.16.5-36.2.39-universal.jar \
bash build.sh commandkeys

MC_JAR=... FORGE_JAR=... PIXELMON_JAR=/path/Pixelmon-1.16.5-9.x-universal.jar \
bash build.sh pokemonkey
```

产物落在 `dist/<modId>-<版本>.jar`，版本号由 `MOD_VERSION` 决定（默认 `0.0.0-dev`）。

构建**不负责**最终文件名：`dist/` 里是无前缀的原始 jar，交付时才由 `./deliver` 按 `NAMING.md` 改名归档进 `成品/模组/`。所以改标题前缀**不要**动 `build.sh`。

```bash
bash build.sh commandkeys   # 产出 dist/commandkeys-<版本>.jar
./deliver --check            # 看它会归档成什么名字
./deliver                    # 归档 + 提交 + 推送
```

注意 `mods.toml` 里写的是 `version="${file.jarVersion}"`：这个占位符由 Forge 从 jar 清单的 `Implementation-Version` 读取，所以版本号必须在打包时写进 MANIFEST（`build.sh` 已经处理）。

`build.sh` 在编译前会先校验两件事，任一条不成立就直接失败、不产生产物：

- **`modId` 必须与目录名一致**。交付时 `./deliver` 从 jar 元数据读 `modId`、按 `NAMING.md` 查前缀，所以 `mods/<目录名>/resources/META-INF/mods.toml` 里声明的 `modId` 必须等于 `<目录名>`。不一致时构建出的 jar 会被归档到另一个模组名下，前缀和实际内容对不上——拦在构建侧比等到谁改名更早发现。
- **`mods.toml` 必须存在且读得出 `modId`**。没有它，`deliver` 会拒收这个 jar（读不到 `modId`），等于白构建一次。

依赖变量缺失同样在编译前报错并点名缺哪个（`MC_JAR` / `FORGE_JAR`），不会变成一堆 javac 符号错误。

## APK 交付入口

APK 的构建在**另一个仓库/工具链**里（Android 侧），本仓库只负责把**已经签好名**的 APK 收进统一的成品目录。入口是 `build-apk.sh`：

```bash
# 落 成品/应用/<原文件名>
bash build-apk.sh /path/重铸百科-1.4.0.apk

# 换默认成品根：落 $DSHBOX_ARTIFACT_DIR/应用/<原文件名>
DSHBOX_ARTIFACT_DIR=/path/外部成品 bash build-apk.sh /path/重铸百科-1.4.0.apk

# 显式 OUT 优先于上面两者：是文件路径就直接用，是目录就拼原文件名
OUT=/path/发布/x.apk bash build-apk.sh /path/重铸百科-1.4.0.apk
OUT=/path/发布/     bash build-apk.sh /path/重铸百科-1.4.0.apk
```

它只做**接收 + 校验 + 落位**，**不签名、不打包、不反编译**——本机没有 `apksigner`/`apktool`/`zipalign`/`aapt2`/`gradle`，脚本也不打算假装有。签名必须由产出 APK 的那一侧完成。

收之前它会查三件事，任一不成立就非零退出，并且**不写任何文件**（连 `成品/应用/` 目录都不建）：

- 是合法 zip，且根上有 `AndroidManifest.xml`；
- `META-INF/` 下**同时**有 `*.SF` 与 `*.RSA|*.DSA|*.EC`——只查签名文件在不在，**不验签内容**；
- 文件名不是 `-unaligned` / `-unsigned` 这类中间产物（zipalign 之前、apksigner 之前的件都不是可交付件）。

原文件名原样保留，不按 `NAMING.md` 改名——APK 不走 `./deliver` 的 modId 归档路径。目标已存在且内容不同时中止且不覆盖，与 `./deliver` 的冲突纪律一致；区别是 `./deliver` 有 `--overwrite` 这个显式覆盖开关（`build-apk.sh` 没有，要替换就先手动移走旧件，见它的报错提示）。APK **不进 git**（`.gitignore` 已挡 `成品/应用/*.apk`），脚本也不 `git add`。

## 三个入口怎么串起来

只有三个入口，其余都是它们之间的搬运：

```
mods/<id>/src  ──build.sh──▶  dist/<id>-<ver>.jar  ──deliver──▶  成品/模组/[自制-<域>-<描述>]<id>-<ver>.jar
                              （验证产物，不入库）                （成品，入库并提交）
                                                                 └─(可选) DSHBOX_ARTIFACT_DIR/模组/  旁路副本

外部的已签名 apk  ──build-apk.sh──▶  成品/应用/<原文件名>（不入库）
                                     └─(可选) DSHBOX_ARTIFACT_DIR/应用/  或显式 OUT
```

**模组这条链**：

```bash
MC_JAR=... FORGE_JAR=... bash build.sh commandkeys   # 1. 产出 dist/commandkeys-<版本>.jar（中性名）
./deliver --check                                    # 2. 看会归档成什么名字，零改动
./deliver                                            # 3. 归档 + 刷新清单 + 提交 + 推送
DSHBOX_ARTIFACT_DIR=/path/外部 ./deliver             # 3'. 想额外留一份给别人就拿这个
```

每一步的性质记清楚：

- `dist/` 里的是**验证产物**（中间文件）：中性名、被 `.gitignore` 挡住、不入库也不提交、
  可随时整目录删掉重建，它是「编译出来了」的凭据，不是交付物。
- `成品/模组/` 里的是**成品**：带前缀、入库、出现在 `成品/文档/模组清单.md` 里。
  前缀只在这一步由 `NAMING.md` 施加——所以改前缀改 `NAMING.md`，不要改 `build.sh` 也不要改 `mods.toml`
  （`mods.toml` 里没有 `artifactName` 这种键，写了也没人读）。
- `DSHBOX_ARTIFACT_DIR` 挂在最后：**归档之后额外复制**，仓库内 `成品/` 仍是主副本、仍照常提交。

**APK 这条链**独立于模组链：外部工具链签好名 → `build-apk.sh` 收进 `成品/应用/`。
这里 `DSHBOX_ARTIFACT_DIR` 是**换默认成品根**（不是额外复制），显式 `OUT` 再优先于它。
两条链的 `DSHBOX_ARTIFACT_DIR` 语义不同，别按同一个理解用。

**没有迁移模式。** 一次性迁移已在提交 `958131a` 完成，仓库里不存在 `--migrate`，也不打算加——
「把别处的 jar 收进来」就是 `./deliver <路径>`：

```bash
./deliver /path/to/别处攒的/某个模组-1.0.0.jar   # 显式路径，同样按 NAMING.md 改名归档
```

同理，`成品apk/`、`模组与其他文件/` 这两类「旧交付目录」在本仓库的全部 git 历史与磁盘上都不曾存在过，
没有需要迁移或兼容的旧状态；`成品/` 是唯一的交付目录。

## 当前状态（重要）

- `mods/*/src` 里的 Java 是**用 CFR 0.152 从现有 jar 反编译**得到的等价源码，不是最初手写的那份：逻辑一致，注释、变量名的原始写法已经丢失。
- 原始构建痕迹还在这台设备的 `/root/mm` 下（不在仓库里）：`client1165.jar`（17MB，1.16.5 客户端）、`client_mappings.txt`、`cfr.jar`、`jdk/`（OpenJDK 21 解包）、`1165.json`（Mojang 版本清单）、`manifest.json`。
- **本机目前没有 forge 与 pixelmon 的 jar**，所以 `build.sh` 在这里还跑不出成品——需要先从别处拿到这两个依赖。
- JDK 21 的 `javac` 用 `--release 8` 编译，产物能跑在 1.16.5 需要的 Java 8 上。

## 怎么跑测试

`deliver`、`build.sh`、`build-apk.sh` 与 `deliver-plugin` 回归测试的入口只有一个：

```bash
# 跑全部用例
bash tests/run.sh

# 只跑名字匹配的用例（glob 作用于 tests/cases/<文件名> 与去掉 .sh 的名字）
bash tests/run.sh 20-check
bash tests/run.sh '*check*'

# 只跑插件同步那组
bash tests/run.sh '7*'
```

全部通过时末尾打印 `通过 N，失败 0` 并以 0 退出；任一用例失败则整体非零退出，并打印 `失败用例：...`。想看单个用例的详细输出就直接跑它，比如 `bash tests/cases/21-same-no-commit.sh`。

### 用例

| 用例 | 锁定的行为 |
|---|---|
| `10-archive` | 正常归档：`dist/<id>-<ver>.jar` 落位成 `成品/模组/[自制-<域>-<描述>]<id>-<ver>.jar`，输出含归档提示，产生一次提交 |
| `20-check` | `--check` 只报告：跑前跑后整棵工作树（排除 `.git`）的哈希指纹完全一致，无提交、无新文件 |
| `21-same-no-commit` | 内容与目标文件名都相同 → 打印「不产生提交」，`git rev-list --count HEAD` 前后相等 |
| `22-rename-is-change` | 内容相同但命名表让目标文件名变了 → 仍算变化：新名落位 + 产生新提交，旧名作为无源码资产留在原处 |
| `23-conflict-aborts-batch` | 目标文件名已存在但内容不同 → 报 `[冲突]` 并整批中止：退出码 1，同批那个「本可归档」的新版本也不落位、不进清理候选，`成品/` 与工作树零改动、旧产物内容不变、源 jar 仍在、不产生提交 |
| `24-conflict-overwrite` | 同一场景加 `--overwrite` → 才允许覆盖：退出码 0、目标换成新内容、覆盖进提交，且旧内容仍能从覆盖前的 commit `git show` 取回 |
| `25-check-conflict-report` | `--check` 如实报告冲突（点名文件、目标、两边的 sha256、解决办法）但退出码仍为 0（它本来就不写）；`--check --overwrite` 说清「会覆盖」也一样零改动 |
| `30-reject-unregistered` | modId 读得出来但 `NAMING.md` 没登记 → 退出码 1，报「未在 NAMING.md 登记」，`成品/` 整棵树零改动、模组清单不重写、不产生提交 |
| `31-reject-no-modid` | jar 缺 `modId` → 退出码 1，`成品/` 整棵树零改动、不产生提交；不许拿文件名顶替 modId |
| `32-reject-no-version` | MANIFEST 无 `Implementation-Version` 且文件名也解析不出版本 → 退出码 1，`成品/` 整棵树零改动、不产生提交 |
| `33-reject-unknown-domain` | 登记的 modId 写了枚举外的功能域 → 退出码 1，报「功能域未在 NAMING.md 登记」，`成品/` 整棵树零改动、不产生提交 |
| `40-prune-report-only` | 有源码的旧版被新版取代 → 只进「可清理」报告；不加 `--prune` 时文件仍在、提交里无删除、`--check` 也不动一个字节 |
| `41-prune-deletes-with-history` | 同上场景加 `--prune` → 旧 jar 消失、删除进提交，且删除前那个 commit 上 `git cat-file -e` / `git show` 仍能取回原内容 |
| `42-prune-no-source-never-candidate` | 旧 jar 没有 `mods/<id>/src` → 即使被更高版本取代也不进候选（单独一条断言），加 `--prune` 后文件仍在、内容不变 |
| `43-prune-baseline-is-inputs` | 比较基准是本次入参不是全目录：本次没给入参的 modId 零候选；没有新产物时零候选，加 `--prune` 也不删 |
| `50-push-nochange-synced` | 无变化且远端已同步：不提交、不推送——输出里没有「已推送」，裸仓库 `main` 的 ref 前后指向同一个 commit |
| `50-push-nochange-ahead` | 无变化但本地有未推送提交（夹具里 `commit --allow-empty` 造的离线提交）→ 仍要推：打印「本地有 1 个未推送的提交」且裸仓库 `main` 更新到本地 HEAD，本地不再产生新提交 |
| `50-push-fail-keeps-commit` | 推送失败（origin 指向不存在的本地路径，不删 origin）：退出码非零、打印「推送失败（已重试 2 次）」与「未回滚」，那个归档提交仍在 `git log` 里，裸仓库 `main` 停在失败前的位置 |
| `50-push-fail-no-rollback` | 同一失败场景下的工作树单独断言：新归档文件仍在盘上且内容与原 jar 逐字节相同、在 HEAD 的树里、`git status` 干净，事后 `--check` 也不再改动一个字节 |
| `60-manifest-refresh` | 清单随交付刷新：交付前预置一份哨兵清单，交付 `demo-1.2.3.jar` 后哨兵被整份重写、表头在位、当次归档的 modId 与目标文件名都能在清单里找到，版本列等于 jar 元数据里的 `Implementation-Version`，且清单与新 jar 在**同一个提交**里 |
| `60-manifest-coverage` | 清单与 `成品/模组/` 双向一一对应：本次入参只有一个新 jar，目录里另有两个非入参的历史产物——清单每一行都要在目录里找得到文件、目录里每个 `.jar` 都要在清单里有行，两个方向的排序 diff 必须为空（钉死「清单遍历目录生成」，防止退化成只列本次入参） |
| `60-manifest-no-source` | 源码列按实际状态标注：目录里同时有无 `mods/<id>/src` 的 legacy 与有源码的 demo，交付后前者那行是 `无源码`、后者是 `有`，并逐行比对清单源码列与 `mods/<modId>/src` 的存在性，二者不得漂移 |
| `70-plugin-sync-archive` | 自研插件整体复制进插件仓库：目录名取**源目录名**而不是 `package.json` 的 `name`，`node_modules`/`.profile-doctor`/`*.log` 不跟着过去，输出 `[新增]`，产生一次提交并真的推到裸仓库 origin，README 表格被重建（含包名与 description **首句**，不含第二句） |
| `71-plugin-sync-skip-clone` | 自带 `.git` 的第三方克隆被跳过：目标仓库里根本不出现（工作树与 `HEAD` 树都没有），输出有 `[跳过] <目录>：自带 .git（第三方克隆），不自动入库`，提交信息不含它；`--check` 仍报告跳过项且零改动 |
| `72-plugin-sync-check` | `--check` 只报告：`[新增]`/`[更新]`/`[不变]` 三态同时出现、多余文件进「将删除」清单、README 表格变化被说明；整棵目标仓库哈希指纹、提交数、`HEAD`、远端 ref 前后全等；目标仓库不存在时也不顺手克隆 |
| `73-plugin-sync-no-empty-commit` | 内容不变的第二次同步：输出全 `[不变]` 并打印「插件仓库无变化，不产生提交。」，提交数/`HEAD`/远端 ref/整树指纹全不变，不再推送，README 也不被重写 |
| `74-plugin-sync-mirror-delete` | 镜像语义：源里删掉的文件在目标仓库被删（走 `git rm --cached` + `rm -f`，删除进提交），空目录一并收掉，没删的文件一个不少，且旧内容仍能从上一个 commit `git show` 取回 |
| `80-build-dist-neutral` | 构建产物留在 `dist/` 且名字中性：`MOD_VERSION` 决定的 `dist/<id>-<ver>.jar` 落盘、清单里有对应 `Implementation-Version`、`dist/` 里没有带 `[自制-…]` 前缀的文件（前缀属交付环节）、`成品/` 零改动 |
| `81-build-modid-mismatch` | `mods.toml` 的 `modId` 与目录名不符 → 退出码 1、信息同时点名两个 id 并说明会归档到别的模组名下，`dist/` 不产生任何产物 |
| `82-build-missing-env` | 缺 `MC_JAR` 或 `FORGE_JAR` → 各自单独断言退出码 1 + 信息点名缺哪个变量，两种情况都不写 `dist/` |
| `83-build-then-deliver` | 端到端：先构建出 `dist/demo-0.4.0.jar`，再不带参数跑 `deliver` 把它归档成 `成品/模组/[自制-<域>-<描述>]demo-0.4.0.jar`；归档件与 `dist/` 产物逐字节相同（改名而非重打包）、验证 jar 仍在 `dist/`、一次提交且工作树干净 |
| `84-deliver-artifact-dir-override` | `DSHBOX_ARTIFACT_DIR` 只做旁路复制：仓库内 `成品/模组/` 照常落位并入库，外部目录下出现同名同内容副本，该目录不进版本库、工作树仍干净 |
| `85-build-missing-modstoml` | 模组缺 `mods.toml`（目录名与依赖都正常）→ 退出码 1、信息点名 `mods.toml`，`dist/` 不产生产物 |
| `86-build-modid-regex` | 目录名带路径分隔符或以点开头（`../etc`、`.hidden`）→ 退出码 1、信息说清不允许，不会把源码目录拼到仓库外（`src` 路径注入防护） |
| `87-apk-default-and-artifact-dir` | APK 入口默认落 `成品/应用/<原文件名>`（内容与入参逐字节相同、原件不动），设了 `DSHBOX_ARTIFACT_DIR` 则落 `<根>/应用/` 且仓库内不再多出一份 |
| `88-apk-out-override` | 显式 `OUT` 优先：是文件路径就直接用、是目录就拼原文件名；与 `DSHBOX_ARTIFACT_DIR` 并存时 `OUT` 赢（外部根下一个文件都不出现），三种情况默认 `成品/应用` 都不被顺手写 |
| `89-apk-reject-intermediate` | 未签名、`-unaligned`、`-unsigned`、非 `.apk` 四种输入 → 各自退出码 1、输出点名原因、`成品/应用` 连目录都不建、显式 `OUT` 也不产出文件 |
| `91-apk-filename-preserved` | 原文件名原样保留（中文 + 空格 + 点号 + 连字符逐字符比对），默认与 `OUT=目录` 两路都不改名、不加 `[自制-…]` 前缀 |
| `90-real-naming-coverage` | 真实仓库的命名登记齐备（跨文件静态检查，不在夹具里）：每个 `mods/<id>` 的 `mods.toml` 声明 `modId` 必须等于目录名，且该 id 在真实 `NAMING.md` 的登记表里有行、功能域在枚举内、具体描述非空；反方向也查——表里每一行的「源码」列必须对得上**版本库**（写 `mods/<id>/src` 就得真被 `git ls-files` 看到，只在本地盘上的写「未入库」） |
| `92-e2e-three-entries` | 三个入口在**同一个夹具仓库**里串通：`build.sh` 产出中性名 `dist/demo-2.1.0.jar`（dist/ 里没有带前缀的件）→ `deliver --check` 报「新增 1 个」且整树零改动 → `deliver` 归档成带前缀名、与 dist/ 产物逐字节相同、dist/ 原件仍在、一次提交 → 重复跑报「未变」不产生新提交 → 改 `NAMING.md` 描述后新名落位而旧名留在原处（命名权威在 NAMING.md 的行为证据）→ `build-apk.sh` 默认落 `成品/应用/`、`DSHBOX_ARTIFACT_DIR` 换根、`OUT` 优先于它 → APK 既在盘上又没被 `git add`（且确实被 `.gitignore` 挡住），全程结束工作树干净 |

用例就这些（40 个；`92` 是唯一的端到端那条，其余各锁一条行为）。它们覆盖的是 `deliver` 的归档、冲突中止、拒绝、清理、提交推送与清单五条主线，`build.sh` 的产物路径与元数据校验，`build-apk.sh` 的默认落位、`DSHBOX_ARTIFACT_DIR`、`OUT` 覆盖与中间产物拒绝四条主线，以及 `deliver-plugin` 的归档、跳过、`--check`、幂等与镜像删除五条主线，**不是**对外行为的全集——下面这些还没有用例：`--no-push`、`--copy-only`、`-h/--help`、显式传入路径（不走 `dist/*.jar`）的成功路径；`build-apk.sh` 的 `-h/--help`、「目标已存在且内容不同」的中止路径、非 zip 与缺 `AndroidManifest.xml` 两种拒绝；插件侧的 `--no-push`、`-h/--help`、`DSHBOX_PLUGIN_REPO` 的自动克隆路径（本机 443 不通，只能离线夹具）、`tools/plugin-watch.sh`（除 `--once` 外没有用例锁它的循环行为）。要动其中任何一处，先补对应用例。

冲突中止这条语义见 #12 的核对结论（#20 评论把它从 7 条收窄成 1 条）：目标文件名已存在但内容不同时，`deliver` 把它当成**冲突**（不是新增），默认整批中止、退出码非零、在任何写操作之前退出；只有显式 `--overwrite` 才覆盖。`--check` 下同样报告冲突，但仍以 0 退出——`--check` 的用途就是「先看看会发生什么」，用非零退出码会让它不可用，而它本来就不写任何东西。

### 测试的边界

- **离线**。夹具仓库的 `origin` 是 `git init --bare` 造出来的本地裸仓库，跑测试不需要网络，也不会连真实远端。推送失败路径也不用网络：把 `origin` 的 URL 改成一个**不存在的本地路径**（`remote_break`，保留 remote 不删），`git push` 会在本地就 `fatal: ... does not appear to be a git repository` 而失败。
- **不碰真实仓库**。每个 case 在 `mktemp -d` 里自建夹具仓库、把自己的 `git config user.name/user.email` 写进去（本机全局没有，不写就 commit 失败），跑完 `rm -rf`。真实 `成品/`、真实的 git 配置与远端都不在测试范围内。
- **不依赖预置二进制夹具**。假 jar 由 `make_jar` 用 `zip` 现场蒸：里面只有 `META-INF/MANIFEST.MF`（带 `Implementation-Version`）与 `META-INF/mods.toml`（`modId` 在这里），够 `deliver` 读元数据就行。需要 `zip` 与 `unzip`，`tests/run.sh` 会先检查。
- **接缝只有命令行**。测试把真实的 `deliver` 与 `build.sh` **复制**进夹具（不是符号链接），然后 `bash ./deliver ...` / `bash ./build.sh ...` 调用它们，断言输出、退出码与文件系统结果。测试从不 source 脚本的内部函数，所以内部怎么改都不该影响测试——除非对外行为变了，那正是要测的。
- **`90-real-naming-coverage` 是唯一读真实仓库的用例**：它只用 `find`/`awk`/`sed` 与 `git ls-files` 读 `mods/`、`NAMING.md` 与版本库的事实，不写、不提交、不在真实仓库里跑 `deliver`。原因是被它检查的东西（命名表漏登一行、或登记行与版本库脱节）在夹具里永远造不出来——这类漂移不会立刻报错，只会在你真去交付那个模组时才暴露。它查两个方向：磁盘上的模组目录 → 表里有行；表里的行 → 版本库里真有那份源码（`test -d` 不够，未跟踪目录在盘上也在，所以要 `git ls-files`）。
- **APK 夹具也是现场蒸的**。`tests/lib/apk-harness.sh` 用 `zip` 造最小 APK：含 `AndroidManifest.xml` + `META-INF/FIXTURE.SF` + `META-INF/FIXTURE.RSA` 就算「已签名」，去掉 `META-INF/` 就是「未签名」（`make_signed_apk` / `make_unsigned_apk`）。它不建 git 仓库——APK 入口不碰 git，用例断言的是落位与拒绝，不是提交。真实 `成品/应用/` 不在测试范围内（脚本被复制进沙箱，`BASH_SOURCE` 定位到的仓库根就是沙箱）。
- **构建夹具不需要真依赖**。`build.sh` 只把 `MC_JAR` / `FORGE_JAR` 拼进 `javac` 的 classpath，而 `javac` 对 classpath 里不存在的条目并不报错，所以夹具用两个只含占位文件的空 jar 就能离线跑通「编译 → 打包」整条链路。夹具模组的源码刻意不 import 任何 Minecraft/Forge 类（`fixture_build_mod`），测的是构建入口的产物路径与元数据校验，不是「真实模组能否编译」——后者需要 1.16.5 客户端与 forge jar，不属于回归测试。
- **期望文件名由夹具的 `NAMING.md` 推导**，测试里不写死前缀常量。
- **夹具预建成品目录**。真实仓库里 `成品/模组`、`成品/文档` 常存，夹具照此预建，所以 `--check` 的「零改动」断言的是**零文件改动**——`deliver` 开头的 `mkdir -p` 若真的建出空目录，不算在这个断言里。要连目录一起管，得先把这个前提从夹具里去掉。
- **沙箱固定在 `/tmp`**。`harness_init` 会拒绝在 `/tmp` 之外造夹具（防止误删真实目录），所以 `TMPDIR` 指到别处时全部用例会红，这是设计而不是 bug。

## 反编译命令（留档）

```bash
java -jar cfr.jar <mod>.jar --outputdir ./src --silent true
```