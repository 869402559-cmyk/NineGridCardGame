extends Control

@onready var hero_grid: GridContainer = $HBox/LeftPanel/HeroScroll/HeroGrid
@onready var btn_dismiss: Button = $HBox/LeftPanel/TitleBox/BtnDismiss
@onready var btn_auto: Button = $HBox/LeftPanel/TitleBox/BtnAuto
@onready var btn_clear: Button = $HBox/LeftPanel/TitleBox/BtnClear
@onready var grid_container: GridContainer = $HBox/RightPanel/GridContainer
@onready var grid_title: Label = $HBox/RightPanel/GridTitle

var slot_cards: Array = [] # 1..9 slot controls

func _ready() -> void:
	btn_auto.pressed.connect(_on_auto_fill)
	btn_clear.pressed.connect(_on_clear)
	if btn_dismiss:
		btn_dismiss.pressed.connect(_on_open_dismiss_modal)
	
	# 设置左侧整个面板区域（LeftPanel）为显式下阵目标（精准接收拖回的单个卡牌）
	var left_panel = $HBox/LeftPanel
	left_panel.script = LeftPanelDropScript
	
	init_formation_slots()
	refresh_all()

func init_formation_slots() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	slot_cards.clear()
	
	for pos in range(1, 10):
		var card = create_slot_card(pos)
		grid_container.add_child(card)
		slot_cards.append(card)

# 创建九宫格阵型位（卡牌支持作为拖拽目标与拖拽源）
func create_slot_card(pos: int) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 140)
	card.set_meta("slot_pos", pos)
	card.script = SlotCardScript
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	card.add_child(vbox)
	
	var pos_lbl = Label.new()
	pos_lbl.name = "PosLbl"
	pos_lbl.text = str(pos) + "号位"
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_lbl.add_theme_font_size_override("font_size", 12)
	pos_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.25))
	vbox.add_child(pos_lbl)
	
	var img = TextureRect.new()
	img.name = "Avatar"
	img.custom_minimum_size = Vector2(60, 80)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(img)
	
	var name_lbl = Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = "(空)"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_lbl)
	
	return card

func refresh_all() -> void:
	refresh_left_hero_grid()
	refresh_right_formation_grid()

func refresh_left_hero_grid() -> void:
	for child in hero_grid.get_children():
		child.queue_free()
		
	var equipped_uuids = []
	for pos in range(1, 10):
		var uid = GameData.player_formation[pos]
		if uid != null:
			equipped_uuids.append(uid)
			
	# 克隆武将列表并排序：已上阵优先，其次品质，再次等级
	var sorted_heroes = GameData.player_heroes.duplicate()
	sorted_heroes.sort_custom(func(a, b):
		var a_eq = a["uuid"] in equipped_uuids
		var b_eq = b["uuid"] in equipped_uuids
		if a_eq != b_eq:
			return a_eq # 已上阵在前
			
		var q_a = GameData.get_quality_config(a.get("quality", "N"))["rank_weight"]
		var q_b = GameData.get_quality_config(b.get("quality", "N"))["rank_weight"]
		if q_a != q_b:
			return q_a > q_b
			
		var lv_a = a.get("level", 1)
		var lv_b = b.get("level", 1)
		return lv_a > lv_b
	)
			
	for hero in sorted_heroes:
		var card = create_hero_portrait_card(hero, hero["uuid"] in equipped_uuids)
		hero_grid.add_child(card)

