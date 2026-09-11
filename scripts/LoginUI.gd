extends Control

@onready var input_user: LineEdit = $CenterBox/Margin/VBox/UserBox/InputUser
@onready var input_pass: LineEdit = $CenterBox/Margin/VBox/PassBox/InputPass
@onready var btn_login: Button = $CenterBox/Margin/VBox/BtnBox/BtnLogin
@onready var btn_register: Button = $CenterBox/Margin/VBox/BtnBox/BtnRegister
@onready var tip_label: Label = $CenterBox/Margin/VBox/TipLabel

func _ready() -> void:
	btn_login.pressed.connect(_on_login)
	btn_register.pressed.connect(_on_register)

func _on_login() -> void:
	var user = input_user.text.strip_edges()
	var pwd = input_pass.text.strip_edges()
	
	var res = GameData.login_account(user, pwd)
	if res == "OK":
		get_tree().change_scene_to_file("res://scenes/MainUI.tscn")
	else:
		tip_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		tip_label.text = res

func _on_register() -> void:
	var user = input_user.text.strip_edges()
	var pwd = input_pass.text.strip_edges()
	
	var res = GameData.register_account(user, pwd)
	if res == "OK":
		tip_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		tip_label.text = "注册成功！请点击【进入游戏】"
	else:
		tip_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		tip_label.text = res
