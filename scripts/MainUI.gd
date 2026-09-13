extends Control

@onready var gold_label: Label = $TopBox/ResBox/GoldLabel
@onready var exp_label: Label = $TopBox/ResBox/ExpLabel
@onready var account_label: Label = $TopBox/AccountLabel
@onready var btn_save: Button = $TopBox/ResBox/BtnSave
@onready var btn_manage_acc: Button = $TopBox/ResBox/BtnManageAcc
@onready var btn_logout: Button = $TopBox/ResBox/BtnLogout
@onready var btn_gacha: Button = $NavBox/BtnGacha
@onready var btn_formation: Button = $NavBox/BtnFormation
@onready var btn_battle: Button = $NavBox/BtnBattle
@onready var content_panel: MarginContainer = $ContentPanel

var prestige_label: Label

var gacha_view: Control
var formation_view: Control
var campaign_view: Control
var battle_view: Control

func _ready() -> void:
	btn_gacha.text = "🍺 招贤酒馆"
	btn_gacha.pressed.connect(_on_tavern_pressed)
	btn_formation.pressed.connect(_on_formation_pressed)
	btn_battle.pressed.connect(_on_campaign_pressed)
	btn_save.pressed.connect(_on_save_pressed)
	if btn_manage_acc:
		btn_manage_acc.pressed.connect(_on_manage_acc_pressed)
	btn_logout.pressed.connect(_on_logout_pressed)
	
	# 添加威望标签
	var res_box = $TopBox/ResBox
	prestige_label = Label.new()
	prestige_label.name = "PrestigeLabel"
	prestige_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	prestige_label.add_theme_font_size_override("font_size", 18)
	res_box.add_child(prestige_label)
	res_box.move_child(prestige_label, 2)
	
	btn_battle.text = "🗺️ 主线征战"
	
	GameData.gold_changed.connect(update_resources)
	GameData.exp_changed.connect(update_resources)
	GameData.prestige_changed.connect(update_resources)
	GameData.save_status_changed.connect(_on_save_status_changed)
	
	account_label.text = "主公: " + GameData.current_account
	update_resources()
	
	# 首次进入检测：若尚未挑选初始武将，自动弹出 8 选 1 武将选择框
	check_and_show_initial_hero_selection()
	
	# 默认打开主线关卡卷轴地图界面
	_on_campaign_pressed()

func update_resources() -> void:
	gold_label.text = "💰 金币: " + str(GameData.player_gold)
	exp_label.text = "✨ 经验: " + str(GameData.player_exp_pool)
	if prestige_label:
		prestige_label.text = "🎖️ 威望: " + str(GameData.player_prestige)

func _on_campaign_pressed() -> void:
	clear_content()
	var camp_scene = load("res://scenes/CampaignUI.tscn")
	if camp_scene:
		campaign_view = camp_scene.instantiate()
		content_panel.add_child(campaign_view)

func start_stage_battle(stage_data: Dictionary) -> void:
	clear_content()
	var battle_scene = load("res://scenes/BattleUI.tscn")
	if battle_scene:
		battle_view = battle_scene.instantiate()
		content_panel.add_child(battle_view)
		if battle_view.has_method("setup_stage_battle"):
			battle_view.setup_stage_battle(stage_data)

func _on_save_pressed() -> void:
	if GameData.is_in_battle:
		btn_save.text = "⚠️ 战斗中不可保存"
		await get_tree().create_timer(1.5).timeout
		btn_save.text = "💾 保存存档"
		return
	GameData.save_current_progress()

func _on_manage_acc_pressed() -> void:
	var modal_scene = load("res://scenes/AccountManageModal.tscn")
	if modal_scene:
		var modal = modal_scene.instantiate()
		add_child(modal)

func _on_save_status_changed(msg: String) -> void:
	btn_save.text = "✅ 已保存"
	await get_tree().create_timer(1.5).timeout
	btn_save.text = "💾 保存存档"

func _on_logout_pressed() -> void:
	GameData.current_account = ""
	get_tree().change_scene_to_file("res://scenes/LoginUI.tscn")

func clear_content() -> void:
	for child in content_panel.get_children():
		child.queue_free()

func _on_tavern_pressed() -> void:
	var tavern_scene = load("res://scenes/TavernUI.tscn")
	if tavern_scene:
		var tavern = tavern_scene.instantiate()
		add_child(tavern)
		if tavern.has_signal("closed"):
			tavern.closed.connect(update_resources)

# 首次登录 8 选 1 初始武将选角框
func check_and_show_initial_hero_selection() -> void:
	if GameData.chosen_initial_hero or GameData.player_heroes.size() > 0:
		return
		
	var dialog = AcceptDialog.new()
	dialog.title = "👑 请选择您的初始主将 (8选1)"
	dialog.dialog_text = "根据《傲视天地》法则，请从8个基础兵种中挑选一位担任您的初始阵营主将！"
	dialog.size = Vector2i(720, 480)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	
	# 过滤出 8 个基础输出武将模板 (source_type == "base")
	var base_list = []
	for tmpl in GameData.HERO_TEMPLATES.values():
		if tmpl.get("source_type", "") == "base":
			base_list.append(tmpl)
			
	for tmpl in base_list:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 180)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.2, 0.95)
		var q_cfg = GameData.get_quality_config(tmpl.get("quality", "N"))
		sb.border_color = q_cfg.get("color", Color.GOLD)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", sb)
		
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_top", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.add_theme_constant_override("margin_bottom", 8)
		card.add_child(m)
		
		var cvbox = VBoxContainer.new()
		m.add_child(cvbox)
		
		var name_lbl = Label.new()
		name_lbl.text = tmpl.get("name", "")
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", q_cfg.get("color", Color.WHITE))
		cvbox.add_child(name_lbl)
		
		var troop = GameData.get_troop_by_id(tmpl.get("troop_id", ""))
		var t_lbl = Label.new()
		t_lbl.text = "兵种: " + troop.get("name", "") + "
(" + troop.get("type_name", "") + ")"
		t_lbl.add_theme_font_size_override("font_size", 12)
		cvbox.add_child(t_lbl)
		
		var sp = Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cvbox.add_child(sp)
		
		var btn = Button.new()
		btn.text = "选择此将"
		cvbox.add_child(btn)
		
		btn.pressed.connect(func():
			GameData.choose_initial_hero(tmpl.get("id", ""))
			dialog.queue_free()
			update_resources()
			_on_campaign_pressed()
		)
		
		grid.add_child(card)
		
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _on_formation_pressed() -> void:
	clear_content()
	var formation_scene = load("res://scenes/FormationUI.tscn")
	if formation_scene:
		formation_view = formation_scene.instantiate()
		content_panel.add_child(formation_view)

func _on_battle_pressed() -> void:
	clear_content()
	var battle_scene = load("res://scenes/BattleUI.tscn")
	if battle_scene:
		battle_view = battle_scene.instantiate()
		content_panel.add_child(battle_view)
