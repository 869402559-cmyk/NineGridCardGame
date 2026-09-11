extends Node

# ---------------------------------------------------
# CSV 配置表数据容器 (支持 Excel / WPS / 记事本 直接编辑导出)
# ---------------------------------------------------
var HERO_TEMPLATES: Dictionary = {}
var TROOP_TEMPLATES: Dictionary = {}
var ENEMY_FORMATIONS_CSV: Dictionary = {}

# ---------------------------------------------------
# 账号与网游存档机制 (数据不手动点击【保存】不写入磁盘)
# ---------------------------------------------------
var ACCOUNTS_FILE: String = "user://accounts.json"

var current_account: String = "" # 当前登录的用户账号
var player_gold: int = 2000
var player_exp_pool: int = 1500
var player_heroes: Array = []
var player_formation: Dictionary = {
	1: null, 2: null, 3: null,
	4: null, 5: null, 6: null,
	7: null, 8: null, 9: null
}
var cleared_difficulties: Array = [] # 记录通关记录，如 ["Easy", "Normal"]
var has_unsaved_changes: bool = false

signal gold_changed()
signal exp_changed()
signal save_status_changed(msg: String)

func _ready() -> void:
	load_csv_tables()
	ensure_default_accounts()

# ---------------------------------------------------
# 1. CSV 表格解析器 (可完美用 Excel 拖拽修改增删武将/兵种/敌人)
# ---------------------------------------------------
func load_csv_tables() -> void:
	parse_troops_csv("res://data/troops.csv")
	parse_heroes_csv("res://data/heroes.csv")
	parse_enemies_csv("res://data/enemies.csv")

