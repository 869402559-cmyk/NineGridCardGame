extends Control

@onready var diff_select: OptionButton = $VBox/TopControls/DiffSelect
@onready var btn_speed: Button = $VBox/TopControls/BtnSpeed
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
	var evade_rate: float = 0.05
	var crit_rate: float = 0.05
	var block_rate: float = 0.05
	var penetrate_rate: float = 0.05
	var bonus_target: String = "无"
	var bonus_rate: float = 0.0
	var mp: int = 50 # 初始士气 50
	var troop_name: String
	var troop_type: String
	var atk_mode: String = "single"
	var skill_name: String
	var skill_desc: String
	var skill_target_type: String = "single"
	var skill_type: String = "normal"
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
var current_acting_unit: BattleUnit = null

# 战术播放倍速控制 (0 = 正常放慢 2.2x 方便阅读, 1 = 1倍速 1.0x 标准, 2 = 2倍速 0.4x 极速)
var speed_mode: int = 0
var anim_speed_scale: float = 2.2

func _on_speed_toggle() -> void:
	speed_mode = (speed_mode + 1) % 3
	GameData.battle_speed_mode = speed_mode
	GameData.has_unsaved_changes = true
	apply_speed_mode()

func apply_speed_mode() -> void:
	speed_mode = GameData.battle_speed_mode
	match speed_mode:
		0:
			anim_speed_scale = 2.2
			if btn_speed: btn_speed.text = "⏩ 速度: 正常"
		1:
			anim_speed_scale = 1.0
			if btn_speed: btn_speed.text = "⏩ 速度: 1倍速"
		2:
			anim_speed_scale = 0.4
			if btn_speed: btn_speed.text = "⏩ 速度: 2倍速"

