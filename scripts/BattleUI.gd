extends Control

@onready var diff_select: OptionButton = $VBox/TopControls/DiffSelect
@onready var btn_start: Button = $VBox/TopControls/BtnStart
@onready var btn_skip: Button = $VBox/TopControls/BtnSkip
@onready var player_grid_ui: GridContainer = $VBox/MainLayout/BattleBoard/PlayerGrid
@onready var enemy_grid_ui: GridContainer = $VBox/MainLayout/BattleBoard/EnemyGrid
@onready var log_scroll: ScrollContainer = $VBox/MainLayout/LogPanel/Margin/LogVBox/LogScroll
@onready var log_text: RichTextLabel = $VBox/MainLayout/LogPanel/Margin/LogVBox/LogScroll/LogText
@onready var log_panel: PanelContainer = $VBox/MainLayout/LogPanel
@onready var fx_layer: Control = $FxLayer

# 战斗逻辑对象
class BattleUnit:
	var uuid: String
	var name: String
	var is_player: bool
	var pos: int # 1..9
	var level: int = 1
	var max_hp: int
	var current_hp: int
	var atk: int
	var def: int
	var satk: int
	var sdef: int
	var spd: int
	var evade_rate: float = 0.05 # 闪避率
	var bonus_target: String = "无"
	var bonus_rate: float = 0.0
	var mp: int = 50 # 初始士气固定为 50
	var troop_name: String
	var troop_type: String
	var atk_type: String
	var skill_name: String
	var skill_desc: String
	var anim_type: String
	var texture_path: String = ""
	var ui_card: Control
	
	func is_alive() -> bool:
		return current_hp > 0

var player_units: Dictionary = {} # pos -> BattleUnit
var enemy_units: Dictionary = {}  # pos -> BattleUnit

var player_cards: Dictionary = {} # pos -> Control
var enemy_cards: Dictionary = {}  # pos -> Control

var is_battle_running: bool = false
var battle_round: int = 1
var is_animating: bool = false
var is_fast_simulating: bool = false
var is_reward_given: bool = false # 确保一次战斗结算奖励只发放一次

func _ready() -> void:
	diff_select.clear()
	diff_select.add_item("简单 (Easy)")
	diff_select.add_item("普通 (Normal)")
	diff_select.add_item("困难 (Hard)")
	diff_select.add_item("噩梦 (Nightmare)")
	diff_select.select(1)
	
	diff_select.item_selected.connect(_on_diff_selected)
	btn_start.pressed.connect(_on_start_battle)
	btn_skip.pressed.connect(_on_skip_battle)
	
	# 设置右侧日志面板的纯色不透明背景
	if log_panel:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.15, 0.98) # 深沉实心暗色纯色背景
		sb.border_color = Color(0.5, 0.42, 0.25, 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		log_panel.add_theme_stylebox_override("panel", sb)
	
	init_boards()
	load_preview_formations()

func init_boards() -> void:
	for child in player_grid_ui.get_children():
		child.queue_free()
	for child in enemy_grid_ui.get_children():
		child.queue_free()
		
	player_cards.clear()
	enemy_cards.clear()
	
	for pos in range(1, 10):
		var p_card = create_card_node(pos, true)
		player_grid_ui.add_child(p_card)
		player_cards[pos] = p_card
		
		var e_card = create_card_node(pos, false)
		enemy_grid_ui.add_child(e_card)
		enemy_cards[pos] = e_card

func create_card_node(pos: int, is_player: bool) -> Control:
	var card = Control.new()
	card.custom_minimum_size = Vector2(135, 185)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.pivot_offset = Vector2(67, 92)
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	card.add_child(margin)
	
	var panel = Panel.new()
	panel.name = "BgPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	
	# 顶部只保留武将名字
	var name_lbl = Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)
	
	var avatar_rect = TextureRect.new()
	avatar_rect.name = "AvatarRect"
	avatar_rect.visible = false
	vbox.add_child(avatar_rect)
	
	# 小兵错位叠加阵型容器 (SquadGrid 改为绝对定位 Control)
	var squad_grid = Control.new()
	squad_grid.name = "SquadGrid"
	squad_grid.custom_minimum_size = Vector2(120, 100)
	squad_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	squad_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 动态容纳最多 16 个小兵节点 (兼容 3x3 与 4x4)
	for idx in range(16):
		var icon = TextureRect.new()
		icon.name = "Sol_" + str(idx)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		squad_grid.add_child(icon)
			
	vbox.add_child(squad_grid)
	
	# 底部：血条与数值
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(0, 8)
	hp_bar.show_percentage = false
	var hp_sb = StyleBoxFlat.new()
	hp_sb.bg_color = Color(0.85, 0.2, 0.2, 1.0)
	hp_bar.add_theme_stylebox_override("fill", hp_sb)
	vbox.add_child(hp_bar)
	
	var hp_lbl = Label.new()
	hp_lbl.name = "HpLbl"
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hp_lbl)
	
	# 底部：士气条与数值
	var mp_bar = ProgressBar.new()
	mp_bar.name = "MpBar"
	mp_bar.custom_minimum_size = Vector2(0, 6)
	mp_bar.max_value = 100
	mp_bar.show_percentage = false
	var mp_sb = StyleBoxFlat.new()
	mp_sb.bg_color = Color(0.2, 0.5, 0.9, 1.0)
	mp_bar.add_theme_stylebox_override("fill", mp_sb)
	vbox.add_child(mp_bar)
	
	var mp_lbl = Label.new()
	mp_lbl.name = "MpLbl"
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(mp_lbl)
	
	card.visible = true
	return card