func parse_troops_csv(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var file = FileAccess.open(file_path, FileAccess.READ)
	var headers = []
	var line_idx = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		# 自动过滤 UTF-8 BOM 头
		if line_idx == 0 and line.begins_with("\ufeff"):
			line = line.substr(1)
		var parts = line.split(",")
		if line_idx == 0:
			headers = parts
		else:
			var id = parts[0]
			var data = {}
			for i in range(min(headers.size(), parts.size())):
				var h = headers[i]
				var val = parts[i]
				if h in ["atk", "def", "satk", "sdef"]:
					data[h] = val.to_int()
				elif h == "evade_rate":
					data[h] = val.to_float()
				else:
					data[h] = val
			TROOP_TEMPLATES[id] = data
		line_idx += 1

func parse_heroes_csv(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var file = FileAccess.open(file_path, FileAccess.READ)
	var headers = []
	var line_idx = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		# 自动过滤 UTF-8 BOM 头
		if line_idx == 0 and line.begins_with("\ufeff"):
			line = line.substr(1)
		var parts = line.split(",")
		if line_idx == 0:
			headers = parts
		else:
			var id = parts[0]
			var data = {}
			for i in range(min(headers.size(), parts.size())):
				var h = headers[i]
				var val = parts[i]
				if h in ["hp", "atk", "def", "satk", "sdef", "spd"]:
					data[h] = val.to_int()
				elif h == "color":
					data[h] = Color.html(val)
				else:
					data[h] = val
			HERO_TEMPLATES[id] = data
		line_idx += 1

func parse_enemies_csv(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var file = FileAccess.open(file_path, FileAccess.READ)
	var headers = []
	var line_idx = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		# 自动过滤 UTF-8 BOM 头
		if line_idx == 0 and line.begins_with("\ufeff"):
			line = line.substr(1)
		var parts = line.split(",")
		if line_idx == 0:
			headers = parts
		else:
			var diff = parts[0]
			var data = { "positions": {}, "stat_mult": 1.0 }
			for i in range(1, 10):
				if i < parts.size() and parts[i] != "":
					data["positions"][i] = parts[i]
			if parts.size() >= 11:
				data["stat_mult"] = parts[10].to_float()
			ENEMY_FORMATIONS_CSV[diff] = data
		line_idx += 1

# ---------------------------------------------------
# 2. 账号与登录系统
# ---------------------------------------------------
func ensure_default_accounts() -> void:
	var accounts = load_all_accounts_data()
	if not accounts.has("admin"):
		accounts["admin"] = {
			"password": "123456",
			"save_data": get_default_new_account_save()
		}
		save_all_accounts_data(accounts)

func load_all_accounts_data() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNTS_FILE):
		return {}
	var file = FileAccess.open(ACCOUNTS_FILE, FileAccess.READ)
	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) == OK:
		return json.get_data() as Dictionary
	return {}

func save_all_accounts_data(accounts: Dictionary) -> void:
	var file = FileAccess.open(ACCOUNTS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(accounts, "	"))

func register_account(username: String, pass_word: String) -> String:
	if username.strip_edges() == "" or pass_word.strip_edges() == "":
		return "账号或密码不能为空！"
	var accounts = load_all_accounts_data()
	if accounts.has(username):
		return "注册失败：账号【" + username + "】已存在！"
	
	accounts[username] = {
		"password": pass_word,
		"save_data": get_default_new_account_save()
	}
	save_all_accounts_data(accounts)
	return "OK"

func login_account(username: String, pass_word: String) -> String:
	ensure_default_accounts()
	var accounts = load_all_accounts_data()
	if not accounts.has(username):
		return "登录失败：账号【" + username + "】不存在！"
	if accounts[username]["password"] != pass_word:
		return "登录失败：密码错误！"
		
	current_account = username
	load_player_save_from_account(accounts[username]["save_data"])
	has_unsaved_changes = false
	return "OK"

func get_default_new_account_save() -> Dictionary:
	var initial_heroes = []
	var init_ids = ["h_01", "h_04", "h_05", "h_08", "h_11"]
	var initial_formation = { "1": null, "2": null, "3": null, "4": null, "5": null, "6": null, "7": null, "8": null, "9": null }
	
	for i in range(init_ids.size()):
		var tid = init_ids[i]
		var tmpl = HERO_TEMPLATES.get(tid, {})
		if not tmpl.is_empty():
			var inst = tmpl.duplicate(true)
			inst["uuid"] = "uuid_" + str(Time.get_ticks_usec()) + "_" + str(i)
			inst["level"] = 1
			if inst.has("color"):
				inst["color"] = (inst["color"] as Color).to_html()
			initial_heroes.append(inst)
			initial_formation[str(i + 1)] = inst["uuid"]
			
	return {
		"gold": 2000,
		"exp_pool": 1500,
		"heroes": initial_heroes,
		"formation": initial_formation,
		"cleared_difficulties": []
	}

# 加载数据到内存
func load_player_save_from_account(save_data: Dictionary) -> void:
	player_gold = save_data.get("gold", 2000)
	player_exp_pool = save_data.get("exp_pool", 1500)
	cleared_difficulties = save_data.get("cleared_difficulties", [])
	
	player_heroes.clear()
	var raw_heroes = save_data.get("heroes", [])
	for h in raw_heroes:
		var hero = (h as Dictionary).duplicate(true)
		if typeof(hero.get("color")) == TYPE_STRING:
			hero["color"] = Color.html(hero["color"])
		player_heroes.append(hero)
		
	player_formation = { 1: null, 2: null, 3: null, 4: null, 5: null, 6: null, 7: null, 8: null, 9: null }
	var raw_form = save_data.get("formation", {})
	for pos_str in raw_form.keys():
		var pos = pos_str.to_int()
		player_formation[pos] = raw_form[pos_str]

# ---------------------------------------------------
# 3. 游戏内主动【保存】按钮机制 (写入 JSON)
# ---------------------------------------------------
func save_current_progress() -> void:
	if current_account == "":
		return
	var accounts = load_all_accounts_data()
	if not accounts.has(current_account):
		return
		
	var heroes_to_save = []
	for h in player_heroes:
		var hero_copy = h.duplicate(true)
		if typeof(hero_copy.get("color")) == TYPE_COLOR:
			hero_copy["color"] = (hero_copy["color"] as Color).to_html()
		heroes_to_save.append(hero_copy)
		
	var form_to_save = {}
	for pos in player_formation.keys():
		form_to_save[str(pos)] = player_formation[pos]
		
	accounts[current_account]["save_data"] = {
		"gold": player_gold,
		"exp_pool": player_exp_pool,
		"heroes": heroes_to_save,
		"formation": form_to_save,
		"cleared_difficulties": cleared_difficulties
	}
	save_all_accounts_data(accounts)
	has_unsaved_changes = false
	emit_signal("save_status_changed", "💾 游戏进度已成功保存！")

# ---------------------------------------------------
# 4. 角色与游戏操作函数
# ---------------------------------------------------
func add_hero(template_id: String) -> Dictionary:
	var tmpl = HERO_TEMPLATES.get(template_id)
	if tmpl == null:
		return {}
	var inst = tmpl.duplicate(true)
	inst["uuid"] = "uuid_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000000)
	inst["level"] = 1
	player_heroes.append(inst)
	has_unsaved_changes = true
	return inst

func auto_fill_formation() -> void:
	for pos in range(1, 10):
		player_formation[pos] = null
	
	var count = min(5, player_heroes.size())
	for i in range(count):
		player_formation[i + 1] = player_heroes[i]["uuid"]
	has_unsaved_changes = true

func get_hero_by_uuid(uuid: String) -> Dictionary:
	for h in player_heroes:
		if h["uuid"] == uuid:
			return h
	return {}

func get_troop_by_id(troop_id: String) -> Dictionary:
	if TROOP_TEMPLATES.has(troop_id):
		return TROOP_TEMPLATES[troop_id]
	return TROOP_TEMPLATES.get("t_cavalry", {})

func get_upgrade_cost(level: int) -> int:
	return level * 100

func upgrade_hero(uuid: String) -> bool:
	var h = get_hero_by_uuid(uuid)
	if h.is_empty():
		return false
	var cost = get_upgrade_cost(h["level"])
	if player_exp_pool >= cost:
		player_exp_pool -= cost
		h["level"] += 1
		h["hp"] += 150
		h["atk"] += 20
		h["def"] += 10
		h["satk"] += 25
		h["sdef"] += 10
		has_unsaved_changes = true
		emit_signal("exp_changed")
		return true
	return false

func calc_combined_stats(hero: Dictionary) -> Dictionary:
	var troop = get_troop_by_id(hero.get("troop_id", "t_cavalry"))
	
	var final_atk = int(hero.get("atk", 100) * 0.7 + troop.get("atk", 100) * 0.3)
	var final_def = int(hero.get("def", 50) * 0.7 + troop.get("def", 50) * 0.3)
	var final_satk = int(hero.get("satk", 100) * 0.7 + troop.get("satk", 100) * 0.3)
	var final_sdef = int(hero.get("sdef", 50) * 0.7 + troop.get("sdef", 50) * 0.3)
	
	return {
		"hp": hero.get("hp", 1000),
		"atk": final_atk,
		"def": final_def,
		"satk": final_satk,
		"sdef": final_sdef,
		"spd": hero.get("spd", 100),
		"evade_rate": troop.get("evade_rate", 0.05),
		"troop_name": troop.get("name", "兵种"),
		"troop_type": troop.get("type_name", "步兵"),
		"atk_type": troop.get("atk_type", "单体攻击"),
		"skill_name": troop.get("skill_name", "无"),
		"skill_desc": troop.get("skill_desc", ""),
		"anim_type": troop.get("anim_type", "slash"),
		"texture_path": troop.get("texture_path", "")
	}

func get_enemy_formation(difficulty: String) -> Dictionary:
	var enemy_formation: Dictionary = {
		1: null, 2: null, 3: null,
		4: null, 5: null, 6: null,
		7: null, 8: null, 9: null
	}
	
	if not ENEMY_FORMATIONS_CSV.has(difficulty):
		difficulty = "Normal"
		
	var csv_data = ENEMY_FORMATIONS_CSV[difficulty]
	var positions = csv_data["positions"]
	var stat_mult = csv_data["stat_mult"]
	
	for pos in positions.keys():
		var tid = positions[pos]
		if HERO_TEMPLATES.has(tid):
			var tmpl = HERO_TEMPLATES[tid].duplicate(true)
			tmpl["uuid"] = "enemy_" + str(pos) + "_" + str(randi() % 100000)
			tmpl["level"] = 1
			tmpl["hp"] = int(tmpl["hp"] * stat_mult)
			tmpl["atk"] = int(tmpl["atk"] * stat_mult)
			tmpl["def"] = int(tmpl["def"] * stat_mult)
			tmpl["satk"] = int(tmpl["satk"] * stat_mult)
			tmpl["sdef"] = int(tmpl["sdef"] * stat_mult)
			enemy_formation[pos] = tmpl
			
	return enemy_formation
