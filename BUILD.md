# 构建说明

两个模组都**不用 ForgeGradle / MDK**。做法是直接对「SRG 生产名」的 Minecraft 1.16.5 客户端 jar 编译：Minecraft 官方发布的 client jar 里类名就是 `func_71410_x`、`field_71439_g` 这种 SRG 名，Forge 在运行时把方法名映射回来。所以只要有依赖 jar，`javac` + `jar` 两条命令就能出成品。

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

## 当前状态（重要）

- `mods/*/src` 里的 Java 是**用 CFR 0.152 从现有 jar 反编译**得到的等价源码，不是最初手写的那份：逻辑一致，注释、变量名的原始写法已经丢失。
- 原始构建痕迹还在这台设备的 `/root/mm` 下（不在仓库里）：`client1165.jar`（17MB，1.16.5 客户端）、`client_mappings.txt`、`cfr.jar`、`jdk/`（OpenJDK 21 解包）、`1165.json`（Mojang 版本清单）、`manifest.json`。
- **本机目前没有 forge 与 pixelmon 的 jar**，所以 `build.sh` 在这里还跑不出成品——需要先从别处拿到这两个依赖。
- JDK 21 的 `javac` 用 `--release 8` 编译，产物能跑在 1.16.5 需要的 Java 8 上。

## 怎么跑测试

`deliver` 回归测试的入口只有一个：

```bash
# 跑全部用例
bash tests/run.sh

# 只跑名字匹配的用例（glob 作用于 tests/cases/<文件名> 与去掉 .sh 的名字）
bash tests/run.sh 20-check
bash tests/run.sh '*check*'
```

全部通过时末尾打印 `通过 N，失败 0` 并以 0 退出；任一用例失败则整体非零退出，并打印 `失败用例：...`。想看单个用例的详细输出就直接跑它，比如 `bash tests/cases/21-same-no-commit.sh`。

### 用例

| 用例 | 锁定的行为 |
|---|---|
| `10-archive` | 正常归档：`dist/<id>-<ver>.jar` 落位成 `成品/模组/[自制-<域>-<描述>]<id>-<ver>.jar`，输出含归档提示，产生一次提交 |
| `20-check` | `--check` 只报告：跑前跑后整棵工作树（排除 `.git`）的哈希指纹完全一致，无提交、无新文件 |
| `21-same-no-commit` | 内容与目标文件名都相同 → 打印「不产生提交」，`git rev-list --count HEAD` 前后相等 |
| `22-rename-is-change` | 内容相同但命名表让目标文件名变了 → 仍算变化：新名落位 + 产生新提交，旧名作为无源码资产留在原处 |
| `30-reject-unregistered` | modId 读得出来但 `NAMING.md` 没登记 → 退出码 1，报「未在 NAMING.md 登记」，`成品/` 整棵树零改动、模组清单不重写、不产生提交 |
| `31-reject-no-modid` | jar 缺 `modId` → 退出码 1，`成品/` 整棵树零改动、不产生提交；不许拿文件名顶替 modId |
| `32-reject-no-version` | MANIFEST 无 `Implementation-Version` 且文件名也解析不出版本 → 退出码 1，`成品/` 整棵树零改动、不产生提交 |
| `40-prune-report-only` | 有源码的旧版被新版取代 → 只进「可清理」报告；不加 `--prune` 时文件仍在、提交里无删除、`--check` 也不动一个字节 |
| `41-prune-deletes-with-history` | 同上场景加 `--prune` → 旧 jar 消失、删除进提交，且删除前那个 commit 上 `git cat-file -e` / `git show` 仍能取回原内容 |
| `42-prune-no-source-never-candidate` | 旧 jar 没有 `mods/<id>/src` → 即使被更高版本取代也不进候选（单独一条断言），加 `--prune` 后文件仍在、内容不变 |
| `43-prune-baseline-is-inputs` | 比较基准是本次入参不是全目录：本次没给入参的 modId 零候选；没有新产物时零候选，加 `--prune` 也不删 |
| `50-push-nochange-synced` | 无变化且远端已同步：不提交、不推送——输出里没有「已推送」，裸仓库 `main` 的 ref 前后指向同一个 commit |
| `50-push-nochange-ahead` | 无变化但本地有未推送提交（夹具里 `commit --allow-empty` 造的离线提交）→ 仍要推：打印「本地有 1 个未推送的提交」且裸仓库 `main` 更新到本地 HEAD，本地不再产生新提交 |
| `50-push-fail-keeps-commit` | 推送失败（origin 指向不存在的本地路径，不删 origin）：退出码非零、打印「推送失败（已重试 2 次）」与「未回滚」，那个归档提交仍在 `git log` 里，裸仓库 `main` 停在失败前的位置 |
| `50-push-fail-no-rollback` | 同一失败场景下的工作树单独断言：新归档文件仍在盘上且内容与原 jar 逐字节相同、在 HEAD 的树里、`git status` 干净，事后 `--check` 也不再改动一个字节 |

后面还有 `60-manifest`（模组清单）待补。

### 测试的边界

- **离线**。夹具仓库的 `origin` 是 `git init --bare` 造出来的本地裸仓库，跑测试不需要网络，也不会连真实远端。推送失败路径也不用网络：把 `origin` 的 URL 改成一个**不存在的本地路径**（`remote_break`，保留 remote 不删），`git push` 会在本地就 `fatal: ... does not appear to be a git repository` 而失败。
- **不碰真实仓库**。每个 case 在 `mktemp -d` 里自建夹具仓库、把自己的 `git config user.name/user.email` 写进去（本机全局没有，不写就 commit 失败），跑完 `rm -rf`。真实 `成品/`、真实的 git 配置与远端都不在测试范围内。
- **不依赖预置二进制夹具**。假 jar 由 `make_jar` 用 `zip` 现场蒸：里面只有 `META-INF/MANIFEST.MF`（带 `Implementation-Version`）与 `META-INF/mods.toml`（`modId` 在这里），够 `deliver` 读元数据就行。需要 `zip` 与 `unzip`，`tests/run.sh` 会先检查。
- **接缝只有命令行**。测试把真实的 `deliver` **复制**进夹具（不是符号链接），然后 `bash ./deliver ...` 调用它，断言输出、退出码与文件系统结果。测试从不 source `deliver` 的内部函数，所以 `deliver` 内部怎么改都不该影响测试——除非对外行为变了，那正是要测的。
- **期望文件名由夹具的 `NAMING.md` 推导**，测试里不写死前缀常量。

## 反编译命令（留档）

```bash
java -jar cfr.jar <mod>.jar --outputdir ./src --silent true
```