# 创建左侧英雄 3:4 头像卡片
func create_hero_portrait_card(hero: Dictionary, is_equipped: bool) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(88, 118)
	card.set_meta("hero_uuid", hero["uuid"])
	card.script = HeroCardScript
	
	var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
	var style = StyleBoxFlat.new()
	style.bg_color = q_cfg["bg_color"]
	style.set_corner_radius_all(6)
	style.border_width_bottom = q_cfg["border_width"]
	style.border_width_left = q_cfg["border_width"]
	style.border_width_right = q_cfg["border_width"]
	style.border_width_top = q_cfg["border_width"]
	style.border_color = q_cfg["border_color"]
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	
	var combined = GameData.calc_combined_stats(hero)
	
	var top_lbl = Label.new()
	top_lbl.text = combined["troop_type"] + " · Lv." + str(hero.get("level", 1))
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_lbl.add_theme_font_size_override("font_size", 10)
	top_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(50, 60)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
		img.texture = load(combined["texture_path"])
		
	var name_lbl = Label.new()
	name_lbl.text = "[" + hero.get("quality", "N") + "] " + hero["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
	
	vbox.add_child(top_lbl)
	vbox.add_child(img)
	vbox.add_child(name_lbl)
	
	if is_equipped:
		var tag = Label.new()
		tag.text = "(已上阵)"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		vbox.add_child(tag)
		
	card.add_child(vbox)
	return card

func refresh_right_formation_grid() -> void:
	var count = 0
	for pos in range(1, 10):
		var card = slot_cards[pos - 1] as PanelContainer
		var vbox = card.get_node("VBox")
		var pos_lbl = vbox.get_node("PosLbl") as Label
		var name_lbl = vbox.get_node("NameLbl") as Label
		var img = vbox.get_node("Avatar") as TextureRect
		
		var hero_uuid = GameData.player_formation[pos]
		if hero_uuid != null:
			var hero = GameData.get_hero_by_uuid(hero_uuid)
			if not hero.is_empty():
				count += 1
				var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
				var style = StyleBoxFlat.new()
				style.bg_color = q_cfg["bg_color"]
				style.set_corner_radius_all(6)
				style.border_width_bottom = q_cfg["border_width"]
				style.border_width_left = q_cfg["border_width"]
				style.border_width_right = q_cfg["border_width"]
				style.border_width_top = q_cfg["border_width"]
				style.border_color = q_cfg["border_color"]
				card.add_theme_stylebox_override("panel", style)
				
				var combined = GameData.calc_combined_stats(hero)
				pos_lbl.text = str(pos) + "号位 · Lv." + str(hero.get("level", 1))
				pos_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
				name_lbl.text = "[" + hero.get("quality", "N") + "] " + hero["name"]
				name_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
				
				if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
					img.texture = load(combined["texture_path"])
				else:
					img.texture = null
			else:
				var style = StyleBoxFlat.new()
				style.bg_color = Color(0.12, 0.12, 0.15, 0.7)
				style.set_corner_radius_all(6)
				style.border_color = Color(0.25, 0.25, 0.3)
				card.add_theme_stylebox_override("panel", style)
				
				pos_lbl.text = str(pos) + "号位"
				pos_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.25))
				name_lbl.text = "(空位)"
				name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				img.texture = null
		else:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.12, 0.15, 0.7)
			style.set_corner_radius_all(6)
			style.border_color = Color(0.25, 0.25, 0.3)
			card.add_theme_stylebox_override("panel", style)
			
			pos_lbl.text = str(pos) + "号位"
			pos_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.25))
			name_lbl.text = "(空位)"
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			img.texture = null
			
	grid_title.text = "玩家九宫格阵型 (已上阵 " + str(count) + "/5)"

func open_hero_detail(uuid: String) -> void:
	var modal_scene = load("res://scenes/HeroDetailModal.tscn")
	if modal_scene:
		var modal = modal_scene.instantiate()
		add_child(modal)
		modal.setup(uuid)
		modal.updated.connect(refresh_all)

func _on_open_dismiss_modal() -> void:
	var modal_scene = load("res://scenes/DismissModal.tscn")
	if modal_scene:
		var modal = modal_scene.instantiate()
		add_child(modal)
		if modal.has_signal("dismissed"):
			modal.dismissed.connect(refresh_all)

func _on_auto_fill() -> void:
	GameData.auto_fill_formation()
	refresh_all()

func _on_clear() -> void:
	for pos in range(1, 10):
		GameData.player_formation[pos] = null
	refresh_all()

# 内部类：左侧列表与面板区域（精确接收从右侧拖回的指定武将进行下阵）
class LeftPanelDropScript extends Control:
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "hero_card" and data.get("from_slot", 0) > 0

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if typeof(data) == TYPE_DICTIONARY and data.get("type") == "hero_card":
			var from_slot = data.get("from_slot", 0)
			if from_slot > 0 and from_slot <= 9:
				GameData.player_formation[from_slot] = null
				var parent_ui = get_parent()
				while parent_ui != null and not parent_ui.has_method("refresh_all"):
					parent_ui = parent_ui.get_parent()
				if parent_ui and parent_ui.has_method("refresh_all"):
					parent_ui.refresh_all()

