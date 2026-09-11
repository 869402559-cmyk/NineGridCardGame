extends ColorRect

@onready var btn_close: Button = $Panel/Margin/VBox/TitleBox/BtnClose
@onready var account_list_container: VBoxContainer = $Panel/Margin/VBox/Scroll/AccountListContainer

signal updated()

func _ready() -> void:
	btn_close.pressed.connect(queue_free)
	refresh_list()

func refresh_list() -> void:
	for child in account_list_container.get_children():
		child.queue_free()
		
	var accounts = GameData.load_all_accounts_data()
	for un in accounts.keys():
		if un == "admin":
			continue # 不显示或不提供删除 admin 账号
			
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 45)
		
		var name_lbl = Label.new()
		name_lbl.text = " 👤 账号: " + un
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(name_lbl)
		
		var btn_del = Button.new()
		btn_del.text = " 🗑️ 删除账号 "
		btn_del.custom_minimum_size = Vector2(100, 36)
		btn_del.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		btn_del.pressed.connect(func():
			_on_delete_account(un)
		)
		hbox.add_child(btn_del)
		
		account_list_container.add_child(hbox)
		
	if account_list_container.get_child_count() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "（当前暂无其他注册账号）"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		account_list_container.add_child(empty_lbl)

func _on_delete_account(username: String) -> void:
	var res = GameData.delete_account(username)
	if res == "OK":
		refresh_list()
		emit_signal("updated")
