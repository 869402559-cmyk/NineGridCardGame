extends Control

@onready var diff_select: OptionButton = $VBox/TopControls/DiffSelect
@onready var btn_start: Button = $VBox/TopControls/BtnStart
@onready var btn_skip: Button = $VBox/TopControls/BtnSkip
@onready var player_grid_ui: GridContainer = $VBox/MainLayout/BattleBoard/PlayerGrid
@onready var enemy_grid_ui: GridContainer = $VBox/MainLayout/BattleBoard/EnemyGrid
@onready var log_text: RichTextLabel = $VBox/MainLayout/LogPanel/LogScroll/LogText
@onready var log_scroll: ScrollContainer = $VBox/MainLayout/LogPanel/LogScroll
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
	var mp: int = 60
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
	card.custom_minimum_size = Vector2(130, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.pivot_offset = Vector2(65, 75)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_child(vbox)
	
	# 位置与名字
	var pos_lbl = Label.new()
	pos_lbl.name = "PosLbl"
	pos_lbl.text = str(pos) + "号位 (空)"
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_lbl.add_theme_font_size_override("font_size", 12)
	pos_lbl.add_theme_color_override("font_color", Color(0.35, 0.3, 0.2))
	vbox.add_child(pos_lbl)
	
	var name_lbl = Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = ""
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	vbox.add_child(name_lbl)
	
	# 小兵军团重叠舞台
	var troop_stage = Control.new()
	troop_stage.name = "TroopStage"
	troop_stage.custom_minimum_size = Vector2(120, 85)
	troop_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(troop_stage)
	
	for i in range(9):
		var sol_rect = TextureRect.new()
		sol_rect.name = "Sol_" + str(i)
		sol_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sol_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sol_rect.custom_minimum_size = Vector2(50, 50)
		sol_rect.size = Vector2(50, 50)
		sol_rect.set_anchors_preset(PRESET_FULL_RECT)
		if not is_player:
			sol_rect.flip_h = true
		troop_stage.add_child(sol_rect)
		
	troop_stage.resized.connect(func():
		update_troop_layout(troop_stage)
	)
	
	# 红色渐变血条
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.show_percentage = false
	hp_bar.value = 100
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color(0.85, 0.15, 0.15)
	hp_style.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	
	var hp_lbl = Label.new()
	hp_lbl.name = "HpLbl"
	hp_lbl.text = ""
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.set_anchors_preset(PRESET_FULL_RECT)
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_lbl.add_theme_constant_override("outline_size", 3)
	hp_bar.add_child(hp_lbl)
	vbox.add_child(hp_bar)
	
	# 士气条
	var mp_bar = ProgressBar.new()
	mp_bar.name = "MpBar"
	mp_bar.custom_minimum_size = Vector2(0, 14)
	mp_bar.show_percentage = false
	mp_bar.max_value = 120
	mp_bar.value = 60
	var mp_style = StyleBoxFlat.new()
	mp_style.bg_color = Color(0.9, 0.7, 0.1)
	mp_style.set_corner_radius_all(2)
	mp_bar.add_theme_stylebox_override("fill", mp_style)
	
	var mp_lbl = Label.new()
	mp_lbl.name = "MpLbl"
	mp_lbl.text = "士气: 60/120"
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp_lbl.set_anchors_preset(PRESET_FULL_RECT)
	mp_lbl.add_theme_font_size_override("font_size", 9)
	mp_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	mp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	mp_lbl.add_theme_constant_override("outline_size", 3)
	mp_bar.add_child(mp_lbl)
	vbox.add_child(mp_bar)
	
	# 阵亡印章 Overlay
	var dead_mask = Label.new()
	dead_mask.name = "DeadStamp"
	dead_mask.text = "【已阵亡】"
	dead_mask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_mask.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dead_mask.add_theme_font_size_override("font_size", 20)
	dead_mask.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 0.95))
	dead_mask.visible = false
	dead_mask.set_anchors_preset(PRESET_FULL_RECT)
	card.add_child(dead_mask)
	
	return card

