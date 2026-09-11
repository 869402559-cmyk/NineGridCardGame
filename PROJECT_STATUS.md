# 🎮 NineGridCardGame 项目架构与状态说明文档

> **本文档供开发者及 AI 助手快速了解项目架构、技术细节、当前进度以及未来重构计划。**
> 只要拉取最新 Git 代码并阅读本文档，即可无缝接手续写本项目。

---

## 📌 1. 文档状态与版本信息 (Document Status)

- **文档版本**：`0.4.1`
- **最后更新时间**：`2026-09-11`
- **Godot 引擎版本**：`Godot 4.6.1-stable` (GDScript)
- **当前项目状态**：核心战斗（5v5 九宫格、兵种动作、士气大招、兵种克制、双层计算公式、抽卡、布阵、多账号存档）已完备可运行。
- **目标平台**：Windows Desktop / Web (HTML5)

---

## 📌 2. 项目概览与开发环境 (Project Overview)

- **项目名称**：`NineGridCardGame`（傲视天地风格 3x3 九宫格卡牌回合制 Web / 桌面游戏）
- **主场景入口**：`res://scenes/LoginUI.tscn`
- **本地存档路径**：`user://accounts.json`（真实磁盘路径如 `%APPDATA%\Godot\app_userdata\NineGridCardGame\accounts.json`）
- **开发与启动方式**：使用 Godot 4.6.1 编辑器直接打开 `project.godot` 运行主场景。

---

## ⚡ 3. 核心游戏机制与两阶段数值公式 (Core Game Mechanics & Stat Formulas)

为了保证游戏数值的清晰性与扩展性，本项目采用**“面板属性复合”与“战斗动态伤害”解耦的两阶段数值结算模型**。任何接手本项目的 AI 或开发者请严格遵循以下计算层次：

### 3.1 第一阶段：面板属性计算（7:3 复合公式）
在进入战斗前或在武将详情弹窗中，先根据英雄基础模板/成长与兵种基础数据计算出单位的固定战斗面板：

$$egin{aligned}
	ext{基础攻击力 (Atk)} &= 	ext{round}(	ext{英雄基础 Atk} 	imes 0.7 + 	ext{兵种基础 Atk} 	imes 0.3) \
	ext{基础防御力 (Def)} &= 	ext{round}(	ext{英雄基础 Def} 	imes 0.7 + 	ext{兵种基础 Def} 	imes 0.3) \
	ext{战法攻击力 (SAtk)} &= 	ext{round}(	ext{英雄基础 SAtk} 	imes 0.7 + 	ext{兵种基础 SAtk} 	imes 0.3) \
	ext{战法防御力 (SDef)} &= 	ext{round}(	ext{英雄基础 SDef} 	imes 0.7 + 	ext{兵种基础 SDef} 	imes 0.3)
\end{aligned}$$

- **直接继承/不参与 7:3 的属性**：
  - $	ext{最终生命值 (HP)} = 	ext{英雄基础 HP}$（受到英雄手动升级的经验成长加成）。
  - $	ext{最终速度 (Spd)} = 	ext{英雄基础 Spd}$。
- **兵种专属闪避率 (MISS)**：
  - 闪避判定绑定在兵种数据上：弓兵 20%、鼓手 15%、骑兵 10%、策士 8%、步兵 5%。

---

### 3.2 第二阶段：战斗动态伤害结算与兵种克制（多层乘算公式）
**注意：兵种克制加成不混在 7:3 复合面板中！** 兵种克制是在战斗中触发攻击时，作为外层伤害修正乘数独立结算的。

#### 1. 基础物理伤害公式 (Raw Damage)
$$	ext{RawDamage} = \max\left(	ext{攻击者 Atk} - 	ext{受击者 Def} 	imes 0.5,\ 1ight)$$

#### 2. 战法大招伤害公式 (Skill Damage)
$$	ext{SkillRawDamage} = \max\left(	ext{攻击者 SAtk} 	imes 1.5 - 	ext{受击者 SDef} 	imes 0.5,\ 1ight)$$

#### 3. 兵种克制判定与加成结算 (Troop Counter)
- 检查攻击方兵种的 `target_type`（如：骑兵克制 `步兵`）是否匹配受击方兵种的 `type_name`。
- 若触发克制，克制乘数 $	ext{CounterBonus} = 1.0 + 	ext{bonus\_rate}$（目前配置 `bonus_rate = 0.10`，即 $1.10$）。
- 若未触发克制，$	ext{CounterBonus} = 1.0$。

