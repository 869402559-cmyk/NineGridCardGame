extends Node

signal gold_changed
signal exp_changed
signal prestige_changed
signal save_status_changed(msg: String)

var player_prestige: int = 0
var cleared_stages: Array = [] # 记录已通关主线关卡节点 ID
var unlocked_surrenders: Array = [] # 记录已解锁招降的武将 ID (如 h_17 张角)
var acquired_prestige_heroes: Array = [] # 记录已领取的威望武将 ID
var last_selected_chapter_idx: int = 0 # 主线征战上一次定位/浏览的章节索引（跨界面保持）

# 主线关卡章节数据配置
const CHAPTERS: Array = [
	{
		"id": "chap_1",
		"name": "第一章：黄巾起义",
		"desc": "苍天已死黄巾当立，讨伐张角保卫地方！",
		"stages": [
			{ "id": "stage_1_1", "name": "1-1 游兵试探", "req_level": 1, "prestige_reward": 50, "gold_reward": 500, "exp_reward": 300, "formation_type": "fish_scale", "enemies": { 5: "h_14" }, "stat_mult": 0.4 },
			{ "id": "stage_1_2", "name": "1-2 哨卡冲突", "req_level": 1, "prestige_reward": 60, "gold_reward": 600, "exp_reward": 400, "formation_type": "fish_scale", "enemies": { 2: "h_14", 8: "h_15" }, "stat_mult": 0.5 },
			{ "id": "stage_1_3", "name": "1-3 贼寇前锋", "req_level": 2, "prestige_reward": 70, "gold_reward": 700, "exp_reward": 500, "formation_type": "fish_scale", "enemies": { 2: "h_14", 5: "h_15" }, "stat_mult": 0.6 },
			{ "id": "stage_1_4", "name": "1-4 阵地遭遇", "req_level": 2, "prestige_reward": 80, "gold_reward": 800, "exp_reward": 600, "formation_type": "cone", "enemies": { 1: "h_14", 3: "h_15" }, "stat_mult": 0.7 },
			{ "id": "stage_1_5", "name": "1-5 弓将黄忠 (降将BOSS)", "is_boss": true, "boss_hero_id": "h_07", "surrender_rate": 0.5, "req_level": 3, "prestige_reward": 150, "gold_reward": 1200, "exp_reward": 800, "formation_type": "fish_scale", "enemies": { 2: "h_07", 8: "h_15" }, "stat_mult": 0.8 },
			{ "id": "stage_1_6", "name": "1-6 突破关隘", "req_level": 3, "prestige_reward": 90, "gold_reward": 900, "exp_reward": 700, "formation_type": "cone", "enemies": { 2: "h_14", 5: "h_14", 8: "h_15" }, "stat_mult": 0.85 },
			{ "id": "stage_1_7", "name": "1-7 连营抄截", "req_level": 4, "prestige_reward": 100, "gold_reward": 1000, "exp_reward": 800, "formation_type": "fish_scale", "enemies": { 1: "h_14", 2: "h_15", 3: "h_14" }, "stat_mult": 0.9 },
			{ "id": "stage_1_8", "name": "1-8 山谷伏击", "req_level": 4, "prestige_reward": 110, "gold_reward": 1100, "exp_reward": 900, "formation_type": "cone", "enemies": { 2: "h_14", 4: "h_15", 6: "h_15" }, "stat_mult": 0.95 },
			{ "id": "stage_1_9", "name": "1-9 贼寇中军", "req_level": 5, "prestige_reward": 120, "gold_reward": 1200, "exp_reward": 1000, "formation_type": "fish_scale", "enemies": { 2: "h_11", 5: "h_15", 8: "h_14" }, "stat_mult": 1.0 },
			{ "id": "stage_1_10", "name": "1-10 骁将姜维 (降将BOSS)", "is_boss": true, "boss_hero_id": "h_09", "surrender_rate": 0.5, "req_level": 6, "prestige_reward": 250, "gold_reward": 2000, "exp_reward": 1500, "formation_type": "cone", "enemies": { 2: "h_09", 4: "h_11", 6: "h_15" }, "stat_mult": 1.05 },
			{ "id": "stage_1_11", "name": "1-11 广宗外围", "req_level": 6, "prestige_reward": 130, "gold_reward": 1300, "exp_reward": 1100, "formation_type": "fish_scale", "enemies": { 1: "h_11", 2: "h_14", 3: "h_15" }, "stat_mult": 1.1 },
			{ "id": "stage_1_12", "name": "1-12 鹿角据点", "req_level": 7, "prestige_reward": 140, "gold_reward": 1400, "exp_reward": 1200, "formation_type": "cone", "enemies": { 2: "h_11", 5: "h_14", 8: "h_15" }, "stat_mult": 1.15 },
			{ "id": "stage_1_13", "name": "1-13 广宗城下", "req_level": 7, "prestige_reward": 150, "gold_reward": 1500, "exp_reward": 1300, "formation_type": "fish_scale", "enemies": { 2: "h_11", 4: "h_15", 6: "h_15", 8: "h_14" }, "stat_mult": 1.2 },
			{ "id": "stage_1_14", "name": "1-14 祭坛护卫", "req_level": 8, "prestige_reward": 160, "gold_reward": 1600, "exp_reward": 1400, "formation_type": "goose_wing", "enemies": { 1: "h_12", 3: "h_15", 5: "h_11", 7: "h_15" }, "stat_mult": 1.25 },
			{ "id": "stage_1_15", "name": "1-15 武圣关羽 (降将BOSS)", "is_boss": true, "boss_hero_id": "h_01", "surrender_rate": 0.5, "req_level": 9, "prestige_reward": 350, "gold_reward": 3000, "exp_reward": 2000, "formation_type": "fish_scale", "enemies": { 2: "h_01", 5: "h_11", 8: "h_15" }, "stat_mult": 1.3 },
			{ "id": "stage_1_16", "name": "1-16 黄巾本营", "req_level": 9, "prestige_reward": 180, "gold_reward": 1800, "exp_reward": 1600, "formation_type": "cone", "enemies": { 2: "h_11", 4: "h_12", 5: "h_15", 6: "h_15", 8: "h_14" }, "stat_mult": 1.35 },
			{ "id": "stage_1_17", "name": "1-17 大法师张角 (终极BOSS)", "is_boss": true, "boss_hero_id": "h_17", "surrender_rate": 0.5, "req_level": 10, "prestige_reward": 500, "gold_reward": 5000, "exp_reward": 3000, "formation_type": "goose_wing", "enemies": { 1: "h_12", 3: "h_15", 5: "h_17", 7: "h_11", 9: "h_15" }, "stat_mult": 1.4 },
			{ "id": "stage_1_legion", "name": "🔥 1-18 军团战：黄巾决战", "is_legion": true, "req_level": 10, "prestige_reward": 800, "gold_reward": 8000, "exp_reward": 5000, "waves": [ { "formation": "fish_scale", "enemies": { 2: "h_14", 5: "h_15", 8: "h_14" }, "stat_mult": 1.0 }, { "formation": "cone", "enemies": { 2: "h_11", 4: "h_12", 5: "h_15", 6: "h_14", 8: "h_15" }, "stat_mult": 1.2 }, { "formation": "goose_wing", "enemies": { 1: "h_12", 3: "h_11", 5: "h_17", 7: "h_15", 9: "h_15" }, "stat_mult": 1.45 } ] }
		]
	},
	{
		"id": "chap_2",
		"name": "第二章：董卓乱政",
		"desc": "西凉魔王割据洛阳，破虎牢击败董卓！",
		"stages": [
			{
				"id": "stage_2_1",
				"name": "2-1 西凉先锋",
				"req_level": 12,
				"prestige_reward": 150,
				"gold_reward": 300,
				"exp_reward": 600,
				"formation_type": "fish_scale",
				"enemies": { 1: "h_13", 2: "h_11", 3: "h_13", 5: "h_07", 8: "h_15" },
				"stat_mult": 1.25
			},
			{
				"id": "stage_2_2",
				"name": "2-2 汜水关战",
				"req_level": 15,
				"prestige_reward": 200,
				"gold_reward": 450,
				"exp_reward": 900,
				"formation_type": "cone",
				"enemies": { 2: "h_18", 4: "h_13", 5: "h_11", 6: "h_13", 8: "h_07" },
				"stat_mult": 1.4
			},
			{
				"id": "stage_2_3",
				"name": "2-3 猛将华雄 (主将Boss)",
				"is_boss": true,
				"boss_hero_id": "h_18",
				"surrender_cost": 1000,
				"req_level": 18,
				"prestige_reward": 350,
				"gold_reward": 800,
				"exp_reward": 1500,
				"formation_type": "crane_wing",
				"enemies": { 1: "h_13", 3: "h_13", 4: "h_11", 6: "h_18", 8: "h_07" },
				"stat_mult": 1.6
			},
			{
				"id": "stage_2_4",
				"name": "2-4 魔王董卓 (主将Boss)",
				"is_boss": true,
				"boss_hero_id": "h_19",
				"surrender_cost": 2500,
				"req_level": 22,
				"prestige_reward": 500,
				"gold_reward": 1500,
				"exp_reward": 3000,
				"formation_type": "bagua",
				"enemies": { 1: "h_18", 3: "h_06", 5: "h_19", 7: "h_04", 9: "h_16" },
				"stat_mult": 1.85
			},
			{
				"id": "stage_2_legion",
				"name": "🔥 军团战：洛阳决战",
				"is_legion": true,
				"req_level": 25,
				"prestige_reward": 1200,
				"gold_reward": 3000,
				"exp_reward": 6000,
				"waves": [
					{ "formation": "fish_scale", "enemies": { 1: "h_13", 2: "h_11", 3: "h_13", 5: "h_07", 8: "h_15" }, "stat_mult": 1.35 },
					{ "formation": "crane_wing", "enemies": { 1: "h_13", 3: "h_13", 4: "h_11", 6: "h_18", 8: "h_07" }, "stat_mult": 1.65 },
					{ "formation": "bagua", "enemies": { 1: "h_18", 3: "h_06", 5: "h_19", 7: "h_04", 9: "h_16" }, "stat_mult": 2.0 }
				]
			}
		]
	}
]

