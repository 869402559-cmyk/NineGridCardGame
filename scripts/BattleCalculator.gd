class_name BattleCalculator
extends Node

# -------------------------------------------------------------------
# 1. 6大阵型配置与位置限制 (3x3 网格仅开放 5 个允许上阵的位置)
# -------------------------------------------------------------------
const FORMATIONS: Dictionary = {
	"fish_scale": {
		"name": "鱼鳞阵",
		"desc": "强化物理攻击与物防",
		"positions": [1, 2, 3, 5, 8],
		"bonuses": { "atk_pct": 0.15, "def_pct": 0.10, "crit_rate": 0.05 }
	},
	"goose_wing": {
		"name": "雁行阵",
		"desc": "强化战法攻击与闪避",
		"positions": [1, 3, 5, 7, 9],
		"bonuses": { "satk_pct": 0.20, "evade_rate": 0.08 }
	},
	"cone": {
		"name": "锥形阵",
		"desc": "强化暴击与物理穿透",
		"positions": [2, 4, 5, 6, 8],
		"bonuses": { "crit_rate": 0.15, "penetrate_rate": 0.15 }
	},
	"crane_wing": {
		"name": "鹤翼阵",
		"desc": "强化物理防御与格挡",
		"positions": [1, 3, 4, 6, 8],
		"bonuses": { "def_pct": 0.15, "block_rate": 0.15 }
	},
	"long_snake": {
		"name": "长蛇阵",
		"desc": "强化普通攻击与速度",
		"positions": [2, 5, 8, 4, 6],
		"bonuses": { "atk_pct": 0.10, "spd_pct": 0.15 }
	},
	"bagua": {
		"name": "八卦阵",
		"desc": "强化闪避与策略防御",
		"positions": [1, 3, 5, 7, 9],
		"bonuses": { "evade_rate": 0.12, "sdef_pct": 0.15 }
	}
}

# -------------------------------------------------------------------
# 2. 6x6 兵种大类克制矩阵 [攻击方][防御方] -> 伤害倍率
# -------------------------------------------------------------------
const COUNTER_MATRIX: Dictionary = {
	"步兵": { "步兵": 1.0, "骑兵": 0.8, "弓兵": 1.25, "策士": 1.0, "鼓手": 1.20, "医师": 1.20, "机械": 0.8 },
	"骑兵": { "步兵": 1.25, "骑兵": 1.0, "弓兵": 0.8, "策士": 1.20, "鼓手": 1.20, "医师": 1.20, "机械": 1.30 },
	"弓兵": { "步兵": 0.8, "骑兵": 1.25, "弓兵": 1.0, "策士": 1.0, "鼓手": 1.20, "医师": 1.20, "机械": 0.8 },
	"策士": { "步兵": 1.0, "骑兵": 1.0, "弓兵": 1.0, "策士": 1.0, "鼓手": 1.0, "医师": 1.0, "机械": 1.40 },
	"机械": { "步兵": 1.30, "骑兵": 0.7, "弓兵": 1.20, "策士": 0.8, "鼓手": 1.20, "医师": 1.20, "机械": 1.0 },
	"鼓手": { "步兵": 0.5, "骑兵": 0.5, "弓兵": 0.5, "策士": 0.5, "鼓手": 0.5, "医师": 0.5, "机械": 0.5 },
	"医师": { "步兵": 0.5, "骑兵": 0.5, "弓兵": 0.5, "策士": 0.5, "鼓手": 0.5, "医师": 0.5, "机械": 0.5 }
}

static func get_counter_multiplier(attacker_type: String, defender_type: String) -> float:
	if COUNTER_MATRIX.has(attacker_type) and COUNTER_MATRIX[attacker_type].has(defender_type):
		return COUNTER_MATRIX[attacker_type][defender_type]
	return 1.0

