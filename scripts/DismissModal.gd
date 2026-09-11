extends ColorRect

@onready var btn_close: Button = $Panel/Margin/VBox/TitleBox/BtnClose
@onready var btn_select_n: Button = $Panel/Margin/VBox/FilterBox/BtnSelectN
@onready var btn_select_r: Button = $Panel/Margin/VBox/FilterBox/BtnSelectR
@onready var btn_select_sr: Button = $Panel/Margin/VBox/FilterBox/BtnSelectSR
@onready var btn_select_ssr: Button = $Panel/Margin/VBox/FilterBox/BtnSelectSSR
@onready var btn_select_ur: Button = $Panel/Margin/VBox/FilterBox/BtnSelectUR
@onready var btn_select_all_valid: Button = $Panel/Margin/VBox/FilterBox/BtnSelectAllValid
@onready var btn_clear_select: Button = $Panel/Margin/VBox/FilterBox/BtnClearSelect
@onready var list_vbox: VBoxContainer = $Panel/Margin/VBox/Scroll/ListVBox
@onready var summary_lbl: Label = $Panel/Margin/VBox/BottomBox/SummaryLbl
@onready var btn_confirm_dismiss: Button = $Panel/Margin/VBox/BottomBox/BtnConfirmDismiss

var selected_uuids: Dictionary = {} # uuid -> bool
var last_clicked_index: int = -1
var item_rows: Array = [] # 记录可视行的渲染数据 [{ "uuid": String, "checkbox": CheckBox, ... }]

signal dismissed()

func _ready() -> void:
	btn_close.pressed.connect(queue_free)
	btn_select_n.pressed.connect(func(): select_by_quality("N"))
	btn_select_r.pressed.connect(func(): select_by_quality("R"))
	btn_select_sr.pressed.connect(func(): select_by_quality("SR"))
	btn_select_ssr.pressed.connect(func(): select_by_quality("SSR"))
	btn_select_ur.pressed.connect(func(): select_by_quality("UR"))
	btn_select_all_valid.pressed.connect(select_all_valid)
	btn_clear_select.pressed.connect(clear_all_selections)
	btn_confirm_dismiss.pressed.connect(_on_confirm_dismiss)
	
	refresh_hero_list()

func refresh_hero_list() -> void:
	for child in list_vbox.get_children():
		child.queue_free()
		
	item_rows.clear()
	last_clicked_index = -1
	
	var equipped_uuids = []
	for pos in GameData.player_formation.keys():
		var uid = GameData.player_formation[pos]
		if uid != null:
			equipped_uuids.append(uid)
			
	var all_heroes = GameData.player_heroes.duplicate()
	# 排序：限制条件（已上阵/非Lv.1）靠后，可解雇在前的顺序列出
	all_heroes.sort_custom(func(a, b):
		var a_eq = a["uuid"] in equipped_uuids or a.get("level", 1) > 1
		var b_eq = b["uuid"] in equipped_uuids or b.get("level", 1) > 1
		if a_eq != b_eq:
			return not a_eq
		var q_a = GameData.get_quality_config(a.get("quality", "N"))["rank_weight"]
		var q_b = GameData.get_quality_config(b.get("quality", "N"))["rank_weight"]
		return q_a > q_b
	)
	
	for idx in range(all_heroes.size()):
		var hero = all_heroes[idx]
		var uid = hero["uuid"]
		var level = hero.get("level", 1)
		var is_equipped = uid in equipped_uuids
		var is_valid = (not is_equipped) and (level == 1)
		
		var row = PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 44)
		
		var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		style.set_corner_radius_all(4)
		style.border_width_left = 4
		style.border_color = q_cfg["border_color"]
		row.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 15)
		
		var cb = CheckBox.new()
		cb.disabled = not is_valid
		cb.button_pressed = selected_uuids.get(uid, false) if is_valid else false
		cb.pressed.connect(func(): _on_checkbox_clicked(idx))
		hbox.add_child(cb)
		
		var combined = GameData.calc_combined_stats(hero)
		var name_lbl = Label.new()
		name_lbl.text = "[" + hero.get("quality", "N") + "] " + hero.get("name", "武将") + " (" + combined["troop_name"] + ")"
		name_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var status_lbl = Label.new()
		if is_equipped:
			status_lbl.text = "⚠️ 已在阵型中 (无法解雇)"
			status_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		elif level > 1:
			status_lbl.text = "⚠️ Lv." + str(level) + " (请先洗练降至Lv.1)"
			status_lbl.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
		else:
			status_lbl.text = "可解雇 (+ " + str(q_cfg.get("dismiss_gold", 30)) + " 金币)"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		status_lbl.add_theme_font_size_override("font_size", 14)
		hbox.add_child(status_lbl)
		
		row.add_child(hbox)
		list_vbox.add_child(row)
		
		item_rows.append({
			"uuid": uid,
			"valid": is_valid,
			"checkbox": cb,
			"quality": hero.get("quality", "N"),
			"dismiss_gold": q_cfg.get("dismiss_gold", 30)
		})
		
	update_summary_display()

func _on_checkbox_clicked(idx: int) -> void:
	var row_data = item_rows[idx]
	if not row_data["valid"]:
		return
		
	# 支持 Shift 键连续多选范围
	if Input.is_key_pressed(KEY_SHIFT) and last_clicked_index != -1:
		var start_idx = min(last_clicked_index, idx)
		var end_idx = max(last_clicked_index, idx)
		var target_state = row_data["checkbox"].button_pressed
		for i in range(start_idx, end_idx + 1):
			var r = item_rows[i]
			if r["valid"]:
				r["checkbox"].button_pressed = target_state
				selected_uuids[r["uuid"]] = target_state
	else:
		selected_uuids[row_data["uuid"]] = row_data["checkbox"].button_pressed
		last_clicked_index = idx
		
	update_summary_display()

func select_by_quality(qual: String) -> void:
	for r in item_rows:
		if r["valid"] and r["quality"] == qual:
			r["checkbox"].button_pressed = true
			selected_uuids[r["uuid"]] = true
	update_summary_display()

func select_all_valid() -> void:
	for r in item_rows:
		if r["valid"]:
			r["checkbox"].button_pressed = true
			selected_uuids[r["uuid"]] = true
	update_summary_display()

func clear_all_selections() -> void:
	selected_uuids.clear()
	for r in item_rows:
		r["checkbox"].button_pressed = false
	update_summary_display()

func update_summary_display() -> void:
	var total_count = 0
	var total_gold = 0
	for r in item_rows:
		if r["valid"] and selected_uuids.get(r["uuid"], false):
			total_count += 1
			total_gold += r["dismiss_gold"]
			
	summary_lbl.text = "已选择: " + str(total_count) + " 人 | 预计可解雇获得金币: +" + str(total_gold)
	btn_confirm_dismiss.disabled = (total_count == 0)

func _on_confirm_dismiss() -> void:
	var uuids_to_dismiss = []
	for uid in selected_uuids.keys():
		if selected_uuids[uid] == true:
			uuids_to_dismiss.append(uid)
			
	if uuids_to_dismiss.size() == 0:
		return
		
	var gained_gold = GameData.dismiss_heroes(uuids_to_dismiss)
	selected_uuids.clear()
	refresh_hero_list()
	emit_signal("dismissed")