# 计算玩家"当前攻略前沿"章节索引：
# 逐章扫描，返回第一个尚未全通的章节；若全部章节已通关，则返回最后一章。
func get_frontier_chapter_index() -> int:
	if CHAPTERS.is_empty():
		return 0
	for i in range(CHAPTERS.size()):
		var stages: Array = CHAPTERS[i].get("stages", [])
		var all_cleared := true
		for st in stages:
			if not (st.get("id", "") in cleared_stages):
				all_cleared = false
				break
		if not all_cleared:
			return i
	return CHAPTERS.size() - 1

# 全局数据表定义
var HERO_TEMPLATES: Dictionary = {}
var TROOP_TEMPLATES: Dictionary = {}
var ENEMY_FORMATIONS_CSV: Dictionary = {}

# 账号与存档常量
const ACCOUNTS_FILE = "user://accounts.json"

# 当前登录账号与玩家持久化内存状态
var current_account: String = ""
var player_gold: int = 100000000
var player_exp_pool: int = 100000000
var player_heroes: Array = []       # 已拥有的英雄实例数组
var player_formation: Dictionary = {} # 1..9 -> hero_uuid (或 null)
var cleared_difficulties: Array = []  # 已通关难度

# 全局状态标记
var is_in_battle: bool = false
var has_unsaved_changes: bool = false

