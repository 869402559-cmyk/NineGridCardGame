extends Control

@onready var option_chapter: OptionButton = $VBox/TopHeader/OptionChapter
@onready var chap_desc: Label = $VBox/TopHeader/ChapDesc
@onready var map_scroll: ScrollContainer = $VBox/MapScroll
@onready var map_hbox: HBoxContainer = $VBox/MapScroll/MapHBox

@onready var lbl_stage_title: Label = $VBox/StageDetailPanel/DetailBox/InfoBox/LblStageTitle
@onready var lbl_stage_rewards: Label = $VBox/StageDetailPanel/DetailBox/InfoBox/LblStageRewards
@onready var lbl_recommend: Label = $VBox/StageDetailPanel/DetailBox/InfoBox/LblRecommend
@onready var btn_start_battle: Button = $VBox/StageDetailPanel/DetailBox/ActionBox/BtnStartBattle

var current_chapter_idx: int = 0
var selected_stage_data: Dictionary = {}

func _ready() -> void:
	option_chapter.item_selected.connect(_on_chapter_changed)
	btn_start_battle.pressed.connect(_on_start_battle)
	
	init_chapter_options()
	refresh_map()

func init_chapter_options() -> void:
	option_chapter.clear()
	for chap in GameData.CHAPTERS:
		option_chapter.add_item(chap["name"])
	# 【方案A】优先自动定位到玩家当前正在攻略的前沿章节
	current_chapter_idx = GameData.get_frontier_chapter_index()
	GameData.last_selected_chapter_idx = current_chapter_idx
	option_chapter.select(current_chapter_idx)

func _on_chapter_changed(index: int) -> void:
	current_chapter_idx = index
	GameData.last_selected_chapter_idx = index
	refresh_map()

func refresh_map() -> void:
	if current_chapter_idx < 0 or current_chapter_idx >= GameData.CHAPTERS.size():
		return
		
	var chap = GameData.CHAPTERS[current_chapter_idx]
	chap_desc.text = chap["desc"]
	
	for child in map_hbox.get_children():
		child.queue_free()
		
	var stages = chap["stages"]
	var is_prev_cleared = true # 第一关默认解锁
	
	for i in range(stages.size()):
		var st = stages[i]
		var st_id = st["id"]
		var is_cleared = st_id in GameData.cleared_stages
		var is_unlocked = is_prev_cleared or is_cleared
		
		var card = create_stage_node_card(st, is_unlocked, is_cleared)
		map_hbox.add_child(card)
		
		# 关卡解锁依赖前置节点通关
		is_prev_cleared = is_cleared

	# 默认选中当前章节最靠前的未通关/可挑战关卡
	var target_index: int = stages.size() - 1
	if stages.size() > 0:
		var target_stage: Dictionary = stages[stages.size() - 1]
		for idx in range(stages.size()):
			var st_candidate = stages[idx]
			if not (st_candidate["id"] in GameData.cleared_stages):
				target_stage = st_candidate
				target_index = idx
				break
		select_stage(target_stage)
		
		# 延迟一帧等待 UI 渲染完成后自动滚动水平 ScrollContainer 到当前目标关卡
		call_deferred("scroll_to_stage_index", target_index)

func scroll_to_stage_index(idx: int) -> void:
	if map_hbox.get_child_count() > idx and idx >= 0:
		var target_card = map_hbox.get_child(idx) as Control
		if target_card and map_scroll:
			# 卡牌宽度为 170，间隔为 30，居中计算偏移
			var scroll_pos = target_card.position.x - (map_scroll.size.x / 2.0) + (target_card.size.x / 2.0)
			map_scroll.scroll_horizontal = int(max(0, scroll_pos))

func create_stage_node_card(st: Dictionary, is_unlocked: bool, is_cleared: bool) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 220)
	
	var style = StyleBoxFlat.new()
	if not is_unlocked:
		style.bg_color = Color(0.12, 0.12, 0.15, 0.8)
		style.border_color = Color(0.3, 0.3, 0.35)
	elif is_cleared:
		style.bg_color = Color(0.15, 0.22, 0.15, 0.9)
		style.border_color = Color(0.3, 0.8, 0.4)
	else:
		style.bg_color = Color(0.22, 0.18, 0.12, 0.9)
		style.border_color = Color(0.9, 0.7, 0.2)
		
	style.set_corner_radius_all(10)
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	
	var name_lbl = Label.new()
	name_lbl.text = st["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	if is_unlocked:
		name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5) if not st.get("is_legion", false) else Color(1, 0.3, 0.3))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(name_lbl)
	
	var lv_lbl = Label.new()
	lv_lbl.text = "建议等级: Lv." + str(st.get("req_level", 1))
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 12)
	lv_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(lv_lbl)
	
	var status_lbl = Label.new()
	if not is_unlocked:
		status_lbl.text = "🔒 未解锁"
		status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif is_cleared:
		status_lbl.text = "⭐ 已通关"
		status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	else:
		status_lbl.text = "⚔️ 可挑战"
		status_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_lbl)
	
	card.add_child(vbox)
	
	# 点击节点切换详情
	if is_unlocked:
		card.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				select_stage(st)
		)
		
	return card

func select_stage(st: Dictionary) -> void:
	selected_stage_data = st
	var is_cleared = st["id"] in GameData.cleared_stages
	
	lbl_stage_title.text = st["name"] + (" (已通关)" if is_cleared else " (未通关)")
	lbl_stage_rewards.text = "通关奖励：威望 +" + str(st.get("prestige_reward", 0)) + " | 金币 +" + str(st.get("gold_reward", 0)) + " | 经验 +" + str(st.get("exp_reward", 0))
	
	if st.get("is_legion", false):
		lbl_recommend.text = "🔥 军团战规则：连续挑战 3 波敌军，中途无补给，全胜可获极高威望！"
	else:
		lbl_recommend.text = "💡 推荐战术：建议阵型【" + BattleCalculator.FORMATIONS.get(st.get("formation_type", "fish_scale"), {}).get("name", "鱼鳞阵") + "】，合理克制敌方兵种！"
		
	btn_start_battle.disabled = false

func _on_start_battle() -> void:
	if selected_stage_data.is_empty():
		return
		
	# 切换到 BattleUI 战斗界面并载入主线关卡节点数据
	var parent_main = get_parent()
	while parent_main != null and not parent_main.has_method("_on_battle_pressed"):
		parent_main = parent_main.get_parent()
		
	if parent_main and parent_main.has_method("start_stage_battle"):
		parent_main.start_stage_battle(selected_stage_data)
