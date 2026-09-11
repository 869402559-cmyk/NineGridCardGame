extends ColorRect

@onready var avatar_texture: TextureRect = $Panel/Margin/HBox/LeftBox/PortraitCard/VBox/AvatarTexture
@onready var name_quality_lbl: Label = $Panel/Margin/HBox/LeftBox/PortraitCard/VBox/NameQualityLbl
@onready var level_lbl: Label = $Panel/Margin/HBox/LeftBox/PortraitCard/VBox/LevelLbl
@onready var btn_upgrade: Button = $Panel/Margin/HBox/LeftBox/BtnUpgrade
@onready var btn_close: Button = $Panel/Margin/HBox/RightBox/TitleBox/BtnClose
@onready var info_text: RichTextLabel = $Panel/Margin/HBox/RightBox/Scroll/InfoText

var current_hero_uuid: String = ""

signal updated()

func _ready() -> void:
	btn_close.pressed.connect(queue_free)
	btn_upgrade.pressed.connect(_on_upgrade_pressed)
	if current_hero_uuid != "":
		refresh_display()

func setup(hero_uuid: String) -> void:
	current_hero_uuid = hero_uuid
	if is_node_ready():
		refresh_display()

func refresh_display() -> void:
	var hero = GameData.get_hero_by_uuid(current_hero_uuid)
	if hero.is_empty():
		return
		
	var combined = GameData.calc_combined_stats(hero)
	var troop = GameData.get_troop_by_id(hero.get("troop_id", "t_cavalry"))
	
	name_quality_lbl.text = "[" + hero.get("quality", "N") + "] " + hero.get("name", "武将")
	level_lbl.text = "等级: Lv." + str(hero.get("level", 1))
	
	var cost = GameData.get_upgrade_cost(hero.get("level", 1))
	btn_upgrade.text = "手动升级 (消耗 " + str(cost) + " 经验)"
	if GameData.player_exp_pool < cost:
		btn_upgrade.disabled = true
	else:
		btn_upgrade.disabled = false
		
	if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
		avatar_texture.texture = load(combined["texture_path"])
	else:
		avatar_texture.texture = null
		
	var info_bbcode = ""
	info_bbcode += "[color=gold][b]👤 武将基础属性[/b][/color]
"
	info_bbcode += "• 姓名: " + hero.get("name", "") + " | 品质: " + hero.get("quality", "") + "
"
	info_bbcode += "• 等级: Lv." + str(hero.get("level", 1)) + "
"
	info_bbcode += "• 武将自身面板: 血量 " + str(hero.get("hp", 0)) + " | 攻击 " + str(hero.get("atk", 0)) + " | 防御 " + str(hero.get("def", 0)) + "
"
	info_bbcode += "• 战法攻击 " + str(hero.get("satk", 0)) + " | 战法防御 " + str(hero.get("sdef", 0)) + " | 速度 " + str(hero.get("spd", 0)) + "

"
	
	info_bbcode += "[color=cyan][b]🛡️ 统领兵种信息[/b][/color]
"
	info_bbcode += "• 兵种名称: " + combined["troop_name"] + " (" + combined["troop_type"] + ")
"
	info_bbcode += "• 兵种基础: 攻击 " + str(troop.get("atk", 0)) + " | 防御 " + str(troop.get("def", 0)) + " | 战攻 " + str(troop.get("satk", 0)) + " | 战防 " + str(troop.get("sdef", 0)) + "
"
	info_bbcode += "• 闪避率: [color=green]" + str(int(combined["evade_rate"] * 100)) + "%[/color] (固定只由兵种决定)
"
	info_bbcode += "• 攻击方式: " + combined["atk_type"] + "
"
	info_bbcode += "• 兵种战法: [color=orange]" + combined["skill_name"] + "[/color]
"
	info_bbcode += "• 战法描述: " + combined["skill_desc"] + "

"
	
	info_bbcode += "[color=green][b]⚖️ 实战结算综合属性 (英雄70% + 兵种30%)[/b][/color]
"
	info_bbcode += "• 实战生命值: [color=red]" + str(combined["hp"]) + "[/color]
"
	info_bbcode += "• 实战攻击力: [color=yellow]" + str(combined["atk"]) + "[/color]  (英雄" + str(hero.get("atk", 0)) + "*70% + 兵种" + str(troop.get("atk", 0)) + "*30%)
"
	info_bbcode += "• 实战防御力: [color=lightblue]" + str(combined["def"]) + "[/color]  (英雄" + str(hero.get("def", 0)) + "*70% + 兵种" + str(troop.get("def", 0)) + "*30%)
"
	info_bbcode += "• 实战战法攻: " + str(combined["satk"]) + " | 实战战法防: " + str(combined["sdef"]) + "
"
	
	info_text.text = info_bbcode

func _on_upgrade_pressed() -> void:
	if GameData.upgrade_hero(current_hero_uuid):
		refresh_display()
		emit_signal("updated")