# 五级品质视觉配置表 (UR, SSR, SR, R, N) 及解雇返还金币基数
const QUALITY_CONFIGS: Dictionary = {
	"UR": {
		"label_color": Color("#FF2255"),
		"border_color": Color("#FFD700"),
		"bg_color": Color(0.35, 0.05, 0.12, 0.95),
		"border_width": 3,
		"rank_weight": 5,
		"dismiss_gold": 2000
	},
	"SSR": {
		"label_color": Color("#FFAA00"),
		"border_color": Color("#FFAA00"),
		"bg_color": Color(0.3, 0.2, 0.05, 0.95),
		"border_width": 2,
		"rank_weight": 4,
		"dismiss_gold": 800
	},
	"SR": {
		"label_color": Color("#AA33FF"),
		"border_color": Color("#AA33FF"),
		"bg_color": Color(0.2, 0.08, 0.32, 0.95),
		"border_width": 2,
		"rank_weight": 3,
		"dismiss_gold": 300
	},
	"R": {
		"label_color": Color("#3399FF"),
		"border_color": Color("#3399FF"),
		"bg_color": Color(0.08, 0.18, 0.32, 0.95),
		"border_width": 1,
		"rank_weight": 2,
		"dismiss_gold": 100
	},
	"N": {
		"label_color": Color("#AAAAAA"),
		"border_color": Color("#666666"),
		"bg_color": Color(0.18, 0.18, 0.18, 0.95),
		"border_width": 1,
		"rank_weight": 1,
		"dismiss_gold": 30
	}
}