func update_troop_layout(stage: Control) -> void:
	var sw = stage.size.x
	var sh = stage.size.y
	if sw < 10 or sh < 10:
		return
		
	var sol_size = Vector2(clamp(sw * 0.4, 32, 65), clamp(sh * 0.5, 32, 65))
	var x_step = (sw - sol_size.x) / 2.0 if sw > sol_size.x else 0.0
	var y_step = (sh - sol_size.y) / 2.0 if sh > sol_size.y else 0.0
	
	var grid_positions = [
		Vector2(0, 0),                  Vector2(x_step, 0),                 Vector2(sw - sol_size.x, 0),
		Vector2(x_step * 0.3, y_step),  Vector2(x_step, y_step),            Vector2(sw - sol_size.x - x_step * 0.3, y_step),
		Vector2(0, sh - sol_size.y),    Vector2(x_step, sh - sol_size.y),   Vector2(sw - sol_size.x, sh - sol_size.y)
	]
	
	for i in range(min(9, stage.get_child_count())):
		var sol = stage.get_child(i) as Control
		sol.size = sol_size
		sol.position = grid_positions[i]

func _on_diff_selected(_index: int) -> void:
	if not is_battle_running and not is_animating:
		load_preview_formations()

func load_preview_formations() -> void:
	var diff_str = "Normal"
	match diff_select.selected:
		0: diff_str = "Easy"
		1: diff_str = "Normal"
		2: diff_str = "Hard"
		3: diff_str = "Nightmare"
		
	player_units.clear()
	enemy_units.clear()
	
	for pos in range(1, 10):
		var uuid = GameData.player_formation[pos]
		if uuid != null:
			var h = GameData.get_hero_by_uuid(uuid)
			if not h.is_empty():
				var combined = GameData.calc_combined_stats(h)
				var u = BattleUnit.new()
				u.uuid = h["uuid"]
				u.name = h["name"]
				u.is_player = true
				u.pos = pos
				u.level = h.get("level", 1)
				u.max_hp = combined["hp"]
				u.current_hp = combined["hp"]
				u.atk = combined["atk"]
				u.def = combined["def"]
				u.satk = combined["satk"]
				u.sdef = combined["sdef"]
				u.spd = combined["spd"]
				u.evade_rate = combined["evade_rate"]
				u.mp = 60
				u.troop_name = combined["troop_name"]
				u.troop_type = combined["troop_type"]
				u.atk_type = combined["atk_type"]
				u.skill_name = combined["skill_name"]
				u.skill_desc = combined["skill_desc"]
				u.anim_type = combined["anim_type"]
				u.texture_path = combined["texture_path"]
				u.ui_card = player_cards[pos]
				player_units[pos] = u
				
	var e_form = GameData.get_enemy_formation(diff_str)
	for pos in range(1, 10):
		var h = e_form[pos]
		if h != null:
			var combined = GameData.calc_combined_stats(h)
			var u = BattleUnit.new()
			u.uuid = h["uuid"]
			u.name = h["name"]
			u.is_player = false
			u.pos = pos
			u.level = h.get("level", 1)
			u.max_hp = combined["hp"]
			u.current_hp = combined["hp"]
			u.atk = combined["atk"]
			u.def = combined["def"]
			u.satk = combined["satk"]
			u.sdef = combined["sdef"]
			u.spd = combined["spd"]
			u.evade_rate = combined["evade_rate"]
			u.mp = 60
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

func _on_start_battle() -> void:
	if is_animating or is_battle_running:
		return
		
	load_preview_formations()
	if player_units.size() == 0:
		log_text.text = "[color=red]报错：玩家未上阵任何武将！请先前往【阵型】布阵。[/color]"
		return
		
	is_battle_running = true
	battle_round = 1
	is_fast_simulating = false
	log_text.text = "[color=yellow]=== 战斗正式开始！难度：" + diff_select.get_item_text(diff_select.selected) + " ===[/color]"
	
	start_auto_battle_loop()

func start_auto_battle_loop() -> void:
	while is_battle_running and not is_fast_simulating:
		is_animating = true
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
			if target == null:
				continue
				
			await play_attack_sequence(attacker, target)
			
			if check_battle_over():
				is_animating = false
				return
				
		battle_round += 1
		is_animating = false
		await get_tree().create_timer(0.2).timeout