#### 4. 最终伤害公式 (Final Damage)
$$	ext{FinalDamage} = 	ext{round}\left(	ext{RawDamage} 	imes 	ext{CounterBonus}ight)$$

**示例说明**：
当**关羽（虎豹骑，骑兵）** 攻击 **张飞（重装步兵，步兵）** 时：
1. 先计算关羽基础 Atk 与张飞基础 Def 的物理基础伤害 $	ext{RawDamage} = 220 - 160 	imes 0.5 = 140$。
2. 判定虎豹骑克制步兵，触发 $+10\%$ 伤害加成（$	ext{CounterBonus} = 1.10$）。
3. 最终伤害为 $	ext{round}(140 	imes 1.10) = 154$ 点，同时在日志打印：`💥 兵种克制！[关羽] 的 虎豹骑 克制 [张飞] 的 重装步兵，造成额外 10% 伤害！`。

---

### 3.3 3x3 九宫格布阵 (3x3 Formation)
- 3x3 网格阵型（位置编号 1 ~ 9），最多上阵 5 名英雄。
- 英雄卡牌统一按 3:4 比例渲染（布阵列表小卡片 `88x118`，详情大图 `250x333`）。
- **拖拽与下阵操作**：
  - 英雄池卡牌可拖拽至 3x3 九宫格槽位上阵。
  - 已上阵槽位之间可互相拖拽交换位置。
  - 将已上阵槽位的卡牌拖拽回左侧英雄池面板，触发定向下阵（Unequip）。
- 双击卡牌可打开 `HeroDetailModal` 弹窗查看详细 7:3 属性拆解及进行升级。

### 3.4 5v5 回合制战斗与动作动画 (Battle System)
- **行动顺序与轮次**：
  - 根据双方存活单位的速度（`Spd`）降序排列决定行动次序。相同速度时玩家单位优先行动。
- **寻敌与攻击规则**：
  - 优先攻击对向前排目标；前排倒下后向中排、后排寻找。
- **士气与战法大招 (Morale System)**：
  - **上限与初始值**：士气上限固定为 **100**，开局所有单位初始士气固定为 **50**。
  - **常规士气积攒（不弹出飘字）**：普通攻击（+10 士气）、受到攻击（+25 士气）。
  - **技能与辅助增益（弹出高亮飘字）**：鼓手擂鼓（+35 士气）、鼓手大招（+60 士气）。
  - **释放规则**：单位行动开始前若士气达到 **100**，则本回合消耗全部士气释放战法大招，行动后士气清零。
- **兵种专属动作与打击反馈**：
  - **骑兵 / 步兵**：攻击时**冲锋至敌方前排近身打击**，随后归位。
  - **弓兵 / 策士**：攻击时**原地点头微动（远程发射/施法）**，随后归位。
  - **鼓手 (专属辅助机制)**：不攻击敌方！普攻为原地擂鼓，随机为一名除自己外的存活队友恢复 **35 点士气**（无队友时给自身加士气）；战法大招为**全队恢复 60 点士气**。
  - **受击与闪避**：受击单位卡牌震动并红闪；触发闪避时向后退避，浮现蓝色 **`MISS!`** 缩放淡出飘字。

### 3.5 养成与结算 (Progression & Reward)
- **战斗结算**：胜利获得 +100 金币、+100 共享经验池（Exp Pool）。
- **英雄升级**：消耗经验池升级英雄，单级消耗费用 = `当前等级 * 100`。升级可提升英雄 HP、Atk、Def、SAtk、SDef 基础属性。

---

## 📁 4. 代码架构与文件职责 (Project Architecture)