func _ready() -> void:
	load_all_csv_data()
	ensure_default_accounts()

# ---------------------------------------------------
# 1. UTF-8 BOM CSV 解析器
# ---------------------------------------------------
func load_all_all_csv() -> void:
	load_all_csv_data()

func load_all_csv_data() -> void:
	parse_troops_csv("res://data/troops.csv")
	parse_heroes_csv("res://data/heroes.csv")
	parse_enemies_csv("res://data/enemies.csv")

# 当前玩家选中的阵型（缺省为 鱼鳞阵 fish_scale）
var current_formation_type: String = "fish_scale"

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
				elif h in ["evade_rate", "crit_rate", "block_rate", "penetrate_rate", "bonus_rate"]:
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
	var admin_default_save = get_default_new_account_save()
	admin_default_save["gold"] = 100000000
	admin_default_save["exp_pool"] = 100000000
	
	# 仅在磁盘上无 admin 账号时创建默认 admin，后续游戏启动绝对不会覆盖已保存的真实进度！
	if not accounts.has("admin"):
		accounts["admin"] = {
			"password": "123456",
			"save_data": admin_default_save
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

func delete_account(username: String) -> String:
	if username == "admin":
		return "删除失败：默认管理员账号 admin 不允许删除！"
	var accounts = load_all_accounts_data()
	if not accounts.has(username):
		return "删除失败：账号不存在！"
	accounts.erase(username)
	save_all_accounts_data(accounts)
	return "OK"

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
	return {
		"gold": 100000000 if current_account == "admin" else 1000,
		"exp_pool": 100000000 if current_account == "admin" else 1000,
		"prestige": 0,
		"heroes": [], # 初始 0 武将，登录后弹出 8 选 1 选角弹窗
		"chosen_initial_hero": false,
		"formation": { "1": null, "2": null, "3": null, "4": null, "5": null, "6": null, "7": null, "8": null, "9": null },
		"cleared_stages": [],
		"unlocked_surrenders": [],
		"acquired_prestige_heroes": [],
		"last_selected_chapter_idx": 0,
		"cleared_difficulties": [],
		"battle_speed_mode": 0
	}

var chosen_initial_hero: bool = false

var battle_speed_mode: int = 0 # 战斗播放倍速设置 (0=正常2.2x, 1=1倍速1.0x, 2=2倍速0.4x)

# 加载数据到内存
func load_player_save_from_account(save_data: Dictionary) -> void:
	player_gold = save_data.get("gold", 100000000 if current_account == "admin" else 1000)
	player_exp_pool = save_data.get("exp_pool", 100000000 if current_account == "admin" else 1000)
	player_prestige = save_data.get("prestige", 0)
	chosen_initial_hero = save_data.get("chosen_initial_hero", false)
		
	cleared_difficulties = save_data.get("cleared_difficulties", [])
	cleared_stages = save_data.get("cleared_stages", [])
	unlocked_surrenders = save_data.get("unlocked_surrenders", [])
	acquired_prestige_heroes = save_data.get("acquired_prestige_heroes", [])
	last_selected_chapter_idx = save_data.get("last_selected_chapter_idx", 0)
	battle_speed_mode = save_data.get("battle_speed_mode", 0)
	
	player_heroes.clear()
	var raw_heroes = save_data.get("heroes", [])
	for h in raw_heroes:
		var hero = (h as Dictionary).duplicate(true)
		
		# 自动刷更新：如果 CSV 表里的品质、名称、兵种有更新，自动同步模板的最新品质与最新兵种 ID
		if HERO_TEMPLATES.has(hero.get("id", "")):
			var tmpl = HERO_TEMPLATES[hero["id"]]
			hero["quality"] = tmpl.get("quality", hero.get("quality", "N"))
			hero["troop_id"] = tmpl.get("troop_id", hero.get("troop_id", ""))
			
		if typeof(hero.get("color")) == TYPE_STRING:
			hero["color"] = Color.html(hero["color"])
		player_heroes.append(hero)
		
	player_formation = { 1: null, 2: null, 3: null, 4: null, 5: null, 6: null, 7: null, 8: null, 9: null }
	var raw_form = save_data.get("formation", {})
	for pos_str in raw_form.keys():
		var pos = pos_str.to_int()
		player_formation[pos] = raw_form[pos_str]
	current_formation_type = save_data.get("formation_type", "fish_scale")

# ---------------------------------------------------
# 3. 游戏内主动【保存】按钮机制 (写入 JSON)
# ---------------------------------------------------
func save_current_progress() -> void:
	if is_in_battle:
		emit_signal("save_status_changed", "⚠️ 战斗进行中，无法保存存档！")
		return
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
		"prestige": player_prestige,
		"chosen_initial_hero": chosen_initial_hero,
		"heroes": heroes_to_save,
		"formation": form_to_save,
		"formation_type": current_formation_type,
		"cleared_stages": cleared_stages,
		"unlocked_surrenders": unlocked_surrenders,
		"acquired_prestige_heroes": acquired_prestige_heroes,
		"last_selected_chapter_idx": last_selected_chapter_idx,
		"cleared_difficulties": cleared_difficulties,
		"battle_speed_mode": battle_speed_mode
	}
	save_all_accounts_data(accounts)
	has_unsaved_changes = false
	emit_signal("save_status_changed", "💾 游戏进度已成功保存！")