func build_action_queue() -> Array:
	var all_units: Array = []
	for p in player_units.keys():
		if player_units[p].is_alive():
			all_units.append(player_units[p])
	for p in enemy_units.keys():
		if enemy_units[p].is_alive():
			all_units.append(enemy_units[p])
			
	all_units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.spd != b.spd:
			return a.spd > b.spd
		if a.is_player != b.is_player:
			return a.is_player
		return a.pos < b.pos
	)
	return all_units

func _on_skip_battle() -> void:
	if not is_battle_running:
		load_preview_formations()
		if player_units.size() == 0:
			log_text.text = "[color=red]报错：玩家未上阵任何武将！请先前往【阵型】布阵。[/color]"
			return
		is_battle_running = true
		battle_round = 1
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
			if target == null:
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

func execute_attack_logic(attacker: BattleUnit, target: BattleUnit) -> void:
	var is_skill = (attacker.mp >= 100)
	
	if attacker.troop_type == "鼓手" and is_skill:
		attacker.mp = 0
		var side_dict = player_units if attacker.is_player else enemy_units
		append_log("[color=yellow]" + attacker.name + "[/color] 释放【" + attacker.skill_name + "】！全队提升35点士气！")
		for p in side_dict.keys():
			var ally = side_dict[p] as BattleUnit
			if ally.is_alive():
				ally.mp = min(120, ally.mp + 35)
		return

	# 判断闪避率 (MISS)
	if randf() < target.evade_rate:
		var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"
		append_log(atk_tag + attacker.name + " 攻击 " + target.name + "，但被敌方 [color=cyan]【" + target.troop_name + "】[/color] 成功 [color=cyan]闪避 (MISS)[/color]！")
		return

	var damage = 0
	if is_skill:
		var base_dmg = (attacker.satk * 2.3) - (target.sdef * 0.75)
		damage = max(15, int(base_dmg * (0.9 + randf() * 0.2)))
		attacker.mp = 0
	else:
		var base_dmg = (attacker.atk * 1.5) - (target.def * 0.8)
		damage = max(10, int(base_dmg * (0.9 + randf() * 0.2)))
		attacker.mp = min(120, attacker.mp + 25)
		
	target.mp = min(120, target.mp + 25)
	target.current_hp = max(0, target.current_hp - damage)
	
	var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"
	var skill_tag = " [color=orange]【战法: " + attacker.skill_name + "】[/color]" if is_skill else " [普攻]"
	append_log(atk_tag + attacker.name + skill_tag + " 攻击 " + target.name + "，造成 [color=red]" + str(damage) + "[/color] 伤害！")
	
	if not target.is_alive():
		append_log("[color=gray]" + target.name + " 阵亡！[/color]")

