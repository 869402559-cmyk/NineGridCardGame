class_name TavernUI
extends Control

@onready var title_lbl: Label = $VBox/TopBar/Title
@onready var quality_filter: OptionButton = $VBox/TopBar/QualityFilter
@onready var info_lbl: Label = $VBox/TopBar/InfoLbl
@onready var btn_close: Button = $VBox/TopBar/BtnClose
@onready var tab_container: TabContainer = $VBox/TabContainer

@onready var base_grid: GridContainer = $"VBox/TabContainer/初始余将/Scroll/Grid"
@onready var surrender_grid: GridContainer = $"VBox/TabContainer/关卡降将/Scroll/Grid"
@onready var prestige_grid: GridContainer = $"VBox/TabContainer/威望名将/Scroll/Grid"

signal closed()

var current_filter_quality: String = "ALL"

func _ready() -> void:
	btn_close.pressed.connect(func():
		hide()
		emit_signal("closed")
	)
	
	init_quality_filter()
	
	visibility_changed.connect(func():
		if visible:
			refresh_ui()
	)
	refresh_ui()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		emit_signal("closed")

func init_quality_filter() -> void:
	quality_filter.clear()
	quality_filter.add_item("全部品质", 0)
	quality_filter.add_item("UR 品质", 1)
	quality_filter.add_item("SSR 品质", 2)
	quality_filter.add_item("SR 品质", 3)
	quality_filter.add_item("R 品质", 4)
	quality_filter.add_item("N 品质", 5)
	
	quality_filter.item_selected.connect(func(index: int):
		match index:
			0: current_filter_quality = "ALL"
			1: current_filter_quality = "UR"
			2: current_filter_quality = "SSR"
			3: current_filter_quality = "SR"
			4: current_filter_quality = "R"
			5: current_filter_quality = "N"
		refresh_ui()
	)

func refresh_ui() -> void:
	info_lbl.text = "💰 金币: " + str(GameData.player_gold) + "  |  🎖️ 威望: " + str(GameData.player_prestige)
	render_base_heroes()
	render_surrender_heroes()
	render_prestige_heroes()

# 通用排序函数：按品质权重由高到低（UR > SSR > SR > R > N）
func sort_heroes_by_quality(list: Array) -> Array:
	var sorted_list = list.duplicate()
	sorted_list.sort_custom(func(a, b):
		var w_a = GameData.get_quality_config(a.get("quality", "N")).get("rank_weight", 0)
		var w_b = GameData.get_quality_config(b.get("quality", "N")).get("rank_weight", 0)
		if w_a != w_b:
			return w_a > w_b
		return a.get("id", "") < b.get("id", "")
	)
	return sorted_list

# 品质筛选过滤
func filter_hero_by_quality(tmpl: Dictionary) -> bool:
	if current_filter_quality == "ALL":
		return true
	return tmpl.get("quality", "N") == current_filter_quality

# 1. 渲染【初始余将】（7位未选择的基础兵种）
func render_base_heroes() -> void:
	for child in base_grid.get_children():
		child.queue_free()
		
	var raw_list = []
	for tmpl in GameData.HERO_TEMPLATES.values():
		if tmpl.get("source_type", "") == "base" and filter_hero_by_quality(tmpl):
			raw_list.append(tmpl)
			
	var sorted_list = sort_heroes_by_quality(raw_list)
	for tmpl in sorted_list:
		var hid = tmpl.get("id", "")
		var is_owned = GameData.is_hero_owned(hid)
		# 初始余将默认直接展示
		var card = create_hero_card_node(tmpl, is_owned, true, "base")
		base_grid.add_child(card)

# 2. 渲染【关卡降将】（已被击败臣服过的敌将）
func render_surrender_heroes() -> void:
	for child in surrender_grid.get_children():
		child.queue_free()
		
	var raw_list = []
	for tmpl in GameData.HERO_TEMPLATES.values():
		if tmpl.get("source_type", "") == "surrender" and filter_hero_by_quality(tmpl):
			# 渐进式解锁：只有曾经在关卡中被击败并臣服过（记录在 unlocked_surrenders）的武将才会在酒馆显示！
			var stage_req = tmpl.get("source_req", "")
			var is_surrendered = GameData.unlocked_surrenders.has(stage_req)
			if is_surrendered:
				raw_list.append(tmpl)
				
	var sorted_list = sort_heroes_by_quality(raw_list)
	for tmpl in sorted_list:
		var hid = tmpl.get("id", "")
		var is_owned = GameData.is_hero_owned(hid)
		var card = create_hero_card_node(tmpl, is_owned, true, "surrender")
		surrender_grid.add_child(card)

