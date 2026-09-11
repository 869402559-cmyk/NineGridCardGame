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
			
	for hero in GameData.player_heroes:
		var card = create_hero_portrait_card(hero, hero["uuid"] in equipped_uuids)
		hero_grid.add_child(card)

# 创建左侧英雄 3:4 头像卡片 (支持拖拽与双击打开详情)
func create_hero_portrait_card(hero: Dictionary, is_equipped: bool) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(95, 126) # 3:4 比例
	card.set_meta("hero_uuid", hero["uuid"])
	card.script = HeroCardScript
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	var combined = GameData.calc_combined_stats(hero)
	
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(60, 80)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
		img.texture = load(combined["texture_path"])
	vbox.add_child(img)
	
	var name_lbl = Label.new()
	var eq_str = " [已上阵]" if is_equipped else ""
	name_lbl.text = "[" + hero["quality"] + "]
" + hero["name"] + eq_str
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	if is_equipped:
		name_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
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
			pos_lbl.text = str(pos) + "号位 [" + combined["troop_type"] + "]"
			name_lbl.text = "[" + hero.get("quality", "N") + "] " + hero.get("name", "未知") + "
Lv." + str(hero.get("level", 1))
			if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
				img.texture = load(combined["texture_path"])
			else:
				img.texture = null
		else:
			pos_lbl.text = str(pos) + "号位"
			name_lbl.text = "(空位)"
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
		lbl.text = "[" + hero.get("quality", "") + "] " + hero.get("name", "")
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		preview.add_child(lbl)
		set_drag_preview(preview)
		return { "type": "hero_card", "uuid": uuid }

# 内部类：阵型放置槽位目标
class SlotCardScript extends PanelContainer:
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "hero_card"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var target_pos = get_meta("slot_pos") as int
		var dragged_uuid = data.get("uuid") as String
		
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