func _ready() -> void:
	diff_select.clear()
	diff_select.add_item("简单 (Easy)")
	diff_select.add_item("普通 (Normal)")
	diff_select.add_item("困难 (Hard)")
	diff_select.add_item("噩梦 (Nightmare)")
	diff_select.add_item("测试1: 满员矩阵(测多目标/贯穿/全屏)")
	diff_select.add_item("测试2: 步兵高格挡(测格挡与反击)")
	diff_select.select(1)
	
	diff_select.item_selected.connect(_on_diff_selected)
	if btn_speed:
		btn_speed.pressed.connect(_on_speed_toggle)
	btn_skip.pressed.connect(_on_skip_battle)
	btn_skip.disabled = false # 允许未开始战斗时直接点击跳过战斗
	
	# 增加【📜 查看结算】独立悬浮按钮（平时隐藏，关闭结算弹窗后显示，供随时重新调出结算弹窗）
	var btn_reopen = Button.new()
	btn_reopen.name = "BtnReopenResult"
	btn_reopen.text = "🏆 查看战果结算"
	btn_reopen.custom_minimum_size = Vector2(130, 36)
	btn_reopen.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	btn_reopen.visible = false
	btn_reopen.pressed.connect(func():
		if result_modal != null and is_instance_valid(result_modal):
			result_modal.visible = true
	)
	$VBox/TopControls.add_child(btn_reopen)
	
	# 设置右侧日志面板的纯色不透明背景
	if log_panel:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.15, 0.98) # 深沉实心暗色纯色背景
		sb.border_color = Color(0.5, 0.42, 0.25, 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		log_panel.add_theme_stylebox_override("panel", sb)
	
	init_boards()
	apply_speed_mode()
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
	card.custom_minimum_size = Vector2(145, 185)
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
	squad_grid.custom_minimum_size = Vector2(160, 130)
	squad_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	squad_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 在方阵上方新增【战旗/军旗】节点
	var flag_banner = Control.new()
	flag_banner.name = "FlagBanner"
	flag_banner.custom_minimum_size = Vector2(70, 28)
	flag_banner.position = Vector2(25, -28) # 居中悬浮于方阵正上方，不重叠
	squad_grid.add_child(flag_banner)
	
	var flag_panel = PanelContainer.new()
	flag_panel.name = "FlagPanel"
	flag_banner.add_child(flag_panel)
	
	var flag_label = Label.new()
	flag_label.name = "FlagLabel"
	flag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flag_label.add_theme_font_size_override("font_size", 14)
	flag_panel.add_child(flag_label)
	
	# 动态容纳最多 16 个小兵节点 (兼容 3x3 与 4x4)
	for idx in range(16):
		var sol_wrapper = Control.new()
		sol_wrapper.name = "SolWrapper_" + str(idx)
		
		# 脚下半透明接地暗影
		var shadow = Panel.new()
		shadow.name = "Shadow"
		var sh_style = StyleBoxFlat.new()
		sh_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
		sh_style.set_corner_radius_all(10)
		shadow.add_theme_stylebox_override("panel", sh_style)
		sol_wrapper.add_child(shadow)
		
		var icon = TextureRect.new()
		icon.name = "Sol"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sol_wrapper.add_child(icon)
		
		squad_grid.add_child(sol_wrapper)
		
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

var current_stage_info: Dictionary = {}
var current_legion_wave: int = 0

func setup_stage_battle(stage_data: Dictionary) -> void:
	current_stage_info = stage_data
	current_legion_wave = 0
	load_preview_formations()
	# 【傲视天地爽快体验】点进关卡即刻以当前/历史保存倍速自动开战！
	call_deferred("_on_start_battle")

func load_preview_formations() -> void:
	# 重置“查看战果结算”常驻按钮
	var btn_reopen = $VBox/TopControls.get_node_or_null("BtnReopenResult")
	if btn_reopen:
		btn_reopen.visible = false
		
	player_units.clear()
	enemy_units.clear()
	
	var p_form = GameData.player_formation
	var form_type = GameData.current_formation_type
	for pos in range(1, 10):
		if p_form.has(pos) and p_form[pos] != null:
			var hero_uuid = p_form[pos]
			var hero = GameData.get_hero_by_uuid(hero_uuid)
			if not hero.is_empty():
				var combined = GameData.calc_combined_stats(hero, form_type)
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
				u.crit_rate = combined["crit_rate"]
				u.block_rate = combined["block_rate"]
				u.penetrate_rate = combined["penetrate_rate"]
				u.bonus_target = combined["bonus_target"]
				u.bonus_rate = combined["bonus_rate"]
				u.mp = 50
				u.troop_name = combined["troop_name"]
				u.troop_type = combined["troop_type"]
				u.atk_mode = combined["atk_mode"]
				u.skill_name = combined["skill_name"]
				u.skill_desc = combined["skill_desc"]
				u.skill_target_type = combined["skill_target_type"]
				u.skill_type = combined["skill_type"]
				u.anim_type = combined["anim_type"]
				u.texture_path = combined["texture_path"]
				u.ui_card = player_cards[pos]
				player_units[pos] = u
			
	load_enemy_units_for_current_stage()

func load_enemy_units_for_current_stage() -> void:
	enemy_units.clear()
	var e_form = {}
	var e_form_type = "fish_scale"
	var stat_mult = 1.0
	
	if not current_stage_info.is_empty():
		if current_stage_info.get("is_legion", false) and current_stage_info.has("waves"):
			var waves = current_stage_info["waves"]
			if current_legion_wave < waves.size():
				var w_cfg = waves[current_legion_wave]
				e_form_type = w_cfg.get("formation", "fish_scale")
				stat_mult = w_cfg.get("stat_mult", 1.0)
				var enemy_map = w_cfg.get("enemies", {})
				for pos in enemy_map.keys():
					var tid = enemy_map[pos]
					if GameData.HERO_TEMPLATES.has(tid):
						var tmpl = GameData.HERO_TEMPLATES[tid].duplicate(true)
						tmpl["uuid"] = "enemy_" + str(pos) + "_" + str(randi() % 10000)
						tmpl["hp"] = int(tmpl["hp"] * stat_mult)
						tmpl["atk"] = int(tmpl["atk"] * stat_mult)
						tmpl["def"] = int(tmpl["def"] * stat_mult)
						tmpl["satk"] = int(tmpl["satk"] * stat_mult)
						tmpl["sdef"] = int(tmpl["sdef"] * stat_mult)
						e_form[pos] = tmpl
		else:
			e_form_type = current_stage_info.get("formation_type", "fish_scale")
			stat_mult = current_stage_info.get("stat_mult", 1.0)
			var enemy_map = current_stage_info.get("enemies", {})
			for pos in enemy_map.keys():
				var tid = enemy_map[pos]
				if GameData.HERO_TEMPLATES.has(tid):
					var tmpl = GameData.HERO_TEMPLATES[tid].duplicate(true)
					tmpl["uuid"] = "enemy_" + str(pos) + "_" + str(randi() % 10000)
					tmpl["hp"] = int(tmpl["hp"] * stat_mult)
					tmpl["atk"] = int(tmpl["atk"] * stat_mult)
					tmpl["def"] = int(tmpl["def"] * stat_mult)
					tmpl["satk"] = int(tmpl["satk"] * stat_mult)
					tmpl["sdef"] = int(tmpl["sdef"] * stat_mult)
					e_form[pos] = tmpl
	else:
		var diff_idx = diff_select.selected
		var diff_str = "Normal"
		match diff_idx:
			0: diff_str = "Easy"
			1: diff_str = "Normal"
			2: diff_str = "Hard"
			3: diff_str = "Nightmare"
			4: diff_str = "Test_AOE"
			5: diff_str = "Test_Block"
		e_form = GameData.get_enemy_formation(diff_str)

	for pos in range(1, 10):
		if e_form.has(pos) and e_form[pos] != null:
			var hero = e_form[pos]
			var combined = GameData.calc_combined_stats(hero, e_form_type)
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
			u.crit_rate = combined["crit_rate"]
			u.block_rate = combined["block_rate"]
			u.penetrate_rate = combined["penetrate_rate"]
			u.bonus_target = combined["bonus_target"]
			u.bonus_rate = combined["bonus_rate"]
			u.mp = 50
			u.troop_name = combined["troop_name"]
			u.troop_type = combined["troop_type"]
			u.atk_mode = combined["atk_mode"]
			u.skill_name = combined["skill_name"]
			u.skill_desc = combined["skill_desc"]
			u.skill_target_type = combined["skill_target_type"]
			u.skill_type = combined["skill_type"]
			u.anim_type = combined["anim_type"]
			u.texture_path = combined["texture_path"]
			u.ui_card = enemy_cards[pos]
			enemy_units[pos] = u
			
	render_all_cards()
	
	# 输出双方阵型加成战报日志
	var p_finfo = BattleCalculator.FORMATIONS.get(GameData.current_formation_type, {})
	var p_fname = p_finfo.get("name", "鱼鳞阵")
	append_log("⚔️ 我方使用【" + p_fname + "】(" + p_finfo.get("desc", "") + ")")
	
	if not is_battle_running:
		btn_skip.disabled = false

func render_all_cards() -> void:
	for pos in range(1, 10):
		update_card_ui(player_cards[pos], player_units.get(pos))
		update_card_ui(enemy_cards[pos], enemy_units.get(pos))

func update_card_ui(card_node: Control, unit: BattleUnit) -> void:
	if card_node == null:
		return
	card_node.visible = true
	var vbox = card_node.get_node_or_null("MarginContainer/VBox")
	if vbox == null:
		return
	var name_lbl = vbox.get_node_or_null("NameLbl") as Label
	var avatar_rect = vbox.get_node_or_null("AvatarRect") as TextureRect
	var squad_grid = vbox.get_node_or_null("SquadGrid") as Control
	var hp_bar = vbox.get_node_or_null("HpBar") as ProgressBar
	var hp_lbl = vbox.get_node_or_null("HpLbl") as Label
	var mp_bar = vbox.get_node_or_null("MpBar") as ProgressBar
	var mp_lbl = vbox.get_node_or_null("MpLbl") as Label
	var bg_panel = card_node.get_node_or_null("MarginContainer/BgPanel") as Panel
	
	if name_lbl == null or squad_grid == null or hp_bar == null or hp_lbl == null or mp_bar == null or mp_lbl == null or bg_panel == null:
		return
	
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
	
	# 隐藏原来顶部的文字名字，交由战旗呈现
	name_lbl.visible = false
	
	# 生存与阵亡处理
	if not unit.is_alive():
		name_lbl.text = "[阵亡] " + unit.name
		name_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		var empty_sb = StyleBoxFlat.new()
		empty_sb.bg_color = Color(0.1, 0.1, 0.1, 0.0)
		empty_sb.border_color = Color(0.3, 0.3, 0.3, 0.2)
		empty_sb.set_border_width_all(1)
		empty_sb.set_corner_radius_all(4)
		bg_panel.add_theme_stylebox_override("panel", empty_sb)
	else:
		card_node.modulate = Color(1, 1, 1, 1.0) # 存活正常显色
		name_lbl.text = unit.name
		name_lbl.remove_theme_color_override("font_color")
		
		# 当轮到当前武将行动且士气满 100 准备释放战法时，背景爆发金色流光（平时静止不闪）
		if unit.mp >= 100 and current_acting_unit == unit:
			var glow_sb = StyleBoxFlat.new()
			glow_sb.bg_color = Color(0.5, 0.38, 0.05, 0.45)
			glow_sb.border_color = Color(1.0, 0.88, 0.3, 1.0)
			glow_sb.set_border_width_all(3)
			glow_sb.set_corner_radius_all(6)
			bg_panel.add_theme_stylebox_override("panel", glow_sb)
		else:
			var normal_sb = StyleBoxFlat.new()
			normal_sb.bg_color = Color(0.1, 0.1, 0.1, 0.0)
			normal_sb.border_color = Color(0.3, 0.3, 0.3, 0.2)
			normal_sb.set_border_width_all(1)
			normal_sb.set_corner_radius_all(4)
			bg_panel.add_theme_stylebox_override("panel", normal_sb)
		
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
		
	# 渲染上方古代军旗
	var flag_banner = squad_grid.get_node_or_null("FlagBanner")
	if flag_banner and unit.is_alive():
		flag_banner.visible = true
		var flag_panel = flag_banner.get_node("FlagPanel") as PanelContainer
		var flag_label = flag_panel.get_node("FlagLabel") as Label
		flag_label.text = unit.name # 显示武将完整名字
		
		var f_style = StyleBoxFlat.new()
		if unit.is_player:
			f_style.bg_color = Color(0.15, 0.45, 0.85, 0.95) # 我方阵营宝蓝战旗
			f_style.border_color = Color(1.0, 0.85, 0.2, 1.0) # 金边
			flag_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		else:
			f_style.bg_color = Color(0.85, 0.2, 0.2, 0.95) # 敌方阵营赤红战旗
			f_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
			flag_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		f_style.set_border_width_all(2)
		f_style.set_corner_radius_all(4)
		flag_panel.add_theme_stylebox_override("panel", f_style)
	elif flag_banner:
		flag_banner.visible = false

	# 动态部署 3x3 或 4x4 的小兵坐标与属性
	for i in range(16):
		var sol_wrapper = squad_grid.get_node_or_null("SolWrapper_" + str(i)) as Control
		if sol_wrapper == null:
			continue
			
		var sol_icon = sol_wrapper.get_node_or_null("Sol") as TextureRect
		var shadow = sol_wrapper.get_node_or_null("Shadow") as Panel
			
		if i < total_count and not hidden_indices.has(i) and unit.is_alive():
			sol_icon.texture = idle_tex
			sol_icon.custom_minimum_size = sol_size
			sol_icon.size = sol_size
			sol_icon.pivot_offset = sol_size / 2.0
			
			shadow.custom_minimum_size = Vector2(sol_size.x * 0.7, 8)
			shadow.size = Vector2(sol_size.x * 0.7, 8)
			shadow.position = Vector2(sol_size.x * 0.15, sol_size.y - 4)
			
			# 布局坐标计算：3x3 与 4x4 紧凑重叠
			var pos_x = 0.0
			var pos_y = 0.0
			if grid_type == "3x3":
				var custom_pos_list = cat_cfg.get("custom_positions", [])
				if i < custom_pos_list.size():
					pos_x = custom_pos_list[i].x
					pos_y = custom_pos_list[i].y
				if not unit.is_player:
					sol_icon.flip_h = true
					pos_x = 100.0 - pos_x
				else:
					sol_icon.flip_h = false
			else:
				var row = i / 4
				var col = i % 4
				if not unit.is_player:
					sol_icon.flip_h = true
					pos_x = (3 - col) * 22 + row * 6
					pos_y = row * 16
				else:
					sol_icon.flip_h = false
					pos_x = col * 22 + (3 - row) * 6
					pos_y = row * 16
					
			sol_wrapper.position = Vector2(pos_x, pos_y)
			sol_wrapper.visible = true
		else:
			sol_wrapper.visible = false
				
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
	btn_skip.disabled = false
	log_text.text = "[color=yellow]=== 战斗开始 ===[/color]
"
	
	# 进战开场缓冲：非跳过模式下等待 0.6 秒展示双方两阵对峙画卷，避免刚切屏即飙伤害
	if not is_fast_simulating:
		await get_tree().create_timer(0.6).timeout
		if not is_battle_running:
			return
			
	start_auto_battle_loop()

func start_auto_battle_loop() -> void:
	while is_battle_running:
		if not is_fast_simulating:
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
			if target == null and attacker.troop_type not in ["鼓手", "医师", "机械"]:
				continue
				
			current_acting_unit = attacker
			render_all_cards() # 更新当前行动者发光 UI
			
			if is_fast_simulating:
				# 开启快进后：不再播放 Tweens 慢速动画，直接瞬间走逻辑计算
				execute_attack_logic(attacker, target)
			else:
				# 未开启快进：按正常速度播放动画
				await play_attack_sequence(attacker, target)
				
			current_acting_unit = null
			render_all_cards()
			
			if check_battle_over():
				break
				
		if check_battle_over():
			break
			
		battle_round += 1
		if not is_fast_simulating:
			await get_tree().create_timer(0.4).timeout
			
	render_all_cards()

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
	# 情况 A：如果在进入战斗前就直接点击了【跳过战斗】
	if not is_battle_running:
		load_preview_formations()
		if player_units.size() == 0:
			log_text.text = "[color=red]报错：玩家未上阵任何武将！请先前往【阵型】布阵。[/color]"
			return
		is_battle_running = true
		is_fast_simulating = true
		is_reward_given = false
		battle_round = 1
		GameData.is_in_battle = true
		btn_skip.disabled = true
		log_text.text = "[color=yellow]=== 战斗开始 (瞬间结算) ===[/color]"
		
		start_auto_battle_loop()
		return

	# 情况 B：在【自动战斗】演播过程中点击【跳过战斗】
	is_fast_simulating = true
	btn_skip.disabled = true
	append_log("
[color=magenta]>>> 触发【跳过战斗】，正在取消动画并无缝瞬间结算剩余战报... <<<[/color]")

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

func execute_attack_logic(attacker: BattleUnit, _unused_target: BattleUnit) -> void:
	var defender_dict = enemy_units if attacker.is_player else player_units
	var friend_dict = player_units if attacker.is_player else enemy_units
	var is_skill = (attacker.mp >= 100)

	var targets = BattleCalculator.find_targets(attacker, defender_dict, friend_dict, is_skill)
	if targets.size() == 0:
		return

	var res = BattleCalculator.execute_attack(attacker, targets, is_skill)

	for log_msg in res["logs"]:
		append_log(log_msg)

func play_attack_sequence(attacker: BattleUnit, _unused_target: BattleUnit) -> void:
	var defender_dict = enemy_units if attacker.is_player else player_units
	var friend_dict = player_units if attacker.is_player else enemy_units
	var is_skill = (attacker.mp >= 100)

	var targets = BattleCalculator.find_targets(attacker, defender_dict, friend_dict, is_skill)
	if targets.size() == 0:
		return

	var res = BattleCalculator.execute_attack(attacker, targets, is_skill)
	var atk_card = attacker.ui_card

	# 攻击前冲卡牌动画
	var tw_atk = create_tween().set_parallel(true)
	tw_atk.tween_property(atk_card, "scale", Vector2(1.15, 1.15), 0.15 * anim_speed_scale)
	if is_skill:
		tw_atk.tween_property(atk_card, "modulate", Color(1.5, 1.2, 0.4), 0.15 * anim_speed_scale)
		# 华丽战法拉条横幅与大招震屏（异步并发播放，绝不阻塞后续战斗结算！）
		show_skill_banner(attacker, attacker.skill_name)
		trigger_screen_shake(7.0, 0.22 * anim_speed_scale)
		spawn_skill_vfx(attacker, targets)
	await tw_atk.finished

	# 播报日志与命中动画处理
	for log_msg in res["logs"]:
		append_log(log_msg)

	for hit in res["hits"]:
		var target = hit["target"] as BattleUnit
		var tgt_card = target.ui_card
		var hit_pos = tgt_card.global_position + Vector2(20, 10)

		if hit["type"] == "miss":
			spawn_floating_text(hit_pos, "MISS", Color(0.3, 0.9, 1.0))
		elif hit["type"] == "heal":
			spawn_floating_text(hit_pos, "+" + str(hit["heal"]), Color(0.2, 0.9, 0.3))
		elif hit["type"] == "mp_boost":
			spawn_floating_text(hit_pos, "+" + str(hit["mp_change"]) + " 士气", Color(1.0, 0.9, 0.2))
		elif hit["type"] == "damage":
			var dmg_str = str(hit["damage"])
			var txt_color = Color(1.0, 0.2, 0.2)
			if hit.get("is_crit", false):
				dmg_str = "暴击! " + dmg_str
				txt_color = Color(1.0, 0.8, 0.1)
				trigger_screen_shake(4.0, 0.15 * anim_speed_scale) # 暴击轻微震屏
			if hit.get("is_blocked", false):
				dmg_str = "格挡 " + dmg_str
				txt_color = Color(0.9, 0.9, 0.3)

			spawn_floating_text(hit_pos, dmg_str, txt_color)

			if hit.get("mp_loss", 0) > 0:
				spawn_floating_text(hit_pos + Vector2(0, 18), "-" + str(hit["mp_loss"]) + " 士气", Color(0.8, 0.3, 0.9))

			# 目标受击红闪震动
			var tw_hit = create_tween().set_parallel(true)
			tw_hit.tween_property(tgt_card, "modulate", Color(2.0, 0.4, 0.4), 0.1 * anim_speed_scale)
			await tw_hit.finished
			var tw_reset_tgt = create_tween().set_parallel(true)
			tw_reset_tgt.tween_property(tgt_card, "modulate", Color(1, 1, 1), 0.1 * anim_speed_scale)

			if hit.get("counter_dmg", 0) > 0:
				spawn_floating_text(atk_card.global_position + Vector2(20, 10), "反击! -" + str(hit["counter_dmg"]), Color(1.0, 0.5, 0.1))

	# 攻击者卡牌复位
	var tw_back = create_tween().set_parallel(true)
	tw_back.tween_property(atk_card, "scale", Vector2(1.0, 1.0), 0.15 * anim_speed_scale)
	tw_back.tween_property(atk_card, "modulate", Color(1, 1, 1), 0.15 * anim_speed_scale)
	await tw_back.finished

	render_all_cards()
	await get_tree().create_timer(0.2 * anim_speed_scale).timeout
	return

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
	tw.tween_property(lbl, "global_position", global_pos + Vector2(0, -35), 0.5 * anim_speed_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5 * anim_speed_scale)
	
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

# ==========================================================
# ⚡ 方案 A 视觉与动效增强：震屏、战法名字横幅与兵种专属粒子特效
# ==========================================================

# 1. 屏幕/战场震动打击感
func trigger_screen_shake(intensity: float = 6.0, duration: float = 0.2) -> void:
	if is_fast_simulating:
		return
	var board = $VBox/MainLayout/BattleBoard
	if not board or not is_inside_tree():
		return
	var orig_pos = board.position
	var elapsed = 0.0
	while elapsed < duration:
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		board.position = orig_pos + offset
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	board.position = orig_pos

# 2. 华丽战法拉条横幅 (Skill Banner)
func show_skill_banner(attacker: BattleUnit, skill_name: String) -> void:
	if is_fast_simulating or not is_inside_tree():
		return
		
	var banner = PanelContainer.new()
	banner.custom_minimum_size = Vector2(500, 50)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.anchor_top = 0.28
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.03, 0.9) if attacker.is_player else Color(0.12, 0.03, 0.05, 0.9)
	style.border_color = Color(1.0, 0.8, 0.25) if attacker.is_player else Color(0.9, 0.2, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	banner.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	banner.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)
	
	var hero_lbl = Label.new()
	hero_lbl.text = attacker.name + " 施展战法:"
	hero_lbl.add_theme_font_size_override("font_size", 16)
	hero_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hbox.add_child(hero_lbl)
	
	var skill_lbl = Label.new()
	skill_lbl.text = "【" + skill_name + "】"
	skill_lbl.add_theme_font_size_override("font_size", 22)
	skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if attacker.is_player else Color(1.0, 0.3, 0.3))
	skill_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	skill_lbl.add_theme_constant_override("outline_size", 4)
	hbox.add_child(skill_lbl)
	
	fx_layer.add_child(banner)
	
	# 横幅淡入弹起与消失动效
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.8, 0.8)
	banner.pivot_offset = Vector2(250, 25)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.12 * anim_speed_scale)
	tw.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.12 * anim_speed_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	
	await get_tree().create_timer(0.25 * anim_speed_scale).timeout
	
	var tw_out = create_tween().set_parallel(true)
	tw_out.tween_property(banner, "modulate:a", 0.0, 0.12 * anim_speed_scale)
	tw_out.tween_property(banner, "scale", Vector2(1.1, 1.1), 0.12 * anim_speed_scale)
	await tw_out.finished
	
	if is_instance_valid(banner):
		banner.queue_free()

