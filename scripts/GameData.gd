## GameData.gd
## 全局 AutoLoad 单例，持有玩家角色数据及全局游戏状态。
## 在 project.godot 中已注册为 AutoLoad，任何脚本均可直接访问 GameData。
extends Node

# ── 玩家角色 ──────────────────────────────────────
## 玩家当前使用的角色实例，游戏启动时初始化。
var player: Character = null

# ── 游戏进度 ──────────────────────────────────────
var current_chapter: int = 1   ## 当前章节
var gold: int = 0              ## 灵石（货币）

# ── 剧情阶段 ──────────────────────────────────────
## 0 = 游戏刚开始，自动播放 morning 场景
## 1 = morning 结束后，提示玩家前往广场测试灵根
## 2 = 玩家踏入广场区域，自动触发 test 场景
## 3 = 灵根测试结束，触发废庙 temple 场景
## 4 = 废庙战斗后，触发 after_battle 场景
var story_phase: int = 0
var morning_triggered: bool = false

## 剧情阶段变化时发出（供 TownScene 等监听）
signal story_phase_changed(new_phase: int)

## 记录玩家最近一次来自哪个场景（"shop"/"tea"/"temple"/""）
## TownScene._ready() 读取此值决定出生点，读后清空
var last_scene: String = ""

## 回程强制触发节点的已触发ID列表（持久化，防止场景切换后重置）
var triggered_events: Array[String] = []

## 破碗是否已交互（持久化，只能触发一次）
var bowl_interacted: bool = false

## 碑文阅读进度（持久化，四个元素对应四块碑文）
var stones_read: Array[bool] = [false, false, false, false]

## 夜晚是否已触发（持久化，防止进出室内场景后重置）
var night_triggered: bool = false

## 隐藏道具：算命先生的铜钱
var got_coin: bool = false
## 是否拿到老婆婆给的平安符
var got_charm: bool = false

## 章末路径标记（"a"=一起走，"b"=回去看爹，""=未到章末）
var chapter_end_path: String = ""

## 存档时所在场景名（供读档后跳转用，与last_scene解耦）
var saved_scene_name: String = "TownScene"
## 存档时玩家坐标（仅TownScene内有意义）
var saved_player_position: Vector2 = Vector2.ZERO

## 消耗品库存
var heal_potions: int = 0    ## 伤药数量
var incenses: int = 0        ## 定神香数量
var talismans: int = 0       ## 辟邪符数量

## 古井今日是否已回血（每次进入TownScene重置）
var well_used_today: bool = false

## 旧物背包已解锁物品列表（持久化）
var unlocked_old_items: Array[String] = []

## 战斗是否胜利（BattleScene写入，TempleScene读取后清空）
var battle_won: bool = false

## 废庙副本状态
var temple_dungeon_state: Dictionary = {
	"wolf_left_defeated": false,
	"wolf_right_defeated": false,
	"toad_defeated": false,
	"boss_defeated": false,
}
## 当前正在交战的敌人ID
var current_enemy_id: String = ""
## 当前敌人数据（供BattleUI读取）
var current_enemy_data: Dictionary = {}
## 战斗前玩家坐标（返回TempleScene后恢复）
var last_player_position: Vector2 = Vector2.ZERO

## 玩家选择记录（RPG分支标签，独立于 triggered_events）
var narrative_flags: Dictionary = {}


func _ready() -> void:
	# 创建默认玩家角色（后续可改为从存档加载）
	_init_player()


## 初始化玩家角色，使用默认起始属性。
func _init_player() -> void:
	player = Character.new("苏云晚", 100, 15, 5)
	print("GameData: 玩家角色已初始化 —— ", str(player))


## 剧情阶段自增一步，发出信号供场景脚本监听。
func advance_phase() -> void:
	story_phase += 1
	story_phase_changed.emit(story_phase)
	print("GameData: story_phase推进到 ", story_phase)


## 跳转到指定阶段（用于需要跳过中间phase的场景，如测灵石 1→3）
func set_phase(target: int) -> void:
	story_phase = target
	story_phase_changed.emit(story_phase)
	print("GameData: story_phase设置为 ", story_phase)


## 仅供Debug使用，强制设置story_phase到指定值并发出信号
func debug_set_phase(target: int) -> void:
	story_phase = target
	story_phase_changed.emit(story_phase)
	print("DEBUG GameData: story_phase强制设为 ", story_phase)