func play_attack_sequence(attacker: BattleUnit, target: BattleUnit) -> void:
	var is_skill = (attacker.mp >= 100)
	var atk_card = attacker.ui_card
	var tgt_card = target.ui_card
	
	if attacker.troop_type == "鼓手" and is_skill:
		attacker.mp = 0
		var side_dict = player_units if attacker.is_player else enemy_units
		append_log("[color=yellow]" + attacker.name + "[/color] 释放【" + attacker.skill_name + "】！全队提升士气！")
		
		var tw = create_tween().set_parallel(true)
		tw.tween_property(atk_card, "scale", Vector2(1.18, 1.18), 0.25)
		tw.tween_property(atk_card, "modulate", Color(1.5, 1.3, 0.4), 0.25)
		spawn_floating_text(atk_card.global_position + Vector2(20, -10), "激昂鼓舞！", Color(1.0, 0.8, 0.1))
		await tw.finished
		
		var reset_tw = create_tween().set_parallel(true)
		reset_tw.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.2)
		reset_tw.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.2)
		
		for p in side_dict.keys():
			var ally = side_dict[p] as BattleUnit
			if ally.is_alive():
				ally.mp = min(120, ally.mp + 35)
				spawn_floating_text(ally.ui_card.global_position + Vector2(20, 10), "+35 士气", Color(1.0, 0.9, 0.2))
				
		render_all_cards()
		await get_tree().create_timer(0.3).timeout
		return

	# 前冲动作
	var forward_dir = Vector2(40, 0) if attacker.is_player else Vector2(-40, 0)
	var orig_global_pos = atk_card.global_position
	var tgt_global_pos = tgt_card.global_position
	
	var tw_atk = create_tween()
	tw_atk.tween_property(atk_card, "global_position", orig_global_pos + forward_dir, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if is_skill:
		spawn_floating_text(atk_card.global_position + Vector2(10, -20), "【" + attacker.skill_name + "】", Color(1.0, 0.5, 0.1))
		tw_atk.tween_property(atk_card, "modulate", Color(2.0, 1.5, 0.8), 0.1)
		
	await tw_atk.finished

	# 判闪避
	if randf() < target.evade_rate:
		var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"
		append_log(atk_tag + attacker.name + " 攻击 " + target.name + "，被 [color=cyan]【" + target.troop_name + "】[/color] 成功 [color=cyan]闪避 (MISS)[/color]！")
		spawn_floating_text(tgt_card.global_position + Vector2(25, 0), "MISS 闪避!", Color(0.2, 0.9, 1.0))
		
		var tw_back = create_tween().set_parallel(true)
		tw_back.tween_property(atk_card, "global_position", orig_global_pos, 0.15)
		tw_back.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15)
		await tw_back.finished
		render_all_cards()
		await get_tree().create_timer(0.2).timeout
		return

	# 攻击命中结算
	var damage = 0
	if is_skill:
		var base_dmg = (attacker.satk * 2.3) - (target.sdef * 0.75)
		damage = max(15, int(base_dmg * (0.9 + randf() * 0.2)))
		attacker.mp = 0
	else:
		var base_dmg = (attacker.atk * 1.5) - (target.def * 0.8)
		damage = max(10, int(base_dmg * (0.9 + randf() * 0.2)))
		attacker.mp = min(120, attacker.mp + 25)
		
	target.mp = min(120, target.mp + 25)
	target.current_hp = max(0, target.current_hp - damage)
	
	var atk_tag = "[color=green][玩家][/color]" if attacker.is_player else "[color=red][电脑][/color]"
	var skill_tag = " [color=orange]【战法: " + attacker.skill_name + "】[/color]" if is_skill else " [普攻]"
	append_log(atk_tag + attacker.name + skill_tag + " 攻击 " + target.name + "，造成 [color=red]" + str(damage) + "[/color] 伤害！")
	
	spawn_floating_text(tgt_card.global_position + Vector2(25, 0), "-" + str(damage), Color(1.0, 0.2, 0.2))
	spawn_floating_text(tgt_card.global_position + Vector2(25, 20), "+25 士气", Color(1.0, 0.8, 0.2))
	
	var tw_hit = create_tween().set_parallel(true)
	tw_hit.tween_property(tgt_card, "global_position", tgt_global_pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
	tw_hit.tween_property(tgt_card, "modulate", Color(2.0, 0.3, 0.3), 0.08)
	
	var tw_back = create_tween().set_parallel(true)
	tw_back.tween_property(atk_card, "global_position", orig_global_pos, 0.15)
	tw_back.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15)
	await tw_back.finished
	
	var tw_reset_tgt = create_tween().set_parallel(true)
	tw_reset_tgt.tween_property(tgt_card, "global_position", tgt_global_pos, 0.1)
	tw_reset_tgt.tween_property(tgt_card, "modulate", Color(1, 1, 1), 0.1)
	
	render_all_cards()
	
	if not target.is_alive():
		append_log("[color=gray]" + target.name + " 阵亡！[/color]")
		spawn_floating_text(tgt_card.global_position + Vector2(10, -10), "阵亡", Color(0.6, 0.1, 0.1))
		play_death_animation(tgt_card)
		
	await get_tree().create_timer(0.25).timeout