# 3. 五大兵种战法粒子与强化视觉特效 (Procedural CPUParticles2D + 光斑强特效)
func spawn_skill_vfx(attacker: BattleUnit, targets: Array) -> void:
	if is_fast_simulating or not is_inside_tree():
		return
		
	var t_type = attacker.troop_type
	for target in targets:
		if not is_instance_valid(target.ui_card):
			continue
		var target_pos = target.ui_card.global_position + Vector2(40, 30)
		
		# 基础爆破粒子
		var particles = CPUParticles2D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 40 # 增加粒子数量让画面极其鲜明
		particles.lifetime = 0.8
		particles.global_position = target_pos
		
		# 增加地面高亮环纹光束提示
		var ring = PanelContainer.new()
		ring.custom_minimum_size = Vector2(80, 80)
		ring.global_position = target_pos - Vector2(40, 40)
		var r_style = StyleBoxFlat.new()
		r_style.set_corner_radius_all(40) # 正圆形光斑
		r_style.bg_color = Color(0, 0, 0, 0)
		
		match t_type:
			"骑兵", "步兵":
				particles.color = Color(1.0, 0.85, 0.2, 0.95)
				particles.direction = Vector2(-1, 0) if attacker.is_player else Vector2(1, 0)
				particles.spread = 60.0
				particles.initial_velocity_min = 200.0
				particles.initial_velocity_max = 380.0
				particles.scale_amount_min = 5.0
				particles.scale_amount_max = 10.0
				r_style.border_color = Color(1.0, 0.8, 0.2, 0.9)
				r_style.set_border_width_all(3)
			"弓兵":
				particles.color = Color(1.0, 0.95, 0.3, 0.95)
				particles.direction = Vector2(0, 1)
				particles.spread = 45.0
				particles.initial_velocity_min = 220.0
				particles.initial_velocity_max = 420.0
				particles.scale_amount_min = 4.0
				particles.scale_amount_max = 8.0
				r_style.border_color = Color(1.0, 0.9, 0.3, 0.9)
				r_style.set_border_width_all(3)
			"策士":
				particles.color = Color(1.0, 0.35, 0.1, 0.95) # 烈焰爆破火线
				particles.direction = Vector2(0, -1)
				particles.spread = 80.0
				particles.initial_velocity_min = 150.0
				particles.initial_velocity_max = 300.0
				particles.scale_amount_min = 6.0
				particles.scale_amount_max = 12.0
				r_style.border_color = Color(1.0, 0.4, 0.1, 0.9)
				r_style.set_border_width_all(4)
			"机械":
				particles.color = Color(0.9, 0.5, 0.1, 0.95) # 巨石砸地/霹雳重火尘浪
				particles.direction = Vector2(0, -1)
				particles.spread = 90.0
				particles.initial_velocity_min = 250.0
				particles.initial_velocity_max = 450.0
				particles.scale_amount_min = 8.0
				particles.scale_amount_max = 16.0
				r_style.border_color = Color(0.9, 0.6, 0.1, 0.95)
				r_style.set_border_width_all(4)
			"医师":
				particles.color = Color(0.2, 1.0, 0.4, 0.95) # 绿色生机治愈光花
				particles.direction = Vector2(0, -1)
				particles.spread = 120.0
				particles.initial_velocity_min = 80.0
				particles.initial_velocity_max = 180.0
				particles.scale_amount_min = 5.0
				particles.scale_amount_max = 10.0
				r_style.border_color = Color(0.3, 1.0, 0.4, 0.9)
				r_style.set_border_width_all(3)
			"鼓手":
				particles.color = Color(1.0, 0.85, 0.1, 0.95) # 金色鼓浪振奋波
				particles.direction = Vector2(0, -1)
				particles.spread = 180.0
				particles.initial_velocity_min = 100.0
				particles.initial_velocity_max = 220.0
				particles.scale_amount_min = 5.0
				particles.scale_amount_max = 9.0
				r_style.border_color = Color(1.0, 0.85, 0.1, 0.9)
				r_style.set_border_width_all(3)
				
		ring.add_theme_stylebox_override("panel", r_style)
		fx_layer.add_child(ring)
		fx_layer.add_child(particles)
		particles.emitting = true
		
		# 光环扩散淡出
		var tw_ring = create_tween().set_parallel(true)
		tw_ring.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.4)
		tw_ring.tween_property(ring, "modulate:a", 0.0, 0.4)
		
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
			if is_instance_valid(ring):
				ring.queue_free()
		)

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
		if p_alive > 0 and current_stage_info.get("is_legion", false) and current_stage_info.has("waves"):
			var waves = current_stage_info["waves"]
			if current_legion_wave + 1 < waves.size():
				current_legion_wave += 1
				append_log("
[color=orange]⚔️ 击破第 " + str(current_legion_wave) + " 波敌军！敌军下一波增援精锐入场！我方继承剩余状态继续厮杀！[/color]")
				load_enemy_units_for_current_stage()
				return false # 战斗未结束，继续下一波
				
		if is_reward_given:
			return true
		is_reward_given = true
		
		is_battle_running = false
		GameData.is_in_battle = false
		btn_skip.disabled = false
		
		var p_rew := 0
		var g_rew := 0
		var e_rew := 0
		var hint_text := ""
		
		if p_alive > 0:
			append_log("
[color=gold]🎉 战斗大捷！全歼敌军！[/color]")
			
			if not current_stage_info.is_empty():
				var st_id = current_stage_info.get("id", "")
				if not st_id in GameData.cleared_stages:
					GameData.cleared_stages.append(st_id)
					
				p_rew = current_stage_info.get("prestige_reward", 0)
				g_rew = current_stage_info.get("gold_reward", 100)
				e_rew = current_stage_info.get("exp_reward", 100)
				
				GameData.player_prestige += p_rew
				GameData.player_gold += g_rew
				GameData.player_exp_pool += e_rew
				
				append_log("[color=green]主关通关奖励：威望 +" + str(p_rew) + "，金币 +" + str(g_rew) + "，经验 +" + str(e_rew) + "[/color]")
				GameData.emit_signal("prestige_changed")
				GameData.emit_signal("gold_changed")
				GameData.emit_signal("exp_changed")
				
				# 首次通关降将 Boss 关（军团战除外）：按概率判定敌将是否臣服
				if current_stage_info.get("is_boss", false) and not current_stage_info.get("is_legion", false):
					var boss_id = current_stage_info.get("boss_hero_id", "")
					var boss_tmpl: Dictionary = GameData.HERO_TEMPLATES.get(boss_id, {})
					var boss_name: String = boss_tmpl.get("name", "敌方主将")
					var surrender_rate: float = current_stage_info.get("surrender_rate", 0.5)
					
					if not st_id in GameData.unlocked_surrenders:
						if randf() <= surrender_rate:
							GameData.unlocked_surrenders.append(st_id)
							hint_text = "[color=#00FF66]🎉 敌将【" + boss_name + "】感念阁下武德，臣服了！前往【招贤酒馆】即可招募入队。[/color]"
						else:
							hint_text = "[color=#FF6655]⚔️ 敌将【" + boss_name + "】性格桀骜，本次未肯臣服！再次挑战击败他有机会使其臣服。[/color]"
					else:
						hint_text = "[color=#FFDD44]💡 敌将【" + boss_name + "】此前已前往酒馆臣服，随时可在【招贤酒馆】招募！[/color]"
			else:
				append_log("[color=green]获得战利品：金币 +100，共享经验 +100[/color]")
				g_rew = 100
				e_rew = 100
				GameData.player_gold += 100
				GameData.player_exp_pool += 100
				GameData.emit_signal("gold_changed")
				GameData.emit_signal("exp_changed")
				
			GameData.has_unsaved_changes = true
		else:
			append_log("
[color=red]☠️ 遗憾败北！全军覆没！[/color]")
			hint_text = "💡 建议：提升武将等级与品质、更换克制敌方的阵型与兵种搭配后再来挑战！"
			
		is_fast_simulating = false
		
		# 【傲视天地风格】弹窗结算提示
		var wave_total := 1
		if current_stage_info.get("is_legion", false) and current_stage_info.has("waves"):
			wave_total = (current_stage_info["waves"] as Array).size()
			
		show_battle_result(p_alive > 0, {
			"subtitle": current_stage_info.get("name", "演炼战斗") if not current_stage_info.is_empty() else "自由演习",
			"rounds": battle_round,
			"survivors": p_alive,
			"total_units": player_units.size(),
			"kills": enemy_units.size() - e_alive,
			"is_legion": current_stage_info.get("is_legion", false),
			"wave": current_legion_wave + 1,
			"wave_total": wave_total,
			"prestige": p_rew,
			"gold": g_rew,
			"exp": e_rew,
			"hint": hint_text
		})
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

# ==========================================================
# 战斗结算弹窗（《傲视天地》风格：古风牌匾 + 战况统计 + 收益明细）
# ==========================================================
var result_modal: Control = null

func show_battle_result(is_victory: bool, stats: Dictionary) -> void:
	if result_modal != null and is_instance_valid(result_modal):
		result_modal.queue_free()
	var modal := BattleResultModal.new()
	add_child(modal)
	modal.setup(
		is_victory, 
		stats, 
		Callable(self, "_on_result_confirm"), 
		Callable(self, "_on_result_retry").bind(is_victory)
	)
	result_modal = modal
	
	# 显示顶部“查看战果结算”常驻按钮
	var btn_reopen = $VBox/TopControls.get_node_or_null("BtnReopenResult")
	if btn_reopen:
		btn_reopen.visible = true

func _on_result_confirm() -> void:
	if result_modal != null and is_instance_valid(result_modal):
		result_modal.queue_free()
	result_modal = null
	
	# 返回主线征战选关地图页面
	var main_ui = _get_main_ui()
	if main_ui and main_ui.has_method("_on_campaign_pressed"):
		main_ui._on_campaign_pressed()
	else:
		load_preview_formations()

func _on_result_retry(is_victory: bool) -> void:
	if result_modal != null and is_instance_valid(result_modal):
		result_modal.queue_free()
	result_modal = null
	
	if is_victory:
		# 胜利：再战一场 (重新开始当前关卡战斗)
		current_legion_wave = 0
		load_preview_formations()
		_on_start_battle()
	else:
		# 失败：重新布阵 (直接跳转打开阵型界面)
		var main_ui = _get_main_ui()
		if main_ui and main_ui.has_method("_on_formation_pressed"):
			main_ui._on_formation_pressed()
		else:
			load_preview_formations()

func _get_main_ui() -> Node:
	var p = get_parent()
	while p != null:
		if p.has_method("_on_campaign_pressed") and p.has_method("_on_formation_pressed"):
			return p
		p = p.get_parent()
	return null

class BattleResultModal extends Control:
	var is_victory: bool = true
	var stats: Dictionary = {}
	var on_confirm: Callable
	var on_retry: Callable
	var _panel: PanelContainer
	var _title_lbl: Label

	func setup(p_victory: bool, p_stats: Dictionary, p_confirm: Callable, p_retry: Callable) -> void:
		is_victory = p_victory
		stats = p_stats
		on_confirm = p_confirm
		on_retry = p_retry
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_build()
		_play_intro()

	func _build() -> void:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.68)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)

		_panel = PanelContainer.new()
		_panel.custom_minimum_size = Vector2(640, 0)
		var style := StyleBoxFlat.new()
		if is_victory:
			style.bg_color = Color(0.14, 0.08, 0.05, 0.98)
			style.border_color = Color(1.0, 0.78, 0.25, 1.0)
		else:
			style.bg_color = Color(0.09, 0.09, 0.12, 0.98)
			style.border_color = Color(0.55, 0.55, 0.62, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(14)
		_panel.add_theme_stylebox_override("panel", style)
		center.add_child(_panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_bottom", 20)
		_panel.add_child(margin)

		var root_vbox := VBoxContainer.new()
		root_vbox.add_theme_constant_override("separation", 14)
		margin.add_child(root_vbox)

		# 1. 顶部牌匾
		var banner := PanelContainer.new()
		var bstyle := StyleBoxFlat.new()
		if is_victory:
			bstyle.bg_color = Color(0.55, 0.16, 0.06, 0.95)
			bstyle.border_color = Color(1.0, 0.82, 0.3, 1.0)
		else:
			bstyle.bg_color = Color(0.16, 0.16, 0.22, 0.95)
			bstyle.border_color = Color(0.62, 0.62, 0.7, 1.0)
		bstyle.set_border_width_all(2)
		bstyle.set_corner_radius_all(10)
		banner.add_theme_stylebox_override("panel", bstyle)
		root_vbox.add_child(banner)

		var banner_margin := MarginContainer.new()
		banner_margin.add_theme_constant_override("margin_top", 8)
		banner_margin.add_theme_constant_override("margin_bottom", 8)
		banner.add_child(banner_margin)

		var banner_vbox := VBoxContainer.new()
		banner_margin.add_child(banner_vbox)

		_title_lbl = Label.new()
		_title_lbl.text = "⚔  大 获 全 胜  ⚔" if is_victory else "☠  惜 败 阵 亡  ☠"
		_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_lbl.add_theme_font_size_override("font_size", 32)
		_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62) if is_victory else Color(0.78, 0.80, 0.86))
		_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_title_lbl.add_theme_constant_override("outline_size", 6)
		banner_vbox.add_child(_title_lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = stats.get("subtitle", "")
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 14)
		sub_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		banner_vbox.add_child(sub_lbl)

		# 2. 战况概览
		var stat_row := HBoxContainer.new()
		stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stat_row.add_theme_constant_override("separation", 16)
		root_vbox.add_child(stat_row)

		_add_stat_cell(stat_row, "战斗回合", str(stats.get("rounds", 1)) + " 回合")
		_add_stat_cell(stat_row, "我军存活", str(stats.get("survivors", 0)) + " 人")
		_add_stat_cell(stat_row, "击破敌将", str(stats.get("kills", 0)) + " 人")
		if stats.get("is_legion", false):
			_add_stat_cell(stat_row, "军团进度", "第 " + str(stats.get("wave", 1)) + " / " + str(stats.get("wave_total", 1)) + " 波")

		# 3. 战利品/提示
		if is_victory:
			var sep := HSeparator.new()
			root_vbox.add_child(sep)

			var rew_title := Label.new()
			rew_title.text = "🏆 战 利 品 丰 收"
			rew_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rew_title.add_theme_font_size_override("font_size", 15)
			rew_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			root_vbox.add_child(rew_title)

			var rew_row := HBoxContainer.new()
			rew_row.alignment = BoxContainer.ALIGNMENT_CENTER
			rew_row.add_theme_constant_override("separation", 18)
			root_vbox.add_child(rew_row)

			_add_reward_chip(rew_row, "🏆 威望", "+" + str(stats.get("prestige", 0)), Color(1.0, 0.55, 0.75))
			_add_reward_chip(rew_row, "💰 金币", "+" + str(stats.get("gold", 0)), Color(1.0, 0.85, 0.35))
			_add_reward_chip(rew_row, "⭐ 经验", "+" + str(stats.get("exp", 0)), Color(0.55, 0.88, 1.0))

		var hint_str: String = stats.get("hint", "")
		if hint_str != "":
			var hint_lbl := RichTextLabel.new()
			hint_lbl.bbcode_enabled = true
			hint_lbl.fit_content = true
			hint_lbl.text = "[center]" + hint_str + "[/center]"
			hint_lbl.add_theme_font_size_override("normal_font_size", 14)
			root_vbox.add_child(hint_lbl)

		# 4. 底部按钮
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 20)
		root_vbox.add_child(btn_row)

		var btn_retry := Button.new()
		btn_retry.text = "🔄 再战一场" if is_victory else "🔄 重新布阵"
		btn_retry.custom_minimum_size = Vector2(150, 42)
		btn_retry.add_theme_font_size_override("font_size", 16)
		btn_retry.pressed.connect(func() -> void:
			if on_retry.is_valid():
				on_retry.call()
		)
		btn_row.add_child(btn_retry)

		var btn_review := Button.new()
		btn_review.text = "📜 查看战报复盘"
		btn_review.custom_minimum_size = Vector2(150, 42)
		btn_review.add_theme_font_size_override("font_size", 16)
		btn_review.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		btn_review.pressed.connect(func() -> void:
			visible = false
		)
		btn_row.add_child(btn_review)

		var btn_ok := Button.new()
		btn_ok.text = "✔ 确定" if is_victory else "✔ 返回"
		btn_ok.custom_minimum_size = Vector2(130, 42)
		btn_ok.add_theme_font_size_override("font_size", 16)
		btn_ok.pressed.connect(func() -> void:
			if on_confirm.is_valid():
				on_confirm.call()
		)
		btn_row.add_child(btn_ok)

	func _add_stat_cell(parent: Control, label_text: String, value_text: String) -> void:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var l := Label.new()
		l.text = label_text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.65, 0.68, 0.76))
		cell.add_child(l)

		var v := Label.new()
		v.text = value_text
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_theme_font_size_override("font_size", 18)
		v.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		cell.add_child(v)

		parent.add_child(cell)

	func _add_reward_chip(parent: Control, title: String, val: String, color: Color) -> void:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)

		var t := Label.new()
		t.text = title + ":"
		t.add_theme_font_size_override("font_size", 14)
		t.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		chip.add_child(t)

		var v := Label.new()
		v.text = val
		v.add_theme_font_size_override("font_size", 15)
		v.add_theme_color_override("font_color", color)
		chip.add_child(v)

		parent.add_child(chip)

	func _play_intro() -> void:
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