# 内部类：左侧英雄卡片拖拽与双击响应脚本
class HeroCardScript extends PanelContainer:
	var double_click_timer: float = 0.0
	
	func _get_drag_data(_at_position: Vector2) -> Variant:
		var uuid = get_meta("hero_uuid", "")
		if uuid == "":
			return null
			
		var preview = PanelContainer.new()
		preview.custom_minimum_size = Vector2(80, 100)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style.set_corner_radius_all(4)
		preview.add_theme_stylebox_override("panel", style)
		
		var hero = GameData.get_hero_by_uuid(uuid)
		var lbl = Label.new()
		lbl.text = hero.get("name", "卡牌")
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.add_child(lbl)
		
		set_drag_preview(preview)
		return {
			"type": "hero_card",
			"uuid": uuid,
			"from_slot": 0
		}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var now = Time.get_ticks_msec() / 1000.0
			if now - double_click_timer < 0.3:
				var uuid = get_meta("hero_uuid", "")
				if uuid != "":
					var p = get_parent()
					while p != null and not p.has_method("open_hero_detail"):
						p = p.get_parent()
					if p and p.has_method("open_hero_detail"):
						p.open_hero_detail(uuid)
			double_click_timer = now

# 内部类：右侧九宫格槽位卡牌（支持放置拖入卡牌 & 槽位间对拽拖换）
class SlotCardScript extends PanelContainer:
	var double_click_timer: float = 0.0
	
	func _get_drag_data(_at_position: Vector2) -> Variant:
		var pos = get_meta("slot_pos", 0)
		var hero_uuid = GameData.player_formation[pos]
		if hero_uuid == null or hero_uuid == "":
			return null
			
		var preview = PanelContainer.new()
		preview.custom_minimum_size = Vector2(90, 120)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 0.85)
		style.set_corner_radius_all(4)
		preview.add_theme_stylebox_override("panel", style)
		
		var hero = GameData.get_hero_by_uuid(hero_uuid)
		var lbl = Label.new()
		lbl.text = hero.get("name", "卡牌")
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.add_child(lbl)
		
		set_drag_preview(preview)
		return {
			"type": "hero_card",
			"uuid": hero_uuid,
			"from_slot": pos
		}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "hero_card"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if typeof(data) != TYPE_DICTIONARY or data.get("type") != "hero_card":
			return
			
		var incoming_uuid = data.get("uuid", "")
		var from_slot = data.get("from_slot", 0)
		var target_slot = get_meta("slot_pos", 0)
		
		if target_slot < 1 or target_slot > 9:
			return
			
		if from_slot == 0:
			# 从左侧列表拖拽上阵到当前槽位
			for p in range(1, 10):
				if GameData.player_formation[p] == incoming_uuid:
					GameData.player_formation[p] = null
			GameData.player_formation[target_slot] = incoming_uuid
		else:
			# 从右侧九宫格槽位互相拖拽调整交换位置
			var existing_uuid_at_target = GameData.player_formation[target_slot]
			GameData.player_formation[target_slot] = incoming_uuid
			GameData.player_formation[from_slot] = existing_uuid_at_target
			
		var parent_ui = get_parent()
		while parent_ui != null and not parent_ui.has_method("refresh_all"):
			parent_ui = parent_ui.get_parent()
		if parent_ui and parent_ui.has_method("refresh_all"):
			parent_ui.refresh_all()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var now = Time.get_ticks_msec() / 1000.0
			if now - double_click_timer < 0.3:
				var pos = get_meta("slot_pos", 0)
				var hero_uuid = GameData.player_formation[pos]
				if hero_uuid != null and hero_uuid != "":
					var p = get_parent()
					while p != null and not p.has_method("open_hero_detail"):
						p = p.get_parent()
					if p and p.has_method("open_hero_detail"):
						p.open_hero_detail(hero_uuid)
			double_click_timer = now
