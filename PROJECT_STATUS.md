# 🎮 NineGridCardGame 项目架构与状态说明文档

> **本文档供开发者及 AI 助手快速了解项目架构、技术细节、当前进度以及未来重构计划。**
> 只要拉取最新 Git 代码并阅读本文档，即可无缝接手续写本项目。

---

## 📌 1. 文档状态与版本信息 (Document Status)

- **文档版本**：`1.0.1`
- **最后更新时间**：`2026-09-13`
- **Godot 引擎版本**：`Godot 4.6.1-stable` / `Godot 4.7.2-stable` (GDScript)
- **当前项目状态**：【7大兵种解耦 + 机械兵种 + 战旗与高密度方阵 + 战斗UI间距优化】完成！
  1. **第 7 大兵种大类“机械”（投石车/霹雳车）**：
     - 包含 `t_machinery_toushiche` 与 `t_machinery_piliche`；
     - 3x3 矩阵 (58×58px 单兵尺寸)，6x6 全兵种克制循环（机械 > 步兵，骑兵/策士 > 机械）；
  2. **视觉密排重叠与战旗系统 (`BattleUI.gd`)**：
     - 方阵上方新增金边宝蓝/赤红帅旗（展示武将姓名），去除原裸露文字；
     - 脚下接地半透明 Oval 投影暗影，增强小兵立体扎实感；
     - 4x4 (48x48px) 与 3x3 (58x58px) 小兵高密度错位重叠方阵；
  3. **战斗 UI 空间与重叠优化 (`BattleUI.tscn` & `BattleUI.gd`)**：
     - `LogPanel` 日志面板缩窄至 `220px`，双方阵营间距拓宽至 `120px`；
     - 卡牌基础宽度调至 `145px`，彻底解决中央血条与小兵方阵重叠问题。
- **目标平台**：Windows Desktop / Web (HTML5)

---

## 📌 2. 项目概览与开发环境 (Project Overview)

- **项目名称**：`NineGridCardGame`（傲视天地风格 3x3 九宫格卡牌回合制 Web / 桌面游戏）
- **主场景入口**：`res://scenes/LoginUI.tscn`
- **本地存档路径**：`user://accounts.json`（真实磁盘路径如 `%APPDATA%\Godot\app_userdata\NineGridCardGame\accounts.json`）
- **开发与启动方式**：使用 Godot 4.6.1 编辑器直接打开 `project.godot` 运行主场景。

---

## ⚡ 3. 核心游戏机制与数值公式 (Core Game Mechanics & Stat Formulas)

本项目采用**“面板属性复合”与“战斗动态伤害/治疗”解耦的两阶段数值结算模型**：

### 3.1 第一阶段：面板属性计算（7:3 复合公式）
在进入战斗前或在武将详情弹窗中，先根据英雄基础模板/成长与兵种基础数据计算出单位的固定战斗面板：

$$ egin{aligned}
	ext{基础攻击力 (Atk)} &= 	ext{round}(	ext{英雄基础 Atk} 	imes 0.7 + 	ext{兵种基础 Atk} 	imes 0.3) \
	ext{基础防御力 (Def)} &= 	ext{round}(	ext{英雄基础 Def} 	imes 0.7 + 	ext{兵种基础 Def} 	imes 0.3) \
	ext{战法攻击力 (SAtk)} &= 	ext{round}(	ext{英雄基础 SAtk} 	imes 0.7 + 	ext{兵种基础 SAtk} 	imes 0.3) \
	ext{战法防御力 (SDef)} &= 	ext{round}(	ext{英雄基础 SDef} 	imes 0.7 + 	ext{兵种基础 SDef} 	imes 0.3)
\end{aligned}$$

- **直接继承/不参与 7:3 的属性**：
  - $	ext{最终生命值 (HP)} = 	ext{英雄基础 HP}$（受到英雄手动升级的经验成长加成）。
  - $	ext{最终速度 (Spd)} = 	ext{英雄基础 Spd}$。
- **兵种专属闪避率 (MISS)**：
  - 闪避判定绑定在兵种数据上：弓兵 20%、鼓手 15%、医师 10%、骑兵 10%、策士 8%、步兵 5%。

---

### 3.2 第二阶段：战斗动态结算与辅助治疗公式 (Battle Mechanics)

#### 1. 基础物理与战法伤害公式 (Raw Damage)
- **普通物理伤害**：$	ext{RawDamage} = \max(	ext{攻击者 Atk} - 	ext{受击者 Def} 	imes 0.5, 1)$
- **战法大招伤害**：$	ext{SkillRawDamage} = \max(	ext{攻击者 SAtk} 	imes 2.3 - 	ext{受击者 SDef} 	imes 0.75, 1)$
- **兵种克制乘数**：若触发克制，乘数 $	ext{CounterBonus} = 1.10$，无克制为 $1.0$。最终伤害 = $	ext{round}(	ext{RawDamage} 	imes 	ext{CounterBonus})$。

