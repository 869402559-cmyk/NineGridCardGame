# 🎨 品质视觉与设计系统 (Quality Visual System)

### 1. 五品质设定与视觉设计

| 品质 | 概率 (抽卡) | 代表色 (RGB / Hex) | 边框与背景效果设计 | 视觉暗喻 |
| :--- | :--- | :--- | :--- | :--- |
| **UR** (彩幻/极品) | 1.0% | `赤金/绚彩` (`#FF2255` ~ `#FFD700`) | 3px 金彩双色重叠粗边框，富丽堂皇金黄渐变背景，文字带有金色光泽特效 | 闪耀夺目、霸气绝伦 |
| **SSR** (传说/史诗) | 4.0% | `金色/暗金` (`#FFAA00` / `#FFC800`) | 2px 亮金色边框，深金黄色暗纹背景，文字耀眼明亮 | 华贵辉煌、主将风范 |
| **SR** (史诗/名将) | 15.0% | `紫色/暗紫` (`#AA33FF` / `#B545FF`) | 2px 紫罗兰色边框，暗紫夜空背景，文字清晰醒目 | 神秘深沉、名将勇武 |
| **R** (精锐/良将) | 35.0% | `蓝色/深蓝` (`#3399FF` / `#2B82EC`) | 1px 湛蓝色边框，暗蓝调背景，文字规整自然 | 稳健干练、精锐骨干 |
| **N** (普通/辅兵) | 45.0% | `灰色/朴素` (`#888888` / `#666666`) | 1px 哑光灰/无边框，极暗无光沉闷灰色背景，文字暗淡无光 | 朴素无华、平凡大众 |

---

### 2. 品质系统数据结构扩展
在 `GameData.gd` 中定义全局品质配置表 `QUALITY_CONFIGS`，包含：
- `rank`: 排序权重（UR: 5, SSR: 4, SR: 3, R: 2, N: 1）
- `color`: 边框/代表颜色 (`Color`)
- `bg_color`: 背景颜色 (`Color`)
- `border_width`: 边框粗细
- `label_color`: 字体颜色

```gdscript
const QUALITY_CONFIGS = {
	"UR": {
		"rank": 5,
		"color": Color(1.0, 0.2, 0.35), # 璀璨赤金/虹彩
		"border_color": Color(1.0, 0.85, 0.2), # 金色亮边框
		"bg_color": Color(0.28, 0.12, 0.15),
		"border_width": 3,
		"label_color": Color(1.0, 0.9, 0.4)
	},
	"SSR": {
		"rank": 4,
		"color": Color(1.0, 0.7, 0.1), # 耀眼金
		"border_color": Color(1.0, 0.8, 0.2),
		"bg_color": Color(0.25, 0.2, 0.08),
		"border_width": 2,
		"label_color": Color(1.0, 0.85, 0.3)
	},
	"SR": {
		"rank": 3,
		"color": Color(0.7, 0.3, 1.0), # 华丽紫
		"border_color": Color(0.8, 0.4, 1.0),
		"bg_color": Color(0.18, 0.1, 0.25),
		"border_width": 2,
		"label_color": Color(0.85, 0.6, 1.0)
	},
	"R": {
		"rank": 2,
		"color": Color(0.2, 0.6, 1.0), # 稳重蓝
		"border_color": Color(0.3, 0.7, 1.0),
		"bg_color": Color(0.08, 0.18, 0.28),
		"border_width": 1,
		"label_color": Color(0.5, 0.8, 1.0)
	},
	"N": {
		"rank": 1,
		"color": Color(0.5, 0.5, 0.5), # 朴素灰
		"border_color": Color(0.4, 0.4, 0.4),
		"bg_color": Color(0.15, 0.15, 0.15),
		"border_width": 1,
		"label_color": Color(0.7, 0.7, 0.7)
	}
}
```