func load_preview_formations() -> void:
	player_units.clear()
	enemy_units.clear()
	
	var p_form = GameData.player_formation
	for pos in range(1, 10):
		if p_form.has(pos) and p_form[pos] != null:
			var hero_uuid = p_form[pos]
			var hero = GameData.get_hero_by_uuid(hero_uuid)
			if not hero.is_empty():
				var combined = GameData.calc_combined_stats(hero)
				var u = BattleUnit.new()
				u.uuid = hero.get("uuid", str(pos))
				u.name = hero.get("name", "英雄")
				u.is_player = true
				u.pos = pos
				u.level = hero.get("level", 1)
				u.max_hp = combined["hp"]
				u.current_hp = u.max_hp
				u.atk = combined["atk"]
				u.def = combined["def"]
				u.satk = combined["satk"]
				u.sdef = combined["sdef"]
				u.spd = combined["spd"]
				u.evade_rate = combined["evade_rate"]
				u.bonus_target = combined["bonus_target"]
				u.bonus_rate = combined["bonus_rate"]
				u.mp = 50
				u.troop_name = combined["troop_name"]
				u.troop_type = combined["troop_type"]
				u.atk_type = combined["atk_type"]
				u.skill_name = combined["skill_name"]
				u.skill_desc = combined["skill_desc"]
				u.anim_type = combined["anim_type"]
				u.texture_path = combined["texture_path"]
				u.ui_card = player_cards[pos]
				player_units[pos] = u
			
	var diff_idx = diff_select.selected
	var diff_str = "Normal"
	match diff_idx:
		0: diff_str = "Easy"
		1: diff_str = "Normal"
		2: diff_str = "Hard"
		3: diff_str = "Nightmare"
		
	var e_form = GameData.get_enemy_formation(diff_str)
	for pos in range(1, 10):
		if e_form.has(pos) and e_form[pos] != null:
			var hero = e_form[pos]
			var combined = GameData.calc_combined_stats(hero)
			var u = BattleUnit.new()
			u.uuid = hero.get("uuid", "enemy_" + str(pos))
			u.name = hero.get("name", "敌将")
			u.is_player = false
			u.pos = pos
			u.level = hero.get("level", 1)
			u.max_hp = combined["hp"]
			u.current_hp = u.max_hp
			u.atk = combined["atk"]
			u.def = combined["def"]
			u.satk = combined["satk"]
			u.sdef = combined["sdef"]
			u.spd = combined["spd"]
			u.evade_rate = combined["evade_rate"]
			u.bonus_target = combined["bonus_target"]
			u.bonus_rate = combined["bonus_rate"]
			u.mp = 50
			u.troop_name = combined["troop_name"]
			u.troop_type = combined["troop_type"]
			u.atk_type = combined["atk_type"]
			u.skill_name = combined["skill_name"]
			u.skill_desc = combined["skill_desc"]
			u.anim_type = combined["anim_type"]
			u.texture_path = combined["texture_path"]
			u.ui_card = enemy_cards[pos]
			enemy_units[pos] = u
			
	render_all_cards()

func render_all_cards() -> void:
	for pos in range(1, 10):
		update_card_ui(player_cards[pos], player_units.get(pos))
		update_card_ui(enemy_cards[pos], enemy_units.get(pos))