# 兵种大类配置（定义各兵种大类的阵型布局配置：grid_size, sol_size, offset, 损耗顺序）
const TROOP_CATEGORY_CONFIGS: Dictionary = {
	"骑兵": {
		"grid_type": "3x3",
		"total_count": 9,
		"sol_size": Vector2(58, 58),
		"custom_positions": [
			# 3x3 紧凑错位斜面排布，放大兵种尺寸至 58x58，实现浑厚重叠
			Vector2(0, 0), Vector2(34, 0), Vector2(68, 0),
			Vector2(14, 28), Vector2(48, 28), Vector2(82, 28),
			Vector2(28, 56), Vector2(62, 56), Vector2(96, 56)
		],
		"removal_order": [0, 2, 6, 8, 1, 3, 5, 7, 4]
	},
	"鼓手": {
		"grid_type": "3x3",
		"total_count": 9,
		"sol_size": Vector2(54, 54),
		"custom_positions": [
			Vector2(0, 0), Vector2(34, 0), Vector2(68, 0),
			Vector2(14, 28), Vector2(48, 28), Vector2(82, 28),
			Vector2(28, 56), Vector2(62, 56), Vector2(96, 56)
		],
		"removal_order": [0, 2, 6, 8, 1, 3, 5, 7, 4]
	},
	"机械": {
		"grid_type": "3x3",
		"total_count": 9,
		"sol_size": Vector2(58, 58),
		"custom_positions": [
			Vector2(0, 0), Vector2(34, 0), Vector2(68, 0),
			Vector2(14, 28), Vector2(48, 28), Vector2(82, 28),
			Vector2(28, 56), Vector2(62, 56), Vector2(96, 56)
		],
		"removal_order": [0, 2, 6, 8, 1, 3, 5, 7, 4]
	},
	"DEFAULT_4x4": {
		"grid_type": "4x4",
		"total_count": 16,
		"sol_size": Vector2(48, 48),
		"custom_positions": [], # 在代码中按 row/col 动态生成 4x4 紧凑错位
		"removal_order": [0, 3, 12, 15, 1, 14, 2, 13, 4, 11, 7, 8, 5, 10, 6, 9]
	}
}