## 重置所有游戏数据到初始状态（新游戏时调用）
## 不清除 manual_1 / manual_2 手动存档文件，只重置内存数据
func reset_to_default() -> void:
	_init_player()
	current_chapter    = 1
	gold               = 0
	story_phase        = 0
	morning_triggered  = false
	last_scene         = ""
	saved_scene_name   = "TownScene"
	saved_player_position = Vector2.ZERO
	triggered_events   = []
	bowl_interacted    = false
	stones_read        = [false, false, false, false]
	night_triggered    = false

	got_coin           = false
	got_charm          = false
	chapter_end_path   = ""
	heal_potions       = 0
	incenses           = 0
	talismans          = 0
	well_used_today    = false
	unlocked_old_items = []
	battle_won         = false
	temple_dungeon_state = {
		"wolf_left_defeated": false,
		"wolf_right_defeated": false,
		"toad_defeated":       false,
		"boss_defeated":       false,
	}
	current_enemy_id   = ""
	current_enemy_data = {}
	last_player_position = Vector2.ZERO
	narrative_flags    = {}
	story_phase_changed.emit(story_phase)
	print("GameData: 已重置为初始状态（新游戏）")


## 获得灵石。
func gain_gold(amount: int) -> void:
	gold += amount


## 消耗灵石，若不足则返回 false。
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


## 将玩家数据序列化为字典，用于存档。
func save_data() -> Dictionary:
	return {
		"player_name":    player.char_name,
		"player_hp":      player.hp,
		"player_max_hp":  player.max_hp,
		"player_atk":     player.atk,
		"player_def":     player.def,
		"gold":           gold,
		"chapter":        current_chapter,

		"got_coin":           got_coin,
		"got_charm":          got_charm,
		"chapter_end_path":  chapter_end_path,
		"story_phase":       story_phase,
		"morning_triggered": morning_triggered,
		"triggered_events":  triggered_events,
		"bowl_interacted":   bowl_interacted,
		"stones_read":       stones_read,
		"night_triggered":   night_triggered,
		"temple_dungeon_state": temple_dungeon_state,
		"last_scene":           last_scene,
		"heal_potions":         heal_potions,
		"incenses":             incenses,
		"talismans":            talismans,
		"unlocked_old_items":   unlocked_old_items,
		"saved_scene_name":     String(get_tree().current_scene.name) if get_tree() and get_tree().current_scene else "TownScene",
		"saved_player_position_x": saved_player_position.x,
		"saved_player_position_y": saved_player_position.y,
		"narrative_flags":      narrative_flags,
	}


## 从字典恢复玩家数据，用于读档。
func load_data(data: Dictionary) -> void:
	player          = Character.new(
		data.get("player_name", "苏云晚"),
		data.get("player_max_hp", 100),
		data.get("player_atk", 15),
		data.get("player_def", 5))
	player.hp       = data.get("player_hp", player.max_hp)
	gold            = data.get("gold", 0)
	current_chapter    = data.get("chapter", 1)

	got_coin           = data.get("got_coin", false)
	got_charm          = data.get("got_charm", false)
	chapter_end_path   = data.get("chapter_end_path", "")
	story_phase        = data.get("story_phase", 0)
	morning_triggered  = data.get("morning_triggered", false)
	triggered_events   = Array(data.get("triggered_events", []), TYPE_STRING, "", null)
	## 兼容旧存档：若曾触发过market对话，视为已拿到平安符
	if not got_charm and triggered_events.has("market_done"):
		got_charm = true
	bowl_interacted    = data.get("bowl_interacted", false)
	stones_read        = Array(data.get("stones_read", [false, false, false, false]), TYPE_BOOL, "", null)
	night_triggered    = data.get("night_triggered", false)
	var default_dungeon_state := {
		"wolf_left_defeated": false,
		"wolf_right_defeated": false,
		"toad_defeated": false,
		"boss_defeated": false
	}
	var loaded_dungeon_state: Dictionary = data.get("temple_dungeon_state", {})
	default_dungeon_state.merge(loaded_dungeon_state, true)
	temple_dungeon_state = default_dungeon_state
	last_scene   = data.get("last_scene", "")
	heal_potions = data.get("heal_potions", 0)
	incenses     = data.get("incenses", 0)
	talismans    = data.get("talismans", 0)
	unlocked_old_items = Array(data.get("unlocked_old_items", []), TYPE_STRING, "", null)
	well_used_today = false
	saved_scene_name = data.get("saved_scene_name", "TownScene")
	saved_player_position = Vector2(
		data.get("saved_player_position_x", 0.0),
		data.get("saved_player_position_y", 0.0)
	)
	narrative_flags = data.get("narrative_flags", {})
	print("GameData: 存档加载完毕 —— ", str(player))