# 3. 渲染【威望名将】（达到威望后解锁显示）
func render_prestige_heroes() -> void:
	for child in prestige_grid.get_children():
		child.queue_free()
		
	var raw_list = []
	for tmpl in GameData.HERO_TEMPLATES.values():
		if tmpl.get("source_type", "") == "prestige" and filter_hero_by_quality(tmpl):
			var req_prestige = tmpl.get("source_req", "0").to_int()
			# 渐进式解锁：威望达标过或已解锁过，才会在此列出显示
			var is_unlocked = GameData.acquired_prestige_heroes.has(tmpl.get("id", ""))
			if GameData.player_prestige >= req_prestige or is_unlocked:
				raw_list.append(tmpl)
				
	var sorted_list = sort_heroes_by_quality(raw_list)
	for tmpl in sorted_list:
		var hid = tmpl.get("id", "")
		var req_prestige = tmpl.get("source_req", "0").to_int()
		var is_owned = GameData.is_hero_owned(hid)
		var is_unlocked = GameData.acquired_prestige_heroes.has(hid)
		
		var card = create_hero_card_node(tmpl, is_owned, is_unlocked, "prestige", req_prestige)
		prestige_grid.add_child(card)

# 创建通用武将卡片节点
func create_hero_card_node(tmpl: Dictionary, is_owned: bool, is_unlocked: bool, tab_type: String, req_prestige: int = 0) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 220)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	var q_cfg = GameData.get_quality_config(tmpl.get("quality", "N"))
	sb.border_color = q_cfg.get("color", Color.GRAY)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# 武将名与品质
	var name_lbl = Label.new()
	name_lbl.text = "[" + tmpl.get("quality", "N") + "] " + tmpl.get("name", "武将")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", q_cfg.get("color", Color.WHITE))
	vbox.add_child(name_lbl)
	
	# 兵种与战法信息
	var troop = GameData.get_troop_by_id(tmpl.get("troop_id", ""))
	var troop_lbl = Label.new()
	troop_lbl.text = "兵种: " + troop.get("name", "兵种") + " (" + troop.get("type_name", "兵种") + ")"
	troop_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(troop_lbl)
	
	var skill_lbl = Label.new()
	skill_lbl.text = "战法: 【" + troop.get("skill_name", "无") + "】"
	skill_lbl.add_theme_font_size_override("font_size", 13)
	skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(skill_lbl)
	
	var hp_lbl = Label.new()
	hp_lbl.text = "基础兵力: " + str(tmpl.get("hp", 1000)) + " | 攻击: " + str(tmpl.get("atk", 100))
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hp_lbl)
	
	# 弹簧隔离
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 招募金币费用计算（N:2000, R:5000, SR:15000, SSR:50000, UR:150000）
	var recruit_cost = 5000
	match tmpl.get("quality", "N"):
		"N": recruit_cost = 2000
		"R": recruit_cost = 5000
		"SR": recruit_cost = 15000
		"SSR": recruit_cost = 50000
		"UR": recruit_cost = 150000
		
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(btn)
	
	if is_owned:
		btn.text = "已在阵中/列表中"
		btn.disabled = true
	elif tab_type != "prestige":
		# 初始余将与关卡臣服页签
		btn.text = "招募 (" + str(recruit_cost) + " 金币)"
		btn.pressed.connect(func():
			if GameData.player_gold < recruit_cost:
				btn.text = "金币不足！"
				return
			GameData.player_gold -= recruit_cost
			GameData.add_hero(tmpl.get("id", ""))
			GameData.auto_fill_formation()
			GameData.save_current_progress()
			refresh_ui()
		)
	else:
		# 威望名将页签
		if is_unlocked:
			btn.text = "招募 (" + str(recruit_cost) + " 金币)"
			btn.pressed.connect(func():
				if GameData.player_gold < recruit_cost:
					btn.text = "金币不足！"
					return
				GameData.player_gold -= recruit_cost
				GameData.add_hero(tmpl.get("id", ""))
				GameData.auto_fill_formation()
				GameData.save_current_progress()
				refresh_ui()
			)
		else:
			if GameData.player_prestige < req_prestige:
				btn.text = "需威望: " + str(req_prestige) + " (未达标)"
				btn.disabled = true
			else:
				btn.text = "解锁武将 (需 " + str(req_prestige) + " 威望)"
				btn.pressed.connect(func():
					GameData.acquired_prestige_heroes.append(tmpl.get("id", ""))
					GameData.save_current_progress()
					refresh_ui()
				)
				
	return panel