func get_troop_category_config(category_name: String) -> Dictionary:
	return TROOP_CATEGORY_CONFIGS.get(category_name, TROOP_CATEGORY_CONFIGS["DEFAULT_4x4"])
func get_quality_config(quality: String) -> Dictionary:
	return QUALITY_CONFIGS.get(quality, QUALITY_CONFIGS["N"])

func get_troop_by_id(troop_id: String) -> Dictionary:
	return TROOP_TEMPLATES.get(troop_id, {
		"name": "普通民兵",
		"type_name": "步兵",
		"atk": 100,
		"def": 100,
		"satk": 100,
		"sdef": 100,
		"evade_rate": 0.05,
		"target_type": "无",
		"bonus_target": "单体攻击",
		"bonus_rate": 0.0,
		"skill_name": "无",
		"skill_desc": "",
		"anim_type": "slash",
		"texture_path": ""
	})

func get_hero_by_uuid(uuid: String) -> Dictionary:
	for h in player_heroes:
		if h.get("uuid", "") == uuid:
			return h
	return {}

# 检查某个武将模板 ID 是否已被账号拥有（包含在阵容/背包中）
func is_hero_owned(hero_template_id: String) -> bool:
	for h in player_heroes:
		if h.get("id", "") == hero_template_id:
			return true
	return false

# 挑选初始武将（8选1，排除战鼓和医师）
func choose_initial_hero(hero_template_id: String) -> Dictionary:
	var added = add_hero(hero_template_id)
	if not added.is_empty():
		chosen_initial_hero = true
		auto_fill_formation()
		save_current_progress()
	return added

# 武将下野（移除背包/阵容中指定 uuid 的武将，要求 1 级且不在阵型中，且列表不能只剩1人）
func dismiss_hero(uuid: String) -> String:
	if player_heroes.size() <= 1:
		return "下野失败：当前队伍仅剩最后 1 位武将，必须保留至少 1 位武将！"
		
	var target_hero = get_hero_by_uuid(uuid)
	if target_hero.is_empty():
		return "下野失败：未找到指定武将！"
		
	if target_hero.get("level", 1) > 1:
		return "下野失败：武将已升级（等级 " + str(target_hero.get("level", 1)) + "），请先在【洗练】中重置为1级后再下野！"
		
	for pos in player_formation.keys():
		if player_formation[pos] == uuid:
			return "下野失败：武将目前在上阵阵容中，请先将其从阵型下架后再下野！"
			
	var idx_to_remove = -1
	for i in range(player_heroes.size()):
		if player_heroes[i].get("uuid", "") == uuid:
			idx_to_remove = i
			break
			
	if idx_to_remove >= 0:
		var hero_name = player_heroes[idx_to_remove].get("name", "武将")
		player_heroes.remove_at(idx_to_remove)
		has_unsaved_changes = true
		save_current_progress()
		return "OK"
		
	return "下野失败：内部数据异常！"