# -------------------------------------------------------------------
# 3. 多目标寻敌算法
# -------------------------------------------------------------------
static func find_targets(attacker: Object, defender_dict: Dictionary, friend_dict: Dictionary, is_skill: bool) -> Array:
	# A. 鼓手普攻特殊寻敌：永远只寻找己方存活友军 (绝对不找敌方)
	if attacker.troop_type == "鼓手" and not is_skill:
		var allies = []
		for p in friend_dict.keys():
			var u = friend_dict[p]
			if u.is_alive() and u != attacker:
				allies.append(u)
		# 若没有其他队友存活，则鼓舞自己
		if allies.size() == 0 and friend_dict.has(attacker.pos) and friend_dict[attacker.pos].is_alive():
			allies.append(friend_dict[attacker.pos])
		return allies

	var mode = attacker.skill_target_type if is_skill else attacker.atk_mode
	var targets: Array = []

	match mode:
		"single":
			var primary = _find_single_primary_target(attacker.pos, attacker.is_player, defender_dict)
			if primary != null:
				targets.append(primary)

		"row_line": # 纵向/一字长蛇（同一列所有存活目标）
			var primary = _find_single_primary_target(attacker.pos, attacker.is_player, defender_dict)
			if primary != null:
				var col = _get_col_of_pos(primary.pos)
				for p in [col, col + 3, col + 6]:
					if defender_dict.has(p) and defender_dict[p].is_alive():
						targets.append(defender_dict[p])

		"col_line": # 横向横扫（同一排所有存活目标）
			var primary = _find_single_primary_target(attacker.pos, attacker.is_player, defender_dict)
			if primary != null:
				var row_start = _get_row_start_of_pos(primary.pos)
				for p in [row_start, row_start + 1, row_start + 2]:
					if defender_dict.has(p) and defender_dict[p].is_alive():
						targets.append(defender_dict[p])

		"front_row": # 敌方前排（找最靠近的前排横排）
			var primary = _find_single_primary_target(attacker.pos, attacker.is_player, defender_dict)
			if primary != null:
				var row_start = _get_row_start_of_pos(primary.pos)
				for p in [row_start, row_start + 1, row_start + 2]:
					if defender_dict.has(p) and defender_dict[p].is_alive():
						targets.append(defender_dict[p])

		"back_target": # 敌方后排优先攻击
			var row_orders = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]
			for row in row_orders:
				var pos_list = [row[0], row[1], row[2]] if attacker.is_player else [row[2], row[1], row[0]]
				for p in pos_list:
					if defender_dict.has(p) and defender_dict[p].is_alive():
						targets.append(defender_dict[p])
						break
				if targets.size() > 0:
					break

		"backline_priority": # 后排突袭（优先打敌方后排 [7,8,9]，再中排 [4,5,6]，最后前排 [1,2,3]）
			var row_orders = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]
			for row in row_orders:
				var pos_list = [row[0], row[1], row[2]] if attacker.is_player else [row[2], row[1], row[0]]
				for p in pos_list:
					if defender_dict.has(p) and defender_dict[p].is_alive():
						targets.append(defender_dict[p])
						break
				if targets.size() > 0:
					break

		"all_targets": # 全体敌军
			for p in range(1, 10):
				if defender_dict.has(p) and defender_dict[p].is_alive():
					targets.append(defender_dict[p])

		"all_allies": # 全体友军
			for p in range(1, 10):
				if friend_dict.has(p) and friend_dict[p].is_alive():
					targets.append(friend_dict[p])

		"lowest_hp_ally": # 友方单体血量百分比最低
			var lowest_u = null
			var lowest_ratio = 999.0
			for p in friend_dict.keys():
				var u = friend_dict[p]
				if u.is_alive():
					var r = float(u.current_hp) / float(u.max_hp)
					if r < lowest_ratio:
						lowest_ratio = r
						lowest_u = u
			if lowest_u != null:
				targets.append(lowest_u)

	return targets

static func _find_single_primary_target(atk_pos: int, is_player: bool, defender_dict: Dictionary) -> Object:
	var row_search_order = []
	if atk_pos in [1, 2, 3]:
		row_search_order = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
	elif atk_pos in [4, 5, 6]:
		row_search_order = [[4, 5, 6], [1, 2, 3], [7, 8, 9]]
	else:
		row_search_order = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]
		
	for row in row_search_order:
		var pos_in_row = [row[0], row[1], row[2]] if is_player else [row[2], row[1], row[0]]
		for p in pos_in_row:
			if defender_dict.has(p) and defender_dict[p].is_alive():
				return defender_dict[p]
	return null

