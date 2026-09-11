extends Control

@onready var hero_grid: GridContainer = $HBox/LeftPanel/HeroScroll/HeroGrid
@onready var btn_auto: Button = $HBox/LeftPanel/TitleBox/BtnAuto
@onready var btn_clear: Button = $HBox/LeftPanel/TitleBox/BtnClear
@onready var grid_container: GridContainer = $HBox/RightPanel/GridContainer
@onready var grid_title: Label = $HBox/RightPanel/GridTitle

var slot_cards: Array = [] # 1..9 slot controls

func _ready() -> void:
	btn_auto.pressed.connect(_on_auto_fill)
	btn_clear.pressed.connect(_on_clear)
	
	# 设置左侧整个面板（LeftPanel）支持接收右侧卡牌拖入以进行下阵
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

# 创建九宫格阵型位（卡牌支持作为拖拽目标）
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
			
	# 克隆武将列表并进行排序：已上阵优先，其次按品质(UR>SSR>SR>R>N)，再次按等级
	var sorted_heroes = GameData.player_heroes.duplicate()
	sorted_heroes.sort_custom(func(a, b):
		var a_eq = a["uuid"] in equipped_uuids
		var b_eq = b["uuid"] in equipped_uuids
		if a_eq != b_eq:
			return a_eq # 已上阵在前的降序 (true > false)
			
		var q_a = GameData.get_quality_config(a.get("quality", "N"))["rank"]
		var q_b = GameData.get_quality_config(b.get("quality", "N"))["rank"]
		if q_a != q_b:
			return q_a > q_b # 品质高者在前
			
		var lv_a = a.get("level", 1)
		var lv_b = b.get("level", 1)
		return lv_a > lv_b
	)
			
	for hero in sorted_heroes:
		var card = create_hero_portrait_card(hero, hero["uuid"] in equipped_uuids)
		hero_grid.add_child(card)

# 创建左侧英雄 3:4 头像卡片 (支持拖拽与双击打开详情)
func create_hero_portrait_card(hero: Dictionary, is_equipped: bool) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(88, 118) # 适配 4 列容器
	card.set_meta("hero_uuid", hero["uuid"])
	card.script = HeroCardScript
	
	# 设置品质框体样式
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
	card.add_child(vbox)
	
	var combined = GameData.calc_combined_stats(hero)
	
	# 顶部兵种与等级小角标
	var top_info = Label.new()
	top_info.text = combined["troop_type"] + " · Lv." + str(hero.get("level", 1))
	top_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_info.add_theme_font_size_override("font_size", 10)
	top_info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	vbox.add_child(top_info)
	
	# 武将大头像/立绘
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(50, 65)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
		img.texture = load(combined["texture_path"])
	vbox.add_child(img)
	
	# 底部名字与品质
	var name_lbl = Label.new()
	var eq_str = " [已上阵]" if is_equipped else ""
	name_lbl.text = "[" + hero.get("quality", "N") + "] " + hero.get("name", "武将") + eq_str
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	if is_equipped:
		name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		name_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
	vbox.add_child(name_lbl)
	
	# 双击 / 点击事件
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				open_hero_detail(hero["uuid"])
	)
	
	return card

func refresh_right_formation_grid() -> void:
	var count = 0
	for pos in range(1, 10):
		var card = slot_cards[pos - 1] as Control
		var uuid = GameData.player_formation[pos]
		var pos_lbl = card.find_child("PosLbl", true, false) as Label
		var img = card.find_child("Avatar", true, false) as TextureRect
		var name_lbl = card.find_child("NameLbl", true, false) as Label
		
		if uuid != null:
			count += 1
			var hero = GameData.get_hero_by_uuid(uuid)
			var combined = GameData.calc_combined_stats(hero)
			var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
			
			# 动态应用品质边框样式
			var style = StyleBoxFlat.new()
			style.bg_color = q_cfg["bg_color"]
			style.set_corner_radius_all(6)
			style.border_width_bottom = q_cfg["border_width"]
			style.border_width_left = q_cfg["border_width"]
			style.border_width_right = q_cfg["border_width"]
			style.border_width_top = q_cfg["border_width"]
			style.border_color = q_cfg["border_color"]
			card.add_theme_stylebox_override("panel", style)
			
			pos_lbl.text = str(pos) + "号位 [" + combined["troop_type"] + "]"
			pos_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			name_lbl.text = "[" + hero.get("quality", "N") + "] " + hero.get("name", "未知") + "