func add_hero(hero_template_id: String) -> Dictionary:
	var tmpl = HERO_TEMPLATES.get(hero_template_id)
	if tmpl == null:
		return {}
	var inst = tmpl.duplicate(true)
	inst["uuid"] = "uuid_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	inst["level"] = 1
	player_heroes.append(inst)
	has_unsaved_changes = true
	return inst

func get_upgrade_cost(current_level: int) -> int:
	return current_level * 100

# 计算累计升级到当前等级消耗的总经验值
func get_total_spent_exp(level: int) -> int:
	var total = 0
	for l in range(1, level):
		total += l * 100
	return total

# 计算洗练洗等级可返还的经验（80% 固定比例）
func get_reset_level_refund_exp(hero: Dictionary) -> int:
	var level = hero.get("level", 1)
	if level <= 1:
		return 0
	var total_spent = get_total_spent_exp(level)
	return int(total_spent * 0.8)

# 洗练武将等级重置为 1 级，恢复基础属性，返还 80% 经验
func reset_hero_level(hero_uuid: String) -> int:
	var h = null
	for hero in player_heroes:
		if hero["uuid"] == hero_uuid:
			h = hero
			break
	if h == null or h.get("level", 1) <= 1:
		return 0
		
	var refund_exp = get_reset_level_refund_exp(h)
	var tid = h.get("id", "")
	if HERO_TEMPLATES.has(tid):
		var tmpl = HERO_TEMPLATES[tid]
		h["level"] = 1
		h["hp"] = tmpl.get("hp", 1000)
		h["atk"] = tmpl.get("atk", 100)
		h["def"] = tmpl.get("def", 50)
		h["satk"] = tmpl.get("satk", 100)
		h["sdef"] = tmpl.get("sdef", 50)
		h["spd"] = tmpl.get("spd", 100)
		
	player_exp_pool += refund_exp
	has_unsaved_changes = true
	emit_signal("exp_changed")
	return refund_exp

func upgrade_hero(hero_uuid: String) -> bool:
	var h = null
	for hero in player_heroes:
		if hero["uuid"] == hero_uuid:
			h = hero
			break
	if h == null:
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

# 批量解雇武将逻辑 (返回获得的金币)
func dismiss_heroes(hero_uuids: Array) -> int:
	var equipped_uuids = []
	for pos in player_formation.keys():
		var uid = player_formation[pos]
		if uid != null:
			equipped_uuids.append(uid)
			
	var total_gold_gained = 0
	var heroes_to_keep = []
	
	for h in player_heroes:
		var uid = h.get("uuid", "")
		if uid in hero_uuids:
			# 检查限制：已上阵或等级不为 1 级的武将跳过，不能解雇
			if uid in equipped_uuids or h.get("level", 1) > 1:
				heroes_to_keep.append(h)
			else:
				var q = h.get("quality", "N")
				var q_cfg = get_quality_config(q)
				total_gold_gained += q_cfg.get("dismiss_gold", 30)
		else:
			heroes_to_keep.append(h)
			
	player_heroes = heroes_to_keep
	player_gold += total_gold_gained
	has_unsaved_changes = true
	emit_signal("gold_changed")
	return total_gold_gained

