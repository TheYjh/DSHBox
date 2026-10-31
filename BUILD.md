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
bash build.sh monkeymacros

MC_JAR=... FORGE_JAR=... PIXELMON_JAR=/path/Pixelmon-1.16.5-9.x-universal.jar \
bash build.sh pokemonkey
```

产物落在 `dist/<modId>-<版本>.jar`，版本号由 `MOD_VERSION` 决定（默认 `0.0.0-dev`）。

注意 `mods.toml` 里写的是 `version="${file.jarVersion}"`：这个占位符由 Forge 从 jar 清单的 `Implementation-Version` 读取，所以版本号必须在打包时写进 MANIFEST（`build.sh` 已经处理）。

## 当前状态（重要）

- `mods/*/src` 里的 Java 是**用 CFR 0.152 从现有 jar 反编译**得到的等价源码，不是最初手写的那份：逻辑一致，注释、变量名的原始写法已经丢失。
- 原始构建痕迹还在这台设备的 `/root/mm` 下（不在仓库里）：`client1165.jar`（17MB，1.16.5 客户端）、`client_mappings.txt`、`cfr.jar`、`jdk/`（OpenJDK 21 解包）、`1165.json`（Mojang 版本清单）、`manifest.json`。
- **本机目前没有 forge 与 pixelmon 的 jar**，所以 `build.sh` 在这里还跑不出成品——需要先从别处拿到这两个依赖。
- JDK 21 的 `javac` 用 `--release 8` 编译，产物能跑在 1.16.5 需要的 Java 8 上。

## 反编译命令（留档）

```bash
java -jar cfr.jar <mod>.jar --outputdir ./src --silent true
```