static func _get_col_of_pos(pos: int) -> int:
	return ((pos - 1) % 3) + 1

static func _get_row_start_of_pos(pos: int) -> int:
	return (((pos - 1) / 3) * 3) + 1

# -------------------------------------------------------------------
# 4. 多目标衰减比例计算
# -------------------------------------------------------------------
static func get_target_decay_ratio(is_skill: bool, mode: String, target_index: int) -> float:
	if is_skill:
		match mode:
			"single", "backline_priority":
				return 2.2 # 战法单体爆破系数
			"row_line", "col_line":
				return 1.3 # 战法多列/多排固定系数
			"all_targets":
				return 0.85 # 战法全体攻击固定系数
			_:
				return 1.0
	else:
		match mode:
			"single", "backline_priority":
				return 1.0
			"row_line", "col_line":
				if target_index == 0: return 1.0
				elif target_index == 1: return 0.7
				else: return 0.5
			"all_targets":
				return 0.5 # 普攻全体统一 50%
			_:
				return 1.0

# -------------------------------------------------------------------
# 5. 战斗核心结算主过程 (返回字典结构 AttackResult)
# -------------------------------------------------------------------
static func execute_attack(attacker: Object, targets: Array, is_skill: bool) -> Dictionary:
	var result = {
		"attacker": attacker,
		"is_skill": is_skill,
		"skill_type": attacker.skill_type if is_skill else "none",
		"hits": [],
		"logs": []
	}

	var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"

	# A. 辅助/鼓手处理
	if attacker.troop_type == "鼓手":
		if is_skill:
			attacker.mp = 0
			result["logs"].append(atk_tag + attacker.name + " 擂响战鼓释放 [color=orange]【" + attacker.skill_name + "】[/color]！己方全体恢复 60 点士气！")
			for ally in targets:
				ally.mp = min(100, ally.mp + 60)
				result["hits"].append({ "target": ally, "heal": 0, "mp_change": 60, "type": "mp_boost" })
		else:
			attacker.mp = min(100, attacker.mp + 10)
			if targets.size() > 0:
				var chosen = targets[randi() % targets.size()]
				chosen.mp = min(100, chosen.mp + 35)
				result["logs"].append(atk_tag + attacker.name + " 鼓舞士气，为 [color=yellow]" + chosen.name + "[/color] 增加了 35 点士气！")
				result["hits"].append({ "target": chosen, "heal": 0, "mp_change": 35, "type": "mp_boost" })
		return result

	# B. 医师处理
	if attacker.troop_type == "医师":
		if is_skill:
			attacker.mp = 0
			var heal_amount = int(500 + attacker.satk * 1.2)
			result["logs"].append(atk_tag + attacker.name + " 施展战法 [color=green]【" + attacker.skill_name + "】[/color]！为己方全体恢复 [color=green]+" + str(heal_amount) + "[/color] 兵力！")
			for ally in targets:
				ally.current_hp = min(ally.max_hp, ally.current_hp + heal_amount)
				result["hits"].append({ "target": ally, "heal": heal_amount, "mp_change": 0, "type": "heal" })
		else:
			attacker.mp = min(100, attacker.mp + 10)
			if targets.size() > 0:
				var ally = targets[0]
				var heal_amount = int(100 + attacker.atk * 0.7 + attacker.satk * 0.8)
				ally.current_hp = min(ally.max_hp, ally.current_hp + heal_amount)
				result["logs"].append(atk_tag + attacker.name + " 妙手施诊，为伤员 [color=green]" + ally.name + "[/color] 恢复了 [color=green]+" + str(heal_amount) + "[/color] 兵力！")
				result["hits"].append({ "target": ally, "heal": heal_amount, "mp_change": 0, "type": "heal" })
		return result

	# C. 攻击型结算（步/骑/弓/战法）
	var mode = attacker.skill_target_type if is_skill else attacker.atk_mode
	var hit_count = 0

	for idx in range(targets.size()):
		var target = targets[idx]
		var decay_ratio = get_target_decay_ratio(is_skill, mode, idx)

		# 1. 闪避判定
		var evade_chance = target.evade_rate
		if not is_skill and randf() < evade_chance:
			result["hits"].append({
				"target": target,
				"is_evaded": true,
				"damage": 0,
				"type": "miss"
			})
			result["logs"].append(atk_tag + attacker.name + " 攻击 " + target.name + "，被其成功 [color=cyan]闪避 (MISS)[/color]！")
			continue

		hit_count += 1
		# 2. 暴击判定
		var is_crit = (randf() < attacker.crit_rate)
		var crit_mult = 1.5 if is_crit else 1.0

		# 3. 格挡判定 (仅普攻可被格挡)
		var is_blocked = false
		var block_mult = 1.0
		if not is_skill and randf() < target.block_rate:
			is_blocked = true
			block_mult = 0.3 # 减免 70% 伤害

		# 4. 穿透与防御削减
		var pen = min(0.8, attacker.penetrate_rate)
		var target_def = target.sdef if is_skill else target.def
		var eff_def = target_def * (1.0 - pen)

		# 5. 攻防基础伤害
		var raw_atk = attacker.satk if is_skill else attacker.atk
		var base_dmg = max(1.0, raw_atk * 1.5 - eff_def * 0.75)

		# 6. 大类克制系数
		var counter_mult = get_counter_multiplier(attacker.troop_type, target.troop_type)

		# 7. 最终伤害公式
		var final_damage = max(10, int(base_dmg * counter_mult * decay_ratio * crit_mult * block_mult * (0.95 + randf() * 0.1)))

		# 8. 降血与加气
		target.current_hp = max(0, target.current_hp - final_damage)

		# 降气/吸气战法特殊结算
		var mp_loss = 0
		if is_skill and attacker.skill_type == "drain":
			mp_loss = 35
			target.mp = max(0, target.mp - mp_loss)
		elif is_skill and attacker.skill_type == "steal":
			mp_loss = 30
			target.mp = max(0, target.mp - mp_loss)
		else:
			target.mp = min(100, target.mp + 25) # 正常受击加气

		# 格挡反击计算
		var counter_dmg = 0
		if is_blocked and target.is_alive():
			var counter_raw = max(5.0, target.atk * 1.0 - attacker.def * 0.8)
			counter_dmg = max(5, int(counter_raw * 0.7))
			attacker.current_hp = max(0, attacker.current_hp - counter_dmg)

		# 记录 Hit 帧数据
		result["hits"].append({
			"target": target,
			"is_evaded": false,
			"is_crit": is_crit,
			"is_blocked": is_blocked,
			"damage": final_damage,
			"mp_loss": mp_loss,
			"counter_dmg": counter_dmg,
			"type": "damage"
		})

		# 拼接日志
		var log_msg = atk_tag + attacker.name
		if is_skill:
			log_msg += " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color] 攻击 " + target.name
		else:
			log_msg += " 攻击 " + target.name

		if counter_mult > 1.0:
			log_msg += " (触发克制 " + str(int(counter_mult * 100)) + "%)"
		if is_crit:
			log_msg += " [color=red]【暴击】[/color]"
		if is_blocked:
			log_msg += " [color=yellow]【格挡减伤】[/color]"

		log_msg += " 造成 [color=red]" + str(final_damage) + "[/color] 伤害！"
		if is_blocked and counter_dmg > 0:
			log_msg += " " + target.name + " [color=orange]反击[/color]造成 [color=red]" + str(counter_dmg) + "[/color] 伤害！"

		result["logs"].append(log_msg)

	# D. 士气结算
	if is_skill:
		if attacker.skill_type == "keep": # 连续战法保留100士气
			attacker.mp = 100
			result["logs"].append("[color=gold]" + attacker.name + " 战法势如破竹，士气保持满额（100）！[/color]")
		elif attacker.skill_type == "steal": # 吸气战法：偷取自身士气
			attacker.mp = min(100, attacker.mp + 30 * hit_count)
			result["logs"].append("[color=gold]" + attacker.name + " 吸收了敌方 " + str(30 * hit_count) + " 点士气！[/color]")
		else:
			attacker.mp = 0
	else:
		attacker.mp = min(100, attacker.mp + 34) # 普攻统一 +34 士气

	return result