```
NineGridCardGame/
├── project.godot               # Godot 项目主配置
├── PROJECT_STATUS.md           # 本说明文档
├── data/                       # CSV 数据表（UTF-8 with BOM 编码）
│   ├── heroes.csv              # 英雄模板表（基础属性、品质、默认兵种等）
│   ├── troops.csv              # 兵种配置表（基础属性、闪避率、动画标签、克制关系）
│   └── enemies.csv             # 敌方阵容与难度倍率表 (stat_mult)
├── scripts/                    # GDScript 业务逻辑
│   ├── GameData.gd             # 单例组件：CSV数据解析、7:3属性计算、账号管理、内存存档持久化
│   ├── LoginUI.gd              # 登录与注册界面
│   ├── MainUI.gd               # 主界面顶部栏（账号状态、金币/经验展示、保存存档拦截、账号清理）
│   ├── FormationUI.gd          # 3x3 拖拽布阵与左侧列表排序
│   ├── HeroDetailModal.gd      # 英雄详情弹窗（3:4 大立绘展示、7:3 拆解、升级）
│   ├── AccountManageModal.gd   # 账号管理与清理弹窗（列出/删除非 admin 账号）
│   ├── GachaUI.gd              # 5级品质抽卡逻辑（单抽/十连）
│   └── BattleUI.gd             # 战斗场景（回合循环、行动排序、寻敌、动画 Tween、平滑日志滚动、原子化结算）
└── scenes/                     # 场景文件 (.tscn)
    ├── LoginUI.tscn
    ├── MainUI.tscn
    ├── FormationUI.tscn
    ├── HeroDetailModal.tscn
    ├── AccountManageModal.tscn
    ├── GachaUI.tscn
    └── BattleUI.tscn
```

---

## 📊 5. 数据配置表规范 (CSV Specifications)

所有 CSV 配置文件均要求保存为 **带有 BOM 头 (UTF-8 with BOM / `\ufeff`)** 的 UTF-8 编码，以兼容 Excel 与 WPS。`GameData.gd` 在读取时会自动清除首字节 BOM。

### 5.1 `heroes.csv` (英雄模板表)
| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | String | 英雄唯一 ID（如 `h_01`） |
| `name` | String | 英雄名称（如 `关羽`） |
| `quality` | String | 品质等级（`UR`, `SSR`, `SR`, `R`, `N`） |
| `troop_id` | String | 默认绑定兵种 ID（如 `t_cavalry`） |
| `hp` | Int | 基础生命值 |
| `atk` | Int | 基础攻击力 |
| `def` | Int | 基础物理防御 |
| `satk` | Int | 基础战法攻击 |
| `sdef` | Int | 基础战法防御 |
| `spd` | Int | 基础速度 |
| `color` | String | 主主题十六进制颜色（如 `#FF2255`） |

### 5.2 `troops.csv` (兵种配置表)
| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | String | 兵种唯一 ID（如 `t_cavalry`） |
| `name` | String | 兵种名称（如 `虎豹骑`） |
| `type_name` | String | 兵种分类（`骑兵`, `步兵`, `弓兵`, `鼓手`, `战法`） |
| `atk` | Int | 兵种基础攻击 |
| `def` | Int | 兵种基础防御 |
| `satk` | Int | 兵种基础战法攻击 |
| `sdef` | Int | 兵种基础战法防御 |
| `evade_rate` | Float | 兵种专属闪避率（如 `0.10` 代表 10%） |
| `target_type` | String | 克制目标兵种类型（如 `步兵`） |
| `bonus_target` | String | 攻击范围分类（如 `单体攻击`, `横排攻击`, `辅助增益`） |
| `bonus_rate` | Float | 克制伤害加成比例（如 `0.10` 代表 +10%） |
| `skill_name` | String | 战法技能名称 |
| `skill_desc` | String | 技能描述 |
| `anim_type` | String | 攻击动画类型（`slash`, `stomp`, `thrust`, `inspire`, `fire`） |
| `texture_path` | String | 兵种立绘纹理路径（可留空使用默认模板） |

---

## 🛡️ 6. 存档与账号系统 (Save & Account System)

1. **账号隔离**：账号密码与英雄存档统一存储于 `user://accounts.json`，不同账号的数据互相隔离。
2. **战斗时存档锁定**：战斗过程中主界面“💾 保存存档”按钮被锁定（提示 `⚠️ 战斗中不可保存`），避免存档时捕获中途不一致的英雄状态。
3. **单次战斗奖励原子性**：`BattleUI.gd` 中设置独占标记 `is_reward_given`，防止正常战斗结束协程与【跳过战斗】快进循环同时触发导致双重加钱加经验。
4. **账号清理机制**：管理员界面提供“🧹 账号清理”功能，可列出并永久删除非 `admin` 的测试账号。
5. **版本配置热同步**：加载存档时，`GameData.gd` 会自动校验并同步 `heroes.csv` 中的最新模板品质（如将关羽、诸葛亮自动提升为 UR），确保老存档也能享受到最新配置更新。

---

## 🛠️ 7. 已解决的重要技术细节与避坑 (Technical Issues Resolved)