func play_death_animation(card: Control) -> void:
	var stamp = card.find_child("DeadStamp", true, false) as Label
	if stamp:
		stamp.visible = true
		stamp.scale = Vector2(2.0, 2.0)
		stamp.modulate.a = 0.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(stamp, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
		tw.tween_property(stamp, "modulate:a", 1.0, 0.2)
		tw.tween_property(card, "modulate", Color(0.4, 0.4, 0.4, 0.7), 0.2)

func spawn_floating_text(global_pos: Vector2, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = global_pos
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	fx_layer.add_child(lbl)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position:y", global_pos.y - 45.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)

func check_battle_over() -> bool:
	var player_alive = false
	for p in player_units.keys():
		if player_units[p].is_alive():
			player_alive = true
			break
			
	var enemy_alive = false
	for p in enemy_units.keys():
		if enemy_units[p].is_alive():
			enemy_alive = true
			break
			
	if not player_alive or not enemy_alive:
		is_battle_running = false
		
		if player_alive:
			append_log("
[color=green]======================[/color]")
			append_log("[color=green]  战斗大捷！玩家获得胜利！  [/color]")
			append_log("[color=green]  战利品：金币 +100，经验池 +100！  [/color]")
			append_log("[color=green]======================[/color]")
			GameData.player_gold += 100
			GameData.player_exp_pool += 100
			GameData.emit_signal("gold_changed")
			GameData.emit_signal("exp_changed")
		else:
			append_log("
[color=red]======================[/color]")
			append_log("[color=red]  惨遭败北！电脑获得胜利！  [/color]")
			append_log("[color=red]======================[/color]")
		return true
	return false

func render_all_cards() -> void:
	for pos in range(1, 10):
		var card = player_cards[pos]
		render_unit_card(card, player_units.get(pos), pos, true)

	for pos in range(1, 10):
		var card = enemy_cards[pos]
		render_unit_card(card, enemy_units.get(pos), pos, false)

func render_unit_card(card: Control, u: BattleUnit, pos: int, is_player: bool) -> void:
	var pos_lbl = card.find_child("PosLbl", true, false) as Label
	var name_lbl = card.find_child("NameLbl", true, false) as Label
	var hp_bar = card.find_child("HpBar", true, false) as ProgressBar
	var hp_lbl = hp_bar.find_child("HpLbl", true, false) as Label
	var mp_bar = card.find_child("MpBar", true, false) as ProgressBar
	var mp_lbl = mp_bar.find_child("MpLbl", true, false) as Label
	var stamp = card.find_child("DeadStamp", true, false) as Label
	var troop_stage = card.find_child("TroopStage", true, false) as Control

	if u != null:
		pos_lbl.text = str(pos) + "号位 [" + u.troop_type + "] Lv." + str(u.level)
		name_lbl.text = u.name
		hp_bar.max_value = u.max_hp
		hp_bar.value = u.current_hp
		
		var hp_percent = int(float(u.current_hp) / float(u.max_hp) * 100.0)
		hp_lbl.text = str(u.current_hp) + "/" + str(u.max_hp) + " (" + str(hp_percent) + "%)"
		
		mp_bar.max_value = 120
		mp_bar.value = u.mp
		mp_lbl.text = "士气: " + str(u.mp) + "/120"
		
		var soldier_count = 9
		if u.current_hp <= 0:
			soldier_count = 1
		elif hp_percent <= 25:
			soldier_count = 3
		elif hp_percent <= 50:
			soldier_count = 5
		elif hp_percent <= 75:
			soldier_count = 7
		else:
			soldier_count = 9

		var tex: Texture2D = null
		if u.texture_path != "" and ResourceLoader.exists(u.texture_path):
			tex = load(u.texture_path)

		for i in range(9):
			var sol_rect = troop_stage.get_child(i) as TextureRect
			sol_rect.texture = tex
			sol_rect.flip_h = not is_player
			
			if i < soldier_count:
				sol_rect.visible = true
			else:
				sol_rect.visible = false
				
		update_troop_layout(troop_stage)
		
		if not u.is_alive():
			stamp.visible = true
			card.modulate = Color(0.4, 0.4, 0.4, 0.7)
		else:
			stamp.visible = false
			card.modulate = Color(1, 1, 1)
	else:
		pos_lbl.text = str(pos) + "号位 (空)"
		pos_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35, 0.5))
		name_lbl.text = ""
		hp_bar.value = 0
		hp_lbl.text = ""
		mp_bar.value = 0
		mp_lbl.text = ""
		stamp.visible = false
		card.modulate = Color(1, 1, 1)
		for i in range(9):
			var sol_rect = troop_stage.get_child(i) as TextureRect
			sol_rect.texture = null
			sol_rect.visible = false

func append_log(msg: String) -> void:
	log_text.text += "
" + msg
	call_deferred("_scroll_log_to_bottom")

func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_text.get_content_height()) + 99999
	var v_bar = log_scroll.get_v_scroll_bar()
	if v_bar:
		v_bar.value = v_bar.max_value
