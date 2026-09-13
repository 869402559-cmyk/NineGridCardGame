# dsh-mneme 记忆种子（首次使用请让 DSH 助手逐条写入）

> **用途**：重启 DSH Desktop 后，把下面每一条内容作为一条 `memory_save` 写入 mneme 记忆库。
> **用法**：把本文件整体 @ 给助手，并说：
> 「请按 `DSH_MEMORY_SEED.md` 里的每一条，逐条调用 `memory_save` 写入记忆库，type / title / content / importance 按文件里写的来。」
> 写完后本文件可以删除，或保留作为「记忆库的版本化备份」。

---

## 记忆条目

### 1. type=project, importance=5
**title**: NineGridCardGame 项目定位与技术栈
**content**: NineGridCardGame 是一个 Godot 4.x 的 3x3 九宫格卡牌回合制 RPG，玩法参考《傲视天地》。引擎版本 Godot 4.6.1-stable，语言 GDScript。主场景入口 `res://scenes/LoginUI.tscn`，单例 `GameData.gd` 负责 CSV 解析、属性计算、账号存档。数据表为 UTF-8 with BOM 的 CSV（`data/heroes.csv`、`data/troops.csv`、`data/enemies.csv`），存档为 `user://accounts.json`。目标平台 Windows Desktop / Web(HTML5)。

### 2. type=constraint, importance=5
**title**: 禁止在代码中引用中文资源目录
**content**: NineGridCardGame 项目严禁在 `.gd` 脚本或 `.tscn` 场景中引用临时中文目录 `res://素材/`。所有需要使用的美术资源必须复制到 `res://assets/textures/` 并使用英文文件名，代码统一引用 `res://assets/textures/...`。原因：中文路径在跨平台导出、Web 构建与 CI 环境中存在兼容风险。

### 3. type=decision, importance=5
**title**: 兵种大类与具体兵种解耦架构
**content**: 项目区分两个层级：兵种大类（`troop_type`：骑兵/步兵/弓兵/鼓手/策士/医师）决定阵型矩阵、小兵数量、掉兵顺序、基础闪避率与克制关系；具体兵种（`troop_id`：虎豹骑/重装步兵/白马义从/战场鼓手/谋士法队/杏林医师）绑定专属技能、成长与纹理路径。矩阵渲染由 `GameData.TROOP_CATEGORY_CONFIGS` + `get_troop_category_config()` 驱动，不要硬编码在 BattleUI.gd 里。

### 4. type=decision, importance=4
**title**: 战场小兵阵型与减员移除顺序规则
**content**: 骑兵与鼓手使用 3x3 交错阵型（9 人，图标 44x44），步兵/弓兵/策士/医师使用 4x4 矩阵（16 人，图标 36x36）。受击掉血时按 `removal_order` 移除小兵：先掉四角、再掉四边，半血时形成核心十字阵型，最后才移除中央主将。右侧敌方单位自动 `flip_h = true` 水平翻转并做对称 X 坐标镜像，形成两军向心对垒视角。

### 5. type=pitfall, importance=5
**title**: Godot 资源必须配套 .import 文件才能加载
**content**: 把图片复制进 `res://assets/textures/` 后，如果缺少对应的 `.import` 和 `.godot/imported/*.ctex`，Godot 会加载出 null 纹理——表现为背景图完全不显示、UI 露底色。正确做法：让 Godot 编辑器重新导入，或在 `.import` 中把 `source_file` 改为新路径并让引擎重新生成 `.ctex`。踩坑记录：`fight_bg.png` 因缺 `.import` 导致战斗背景不显示。

### 6. type=pitfall, importance=4
**title**: 跨 Godot 版本切换开发的风险
**content**: 项目会在 Godot 4.7 与 4.6 两台电脑之间切换开发。风险：高版本保存的 `.tscn` 可能写入低版本不认识的新属性导致解析报错；两个版本的资源导入器差异会让 `.import` / UID 产生大量伪变更污染 git。建议：尽量统一两台机器的 Godot 版本；跨版本提交前先用 `git status` 检查，不要提交引擎自动重新导入产生的脏文件，只提交自己改的 `.gd` / `.tscn`。

### 7. type=pitfall, importance=4
**title**: DSH 插件安装后必须重启桌面端才生效
**content**: DSH Desktop 的插件在 profile 的 `package.json#dsh.profile.bundles` 中注册，宿主只在启动时加载该清单，所以新装插件必须重启 DSH Desktop（或至少重开 web 服务）才生效。另外该清单若带 UTF-8 BOM 会让 `dsh plugin` CLI 在最后写清单阶段崩溃（`JSON.parse` 报 Unexpected token）——安装其实已完成，只是清单没自动写入，需要手动补 bundles。

### 8. type=preference, importance=4
**title**: 用户的工作方式偏好
**content**: 用户偏好：① 让助手直接动手改项目源码，而不是只给建议；② 重要改动完成后要更新 `PROJECT_STATUS.md` 并推送到 GitHub；③ 讨论 UI/玩法设计时希望先给多个方案对比再选；④ 中文交流；⑤ 代码与注释保持中文。

### 9. type=decision, importance=3
**title**: 战斗 UI 重构方向讨论结论（待定）
**content**: 现状问题：战斗界面与《傲视天地》差距较大、不够饱满；原版没有战斗记录，但用户希望保留战报、血量、士气、武将名称显示。已提出三套方案：① 复刻原版大气古战场风（取消卡牌外框、信息条悬浮在兵队上方、战报改为可展开卷轴 + 飘字）；② 战棋式阵型底座 + 右侧暗金羊皮纸可折叠战报；③ 底部横向战报栏 + 高质感黑金卡牌。方案尚未最终选定。

---

## 用户画像与规则（建议填进「记忆库设置 → 用户画像 / 规则」）

**用户画像（自由文本）**：
```
我是一名独立游戏开发者，正在用 Godot 4.x + GDScript 开发一款 3x3 九宫格卡牌回合制 RPG《NineGridCardGame》，
玩法参考《傲视天地》。我会在 Windows 上用 DSH Desktop 与 AI 协作开发，有时会在两台电脑之间切换（Godot 4.6 / 4.7）。
我的母语是中文，希望用中文交流。我不熟悉前端/引擎的每个细节，所以请主动替我查证、动手改代码，并在改完后说明改了什么。
```

**规则（行为约束列表）**：
```
1. 回答先给结论，再给理由，不要长篇铺垫。
2. 改代码前先说清要动哪个文件、为什么；改完列出改动清单。
3. 不允许在代码或场景里引用 res://素材/ 等中文路径，资源统一放 res://assets/textures/。
4. 重要里程碑完成后，主动更新 PROJECT_STATUS.md 并提示我 push 到 GitHub。
5. 涉及 UI / 玩法设计时，先给 2-3 个方案对比，等我选定再动手。
6. 遇到不确定的引擎行为，先查文档或实测验证，不要凭印象回答。
```
