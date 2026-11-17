# 命名表

`成品/模组/` 中 jar 文件名的**唯一权威来源**。文件名格式：

```
[自制-<功能域>-<具体描述>]<modId>-<版本>.jar
```

`mods.toml` 不含此信息（Forge 的运行时格式里塞自定义键会污染语义），`build.sh` 也不产出带前缀的名字——前缀只在 `./deliver` 归档时施加。

## 功能域（闭合枚举）

只允许下列取值。要新增，先在这一节登记，再用于命名：

| 功能域 | 含义 |
|---|---|
| `GOD` | 改变游戏核心数值/规则（如努力值、个体值） |
| `辅助` | 改善操作或兼容性，不改变数值规则 |
| `工具` | 提供新命令、新界面等独立功能 |

## 模组登记

| modId | 功能域 | 具体描述 | 源码 |
|---|---|---|---|
| `pokemonkey` | `GOD` | `努力与汗水` | `mods/pokemonkey/src` |
| `ipnbackpacksort` | `辅助` | `IPN精妙背包整理兼容` | `mods/ipnbackpacksort/src` |
| `ohmygod_greninja` | `GOD` | `我的天呐智娃大人` | `mods/ohmygod_greninja/src` |
| `commandkeys` | `工具` | `指令按键` | `mods/commandkeys/src` |
| `bond_greninja` | `GOD` | `羁绊忍蛙与传说技能碟` | 未入库（仅作者盘上） |

新增模组时在这里加一行；`./deliver` 遇到未登记的 modId 会拒绝归档，而不是自己编一个前缀。

「源码」列写的是**这份源码在不在版本库里**，不是作者手上有没有。填 `mods/<modId>/src`
就必须真的入库；只在本地盘上的写「未入库」。本表是入库文件，所以这一列要按新克隆的事实写——
写错不会让 `./deliver` 出错（它只读功能域与具体描述两列），但会误导人，也会被
`tests/cases/90-real-naming-coverage.sh` 用 `git ls-files` 检查出来。