## 存档槽路径映射
const SAVE_PATHS := {
	"auto":      "user://save_auto.json",
	"manual_1":  "user://save_manual_1.json",
	"manual_2":  "user://save_manual_2.json",
	"crossroad": "user://save_crossroad.json",
}


## 将当前GameData写入指定存档槽
## slot_name: "auto" / "manual_1" / "manual_2" / "crossroad"
## 使用"先写临时文件再替换"的安全写入策略，防止写入中断导致存档损坏
func save_to_file(slot_name: String = "auto") -> void:
	if not SAVE_PATHS.has(slot_name):
		push_error("GameData: 未知存档槽 '%s'" % slot_name)
		return

	var path: String = SAVE_PATHS[slot_name]
	var data := save_data()
	var json_str := JSON.stringify(data, "\t")

	## 先写临时文件
	var tmp_path := path + ".tmp"
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		push_error("GameData: 无法写入临时存档文件，错误码 %d" % FileAccess.get_open_error())
		return
	tmp_file.store_string(json_str)
	tmp_file.close()

	## 临时文件写入成功后替换正式存档
	## Windows上rename_absolute无法覆盖已存在文件，必须先删除旧档
	if FileAccess.file_exists(path):
		var rm_err := DirAccess.remove_absolute(path)
		if rm_err != OK:
			push_error("GameData: 无法删除旧存档以进行覆盖，错误码 %d" % rm_err)
			return

	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("GameData: 存档替换失败，错误码 %d" % err)
		return

	print("GameData: 存档已保存 → %s（槽位：%s）" % [path, slot_name])


## 从指定存档槽读取并恢复GameData
## slot_name: "auto" / "manual_1" / "manual_2" / "crossroad"
## 返回true表示成功读取，false表示无存档或读取失败
func load_from_file(slot_name: String = "auto") -> bool:
	if not SAVE_PATHS.has(slot_name):
		push_error("GameData: 未知存档槽 '%s'" % slot_name)
		return false

	var path: String = SAVE_PATHS[slot_name]

	if not FileAccess.file_exists(path):
		print("GameData: 槽位 '%s' 无存档文件" % slot_name)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: 无法读取存档文件，错误码 %d" % FileAccess.get_open_error())
		return false

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("GameData: 存档JSON解析失败（行 %d）：%s" % [
			json.get_error_line(), json.get_error_message()])
		return false

	load_data(json.data)
	print("GameData: 存档读取成功（槽位：%s）story_phase = %d，last_scene = %s" % [
		slot_name, story_phase, last_scene])
	return true


## 删除指定存档槽文件（用于"重新开始"或覆盖提示前的清理）
func delete_save(slot_name: String = "auto") -> void:
	if not SAVE_PATHS.has(slot_name):
		push_error("GameData: 未知存档槽 '%s'" % slot_name)
		return

	var path: String = SAVE_PATHS[slot_name]
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err == OK:
			print("GameData: 存档已删除（槽位：%s）" % slot_name)
		else:
			push_error("GameData: 存档删除失败，错误码 %d" % err)


## 查询指定存档槽是否有存档文件（供主菜单和系统菜单判断按钮状态）
func has_save(slot_name: String) -> bool:
	if not SAVE_PATHS.has(slot_name):
		return false
	return FileAccess.file_exists(SAVE_PATHS[slot_name])


## 获取指定存档槽的简要信息（供主菜单显示存档预览）
## 返回字典含 phase/gold/name，读取失败返回空字典
func get_save_preview(slot_name: String) -> Dictionary:
	if not has_save(slot_name):
		return {}

	var path: String = SAVE_PATHS[slot_name]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw) != OK:
		return {}

	var data: Dictionary = json.data
	return {
		"phase": data.get("story_phase", 0),
		"gold":  data.get("gold", 0),
		"name":  data.get("player_name", "苏云晚"),
	}