#### 2. 医师专属治疗计算公式 (Physician Healing Model)
医师兵种（如神医华佗）**不攻击敌方、无克制关系**，每回合优先为己方当前生命值百分比（Current HP / Max HP）最低的存活英雄施诊救治：
- **普通回合诊疗加血**：
  $$	ext{HealAmount} = 	ext{round}(100 + 	ext{医师 Atk} 	imes 0.7 + 	ext{医师 SAtk} 	imes 0.8)$$
  *（由普通攻击 Atk 和战法攻击 SAtk 共同提供双重医术加成，且受英雄升级成长提升）*
- **战法大招【悬壶济世】（满 100 士气）**：
  $$	ext{UltimateHealAmount} = 	ext{round}(500 + 	ext{医师 SAtk} 	imes 1.2)$$
  *（固定 500 点高额大招基底 + 1.2 倍战法攻击加成，为全军所有存活队友恢复兵力）*
- **治疗飘字反馈**：受击伤害弹出红色数字；治疗与回血弹出绿色亮光数字（如 `+380`）。

---

### 3.3 养成、洗练与武将解雇机制 (Progression, Reset & Dismissal)

#### 1. 洗练洗等级功能 (Level Reset System)
- **功能位置**：英雄详情弹窗（`HeroDetailModal`）新增 `🔄 洗练洗等级` 按钮。
- **重置规则**：将等级大于 1 的武将重置回 **Lv.1**，英雄基础属性（HP/Atk/Def/SAtk/SDef）恢复至基础模板初始值。
- **经验返还公式**：
  $$	ext{RefundExp} = 	ext{round}\left(	ext{TotalSpentExp} 	imes 80\%ight)$$
  - 累计消耗的总经验值：$	ext{TotalSpentExp} = \sum_{l=1}^{	ext{Level}-1} (l 	imes 100)$。洗练固定**无损返还 80% 经验值**归还至公共经验池，用于重新培养其他强力英雄。

#### 2. 批量解雇武将功能 (Dismissal System)
- **入口位置**：布阵界面左侧面板顶部新增 `🚪 解雇` 按钮，点击弹出独立 `DismissModal` 列表面板。
- **解雇条件约束（安全性校验）**：
  - ⚠️ **已在阵型中的武将不可解雇**（防止因解雇导致上阵状态异常）。
  - ⚠️ **等级大于 1 级的武将不可解雇**（强制要求玩家先在详情页使用 `洗练洗等级` 找回经验后方可解雇，避免误操作损失经验）。
- **操作支持与品质快速全选**：
  - 支持快捷按钮**按品质一键全选**（`全选 N`, `全选 R`, `全选 SR`, `全选 SSR`, `全选 UR`）、`全选所有可解雇` 和 `反选/清空`。
  - 列表中按键支持 **Shift 连续批量范围多选**。
- **解雇金币收益配比**：
  - 解雇后武将从玩家背包永久移除，并根据品质按固定基数返还金币：
    - **UR**：+2,000 金币 / 人
    - **SSR**：+800 金币 / 人
    - **SR**：+300 金币 / 人
    - **R**：+100 金币 / 人
    - **N**：+30 金币 / 人

---

### 3.4 3x3 九宫格布阵 (3x3 Formation)
- 3x3 网格阵型（位置编号 1 ~ 9），最多上阵 5 名英雄。
- 英雄卡牌统一按 3:4 比例渲染（布阵列表小卡片 `88x118`，详情大图 `250x333`）。
- **拖拽与下阵操作**：
  - 英雄池卡牌可拖拽至 3x3 九宫格槽位上阵。
  - 已上阵槽位之间可互相拖拽交换位置。
  - 将已上阵槽位的卡牌拖拽回左侧英雄池面板，触发定向下阵（Unequip）。

### 3.5 5v5 回合制战斗与动作动画 (Battle System)
- **行动顺序与轮次**：根据双方存活单位的速度（`Spd`）降序排列决定行动次序。相同速度时玩家单位优先行动。
- **寻敌与攻击规则**：优先攻击对向前排目标；前排倒下后向中排、后排寻找。
- **士气与战法大招**：初始 50 士气，满 100 士气释放战法。普攻/受击积攒士气；鼓手与医师触发专属光效与日志/飘字反馈。

### 3.6 兵种大类配置驱动与动态阵型（Troop Matrix Architecture）
- **兵种大类与具体兵种解耦**：
  - **兵种大类 (`troop_type`)**：`骑兵`, `步兵`, `弓兵`, `鼓手`, `策士`, `医师`（决定阵型矩阵、掉兵顺序、基础闪避率、大类克制关系）。
  - **具体兵种 (`troop_id`)**：`虎豹骑`, `重装步兵`, `白马义从`, `战场鼓手`, `谋士法队`, `杏林医师`（绑定专属技能、成长、纹理路径）。
- **配置驱动矩阵与 3x3 / 4x4 错位布局 (`TROOP_CATEGORY_CONFIGS`)**：
  - 骑兵/鼓手采用 **3x3 交错阵型 (9人, 44x44 图标)**，更显饱满冲锋感；步兵/弓兵/策士/医师采用 **4x4 标准矩阵 (16人, 36x36 图标)**。
  - **战术减员移除顺序 (`removal_order`)**：受击掉血时按配置顺序移除小兵（先掉四角、次掉四边，半血保留核心十字阵型，最后保留中央主将）。
