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
var exp: int = 0               ## 经验值
var level: int = 1             ## 境界等级

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


func _ready() -> void:
	# 创建默认玩家角色（后续可改为从存档加载）
	_init_player()


## 初始化玩家角色，使用默认起始属性。
func _init_player() -> void:
	player = Character.new("无名散修", 100, 15, 5)
	print("GameData: 玩家角色已初始化 —— ", str(player))


## 玩家获得经验值，满足阈值后自动升级。
func gain_exp(amount: int) -> void:
	exp += amount
	var threshold: int = level * 100  # 每级所需经验 = 等级 × 100
	if exp >= threshold:
		exp -= threshold
		_level_up()


## 升级：提升属性并打印日志。
func _level_up() -> void:
	level += 1
	player.max_hp += 20
	player.hp = player.max_hp  # 升级时回满 HP
	player.atk += 3
	player.def += 1
	print("🎊 境界突破！当前等级：%d  %s" % [level, str(player)])


## 推进剧情阶段，发出信号供场景脚本监听。
func set_story_phase(phase: int) -> void:
	story_phase = phase
	story_phase_changed.emit(phase)
	print("GameData: 剧情阶段推进 → phase ", phase)


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
		"level":          level,
		"exp":            exp,
		"gold":           gold,
		"chapter":        current_chapter,
	}


## 从字典恢复玩家数据，用于读档。
func load_data(data: Dictionary) -> void:
	player          = Character.new(data["player_name"], data["player_max_hp"],
									data["player_atk"],  data["player_def"])
	player.hp       = data["player_hp"]
	level           = data["level"]
	exp             = data["exp"]
	gold            = data["gold"]
	current_chapter = data["chapter"]
	print("GameData: 存档加载完毕 —— ", str(player))
