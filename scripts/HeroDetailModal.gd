extends ColorRect

@onready var avatar_texture: TextureRect = $Panel/Margin/HBox/LeftBox/PortraitCard/AvatarTexture
@onready var name_quality_lbl: Label = $Panel/Margin/HBox/LeftBox/InfoSubBox/NameQualityLbl
@onready var level_lbl: Label = $Panel/Margin/HBox/LeftBox/InfoSubBox/LevelLbl
@onready var btn_upgrade: Button = $Panel/Margin/HBox/LeftBox/BtnUpgrade
@onready var btn_reset_level: Button = $Panel/Margin/HBox/LeftBox/BtnResetLevel
@onready var btn_close: Button = $Panel/Margin/HBox/RightBox/TitleBox/BtnClose
@onready var info_text: RichTextLabel = $Panel/Margin/HBox/RightBox/Scroll/InfoText

var current_hero_uuid: String = ""

signal updated()

func _ready() -> void:
	btn_close.pressed.connect(queue_free)
	btn_upgrade.pressed.connect(_on_upgrade_pressed)
	if btn_reset_level:
		btn_reset_level.pressed.connect(_on_reset_level_pressed)
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
	var q_cfg = GameData.get_quality_config(hero.get("quality", "N"))
	
	# 设置左侧头像框品质底色与边框
	var portrait_card = $Panel/Margin/HBox/LeftBox/PortraitCard as PanelContainer
	if portrait_card:
		var style = StyleBoxFlat.new()
		style.bg_color = q_cfg["bg_color"]
		style.set_corner_radius_all(8)
		style.border_width_bottom = q_cfg["border_width"]
		style.border_width_left = q_cfg["border_width"]
		style.border_width_right = q_cfg["border_width"]
		style.border_width_top = q_cfg["border_width"]
		style.border_color = q_cfg["border_color"]
		portrait_card.add_theme_stylebox_override("panel", style)
		
	name_quality_lbl.text = "[" + hero.get("quality", "N") + "] " + hero.get("name", "武将")
	name_quality_lbl.add_theme_color_override("font_color", q_cfg["label_color"])
	level_lbl.text = "等级: Lv." + str(hero.get("level", 1))
	
	var cost = GameData.get_upgrade_cost(hero.get("level", 1))
	btn_upgrade.text = "手动升级 (消耗 " + str(cost) + " 经验)"
	if GameData.player_exp_pool < cost:
		btn_upgrade.disabled = true
	else:
		btn_upgrade.disabled = false
		
	var hero_lv = hero.get("level", 1)
	if btn_reset_level:
		if hero_lv > 1:
			var refund_exp = GameData.get_reset_level_refund_exp(hero)
			btn_reset_level.text = "🔄 洗练洗等级 (返还 " + str(refund_exp) + " 经验)"
			btn_reset_level.disabled = false
		else:
			btn_reset_level.text = "🔄 已经是 Lv.1 (无须洗练)"
			btn_reset_level.disabled = true
		
	if combined["texture_path"] != "" and ResourceLoader.exists(combined["texture_path"]):
		avatar_texture.texture = load(combined["texture_path"])
	else:
		avatar_texture.texture = null
		
	var info_bbcode = ""
	info_bbcode += "[color=" + q_cfg["label_color"].to_html() + "][b]👤 武将基础属性[/b][/color]
"
	info_bbcode += "• 姓名: " + hero.get("name", "") + " | 品质: [color=" + q_cfg["label_color"].to_html() + "]" + hero.get("quality", "") + "[/color]
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
	if troop.get("target_type", "无") != "无":
		info_bbcode += "• 兵种克制: [color=orange]对 " + str(troop.get("target_type", "")) + " 伤害 +" + str(int(troop.get("bonus_rate", 0.0) * 100)) + "%[/color]
"
	info_bbcode += "• 闪避率: [color=green]" + str(int(combined["evade_rate"] * 100)) + "%[/color] (固定只由兵种决定)
"
	var atk_mode_str = combined.get("atk_mode", "single")
	var atk_mode_name = "单体攻击"
	match atk_mode_str:
		"single": atk_mode_name = "单体攻击"
		"row_line": atk_mode_name = "纵向/一字长蛇"
		"col_line": atk_mode_name = "横向/横扫"
		"backline_priority": atk_mode_name = "后排突袭"
		"all_targets": atk_mode_name = "全屏/全体攻击"
		"all_allies": atk_mode_name = "友方全体"
		"lowest_hp_ally": atk_mode_name = "友方单体救治"
		
	info_bbcode += "• 攻击方式: " + atk_mode_name + "
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

func _on_reset_level_pressed() -> void:
	var refund = GameData.reset_hero_level(current_hero_uuid)
	if refund > 0:
		refresh_display()
		emit_signal("updated")