- **敌方单位镜像对称 (`flip_h` & Mirrored Offsets)**：
  - 右侧敌方单位自动触发 `flip_h = true` 水平翻转面向，并且错位 X 坐标进行对称反转，展现两军向心对垒视角。

---

## 📁 4. 代码架构与文件职责 (Project Architecture)

```
NineGridCardGame/
├── project.godot               # Godot 项目主配置
├── PROJECT_STATUS.md           # 本说明文档
├── data/                       # CSV 数据表（UTF-8 with BOM 编码）
│   ├── heroes.csv              # 英雄模板表（基础属性、品质、默认兵种，包含华佗等）
│   ├── troops.csv              # 兵种配置表（基础属性、闪避率、动画标签，包含医师等）
│   └── enemies.csv             # 敌方阵容与难度倍率表 (stat_mult)
├── assets/                     # 游戏美术资源目录（禁止直接引用临时中文"素材/"路径）
│   └── textures/               # 战斗背景图 (fight_bg.png)、兵种待机图 (hobaoqi_idle.png, baimayicong_idle.png)
├── scripts/                    # GDScript 业务逻辑
│   ├── GameData.gd             # 单例组件：CSV解析、属性计算、账号/存档、解雇洗练、TROOP_CATEGORY_CONFIGS 兵种大类配置
│   ├── LoginUI.gd              # 登录与注册界面
│   ├── MainUI.gd               # 主界面顶部栏（账号状态、金币/经验展示、保存存档拦截、账号清理）
│   ├── FormationUI.gd          # 3x3 拖拽布阵与左侧列表排序（打开解雇弹窗入口）
│   ├── HeroDetailModal.gd      # 英雄详情弹窗（3:4 大立绘展示、7:3 拆解、升级与洗练等级）
│   ├── DismissModal.gd         # 武将批量解雇弹窗（品质快速全选、Shift范围多选、解雇金币结算）
│   ├── AccountManageModal.gd   # 账号管理与清理弹窗（列出/删除非 admin 账号）
│   ├── GachaUI.gd              # 5级品质抽卡逻辑（单抽/十连，可抽神医华佗）
│   └── BattleUI.gd             # 战斗场景（回合循环、行动排序、寻敌/救护、Tween动画、错位阵型渲染、纯色底框战报日志）
└── scenes/                     # 场景文件 (.tscn)
    ├── LoginUI.tscn
    ├── MainUI.tscn
    ├── FormationUI.tscn
    ├── HeroDetailModal.tscn
    ├── DismissModal.tscn
    ├── AccountManageModal.tscn
    ├── GachaUI.tscn
    └── BattleUI.tscn
```

---

## 📊 5. 数据配置表规范 (CSV Specifications)

所有 CSV 配置文件均要求保存为 **带有 BOM 头 (UTF-8 with BOM / `\ufeff`)** 的 UTF-8 编码，以兼容 Excel 与 WPS。`GameData.gd` 在读取时会自动清除首字节 BOM。

---

## 🛡️ 6. 存档与账号系统 (Save & Account System)

1. **账号隔离与初始资金**：账号密码与英雄存档统一存储于 `user://accounts.json`。管理员 `admin` 登录默认提供 **1 亿金币 & 1 亿经验** 方便测试，存档读取时保留实际进度。
2. **战斗时存档锁定**：战斗过程中主界面“💾 保存存档”按钮被锁定（提示 `⚠️ 战斗中不可保存`）。
3. **单次战斗奖励原子性**：`BattleUI.gd` 中设置独占标记 `is_reward_given`，防止双重结算，胜利奖励即时触发 UI 刷新信号。

---

## 🛠️ 7. 已解决的重要技术细节与避坑 (Technical Issues Resolved)

1. **洗练洗等级经验无损换算**：提供 80% 固定经验返还，刷新等级为 Lv.1 并在 UI 即时更新经验池。
2. **解雇防误删安全锁**：强制禁止解雇已上阵或等级不为 1 的武将，防范玩家误解雇高等级主力。
3. **Shift 多选范围连续选择**：在 `DismissModal.gd` 记录上次点击的索引，完美支持 Shift 连续批量拉选。
4. **跳过战斗后再次自动战斗卡死**：重置 `is_fast_simulating = false`，保证战斗状态正常重置。
5. **资源路径管理规范**：所有资源文件统一放入 `res://assets/textures/`（英文命名），代码和 `.tscn` 中绝不直接硬编码引用临时中文目录 `res://素材/`。
6. **战报日志背景穿透**：`LogPanel` 使用 `PanelContainer` 配合 `StyleBoxFlat` 设置 `Color(0.12, 0.12, 0.15, 0.98)` 不透明深色背景，解决背景图透字问题。

---

## 🔴 8. 未实现功能与重构规划清单 (Roadmap)
*(详见后续技能驱动表 `skills.csv`、密码哈希、数据校验等重构计划)*