Lv." + str(hero.get("level", 1))
			name_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
			
			if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
				img.texture = load(combined["texture_path"])
			else:
				img.texture = null
		else:
			# 空槽位样式
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
			style.set_corner_radius_all(6)
			style.border_width_bottom = 1
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_color = Color(0.3, 0.3, 0.3, 0.5)
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

func _on_auto_fill() -> void:
	GameData.auto_fill_formation()
	refresh_all()

func _on_clear() -> void:
	for pos in range(1, 10):
		GameData.player_formation[pos] = null
	refresh_all()

# 内部类：拖拽英雄头像源卡片
class HeroCardScript extends PanelContainer:
	func _get_drag_data(_at_position: Vector2) -> Variant:
		var uuid = get_meta("hero_uuid")
		var preview = Control.new()
		var lbl = Label.new()
		var hero = GameData.get_hero_by_uuid(uuid)
		var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
		lbl.text = "[" + hero.get("quality", "") + "] " + hero.get("name", "")
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", q_cfg["label_color"])
		preview.add_child(lbl)
		set_drag_preview(preview)
		return { "type": "hero_card", "uuid": uuid, "from": "left_list" }

# 内部类：左侧列表与面板区域（接收从右侧拖回的武将进行下阵）
class LeftPanelDropScript extends VBoxContainer:
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "hero_card"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var dragged_uuid = data.get("uuid") as String
		# 将该武将从右侧阵型中移除（下阵）
		for p in range(1, 10):
			if GameData.player_formation[p] == dragged_uuid:
				GameData.player_formation[p] = null
				
		GameData.has_unsaved_changes = true
		
		# 安全获取 FormationUI 并刷新
		var p_node: Node = self
		while p_node:
			if p_node.has_method("refresh_all"):
				p_node.refresh_all()
				break
			p_node = p_node.get_parent()

	# 拖拽下阵：如果卡片被释放拖拽（且未被九宫格接收），判定为拖出阵型下阵
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			if not is_drag_successful():
				var pos = get_meta("slot_pos") as int
				if GameData.player_formation[pos] != null:
					GameData.player_formation[pos] = null
					GameData.has_unsaved_changes = true
					
					var p_node: Node = self
					while p_node:
						if p_node.has_method("refresh_all"):
							p_node.refresh_all()
							break
						p_node = p_node.get_parent()

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var pos = get_meta("slot_pos") as int
		var uuid = GameData.player_formation[pos]
		if uuid == null:
			return null
		
		var preview = Control.new()
		var lbl = Label.new()
		var hero = GameData.get_hero_by_uuid(uuid)
		var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
		lbl.text = "[" + hero.get("quality", "") + "] " + hero.get("name", "")
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", q_cfg["label_color"])
		preview.add_child(lbl)
		set_drag_preview(preview)
		return { "type": "hero_card", "uuid": uuid, "from_slot": pos }

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "hero_card"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var target_pos = get_meta("slot_pos") as int
		var dragged_uuid = data.get("uuid") as String
		var from_slot = data.get("from_slot", 0) as int
		
		if from_slot > 0:
			# 来自右侧九宫格另一个槽位：直接互换或移动位置
			var target_uuid = GameData.player_formation[target_pos]
			GameData.player_formation[target_pos] = dragged_uuid
			GameData.player_formation[from_slot] = target_uuid
		else:
			# 来自左侧列表：放置上阵
			# 若已在其他槽位，先清空原槽位
			for p in range(1, 10):
				if GameData.player_formation[p] == dragged_uuid:
					GameData.player_formation[p] = null
					
			# 检查 5 人限制
			var current_count = 0
			for p in range(1, 10):
				if GameData.player_formation[p] != null:
					current_count += 1
					
			if current_count >= 5 and GameData.player_formation[target_pos] == null:
				# 满5人无法放入空位
				pass
			else:
				GameData.player_formation[target_pos] = dragged_uuid
			
		GameData.has_unsaved_changes = true
		var parent_ui = get_tree().current_scene.find_child("FormationUI", true, false)
		if parent_ui:
			parent_ui.refresh_all()
		else:
			var p_node = get_parent()
			while p_node:
				if p_node.has_method("refresh_all"):
					p_node.refresh_all()
					break
				p_node = p_node.get_parent()