func calc_combined_stats(hero: Dictionary, formation_type: String = "fish_scale") -> Dictionary:
	var troop = get_troop_by_id(hero.get("troop_id", "t_cavalry"))
	
	var base_atk = int(hero.get("atk", 100) * 0.7 + troop.get("atk", 100) * 0.3)
	var base_def = int(hero.get("def", 50) * 0.7 + troop.get("def", 50) * 0.3)
	var base_satk = int(hero.get("satk", 100) * 0.7 + troop.get("satk", 100) * 0.3)
	var base_sdef = int(hero.get("sdef", 50) * 0.7 + troop.get("sdef", 50) * 0.3)
	var base_spd = hero.get("spd", 100)
	
	var evade_rate = troop.get("evade_rate", 0.05)
	var crit_rate = troop.get("crit_rate", 0.05)
	var block_rate = troop.get("block_rate", 0.05)
	var penetrate_rate = troop.get("penetrate_rate", 0.05)
	
	# 读取阵型 Buff 加成
	var form_info = BattleCalculator.FORMATIONS.get(formation_type, {})
	var bonuses = form_info.get("bonuses", {})
	
	var final_atk = int(base_atk * (1.0 + bonuses.get("atk_pct", 0.0)))
	var final_def = int(base_def * (1.0 + bonuses.get("def_pct", 0.0)))
	var final_satk = int(base_satk * (1.0 + bonuses.get("satk_pct", 0.0)))
	var final_sdef = int(base_sdef * (1.0 + bonuses.get("sdef_pct", 0.0)))
	var final_spd = int(base_spd * (1.0 + bonuses.get("spd_pct", 0.0)))
	
	evade_rate += bonuses.get("evade_rate", 0.0)
	crit_rate += bonuses.get("crit_rate", 0.0)
	block_rate += bonuses.get("block_rate", 0.0)
	penetrate_rate += bonuses.get("penetrate_rate", 0.0)
	
	return {
		"hp": hero.get("hp", 1000),
		"atk": final_atk,
		"def": final_def,
		"satk": final_satk,
		"sdef": final_sdef,
		"spd": final_spd,
		"evade_rate": evade_rate,
		"crit_rate": crit_rate,
		"block_rate": block_rate,
		"penetrate_rate": penetrate_rate,
		"bonus_target": troop.get("bonus_target", "无"),
		"bonus_rate": troop.get("bonus_rate", 0.0),
		"troop_name": troop.get("name", "兵种"),
		"troop_type": troop.get("type_name", "步兵"),
		"atk_mode": troop.get("atk_mode", "single"),
		"skill_name": troop.get("skill_name", "无"),
		"skill_desc": troop.get("skill_desc", ""),
		"skill_target_type": troop.get("skill_target_type", "single"),
		"skill_type": troop.get("skill_type", "normal"),
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
			tmpl["hp"] = int(tmpl["hp"] * stat_mult)
			tmpl["atk"] = int(tmpl["atk"] * stat_mult)
			tmpl["def"] = int(tmpl["def"] * stat_mult)
			tmpl["satk"] = int(tmpl["satk"] * stat_mult)
			tmpl["sdef"] = int(tmpl["sdef"] * stat_mult)
			enemy_formation[pos] = tmpl
			
	return enemy_formation

func auto_fill_formation() -> void:
	for pos in range(1, 10):
		player_formation[pos] = null
		
	var sorted_heroes = player_heroes.duplicate()
	sorted_heroes.sort_custom(func(a, b):
		var q_a = get_quality_config(a.get("quality", "N"))["rank_weight"]
		var q_b = get_quality_config(b.get("quality", "N"))["rank_weight"]
		if q_a != q_b:
			return q_a > q_b
		var lv_a = a.get("level", 1)
		var lv_b = b.get("level", 1)
		return lv_a > lv_b
	)
	
	var valid_positions = [1, 2, 3, 5, 8]
	if BattleCalculator.FORMATIONS.has(current_formation_type):
		valid_positions = BattleCalculator.FORMATIONS[current_formation_type].get("positions", [1, 2, 3, 5, 8])
		
	for i in range(min(valid_positions.size(), sorted_heroes.size())):
		var pos = valid_positions[i]
		player_formation[pos] = sorted_heroes[i]["uuid"]
		
	has_unsaved_changes = true
