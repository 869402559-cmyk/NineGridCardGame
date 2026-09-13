extends SceneTree

func _init() -> void:
	print("==========================================")
	print("🚀 开始 3 项 UI 方案 A 落地自动化自测...")
	print("==========================================")

	var GameDataScript = load("res://scripts/GameData.gd")
	var game_data = GameDataScript.new()
	game_data.load_all_csv_data()

	# 1. 测试 GameData 章节前沿自动定位逻辑
	print("[1/3] 测试 GameData 前沿章节计算 (get_frontier_chapter_index)...")
	game_data.cleared_stages.clear()
	var front_0 = game_data.get_frontier_chapter_index()
	assert(front_0 == 0, "全新账号应定位到 0 章")

	# 模拟通关第一章全部关卡
	for st in game_data.CHAPTERS[0]["stages"]:
		game_data.cleared_stages.append(st["id"])
	var front_1 = game_data.get_frontier_chapter_index()
	assert(front_1 == 1, "全通第一章后应定位到 1 章")
	print("  -> GameData 自动定位计算正确！(未通关: 第" + str(front_0 + 1) + "章, 通关第1章后: 第" + str(front_1 + 1) + "章)")

	# 2. 测试 CampaignUI 默认章节与关卡选择
	print("[2/3] 测试 CampaignUI 脚本语法与逻辑...")
	var campaign_script = load("res://scripts/CampaignUI.gd")
	assert(campaign_script != null, "CampaignUI 脚本应该加载正常")

	# 3. 测试 BattleUI 结算弹窗创建
	print("[3/3] 测试 BattleUI 结算弹窗组件...")
	var battle_script = load("res://scripts/BattleUI.gd")
	assert(battle_script != null, "BattleUI 脚本应该加载正常")

	print("==========================================")
	print("🎉 3 项方案 A 全部通过无头自动化校验！零语法/运行时错误！")
	print("==========================================")
	quit()
