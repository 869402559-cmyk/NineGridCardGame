extends Control

@onready var gold_label: Label = $TopBox/ResBox/GoldLabel
@onready var exp_label: Label = $TopBox/ResBox/ExpLabel
@onready var account_label: Label = $TopBox/AccountLabel
@onready var btn_save: Button = $TopBox/ResBox/BtnSave
@onready var btn_logout: Button = $TopBox/ResBox/BtnLogout
@onready var btn_gacha: Button = $NavBox/BtnGacha
@onready var btn_formation: Button = $NavBox/BtnFormation
@onready var btn_battle: Button = $NavBox/BtnBattle
@onready var content_panel: MarginContainer = $ContentPanel

var gacha_view: Control
var formation_view: Control
var battle_view: Control

func _ready() -> void:
	btn_gacha.pressed.connect(_on_gacha_pressed)
	btn_formation.pressed.connect(_on_formation_pressed)
	btn_battle.pressed.connect(_on_battle_pressed)
	btn_save.pressed.connect(_on_save_pressed)
	btn_logout.pressed.connect(_on_logout_pressed)
	
	GameData.gold_changed.connect(update_resources)
	GameData.exp_changed.connect(update_resources)
	GameData.save_status_changed.connect(_on_save_status_changed)
	
	account_label.text = "主公: " + GameData.current_account
	update_resources()
	_on_formation_pressed()

func update_resources() -> void:
	gold_label.text = "💰 金币: " + str(GameData.player_gold)
	exp_label.text = "✨ 经验池: " + str(GameData.player_exp_pool)

func _on_save_pressed() -> void:
	GameData.save_current_progress()

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

func _on_gacha_pressed() -> void:
	clear_content()
	var gacha_scene = load("res://scenes/GachaUI.tscn")
	if gacha_scene:
		gacha_view = gacha_scene.instantiate()
		content_panel.add_child(gacha_view)
		if gacha_view.has_signal("gold_changed"):
			gacha_view.gold_changed.connect(update_resources)

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