func update_card_ui(card_node: Control, unit: BattleUnit) -> void:
	card_node.visible = true
	var vbox = card_node.get_node("MarginContainer/VBox")
	var name_lbl = vbox.get_node("NameLbl") as Label
	var avatar_rect = vbox.get_node("AvatarRect") as TextureRect
	var squad_grid = vbox.get_node("SquadGrid") as Control
	var hp_bar = vbox.get_node("HpBar") as ProgressBar
	var hp_lbl = vbox.get_node("HpLbl") as Label
	var mp_bar = vbox.get_node("MpBar") as ProgressBar
	var mp_lbl = vbox.get_node("MpLbl") as Label
	var bg_panel = card_node.get_node("MarginContainer/BgPanel") as Panel
	
	# 空槽位处理
	if unit == null:
		name_lbl.text = ""
		avatar_rect.texture = null
		squad_grid.visible = false
		hp_bar.visible = false
		hp_lbl.visible = false
		mp_bar.visible = false
		mp_lbl.visible = false
		card_node.modulate = Color(1, 1, 1, 0.2)
		var empty_sb = StyleBoxFlat.new()
		empty_sb.bg_color = Color(0.1, 0.1, 0.1, 0.0) # 无底色透明
		empty_sb.border_color = Color(0.3, 0.3, 0.3, 0.2)
		empty_sb.set_border_width_all(1)
		empty_sb.set_corner_radius_all(4)
		bg_panel.add_theme_stylebox_override("panel", empty_sb)
		return
		
	squad_grid.visible = true
	hp_bar.visible = true
	hp_lbl.visible = true
	mp_bar.visible = true
	mp_lbl.visible = true
	
	# 生存与阵亡处理
	if not unit.is_alive():
		card_node.modulate = Color(0.4, 0.4, 0.4, 0.7) # 阵亡置灰
		name_lbl.text = "[阵亡] " + unit.name
		name_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		card_node.modulate = Color(1, 1, 1, 1.0) # 存活正常显色
		name_lbl.text = unit.name
		name_lbl.remove_theme_color_override("font_color")
		
	hp_bar.max_value = unit.max_hp
	hp_bar.value = max(0, unit.current_hp)
	hp_lbl.text = str(max(0, unit.current_hp)) + " / " + str(unit.max_hp)
	
	mp_bar.max_value = 100
	mp_bar.value = unit.mp
	mp_lbl.text = "士气: " + str(unit.mp) + " / 100"
	
	# 根据兵种大类读取配置表 (GameData.TROOP_CATEGORY_CONFIGS)
	var cat_cfg = GameData.get_troop_category_config(unit.troop_type)
	var total_count = cat_cfg.get("total_count", 16)
	var removal_order = cat_cfg.get("removal_order", [0, 3, 12, 15, 1, 14, 2, 13, 4, 11, 7, 8, 5, 10, 6, 9])
	var sol_size = cat_cfg.get("sol_size", Vector2(36, 36))
	var grid_type = cat_cfg.get("grid_type", "4x4")
	
	# 计算存活小兵数量
	var hp_ratio = float(max(0, unit.current_hp)) / float(max(1, unit.max_hp))
	var alive_soldiers = 0
	if unit.is_alive():
		alive_soldiers = int(ceil(hp_ratio * float(total_count)))
		alive_soldiers = clamp(alive_soldiers, 1, total_count)
		
	# 计算需要隐藏的小兵索引
	var hidden_indices = {}
	var removed_count = total_count - alive_soldiers
	for k in range(min(removed_count, removal_order.size())):
		hidden_indices[removal_order[k]] = true
		
	var idle_tex: Texture2D = null
	if unit.texture_path != "" and ResourceLoader.exists(unit.texture_path):
		idle_tex = load(unit.texture_path)
	elif unit.troop_type == "弓兵" and ResourceLoader.exists("res://assets/textures/baimayicong_idle.png"):
		idle_tex = load("res://assets/textures/baimayicong_idle.png")
	elif ResourceLoader.exists("res://assets/textures/hobaoqi_idle.png"):
		idle_tex = load("res://assets/textures/hobaoqi_idle.png")
	else:
		idle_tex = load("res://assets/textures/hobaoqi_idle.png")
		
	# 动态部署 3x3 或 4x4 的小兵坐标与属性
	for i in range(16):
		var sol_icon = squad_grid.get_node_or_null("Sol_" + str(i)) as TextureRect
		if sol_icon == null:
			continue
			
		if i < total_count and not hidden_indices.has(i) and unit.is_alive():
			sol_icon.texture = idle_tex
			sol_icon.custom_minimum_size = sol_size
			sol_icon.size = sol_size
			sol_icon.pivot_offset = sol_size / 2.0
			
			# 布局坐标计算：3x3 专有更饱满大坐标，4x4 标准网格坐标
			var pos_x = 0.0
			var pos_y = 0.0
			if grid_type == "3x3":
				var custom_pos_list = cat_cfg.get("custom_positions", [])
				if i < custom_pos_list.size():
					pos_x = custom_pos_list[i].x
					pos_y = custom_pos_list[i].y
				if not unit.is_player:
					sol_icon.flip_h = true
					# 镜像水平转换
					pos_x = 80.0 - pos_x
				else:
					sol_icon.flip_h = false
			else:
				var row = i / 4
				var col = i % 4
				if not unit.is_player:
					sol_icon.flip_h = true
					pos_x = (3 - col) * 20 + row * 6
					pos_y = row * 18
				else:
					sol_icon.flip_h = false
					pos_x = col * 20 + (3 - row) * 6
					pos_y = row * 18
					
			sol_icon.position = Vector2(pos_x, pos_y)
			sol_icon.visible = true
		else:
			sol_icon.visible = false
				
	# 取消红绿卡牌背景框（采用完全透明底色，去除实心矩形和高亮边框）
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(0)
	bg_panel.add_theme_stylebox_override("panel", sb)
	
	if unit.texture_path != "" and ResourceLoader.exists(unit.texture_path):
		avatar_rect.texture = load(unit.texture_path)
	else:
		avatar_rect.texture = null

