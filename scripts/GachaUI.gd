extends Control

signal gold_changed

@onready var btn_draw_one: Button = $VBox/BtnBox/BtnDrawOne
@onready var btn_draw_ten: Button = $VBox/BtnBox/BtnDrawTen
@onready var result_grid: GridContainer = $VBox/ResultScroll/ResultGrid

func _ready() -> void:
	btn_draw_one.pressed.connect(_on_draw_one)
	btn_draw_ten.pressed.connect(_on_draw_ten)

func _on_draw_one() -> void:
	if GameData.player_gold < 100:
		return
	GameData.player_gold -= 100
	GameData.emit_signal("gold_changed")
	emit_signal("gold_changed")
	
	clear_results()
	var hero = perform_single_draw()
	add_card_display(hero)

func _on_draw_ten() -> void:
	if GameData.player_gold < 1000:
		return
	GameData.player_gold -= 1000
	GameData.emit_signal("gold_changed")
	emit_signal("gold_changed")
	
	clear_results()
	for i in range(10):
		var hero = perform_single_draw()
		add_card_display(hero)

func perform_single_draw() -> Dictionary:
	var rand_val = randf() * 100.0
	var quality = "N"
	if rand_val < 1.0:
		quality = "UR"
	elif rand_val < 5.0: # 1% + 4% = 5%
		quality = "SSR"
	elif rand_val < 20.0: # 5% + 15% = 20%
		quality = "SR"
	elif rand_val < 55.0: # 20% + 35% = 55%
		quality = "R"
	else:
		quality = "N"
		
	var pool = []
	for key in GameData.HERO_TEMPLATES.keys():
		if GameData.HERO_TEMPLATES[key]["quality"] == quality:
			pool.append(key)
			
	if pool.size() == 0:
		pool = ["h_14"]
		
	var chosen_id = pool[randi() % pool.size()]
	return GameData.add_hero(chosen_id)

func clear_results() -> void:
	for child in result_grid.get_children():
		child.queue_free()

func add_card_display(hero: Dictionary) -> void:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 160)
	
	var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
	var style = StyleBoxFlat.new()
	style.bg_color = q_cfg["bg_color"]
	style.set_corner_radius_all(8)
	style.border_width_bottom = q_cfg["border_width"]
	style.border_width_left = q_cfg["border_width"]
	style.border_width_right = q_cfg["border_width"]
	style.border_width_top = q_cfg["border_width"]
	style.border_color = q_cfg["border_color"]
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var combined = GameData.calc_combined_stats(hero)
	
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(50, 65)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
		img.texture = load(combined["texture_path"])
	vbox.add_child(img)
	
	var qual_lbl = Label.new()
	qual_lbl.text = "[" + hero.get("quality", "N") + "] " + combined["troop_type"]
	qual_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qual_lbl.add_theme_font_size_override("font_size", 13)
	qual_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
	
	var name_lbl = Label.new()
	name_lbl.text = hero["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
	
	var skill_lbl = Label.new()
	skill_lbl.text = "战法: " + combined["skill_name"]
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_lbl.add_theme_font_size_override("font_size", 12)
	skill_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	vbox.add_child(qual_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(skill_lbl)
	card.add_child(vbox)
	
	result_grid.add_child(card)