1. **拖拽下阵误清空阵型**：修复了 `NOTIFICATION_DRAG_END` 在所有卡牌上触发导致整体阵型被重置的问题，改为在左侧英雄池挂载专用的 `LeftPanelDropScript`，仅当拖入卡牌 `from_slot > 0` 时触发定向下阵。
2. **退出战斗场景 Coroutine Null Instance 崩溃**：对 `_scroll_log_to_bottom` 等异步协程补充了 `if not is_inside_tree() or get_tree() == null:` 防护，场景销毁后安全退出协程。
3. **跳过战斗双重奖励结算**：增加 `is_reward_given` 原子锁，确保无论是正常播放完毕还是快进跳过，每场战斗仅结算一次收益与战报。
4. **英雄池列表卡片尺寸变形与消失**：固定卡片最小尺寸为 `88x118`，移除了 `HeroGrid` 上的 `SIZE_EXPAND_FILL` 强制拉伸，保持 4 列网格稳定排列。

---

## 🔴 8. 未实现功能与重构规划清单 (Unimplemented Features & Roadmap)

经评估，以下功能在建议或设计方案中提到，但**目前代码中尚未实现/有待后续迭代重构**：

### 8.1 未实现的游戏功能 (Unimplemented Game Features)
1. **技能数据驱动表 (`data/skills.csv`)**：
   - *现状*：技能效果（如鼓手加士气、法师横排火攻）目前直接硬编码在 `BattleUI.gd` 中。
   - *规划*：新建 `skills.csv`，将技能伤害倍率、作用目标规则、士气消耗、动画标签数据驱动化。
2. **英雄模板与英雄实例分离 (Template vs Instance)**：
   - *现状*：玩家拥有的英雄属性直接保存在 JSON 存档字典中。
   - *规划*：存档仅保存 `instance_id`、`template_id`、`level`、`exp`，属性由模版基础值 + 等级成长公式动态计算。
3. **独立战斗服务层与视图解耦 (`BattleSession` & `BattleService`)**：
   - *现状*：战斗计算、寻敌、士气逻辑与 UI 渲染（Tween 动画、日志）均集中在 `BattleUI.gd` 中。
   - *规划*：将战斗纯逻辑独立为 `BattleSession`，返回纯数据事件流；`BattleUI` 仅负责读取事件流播放动画，便于无动画快速模拟与战斗回放。
4. **关卡解锁与副本推进系统**：
   - *现状*：目前仅提供简单/普通/困难/噩梦下拉框选择敌方阵容。
   - *规划*：建立关卡树（Stage Progress），实现通关解锁下一关、首次通关奖励与关卡星级评定。
5. **装备系统与兵种科技树**：
   - *现状*：未实现装备位与兵种科技研磨提升。
6. **抽卡保底与概率公示弹窗**：
   - *现状*：已支持 5 级品质概率抽卡，但尚未实现硬保底（如 90 抽必出 UR）及概率公示说明面板。

### 8.2 未实现的技术/安全与数据规范 (Unimplemented Tech/Security Specs)
1. **密码哈希安全保存 (Password Hashing)**：
   - *现状*：`accounts.json` 中密码为明文保存。
   - *规划*：引入 Salt + SHA256 哈希加密保存，并区分生产环境与开发调试模式（正式版禁用默认 `admin/123456`）。
2. **存档原子写入与备份恢复 (`.tmp` / `.bak`)**：
   - *现状*：存档直接覆盖写入 `accounts.json`。
   - *规划*：采用 `写入 .tmp -> 备份 .bak -> 替换正本` 流程，并引入 `schema_version` 处理未来存档版本迁移。
3. **启动数据校验器 (CSV Data Validator)**：
   - *现状*：缺失部分字段时依赖 GDScript 的 `get()` 默认值兜底。
   - *规划*：游戏启动时校验 CSV 表头格式、外键引用合法性（如 `troop_id` 是否存在）、抽卡概率和是否为 100%。
4. **多重克制关系表 (`troop_counters.csv`)**：
   - *现状*：克制关系单一配置在 `troops.csv` 的 `target_type` 字段中（仅支持 1 对 1 克制）。
   - *规划*：拆分出独立克制表，支持单兵种对多个兵种的不同克制加成比例。
5. **单元测试与自动化测试集成 (Unit Tests)**：
   - *现状*：尚未建立自动化测试用例。