func _on_diff_selected(_idx: int) -> void:
	if not is_battle_running:
		load_preview_formations()

func _on_start_battle() -> void:
	if is_battle_running:
		return
		
	# 如果上一局已经结束，先重新加载阵型和充填数值
	load_preview_formations()
	if player_units.size() == 0:
		log_text.text = "[color=red]报错：玩家未上阵任何武将！请先前往【阵型】布阵。[/color]"
		return
		
	is_battle_running = true
	is_fast_simulating = false
	is_reward_given = false
	battle_round = 1
	GameData.is_in_battle = true
	btn_start.disabled = true
	btn_skip.disabled = false
	log_text.text = "[color=yellow]=== 战斗开始 ===[/color]
"
	
	start_auto_battle_loop()

func start_auto_battle_loop() -> void:
	while is_battle_running:
		append_log("
[color=cyan]--- 第 " + str(battle_round) + " 回合 ---[/color]")
		var action_queue = build_action_queue()
		
		for attacker in action_queue:
			if not is_battle_running or is_fast_simulating:
				break
			if not (attacker as BattleUnit).is_alive():
				continue
				
			var defender_dict = enemy_units if attacker.is_player else player_units
			var target = find_target(attacker, defender_dict)
			if target == null and attacker.troop_type not in ["鼓手", "医师"]:
				continue
				
			await play_attack_sequence(attacker, target)
			
			if check_battle_over():
				break
				
		if is_fast_simulating:
			break
			
		battle_round += 1
		await get_tree().create_timer(0.4).timeout

func build_action_queue() -> Array:
	var list = []
	for u in player_units.values():
		if (u as BattleUnit).is_alive():
			list.append(u)
	for u in enemy_units.values():
		if (u as BattleUnit).is_alive():
			list.append(u)
			
	list.sort_custom(func(a: BattleUnit, b: BattleUnit):
		if a.spd != b.spd:
			return a.spd > b.spd
		return a.is_player and not b.is_player
	)
	return list

func _on_skip_battle() -> void:
	if not is_battle_running:
		load_preview_formations()
		if player_units.size() == 0:
			log_text.text = "[color=red]报错：玩家未上阵任何武将！请先前往【阵型】布阵。[/color]"
			return
		is_battle_running = true
		is_reward_given = false
		battle_round = 1
		GameData.is_in_battle = true
		log_text.text = "[color=yellow]=== 战斗开始 (已跳过演播) ===[/color]"
			
	is_fast_simulating = true
	append_log("
[color=magenta]>>> 触发【跳过战斗】，正在瞬间演算剩余回合战报... <<<[/color]")
	
	while is_battle_running:
		append_log("
[color=cyan]--- 第 " + str(battle_round) + " 回合 ---[/color]")
		var action_queue = build_action_queue()
				
		for attacker in action_queue:
			if not is_battle_running:
				break
			if not (attacker as BattleUnit).is_alive():
				continue
				
			var defender_dict = enemy_units if attacker.is_player else player_units
			var target = find_target(attacker, defender_dict)
			if target == null and attacker.troop_type not in ["鼓手", "医师"]:
				continue
				
			execute_attack_logic(attacker, target)
			
			if check_battle_over():
				break
				
		battle_round += 1
		
	render_all_cards()

func find_target(attacker: BattleUnit, defender_dict: Dictionary) -> BattleUnit:
	var atk_pos = attacker.pos
	var row_search_order = []
	if atk_pos in [1, 2, 3]:
		row_search_order = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
	elif atk_pos in [4, 5, 6]:
		row_search_order = [[4, 5, 6], [1, 2, 3], [7, 8, 9]]
	else:
		row_search_order = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]
		
	for row in row_search_order:
		var pos_in_row = []
		if attacker.is_player:
			pos_in_row = [row[0], row[1], row[2]]
		else:
			pos_in_row = [row[2], row[1], row[0]]
			
		for p in pos_in_row:
			if defender_dict.has(p):
				var unit = defender_dict[p] as BattleUnit
				if unit.is_alive():
					return unit
	return null

# 寻找友方当前生命值百分比最低（或最需要加血）的活着单位
func find_lowest_hp_ally(attacker: BattleUnit) -> BattleUnit:
	var side_dict = player_units if attacker.is_player else enemy_units
	var lowest_unit: BattleUnit = null
	var lowest_ratio: float = 999.0
	
	for p in side_dict.keys():
		var ally = side_dict[p] as BattleUnit
		if ally.is_alive():
			var ratio = float(ally.current_hp) / float(ally.max_hp)
			if ratio < lowest_ratio:
				lowest_ratio = ratio
				lowest_unit = ally
	return lowest_unit

func execute_attack_logic(attacker: BattleUnit, target: BattleUnit) -> void:
	var is_skill = (attacker.mp >= 100)
	var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"
	
	# 1. 鼓手普通攻击与战法大招逻辑
	if attacker.troop_type == "鼓手":
		if is_skill:
			attacker.mp = 0
			var side_dict = player_units if attacker.is_player else enemy_units
			append_log(atk_tag + attacker.name + " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color]！全军（含自己）恢复 60 士气！")
			for p in side_dict.keys():
				var ally = side_dict[p] as BattleUnit
				if ally.is_alive():
					ally.mp = min(100, ally.mp + 60)
		else:
			attacker.mp = min(100, attacker.mp + 10) # 鼓手自己普攻加10士气
			var side_dict = player_units if attacker.is_player else enemy_units
			var candidates = []
			for p in side_dict.keys():
				var ally = side_dict[p] as BattleUnit
				if ally.is_alive() and ally.uuid != attacker.uuid:
					candidates.append(ally)
			if candidates.size() > 0:
				var chosen = candidates[randi() % candidates.size()]
				chosen.mp = min(100, chosen.mp + 35)
				append_log(atk_tag + attacker.name + " 擂鼓助威，为队友 [color=yellow]" + chosen.name + "[/color] 增加了 35 点士气！")
		return

	# 2. 医师专属治疗与大招逻辑 (无攻击、无克制)
	if attacker.troop_type == "医师":
		var side_dict = player_units if attacker.is_player else enemy_units
		if is_skill:
			attacker.mp = 0
			# 大招悬壶济世：基础 500 固定治疗 + 1.2 * satk 战法加成
			var heal_amount = int(500 + attacker.satk * 1.2)
			append_log(atk_tag + attacker.name + " 释放战法 [color=green]【" + attacker.skill_name + "】[/color]！悬壶济世为己方全体恢复 [color=green]+" + str(heal_amount) + "[/color] 兵力！")
			for p in side_dict.keys():
				var ally = side_dict[p] as BattleUnit
				if ally.is_alive():
					ally.current_hp = min(ally.max_hp, ally.current_hp + heal_amount)
		else:
			attacker.mp = min(100, attacker.mp + 10) # 普攻治疗加 10 士气
			var lowest_ally = find_lowest_hp_ally(attacker)
			if lowest_ally != null:
				# 普攻治疗公式：100 基础治疗 + 0.7 * atk + 0.8 * satk
				var heal_amount = int(100 + attacker.atk * 0.7 + attacker.satk * 0.8)
				lowest_ally.current_hp = min(lowest_ally.max_hp, lowest_ally.current_hp + heal_amount)
				append_log(atk_tag + attacker.name + " 妙手施诊，为伤势最重的 [color=green]" + lowest_ally.name + "[/color] 恢复了 [color=green]+" + str(heal_amount) + "[/color] 兵力！")
		return

	# 3. 战法攻击
	if is_skill:
		attacker.mp = 0
		var base_dmg = (attacker.satk * 2.3) - (target.sdef * 0.75)
		var damage = max(15, int(base_dmg * (0.9 + randf() * 0.2)))
		
		# 兵种克制伤害加成
		if attacker.bonus_target != "无" and attacker.bonus_target == target.troop_type:
			damage = int(damage * (1.0 + attacker.bonus_rate))
			append_log(atk_tag + attacker.name + " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color]！触发兵种克制(" + target.troop_type + ")，造成 [color=red]" + str(damage) + "[/color] 强力伤害！")
		else:
			append_log(atk_tag + attacker.name + " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color] 攻击 " + target.name + "，造成 [color=red]" + str(damage) + "[/color] 战法伤害！")
			
		target.mp = min(100, target.mp + 25) # 受击加 25 士气
		target.current_hp = max(0, target.current_hp - damage)
		if not target.is_alive():
			append_log("[color=gray]" + target.name + " 阵亡！[/color]")
		return

	# 4. 普通攻击：判断闪避
	if randf() < target.evade_rate:
		append_log(atk_tag + attacker.name + " 攻击 " + target.name + "，但被敌方 [color=cyan]【" + target.troop_name + "】[/color] 成功 [color=cyan]闪避 (MISS)[/color]！")
		attacker.mp = min(100, attacker.mp + 10) # 普攻未命中也增加 10 士气
		return

	# 5. 普通攻击命中结算
	attacker.mp = min(100, attacker.mp + 10) # 普攻加 10 士气
	var base_dmg = (attacker.atk * 1.5) - (target.def * 0.8)
	var damage = max(10, int(base_dmg * (0.9 + randf() * 0.2)))
	
	# 兵种克制伤害加成
	if attacker.bonus_target != "无" and attacker.bonus_target == target.troop_type:
		damage = int(damage * (1.0 + attacker.bonus_rate))
		append_log(atk_tag + attacker.name + " 普攻触发兵种克制(对" + target.troop_type + "+" + str(int(attacker.bonus_rate*100)) + "%)，对 " + target.name + " 造成 [color=red]" + str(damage) + "[/color] 伤害！")
	else:
		append_log(atk_tag + attacker.name + " [普攻] 攻击 " + target.name + "，造成 [color=red]" + str(damage) + "[/color] 伤害！")
		
	target.mp = min(100, target.mp + 25) # 受击加 25 士气
	target.current_hp = max(0, target.current_hp - damage)
	if not target.is_alive():
		append_log("[color=gray]" + target.name + " 阵亡！[/color]")

func play_attack_sequence(attacker: BattleUnit, target: BattleUnit) -> void:
	var is_skill = (attacker.mp >= 100)
	var atk_card = attacker.ui_card
	var tgt_card = target.ui_card if target != null else null
	var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"
	var orig_global_pos = atk_card.global_position
	var tgt_global_pos = tgt_card.global_position if tgt_card != null else Vector2.ZERO
	
	# ----------------------------------------------------
	# 1. 鼓手专属攻击与战法动画逻辑 (不攻击敌方)
	# ----------------------------------------------------
	if attacker.troop_type == "鼓手":
		var tw_drum = create_tween().set_parallel(true)
		tw_drum.tween_property(atk_card, "scale", Vector2(1.15, 1.15), 0.2)
		tw_drum.tween_property(atk_card, "modulate", Color(1.5, 1.3, 0.4), 0.2)
		
		if is_skill:
			attacker.mp = 0
			var side_dict = player_units if attacker.is_player else enemy_units
			append_log(atk_tag + attacker.name + " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color]！全军（含自己）恢复 60 士气！")
			spawn_floating_text(atk_card.global_position + Vector2(20, -15), "【" + attacker.skill_name + "】", Color(1.0, 0.8, 0.1))
			await tw_drum.finished
			
			var reset_tw = create_tween().set_parallel(true)
			reset_tw.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.15)
			reset_tw.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15)
			
			for p in side_dict.keys():
				var ally = side_dict[p] as BattleUnit
				if ally.is_alive():
					ally.mp = min(100, ally.mp + 60)
					spawn_floating_text(ally.ui_card.global_position + Vector2(20, 10), "+60 士气", Color(1.0, 0.9, 0.2))
					
			render_all_cards()
			await get_tree().create_timer(0.3).timeout
			return
		else:
			attacker.mp = min(100, attacker.mp + 10)
			var side_dict = player_units if attacker.is_player else enemy_units
			var candidates = []
			for p in side_dict.keys():
				var ally = side_dict[p] as BattleUnit
				if ally.is_alive() and ally.uuid != attacker.uuid:
					candidates.append(ally)
			
			if candidates.size() > 0:
				var chosen = candidates[randi() % candidates.size()]
				chosen.mp = min(100, chosen.mp + 35)
				append_log(atk_tag + attacker.name + " 擂鼓助威，为队友 [color=yellow]" + chosen.name + "[/color] 增加了 35 点士气！")
				spawn_floating_text(atk_card.global_position + Vector2(20, -15), "擂鼓助威", Color(0.9, 0.8, 0.2))
				spawn_floating_text(chosen.ui_card.global_position + Vector2(20, 10), "+35 士气", Color(1.0, 0.9, 0.2))
			else:
				spawn_floating_text(atk_card.global_position + Vector2(20, -15), "擂鼓助威", Color(0.9, 0.8, 0.2))
				
			await tw_drum.finished
			var reset_tw = create_tween().set_parallel(true)
			reset_tw.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.15)
			reset_tw.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15)
			
			render_all_cards()
			await get_tree().create_timer(0.25).timeout
			return

	# ----------------------------------------------------
	# 2. 医师专属治疗与战法动画逻辑 (绿色数字飘字)
	# ----------------------------------------------------
	if attacker.troop_type == "医师":
		var tw_doc = create_tween().set_parallel(true)
		tw_doc.tween_property(atk_card, "scale", Vector2(1.15, 1.15), 0.2)
		tw_doc.tween_property(atk_card, "modulate", Color(0.4, 1.8, 0.6), 0.2)
		
		var side_dict = player_units if attacker.is_player else enemy_units
		if is_skill:
			attacker.mp = 0
			var heal_amount = int(500 + attacker.satk * 1.2)
			append_log(atk_tag + attacker.name + " 释放战法 [color=green]【" + attacker.skill_name + "】[/color]！悬壶济世为己方全体恢复 [color=green]+" + str(heal_amount) + "[/color] 兵力！")
			spawn_floating_text(atk_card.global_position + Vector2(15, -20), "【" + attacker.skill_name + "】", Color(0.2, 1.0, 0.4))
			await tw_doc.finished
			
			var reset_tw = create_tween().set_parallel(true)
			reset_tw.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.15)
			reset_tw.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15)
			
			for p in side_dict.keys():
				var ally = side_dict[p] as BattleUnit
				if ally.is_alive():
					ally.current_hp = min(ally.max_hp, ally.current_hp + heal_amount)
					# 绿色治疗数字飘字
					spawn_floating_text(ally.ui_card.global_position + Vector2(20, -10), "+" + str(heal_amount), Color(0.2, 1.0, 0.4))
					
			render_all_cards()
			await get_tree().create_timer(0.35).timeout
			return
		else:
			attacker.mp = min(100, attacker.mp + 10)
			var lowest_ally = find_lowest_hp_ally(attacker)
			if lowest_ally != null:
				var heal_amount = int(100 + attacker.atk * 0.7 + attacker.satk * 0.8)
				lowest_ally.current_hp = min(lowest_ally.max_hp, lowest_ally.current_hp + heal_amount)
				append_log(atk_tag + attacker.name + " 妙手施诊，为伤势最重的 [color=green]" + lowest_ally.name + "[/color] 恢复了 [color=green]+" + str(heal_amount) + "[/color] 兵力！")
				spawn_floating_text(atk_card.global_position + Vector2(15, -20), "妙手回春", Color(0.3, 0.9, 0.4))
				# 绿色治疗数字飘字
				spawn_floating_text(lowest_ally.ui_card.global_position + Vector2(20, -10), "+" + str(heal_amount), Color(0.2, 1.0, 0.4))
			else:
				spawn_floating_text(atk_card.global_position + Vector2(15, -20), "妙手回春", Color(0.3, 0.9, 0.4))
				
			await tw_doc.finished
			var reset_tw = create_tween().set_parallel(true)
			reset_tw.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.15)
			reset_tw.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15)
			
			render_all_cards()
			await get_tree().create_timer(0.3).timeout
			return

	# ----------------------------------------------------
	# 3. 攻击者前跃动作起手 (根据兵种与战法区分)
	# ----------------------------------------------------
	var tw_atk = create_tween()
	if is_skill:
		# 战法大招：原地点亮并放大动一下释放
		spawn_floating_text(atk_card.global_position + Vector2(10, -20), "【" + attacker.skill_name + "】", Color(1.0, 0.5, 0.1))
		tw_atk.set_parallel(true)
		tw_atk.tween_property(atk_card, "scale", Vector2(1.15, 1.15), 0.15)
		tw_atk.tween_property(atk_card, "modulate", Color(2.0, 1.5, 0.8), 0.15)
		await tw_atk.finished
		
		var reset_atk = create_tween().set_parallel(true)
		reset_atk.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.1)
		reset_atk.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.1)
	else:
		# 普通攻击：骑兵/步兵冲到敌人身前；弓兵/策士原地点一下
		if attacker.troop_type in ["骑兵", "步兵"]:
			# 冲到敌人身前 80px 处
			var offset_x = -80.0 if attacker.is_player else 80.0
			var attack_target_pos = tgt_global_pos + Vector2(offset_x, 0)
			tw_atk.tween_property(atk_card, "global_position", attack_target_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			# 弓兵、策士只在原地点一下（向前微动 20px）
			var forward_dir = Vector2(25, 0) if attacker.is_player else Vector2(-25, 0)
			tw_atk.tween_property(atk_card, "global_position", orig_global_pos + forward_dir, 0.1).set_trans(Tween.TRANS_QUAD)
		await tw_atk.finished

	# ----------------------------------------------------
	# 4. 判定闪避 (MISS) —— 闪避向后退并浮出大 MISS 飘字
	# ----------------------------------------------------
	if not is_skill and randf() < target.evade_rate:
		attacker.mp = min(100, attacker.mp + 10)
		append_log(atk_tag + attacker.name + " 攻击 " + target.name + "，被 [color=cyan]【" + target.troop_name + "】[/color] 成功 [color=cyan]闪避 (MISS)[/color]！")
		
		# 闪避受击方动作：向后退一下
		var evade_dir = Vector2(-30, 0) if target.is_player else Vector2(30, 0)
		var tw_evade = create_tween().set_parallel(true)
		tw_evade.tween_property(tgt_card, "global_position", tgt_global_pos + evade_dir, 0.1).set_trans(Tween.TRANS_QUAD)
		spawn_big_miss_text(tgt_card.global_position + Vector2(20, -20))
		await tw_evade.finished
		
		# 恢复原位
		var tw_back = create_tween().set_parallel(true)
		tw_back.tween_property(atk_card, "global_position", orig_global_pos, 0.18)
		tw_back.tween_property(tgt_card, "global_position", tgt_global_pos, 0.15)
		await tw_back.finished
		
		render_all_cards()
		await get_tree().create_timer(0.2).timeout
		return

	# ----------------------------------------------------
	# 5. 命中伤害结算与受击上下震动动画
	# ----------------------------------------------------
	var damage = 0
	if is_skill:
		var base_dmg = (attacker.satk * 2.3) - (target.sdef * 0.75)
		damage = max(15, int(base_dmg * (0.9 + randf() * 0.2)))
		attacker.mp = 0
		if attacker.bonus_target != "无" and attacker.bonus_target == target.troop_type:
			damage = int(damage * (1.0 + attacker.bonus_rate))
			append_log(atk_tag + attacker.name + " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color]！触发克制(" + target.troop_type + ")，造成 [color=red]" + str(damage) + "[/color] 伤害！")
		else:
			append_log(atk_tag + attacker.name + " 释放战法 [color=orange]【" + attacker.skill_name + "】[/color] 攻击 " + target.name + "，造成 [color=red]" + str(damage) + "[/color] 战法伤害！")
	else:
		attacker.mp = min(100, attacker.mp + 10)
		var base_dmg = (attacker.atk * 1.5) - (target.def * 0.8)
		damage = max(10, int(base_dmg * (0.9 + randf() * 0.2)))
		if attacker.bonus_target != "无" and attacker.bonus_target == target.troop_type:
			damage = int(damage * (1.0 + attacker.bonus_rate))
			append_log(atk_tag + attacker.name + " 普攻触发克制(对" + target.troop_type + "+" + str(int(attacker.bonus_rate*100)) + "%)，对 " + target.name + " 造成 [color=red]" + str(damage) + "[/color] 伤害！")
		else:
			append_log(atk_tag + attacker.name + " [普攻] 攻击 " + target.name + "，造成 [color=red]" + str(damage) + "[/color] 伤害！")
			
	target.mp = min(100, target.mp + 25) # 受击加 25 士气
	target.current_hp = max(0, target.current_hp - damage)
	if not target.is_alive():
		append_log("[color=gray]" + target.name + " 阵亡！[/color]")
		
	# 受击方 Card 抖动效果 (Y 轴小幅度晃动)
	var tw_hit = create_tween()
	tw_hit.tween_property(tgt_card, "global_position", tgt_global_pos + Vector2(0, -15), 0.05)
	tw_hit.tween_property(tgt_card, "global_position", tgt_global_pos + Vector2(0, 15), 0.05)
	tw_hit.tween_property(tgt_card, "global_position", tgt_global_pos, 0.05)
	
	# 红色扣血数字飘字
	spawn_floating_text(tgt_card.global_position + Vector2(25, -10), "-" + str(damage), Color(1.0, 0.25, 0.2))
	
	await tw_hit.finished
	
	# 攻击者返回原位
	var tw_return = create_tween()
	tw_return.tween_property(atk_card, "global_position", orig_global_pos, 0.18).set_trans(Tween.TRANS_QUAD)
	await tw_return.finished
	
	if not target.is_alive():
		spawn_floating_text(tgt_card.global_position + Vector2(10, -10), "阵亡", Color(0.6, 0.1, 0.1))
		
	render_all_cards()
	await get_tree().create_timer(0.2).timeout

func spawn_big_miss_text(global_pos: Vector2) -> void:
	if not is_inside_tree():
		return
	var lbl = Label.new()
	lbl.text = "MISS!"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	lbl.global_position = global_pos
	lbl.scale = Vector2(0.5, 0.5)
	lbl.pivot_offset = Vector2(30, 15)
	fx_layer.add_child(lbl)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position", global_pos + Vector2(0, -40), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.2)
	tw.chain().tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

func spawn_floating_text(global_pos: Vector2, text: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color)
	lbl.global_position = global_pos
	fx_layer.add_child(lbl)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position", global_pos + Vector2(0, -35), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

func check_battle_over() -> bool:
	var p_alive = 0
	for u in player_units.values():
		if (u as BattleUnit).is_alive():
			p_alive += 1
			
	var e_alive = 0
	for u in enemy_units.values():
		if (u as BattleUnit).is_alive():
			e_alive += 1
			
	if p_alive == 0 or e_alive == 0:
		if is_reward_given:
			return true
		is_reward_given = true
		
		is_battle_running = false
		GameData.is_in_battle = false
		btn_start.disabled = false
		btn_skip.disabled = true
		
		if p_alive > 0:
			append_log("
[color=gold]🎉 战斗大捷！全歼敌军！[/color]")
			append_log("[color=green]获得战利品：金币 +100，共享经验 +100[/color]")
			GameData.player_gold += 100
			GameData.player_exp_pool += 100
			GameData.emit_signal("gold_changed")
			GameData.emit_signal("exp_changed")
			GameData.has_unsaved_changes = true
		else:
			append_log("
[color=red]☠️ 遗憾败北！全军覆没！[/color]")
		is_fast_simulating = false
		return true
	return false

func append_log(msg: String) -> void:
	log_text.text += msg + "
"
	_scroll_log_to_bottom()

func _scroll_log_to_bottom() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_inside_tree() or get_tree() == null:
		return
	log_scroll.scroll_vertical = 99999
