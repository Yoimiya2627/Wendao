## TownScene.gd
## 碎玉镇大地图：40×30格，每格32px
## 双层TileMap：Layer0=地面（可行走），Layer1=碰撞（建筑/障碍）
## 三处建筑入口：按 E 进入，带1秒冷却，SceneTransition淡入淡出
extends Node2D

# ══════════════════════════════════════════════════════════════════
# 一、地图常量
# ══════════════════════════════════════════════════════════════════

## 每格像素大小
const TILE_SIZE  : int = 32
## 地图列数（横向格数）
const MAP_COLS   : int = 40
## 地图行数（纵向格数）
const MAP_ROWS   : int = 30

# 地块索引（对应 TileSetAtlasSource 的 atlas_x 坐标）
const TILE_ROAD   : int = 0  ## 青石板路（主干道，灰色）
const TILE_GRASS  : int = 1  ## 草地（绿色，可行走）
const TILE_SHOP   : int = 2  ## 铺前土地（棕色，建筑门口过渡）
const TILE_MARKET : int = 3  ## 集市地面（米黄色）
const TILE_DARK   : int = 4  ## 深色草地（废庙方向，偏暗）
const TILE_WALL   : int = 5  ## 建筑外墙（深棕色，Layer1，有碰撞）
const TILE_PLAZA  : int = 6  ## 青石板广场（冷灰色，测灵广场）

# ══════════════════════════════════════════════════════════════════
# 二、入口格坐标（对应规范第四节）
# ══════════════════════════════════════════════════════════════════

## 杂货铺入口格坐标，像素 = (192, 352)
const ENTRANCE_SHOP_GRID   : Vector2i = Vector2i(6,  11)
## 茶馆入口格坐标，像素 = (896, 768)
const ENTRANCE_TEA_GRID    : Vector2i = Vector2i(28, 24)
## 废庙入口格坐标，像素 = (1184, 896)
const ENTRANCE_TEMPLE_GRID : Vector2i = Vector2i(36, 28)

## 入口触发检测半径（格子数，±1格均可触发提示）
## 注意：必须保持为1，否则SPAWN_FROM_SHOP/TEA/TEMPLE的1格偏移就脱离了入口判定区
## 同时也用于story phase 3的"灯还亮着"等回程旁白触发
const ENTRANCE_RANGE : int = 1

## 场景切换冷却时间（秒），防止连续重复触发
const TRANSITION_COOLDOWN : float = 1.0

# ══════════════════════════════════════════════════════════════════
# 三、出生点坐标（对应规范第五节）
# 坐标公式：Vector2(grid_x * TILE_SIZE, grid_y * TILE_SIZE)
# ══════════════════════════════════════════════════════════════════

## 从杂货铺(ShopScene)返回，出生在格(6,12)
## 验证：grid(6,12) 与 ENTRANCE_SHOP_GRID(6,11) 的距离 = abs(12-11)=1 ≤ ENTRANCE_RANGE(1)，双向有效 ✓
const SPAWN_FROM_SHOP   : Vector2 = Vector2(192,  384)
## 从茶馆(TeaScene)返回，出生在格(28,25)
const SPAWN_FROM_TEA    : Vector2 = Vector2(896,  800)
## 从废庙(TempleScene)返回，出生在格(37,29)
const SPAWN_FROM_TEMPLE : Vector2 = Vector2(1152, 896)
## 默认出生点：主干道交叉口格(20,14)
const SPAWN_DEFAULT     : Vector2 = Vector2(640,  448)

# ══════════════════════════════════════════════════════════════════
# 四、回程强制触发节点表（story_phase == 3 时生效）
# 玩家走进对应格子范围自动触发旁白，每个节点只触发一次（由 is_triggered 守卫）
# ══════════════════════════════════════════════════════════════════

const FORCE_TRIGGER_NODES : Array = [
	{ "grid": Vector2i(21, 15), "scene_id": "water_carrier_return",  "node_name": "NPC_WaterCarrier" },
	{ "grid": Vector2i(17, 16), "scene_id": "dog_return",            "node_name": "NPC_OldDog" },
	{ "grid": Vector2i(14, 14), "scene_id": "aunts_return",          "node_name": "NPC_AuntA" },
	{ "grid": Vector2i(10, 18), "scene_id": "celebration_boy",       "node_name": "" },
	{ "grid": Vector2i(8,  22), "scene_id": "fortune_teller_return", "node_name": "NPC_FortuneTeller" },
]

# ══════════════════════════════════════════════════════════════════
# 四b、环境气泡对话节点（story_phase==1 广场探索时触发）
# 玩家走近指定格子自动弹出浮动文字，每条只触发一次
# ══════════════════════════════════════════════════════════════════

const BUBBLE_NODES : Array = [
	{ "grid": Vector2i(28, 11), "text": "也不知道能测出什么来……" },
	{ "grid": Vector2i(34, 10), "text": "今年来的人不少。" },
	{ "grid": Vector2i(35,  9), "text": "八品！能进门就行，够了够了。" },
	{ "grid": Vector2i(17, 14), "text": "老榕树的根把石板路拱起来了一块。" },
	{ "grid": Vector2i(22, 17), "text": "井沿磨得很光，往下看，黑洞洞的。" },
]

## 隐藏交互点：玩家走近后按E触发，每个只触发一次
const HIDDEN_INTERACT_NODES: Array = [
	## 传音阵：南门附近偏僻角落，格(23,27)
	{
		"grid":     Vector2i(23, 27),
		"scene_id": "transmission_array",
		"hint":     "按 E 查看",
	},
	## 残页一：杂货铺货架后侧，格(3,8)
	{
		"grid":     Vector2i(3, 8),
		"scene_id": "remnant_page_1",
		"hint":     "按 E 查看",
	},
	## 残页二：老榕树树洞后侧，格(17,14)
	{
		"grid":     Vector2i(17, 14),
		"scene_id": "remnant_page_2",
		"hint":     "按 E 查看",
	},
	## 残页三：古井旁石缝，格(22,17)
	{
		"grid":     Vector2i(22, 17),
		"scene_id": "remnant_page_3",
		"hint":     "按 E 查看",
	},
	## 公告栏：测灵台旁，格(22,13)，路标型：phase<3显示before，phase≥3显示after
	{
		"grid":        Vector2i(22, 13),
		"scene_id":    "notice_board_before",
		"hint":        "按 E 查看公告",
		"is_signpost": true,
		"alt_scene_id": "notice_board_after",
		"alt_phase":   3,
	},
	## 西墙根磨平的石板：杂货铺以西空地，格(2,14)，路标型（可反复看，phase 切换文本）
	{
		"grid":        Vector2i(2, 14),
		"scene_id":    "west_stone_slab",
		"hint":        "按 E 查看",
		"is_signpost": true,
		"alt_scene_id": "west_stone_slab_after",
		"alt_phase":   3,
	},
]

# ══════════════════════════════════════════════════════════════════
# 五、节点引用（@onready 在 _ready() 前自动赋值）
# ══════════════════════════════════════════════════════════════════

@onready var _tile_map    : TileMap         = $TownMap
@onready var _player      : CharacterBody2D = $Player
@onready var _spawn_point : Node2D          = $SpawnPoint
@onready var _enter_hint  : Label           = $Player/EnterHintLabel

# ══════════════════════════════════════════════════════════════════
# 五、状态变量
# ══════════════════════════════════════════════════════════════════

## 当前靠近的入口键（"shop" / "tea" / "temple" / ""=无）
var _current_entrance  : String = ""
## 场景切换冷却剩余时间（秒）
var _transition_timer  : float  = 0.0
## TileSet 源ID，绘制地图时引用
var _tileset_source_id : int    = -1
## 是否已完成初始化（story_phase==0重定向时为false，跳过_process逻辑）
var _initialized       : bool   = false

## 测灵广场触发范围（cols 25-38, rows 2-12）
const PLAZA_RECT_MIN : Vector2i = Vector2i(25, 2)
const PLAZA_RECT_MAX : Vector2i = Vector2i(38, 12)

## 测灵石是否已激活（test第一段结束后变为true）
var _stone_interactable: bool = false
## 测灵石是否已使用（防止重复触发）
var _stone_used: bool = false

## 夜晚渐变用的CanvasLayer和ColorRect
var _night_overlay: ColorRect = null
var _night_triggered: bool = false

## 气泡对话标签（世界空间 RichTextLabel，动态创建，支持 BBCode 斜体）
var _bubble_label: RichTextLabel = null
## 气泡显示剩余时间（秒）
var _bubble_timer: float = 0.0
## 气泡触发状态（BUBBLE_NODES的运行时副本，含triggered字段）
var _bubble_states: Array = []

## 隐藏交互点的触发状态（运行时副本）
var _hidden_interact_states: Array = []
## 当前靠近的隐藏交互点索引（-1=无）
var _nearby_hidden_interact: int = -1
## 玩家是否在药婆感应区内
var _near_vendor: bool = false

## 测灵失败演出: 暗化遮罩节点（在 DialogueBox 之下、世界之上）
var _test_dim_canvas: CanvasLayer = null
var _test_dim_overlay: ColorRect = null


# ══════════════════════════════════════════════════════════════════
# 六、生命周期
# ══════════════════════════════════════════════════════════════════

func _ready() -> void:
	## 读档职能已移交MainMenuScene，此处不再自行读档

	## 规则七：morning未触发（新游戏或存档phase==0）直接切换至杂货铺
	if not GameData.morning_triggered:
		await _wait_for_transition()
		SceneTransition.change_scene("res://scenes/ShopScene.tscn")
		return

	# 执行顺序（规范第八节）：① 建地图 → ② 设出生点 → ③ 设摄像机 → ④ 连信号
	_build_tileset_and_map()
	_set_spawn_position()
	_setup_camera()
	_connect_story_signals()
	## NPC状态恢复：从GameData读取持久化状态，恢复消失/对话切换
	var npc_layer_ready = get_node_or_null("NPCLayer")
	if npc_layer_ready:
		for npc in npc_layer_ready.get_children():
			if npc.has_method("restore_state_from_save"):
				npc.restore_state_from_save()
	## 强制矫正测验师状态（基于story_phase，防止切场景后重置）
	if GameData.story_phase >= 3:
		var examiner_node = get_node_or_null("NPCLayer/NPC_Examiner")
		if examiner_node:
			examiner_node.dialogue_scene_id = "examiner_after"
		## 老婆婆：phase 1 专属角色（给平安符后消失）。
		## 若玩家 phase 1 未与她互动，到 phase 3 应视为"她自己离开了"，
		## 否则会触发过时的 market 对话（仍在讨论测灵）。
		var old_woman_late = get_node_or_null("NPCLayer/NPC_OldWoman")
		if old_woman_late and old_woman_late.visible:
			old_woman_late.disappear()
	_setup_night_overlay()
	_init_bubble_states()
	_init_hidden_interact_states()
	## 每次进入TownScene重置古井回血（时间成本限制）
	GameData.well_used_today = false
	## 夜晚且phase<5时刷出药婆
	if GameData.night_triggered and GameData.story_phase < 5:
		_setup_night_vendor()
	## 夜晚且phase在3-4之间时激活古井回血区
	if GameData.night_triggered and GameData.story_phase >= 3 and GameData.story_phase < 5:
		_setup_well_heal_area()
	## 算命先生状态恢复
	var ft_npc_ready = get_node_or_null("NPCLayer/NPC_FortuneTeller")
	if ft_npc_ready:
		if GameData.got_coin:
			## 已拿过铜钱：彻底禁用
			ft_npc_ready.dialogue_scene_id = ""
			ft_npc_ready.is_triggered = true
		elif GameData.triggered_events.has("fortune_teller_return"):
			## 旁白已触发但未拿铜钱：切换为铜钱对话
			ft_npc_ready.dialogue_scene_id = "fortune_teller_coin"
			ft_npc_ready.is_triggered = false
	## 香料摊回程文案按是否买过桂皮动态切换
	_sync_vendor_b_return_dialogue()
	## 读档后全量同步UI（HP条+背包+心绪面板）
	UIManager.refresh_all_data()
	## BGM：夜晚 / phase ≥ 3 白天 / phase < 3 白天 三档
	## v40.8: phase 3 白天用 shop_return 钢琴感 (心境已沉)
	## v40.9: town_night 用 3.0s 慢淡入 (默认 1.5s 太"扑面")
	##        让"夜的声音慢慢浮起来"——配合 ShopScene 出门时 BGM 已渐止到无声
	if GameData.night_triggered:
		AudioManager.play_bgm("town_night", 3.0)
	elif GameData.story_phase >= 3:
		AudioManager.play_bgm("shop_return")
	else:
		AudioManager.play_bgm("town_day")
	_initialized = true


func _exit_tree() -> void:
	if DialogueManager.event_triggered.is_connected(_on_event_triggered):
		DialogueManager.event_triggered.disconnect(_on_event_triggered)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)


func _process(delta: float) -> void:
	# 未初始化时跳过（story_phase==0重定向期间）
	if not _initialized:
		return
	# 冷却倒计时
	if _transition_timer > 0.0:
		_transition_timer -= delta
	# 每帧检测玩家与入口的距离，更新提示标签
	_check_entrance_proximity()
	# 回程阶段：走近 NPC 自动触发旁白，无需按 E
	if GameData.story_phase == 3:
		_check_force_triggers()
	## 检测玩家进入测灵广场（story_phase==1时自动触发test）
	if GameData.story_phase == 1 and _initialized:
		_check_plaza_trigger()
	## 测灵石激活后检测玩家是否靠近
	if _stone_interactable and _initialized:
		_check_stone_interaction()
	## 检测回家触发（story_phase==3时走回杂货铺自动触发）
	if GameData.story_phase == 3 and _initialized:
		_check_return_home_trigger()
	## 夜行氛围旁白（经过榕树/古井时自动触发，一次性）
	if GameData.night_triggered and _initialized:
		_check_night_walk_triggers()
	## 气泡计时器倒计
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_hide_bubble()
	## 气泡对话触发（story_phase==1 广场探索时）
	if GameData.story_phase == 1 and _initialized:
		_check_bubble_triggers()
	## 检测隐藏交互点
	if _initialized:
		_check_hidden_interact_proximity()


func _unhandled_input(event: InputEvent) -> void:
	# 调试快捷键：强制设置 story_phase（仅 debug 构建生效）
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				## 调试 (v40.6): 快速测试"测灵失败"演出
				## 原 KEY_1=debug_set_phase(1) 被覆盖，重置相关状态后直接进入 test_stone
				if DialogueManager.is_active:
					DialogueManager.force_stop()
				# 清理上一次测试可能残留的暗化遮罩
				if _test_dim_canvas != null and is_instance_valid(_test_dim_canvas):
					_test_dim_canvas.queue_free()
				_test_dim_canvas = null
				_test_dim_overlay = null
				# 重置 phase 与选择 flag, 允许重复触发并测两种选择分支
				GameData.story_phase = 1
				GameData.narrative_flags.erase("self_test_calm")
				GameData.narrative_flags.erase("self_test_hurt")
				# v40.8: KEY_1 强制把 BGM 切回 town_day, 保证每次测试起点一致
				# (上一次测试结尾会切到 shop_return, 不重置就测的是 shop_return 衔接)
				AudioManager.play_bgm("town_day", 0.3)
				# 把玩家送到测灵石跟前 (960, 280): 视觉上下文对得上"广场上测灵那一刻"
				_player.global_position = Vector2(960, 280)
				print("[DEBUG] KEY_1 → 触发测灵失败演出 (test_stone)")
				DialogueManager.start_scene("test_stone")
			KEY_2: GameData.debug_set_phase(2)
			KEY_3: GameData.debug_set_phase(3)
			KEY_4: GameData.debug_set_phase(4)
			KEY_5:
				## 调试：直接进内殿，跳过前置流程
				## 石碑全读完（解锁内殿门和BOSS门条件）
				GameData.stones_read = Array([true, true, true, false], TYPE_BOOL, "", null)
				## 左右幽影狼已击败（跳过厢房）
				GameData.temple_dungeon_state["wolf_left_defeated"] = true
				GameData.temple_dungeon_state["wolf_right_defeated"] = true
				## 石皮蟾保持存活，BOSS保持存活
				GameData.temple_dungeon_state["toad_defeated"] = false
				## 推进到正确phase（3=进废庙前，战斗尚未开始）
				GameData.debug_set_phase(3)
				GameData.morning_triggered = true
				GameData.night_triggered = true
				## 调试时跳过首次战斗教学（避免每次重置都弹教学对话卡住按钮）
				if not GameData.triggered_events.has("tutorial_first_battle"):
					GameData.triggered_events.append("tutorial_first_battle")
				## 玩家落点设为内殿入口
				GameData.last_player_position = Vector2(240, -51)
				SceneTransition.change_scene("res://scenes/TempleScene.tscn")
			KEY_6:
				## 调试：直接进入BOSS战，且BOSS已进入第二阶段
				GameData.stones_read = Array([true, true, true, true], TYPE_BOOL, "", null)
				GameData.temple_dungeon_state["wolf_left_defeated"] = true
				GameData.temple_dungeon_state["wolf_right_defeated"] = true
				GameData.temple_dungeon_state["toad_defeated"] = true
				GameData.debug_set_phase(3)
				GameData.morning_triggered = true
				GameData.night_triggered = true
				GameData.current_enemy_id = "boss"
				GameData.current_enemy_data = {
					"name": "虚形魇",
					"hp": 30,
					"max_hp": 120,
					"atk": 16,
					"def": 4
				}
				SceneTransition.change_scene("res://scenes/BattleScene.tscn")

	# 未初始化或没有靠近任何入口时忽略
	if not _initialized:
		return
	# E 键处理
	if event is InputEventKey \
			and event.keycode == KEY_E \
			and event.pressed \
			and not event.echo:
		## 测灵石交互
		if _stone_interactable and not _stone_used:
			var stone = get_node_or_null("PlazaLayer/TestingStone")
			if stone:
				var area = stone.get_node_or_null("Area2D")
				if area:
					var bodies = area.get_overlapping_bodies()
					for body in bodies:
						if body is CharacterBody2D:
							_stone_used = true
							_stone_interactable = false
							_enter_hint.hide()
							DialogueManager.start_scene("test_stone")
							get_viewport().set_input_as_handled()
							return
		## 药婆购买
		if GameData.night_triggered and GameData.story_phase < 5:
			if _try_vendor_interact():
				get_viewport().set_input_as_handled()
				return

		## 古井回血
		if GameData.night_triggered and GameData.story_phase >= 3 and GameData.story_phase < 5:
			var well_node = get_node_or_null("WellHealArea")
			if well_node:
				var well_area = well_node.get_node_or_null("Area2D")
				if well_area:
					for body_node in well_area.get_overlapping_bodies():
						if body_node is CharacterBody2D:
							if not GameData.well_used_today \
									and GameData.player.hp < GameData.player.max_hp \
									and not DialogueManager.is_active:
								GameData.well_used_today = true
								var heal_amount := ceili(GameData.player.max_hp * 0.3)
								GameData.player.heal(heal_amount)
								_enter_hint.hide()
								UIManager.refresh_hp()
								DialogueManager.start_scene("well_heal")
								get_viewport().set_input_as_handled()
								return

		## 隐藏交互点
		if _nearby_hidden_interact >= 0:
			var state = _hidden_interact_states[_nearby_hidden_interact]
			## 路标型：不锁定，每次按E都可触发，根据phase选不同场景
			if state["is_signpost"]:
				var sid: String
				if state["alt_phase"] >= 0 and GameData.story_phase >= state["alt_phase"]:
					sid = state["alt_scene_id"]
				else:
					sid = state["scene_id"]
				DialogueManager.start_scene(sid)
				get_viewport().set_input_as_handled()
				return
			## 普通隐藏交互：触发一次后锁定
			state["triggered"] = true
			_nearby_hidden_interact = -1
			_enter_hint.hide()
			DialogueManager.start_scene(state["scene_id"])
			get_viewport().set_input_as_handled()
			return
		## 入口进入
		if _current_entrance != "":
			# 延迟一帧执行：让同一帧内的 NPC 交互优先（NPC.interact()会先设置 is_active）
			call_deferred("_try_enter_scene", _current_entrance)


# ══════════════════════════════════════════════════════════════════
# 七、出生点系统（规范第五节）
# ══════════════════════════════════════════════════════════════════

## 根据 GameData.last_scene 决定玩家进入 TownScene 后的出生位置
func _set_spawn_position() -> void:
	var pos: Vector2
	## 有手动存档坐标时优先使用（ESC菜单存档时记录）
	if GameData.saved_player_position != Vector2.ZERO:
		pos = GameData.saved_player_position
		GameData.saved_player_position = Vector2.ZERO
	else:
		match GameData.last_scene:
			"shop":
				pos = SPAWN_FROM_SHOP
			"tea":
				pos = SPAWN_FROM_TEA
			"temple":
				pos = SPAWN_FROM_TEMPLE
			_:
				pos = SPAWN_DEFAULT
	# 同步更新 SpawnPoint 节点位置与玩家位置
	_spawn_point.global_position = pos
	_player.global_position      = pos
	# 清空 last_scene，防止下次进入TownScene时重复读取旧值
	GameData.last_scene = ""


# ══════════════════════════════════════════════════════════════════
# 八、摄像机设置（规范第三节）
# ══════════════════════════════════════════════════════════════════

## 设置 Player.tscn 内 Camera2D 的边界与平滑参数
func _setup_camera() -> void:
	var cam: Camera2D = _player.get_node("Camera2D")
	# zoom=1.0：视口即世界，1280×720 完整呈现，不额外放大
	cam.zoom = Vector2(1.0, 1.0)
	# 地图边界：40×32 = 1280px，30×32 = 960px
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = MAP_COLS * TILE_SIZE   # = 1280
	cam.limit_bottom = MAP_ROWS * TILE_SIZE   # = 960
	# 开启位置平滑，防止摄像机抖动
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed   = 5.0


# ══════════════════════════════════════════════════════════════════
# 九、入口检测系统（规范第四节）
# ══════════════════════════════════════════════════════════════════

## 每帧将玩家像素坐标转换为格坐标，判断是否靠近三个入口
func _check_entrance_proximity() -> void:
	# 对话进行中不显示入口提示
	if DialogueManager.is_active:
		_set_entrance_hint("")
		return

	## 药婆感应区内：维持"按E购买"提示，不被入口提示覆盖
	if _near_vendor:
		_enter_hint.text = "按 E 购买"
		_enter_hint.show()
		_current_entrance = ""
		return

	# 玩家当前格坐标（整数除法向下取整）
	var pg := Vector2i(
		int(_player.global_position.x / TILE_SIZE),
		int(_player.global_position.y / TILE_SIZE)
	)

	# 按优先级依次检测三个入口
	if _in_range(pg, ENTRANCE_SHOP_GRID):
		_set_entrance_hint("shop")
		return

	if _in_range(pg, ENTRANCE_TEA_GRID):
		if GameData.night_triggered:
			_enter_hint.text = "茶馆已打烊"
			_enter_hint.show()
			_current_entrance = ""
		else:
			_set_entrance_hint("tea")
		return

	if _in_range(pg, ENTRANCE_TEMPLE_GRID):
		# 废庙特殊规则：story_phase < 3 时大门紧锁
		if GameData.story_phase < 3 or not GameData.night_triggered:
			_enter_hint.text = "大门紧锁"
			_enter_hint.show()
			_current_entrance = ""
		else:
			_set_entrance_hint("temple")
			CharmSpirit.try_whisper("before_temple")
		return

	# 不靠近任何入口，隐藏提示
	_set_entrance_hint("")


## 判断玩家格坐标是否在指定入口格的 ±ENTRANCE_RANGE 范围内
func _in_range(player_grid: Vector2i, entrance_grid: Vector2i) -> bool:
	return abs(player_grid.x - entrance_grid.x) <= ENTRANCE_RANGE \
		and abs(player_grid.y - entrance_grid.y) <= ENTRANCE_RANGE


## 回程强制触发：玩家走进格子范围自动触发旁白，无需按E，每个节点只触发一次
func _check_force_triggers() -> void:
	## 夜晚不触发任何回程旁白
	if GameData.night_triggered:
		return
	if DialogueManager.is_active:
		return
	var pg := Vector2i(
		int(_player.global_position.x / TILE_SIZE),
		int(_player.global_position.y / TILE_SIZE)
	)
	for entry in FORCE_TRIGGER_NODES:
		if GameData.triggered_events.has(entry["scene_id"]):
			continue
		if abs(pg.x - entry["grid"].x) <= 2 and abs(pg.y - entry["grid"].y) <= 2:
			GameData.triggered_events.append(entry["scene_id"])
			## node_name不为空时才设置is_triggered
			if not entry["node_name"].is_empty():
				var npc_node = get_node_or_null("NPCLayer/" + entry["node_name"])
				if npc_node:
					npc_node.is_triggered = true
			## 算命先生收摊旁白触发后，切换为铜钱对话，玩家可主动按E获取
			if entry["scene_id"] == "fortune_teller_return":
				var ft_npc = get_node_or_null("NPCLayer/NPC_FortuneTeller")
				if ft_npc and not GameData.got_coin:
					ft_npc.dialogue_scene_id = "fortune_teller_coin"
					ft_npc.dialogue_scene_id_after = ""
					ft_npc.is_triggered = false
			DialogueManager.start_scene(entry["scene_id"])
			return


## 更新 _current_entrance 并刷新提示标签文字与可见性
func _set_entrance_hint(entrance: String) -> void:
	_current_entrance = entrance
	if entrance == "":
		_enter_hint.hide()
	else:
		_enter_hint.text = "按 E 进入"
		_enter_hint.show()


# ══════════════════════════════════════════════════════════════════
# 十、场景切换系统（规范第四节）
# ══════════════════════════════════════════════════════════════════

## 延迟执行：若同帧内 NPC 对话已启动则放弃切换（NPC交互优先级更高）
func _try_enter_scene(entrance: String) -> void:
	if DialogueManager.is_active:
		return
	_enter_scene(entrance)


## 执行场景切换，带冷却与防重入保护
func _enter_scene(entrance: String) -> void:
	# 冷却未结束或过渡动画进行中，拒绝切换
	if _transition_timer > 0.0 or SceneTransition.is_transitioning:
		return
	_transition_timer = TRANSITION_COOLDOWN
	match entrance:
		"shop":
			SceneTransition.change_scene("res://scenes/ShopScene.tscn")
		"tea":
			SceneTransition.change_scene("res://scenes/TeaScene.tscn")
		"temple":
			## 夜晚首次进废庙：播放入口氛围旁白
			if GameData.night_triggered \
					and not GameData.triggered_events.has("temple_entrance_night"):
				GameData.triggered_events.append("temple_entrance_night")
				DialogueManager.start_scene("temple_entrance_night")
				await DialogueManager.dialogue_ended
				if not is_inside_tree():
					return
			## 进入废庙前保存：废庙内战斗不保存，以此为最后存档点
			GameData.last_scene = ""
			GameData.saved_player_position = Vector2.ZERO
			GameData.save_to_file("auto")
			SceneTransition.change_scene("res://scenes/TempleScene.tscn")


## 等待 SceneTransition 当前过渡动画完成（供 story_phase==0 重定向使用）
func _wait_for_transition() -> void:
	while SceneTransition.is_transitioning:
		if not is_inside_tree():
			return
		await get_tree().process_frame


# ══════════════════════════════════════════════════════════════════
# 十一、TileSet 构建（规范第一、二节）
# ══════════════════════════════════════════════════════════════════

## 程序化构建7色TileSet（含Layer1碰撞定义）并绘制完整地图
func _build_tileset_and_map() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# ① 添加物理碰撞层，供 TILE_WALL（tile 5）使用
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)  # 物理碰撞层1
	ts.set_physics_layer_collision_mask(0, 1)   # 碰撞掩码1（与玩家CapsuleShape匹配）

	# ② 创建 224×32 色板图（7种颜色横排，每格32×32）
	var img := Image.create(7 * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_fill_tile(img, TILE_ROAD   * TILE_SIZE, Color(0.55, 0.55, 0.58))  # 青石板路（灰）
	_fill_tile(img, TILE_GRASS  * TILE_SIZE, Color(0.26, 0.50, 0.20))  # 草地（绿）
	_fill_tile(img, TILE_SHOP   * TILE_SIZE, Color(0.50, 0.37, 0.22))  # 铺前土地（棕）
	_fill_tile(img, TILE_MARKET * TILE_SIZE, Color(0.71, 0.61, 0.43))  # 集市地面（米黄）
	_fill_tile(img, TILE_DARK   * TILE_SIZE, Color(0.15, 0.28, 0.15))  # 深色草地（废庙）
	_fill_tile(img, TILE_WALL   * TILE_SIZE, Color(0.30, 0.24, 0.20))  # 建筑外墙（深棕）
	_fill_tile(img, TILE_PLAZA  * TILE_SIZE, Color(0.48, 0.52, 0.60))  # 青石板广场（冷灰）

	# ③ 构建 TileSetAtlasSource，逐列注册7个Tile
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for col in 7:
		src.create_tile(Vector2i(col, 0))

	# ④ 注册 Source 到 TileSet（必须在设置碰撞多边形之前，否则 TileData 不知道物理层）
	_tileset_source_id = ts.add_source(src)

	# ⑤ 为 TILE_WALL（tile 5）添加碰撞多边形（以 tile 中心为原点，覆盖整个 32×32 格）
	var wall_poly := PackedVector2Array([
		Vector2(-16.0, -16.0), Vector2(16.0, -16.0),
		Vector2(16.0,   16.0), Vector2(-16.0, 16.0)
	])
	var wall_td: TileData = src.get_tile_data(Vector2i(TILE_WALL, 0), 0)
	wall_td.add_collision_polygon(0)
	wall_td.set_collision_polygon_points(0, 0, wall_poly)
	print("wall polygon points: ", wall_td.get_collision_polygon_points(0, 0))

	# ⑥ 确保 TileMap 有2个图层（Layer0=地面，Layer1=碰撞）
	while _tile_map.get_layers_count() < 2:
		_tile_map.add_layer(_tile_map.get_layers_count())
	_tile_map.set_layer_name(0, "地面")
	_tile_map.set_layer_name(1, "碰撞")

	# ⑦ 应用 TileSet 后绘制地图
	_tile_map.tile_set = ts
	_tile_map.z_index = 0
	_draw_map()
	_spawn_world_decorations()
	_build_plaza_silhouettes()


## 将 img 从 x_off 起的 32×32 区域涂为纯色
## 去掉 1px 硬边框（消除网格感），保留极轻微扰动（±0.02）避免完全平板
func _fill_tile(img: Image, x_off: int, color: Color) -> void:
	for x in TILE_SIZE:
		for y in TILE_SIZE:
			var n := (randf() - 0.5) * 0.02
			img.set_pixel(x_off + x, y, Color(
				clamp(color.r + n, 0.0, 1.0),
				clamp(color.g + n, 0.0, 1.0),
				clamp(color.b + n, 0.0, 1.0)
			))


# ══════════════════════════════════════════════════════════════════
# 十二、地图绘制（规范第二节区域布局）
# 先绘Layer0地面，再绘Layer1碰撞墙体
# ══════════════════════════════════════════════════════════════════

func _draw_map() -> void:
	# ─────────── Layer 0：地面（可行走） ───────────────────────────

	# 基底：全图铺草地
	for x in MAP_COLS:
		for y in MAP_ROWS:
			_place_tile(0, x, y, TILE_GRASS)

	# 横向主路：rows 13-15，全宽40格
	for x in MAP_COLS:
		for y in range(13, 16):
			_place_tile(0, x, y, TILE_ROAD)

	# 纵向主路：cols 18-21，全高30格
	for x in range(18, 22):
		for y in MAP_ROWS:
			_place_tile(0, x, y, TILE_ROAD)

	# 铺前土地：cols 1-11，row 11（杂货铺门口过渡区）
	for x in range(1, 12):
		_place_tile(0, x, 11, TILE_SHOP)

	# 测灵广场：cols 25-38，rows 2-12（青石板冷灰色）
	for x in range(25, 39):
		for y in range(2, 13):
			_place_tile(0, x, y, TILE_PLAZA)

	# 集市地面：cols 2-16，rows 18-28（米黄色）
	for x in range(2, 17):
		for y in range(18, 29):
			_place_tile(0, x, y, TILE_MARKET)

	# 废庙方向深色草地：cols 33-39，rows 20-29
	for x in range(33, 40):
		for y in range(20, 30):
			_place_tile(0, x, y, TILE_DARK)

	# ─────────── Layer 1：碰撞墙体（不可行走） ─────────────────────

	# 杂货铺建筑外墙：cols 2-10，rows 2-10
	for x in range(2, 11):
		for y in range(2, 11):
			_place_tile(1, x, y, TILE_WALL)

	# 茶馆建筑：cols 25-32，rows 18-24
	for x in range(25, 33):
		for y in range(18, 25):
			_place_tile(1, x, y, TILE_WALL)

	# 集市摊位障碍物：6个，制造S型路线（玩家需绕行）
	# 西侧摊位列（格(4,20)、(4,21)）
	_place_tile(1, 4,  20, TILE_WALL)
	_place_tile(1, 4,  21, TILE_WALL)
	# 中间摊位列（格(9,23)、(10,23)）
	_place_tile(1, 9,  23, TILE_WALL)
	_place_tile(1, 10, 23, TILE_WALL)
	# 东侧摊位列（格(14,25)、(14,26)）
	_place_tile(1, 14, 25, TILE_WALL)
	_place_tile(1, 14, 26, TILE_WALL)


## 简写：在指定 TileMap 图层放置一个格子，使用当前 _tileset_source_id
## 注意：不能命名为 _set，会与 Godot 内置虚函数 Node._set(property,value) 冲突
func _place_tile(layer: int, x: int, y: int, tile_col: int) -> void:
	_tile_map.set_cell(layer, Vector2i(x, y), _tileset_source_id, Vector2i(tile_col, 0))


## 世界场景装饰物：老榕树、古井、公告栏（纯Polygon2D，无需图片资源）
func _spawn_world_decorations() -> void:
	var layer := Node2D.new()
	layer.name = "WorldDecorations"
	layer.z_index = 2
	add_child(layer)

	## 老榕树（格17,14 → 像素544,448）
	_add_tree(layer, Vector2(544, 440))
	## 古井（格22,17 → 像素704,544）
	_add_well(layer, Vector2(704, 544))
	## 公告栏（格22,13 → 像素704,416）
	_add_notice_board(layer, Vector2(704, 410))

	## 西墙根磨平的石板（被遗忘的旧物，供玩家停留观察）
	_add_west_stone(layer, Vector2(80, 448))

	## ─── L1 美术优化：仅废庙装饰 + 杂货铺门口横梁 ────────────────
	_decorate_temple(layer)
	_decorate_shop_facade(layer)


## 将广场路人ColorRect替换为人形轮廓（头部椭圆＋梯形躯干）
func _build_plaza_silhouettes() -> void:
	var plaza := get_node_or_null("PlazaLayer")
	if not plaza:
		return
	for child in plaza.get_children():
		var rect: ColorRect = child.get_node_or_null("ColorRect")
		if rect == null:
			continue
		var col := rect.color
		rect.hide()
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-10, -5), Vector2(10, -5),
			Vector2(8, 20), Vector2(-8, 20)])
		body.color = col
		child.add_child(body)
		var head := Polygon2D.new()
		head.polygon = _plaza_ellipse(0.0, -12.0, 6.0, 7.0, 10)
		head.color = col
		child.add_child(head)


func _plaza_ellipse(cx: float, cy: float, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var angle := TAU * i / n
		pts.append(Vector2(cx + rx * cos(angle), cy + ry * sin(angle)))
	return pts


func _add_tree(parent: Node2D, pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	## 树冠
	var canopy := Polygon2D.new()
	canopy.polygon = PackedVector2Array([
		Vector2(0, -28), Vector2(19, -20), Vector2(26, -6),
		Vector2(22, 10), Vector2(8, 18), Vector2(-8, 18),
		Vector2(-22, 10), Vector2(-26, -6), Vector2(-19, -20)
	])
	canopy.color = Color(0.17, 0.30, 0.13, 0.92)
	node.add_child(canopy)
	## 树干
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-5, 6), Vector2(5, 6), Vector2(4, 22), Vector2(-4, 22)
	])
	trunk.color = Color(0.34, 0.22, 0.12, 1.0)
	node.add_child(trunk)
	## 树干碰撞（仅贴合树干，不阻挡树冠下走动）
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 14)
	cshape.shape = rect
	cshape.position = Vector2(0, 14)
	body.add_child(cshape)
	node.add_child(body)
	parent.add_child(node)


func _add_well(parent: Node2D, pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	## 井沿外圈
	var outer := Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(11, -11), Vector2(16, 0),
		Vector2(11, 11), Vector2(0, 16), Vector2(-11, 11),
		Vector2(-16, 0), Vector2(-11, -11)
	])
	outer.color = Color(0.42, 0.36, 0.28, 1.0)
	node.add_child(outer)
	## 井口（黑色水面）
	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(0, -9), Vector2(6, -6), Vector2(9, 0),
		Vector2(6, 6), Vector2(0, 9), Vector2(-6, 6),
		Vector2(-9, 0), Vector2(-6, -6)
	])
	inner.color = Color(0.05, 0.06, 0.10, 0.96)
	node.add_child(inner)
	parent.add_child(node)


func _add_notice_board(parent: Node2D, pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	## 支柱
	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-3, -8), Vector2(3, -8), Vector2(3, 16), Vector2(-3, 16)
	])
	pole.color = Color(0.38, 0.26, 0.14, 1.0)
	node.add_child(pole)
	## 牌面
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([
		Vector2(-18, -26), Vector2(18, -26), Vector2(18, -8), Vector2(-18, -8)
	])
	board.color = Color(0.62, 0.48, 0.26, 1.0)
	node.add_child(board)
	## 牌面横纹（装饰线）
	var line1 := Polygon2D.new()
	line1.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(14, -22), Vector2(14, -21), Vector2(-14, -21)
	])
	line1.color = Color(0.38, 0.26, 0.14, 0.6)
	node.add_child(line1)
	var line2 := Polygon2D.new()
	line2.polygon = PackedVector2Array([
		Vector2(-14, -16), Vector2(14, -16), Vector2(14, -15), Vector2(-14, -15)
	])
	line2.color = Color(0.38, 0.26, 0.14, 0.6)
	node.add_child(line2)
	parent.add_child(node)


## 西墙根风化石板：半埋、倾斜、裂纹、青苔、野草——"被遗忘"的视觉语言
func _add_west_stone(parent: Node2D, pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = 1

	## 石板本体：四边不齐的梯形，略倾斜，表面被晒得发白
	var slab := Polygon2D.new()
	slab.polygon = PackedVector2Array([
		Vector2(-22, -9), Vector2(20, -11),
		Vector2(23, 5), Vector2(-19, 6)
	])
	slab.color = Color(0.58, 0.55, 0.48, 1.0)
	node.add_child(slab)

	## 石板顶面高光（细细一条，表示被日头晒白的上缘）
	var hilite := Polygon2D.new()
	hilite.polygon = PackedVector2Array([
		Vector2(-20, -9), Vector2(18, -10),
		Vector2(18, -8), Vector2(-20, -7)
	])
	hilite.color = Color(0.72, 0.68, 0.60, 0.7)
	node.add_child(hilite)

	## 主裂缝（斜贯石面）
	var crack := Polygon2D.new()
	crack.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(12, -3),
		Vector2(12, -2), Vector2(-8, -7)
	])
	crack.color = Color(0.28, 0.25, 0.22, 1.0)
	node.add_child(crack)

	## 青苔斑（左下角，深绿+半透）
	var moss := Polygon2D.new()
	moss.polygon = PackedVector2Array([
		Vector2(-22, -2), Vector2(-12, -4),
		Vector2(-8, 3), Vector2(-19, 6)
	])
	moss.color = Color(0.32, 0.45, 0.28, 0.75)
	node.add_child(moss)

	## 右侧几根长野草（暗示无人打理）
	var blade_coords := [
		Vector2(24, 5), Vector2(27, 5), Vector2(30, 4),
		Vector2(22, 4), Vector2(33, 5)
	]
	var blade_heights := [9, 12, 8, 7, 11]
	for i in blade_coords.size():
		var blade := Polygon2D.new()
		var b: Vector2 = blade_coords[i]
		var h: int = blade_heights[i]
		blade.polygon = PackedVector2Array([
			Vector2(b.x, b.y),
			Vector2(b.x + 1, b.y - h),
			Vector2(b.x + 2, b.y)
		])
		blade.color = Color(0.40, 0.52, 0.30, 0.9)
		node.add_child(blade)

	## 碰撞体（矩形，贴合石板本身）
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(42, 14)
	cshape.shape = rect
	cshape.position = Vector2(0, -2)
	body.add_child(cshape)
	node.add_child(body)

	parent.add_child(node)


# ══════════════════════════════════════════════════════════════════
# 十二·B、L1 美术优化：建筑细节 / 装饰物 / 光影 / 粒子
# ══════════════════════════════════════════════════════════════════

## 废庙建筑立体化：屋檐探出 + 屋脊暗线 + 瓦片
func _decorate_temple(parent: Node2D) -> void:
	var node := Node2D.new()
	node.position = Vector2(0, 0)
	node.z_index = 1
	## 屋檐（从屋顶两端探出的深色梯形）
	var eave_l := Polygon2D.new()
	eave_l.polygon = PackedVector2Array([
		Vector2(1152, 784), Vector2(1172, 784),
		Vector2(1164, 796), Vector2(1148, 796)
	])
	eave_l.color = Color(0.05, 0.04, 0.03, 1.0)
	node.add_child(eave_l)
	var eave_r := Polygon2D.new()
	eave_r.polygon = PackedVector2Array([
		Vector2(1268, 784), Vector2(1288, 784),
		Vector2(1288, 796), Vector2(1276, 796)
	])
	eave_r.color = Color(0.05, 0.04, 0.03, 1.0)
	node.add_child(eave_r)
	## 屋脊（屋顶横向暗线）
	var ridge := Polygon2D.new()
	ridge.polygon = PackedVector2Array([
		Vector2(1160, 788), Vector2(1280, 788),
		Vector2(1280, 791), Vector2(1160, 791)
	])
	ridge.color = Color(0.02, 0.02, 0.02, 0.85)
	node.add_child(ridge)
	## 瓦片横纹（3 条）
	for i in 3:
		var tile := Polygon2D.new()
		var yy := 784 + 4 + i * 4
		tile.polygon = PackedVector2Array([
			Vector2(1160, yy), Vector2(1280, yy),
			Vector2(1280, yy + 1), Vector2(1160, yy + 1)
		])
		tile.color = Color(0.15, 0.11, 0.08, 0.55)
		node.add_child(tile)
	## 门框对联（两侧暗红竖条）
	for dx in [-4, 30]:
		var scroll := Polygon2D.new()
		scroll.polygon = PackedVector2Array([
			Vector2(1156 + dx, 856), Vector2(1160 + dx, 856),
			Vector2(1160 + dx, 944), Vector2(1156 + dx, 944)
		])
		scroll.color = Color(0.32, 0.10, 0.08, 0.85)
		node.add_child(scroll)
	parent.add_child(node)


## 杂货铺门面装饰：屋檐 + 招牌横梁（标签下方）
func _decorate_shop_facade(parent: Node2D) -> void:
	var node := Node2D.new()
	node.z_index = 1
	## 屋檐横梁（row 10-11 之间）
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		Vector2(32, 344), Vector2(384, 344),
		Vector2(384, 352), Vector2(32, 352)
	])
	beam.color = Color(0.22, 0.15, 0.08, 1.0)
	node.add_child(beam)
	## 屋檐阴影线（更深一道）
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(32, 352), Vector2(384, 352),
		Vector2(384, 355), Vector2(32, 355)
	])
	shadow.color = Color(0.08, 0.05, 0.03, 0.6)
	node.add_child(shadow)
	parent.add_child(node)


# ══════════════════════════════════════════════════════════════════
# 十三、剧情信号（保持不变，规范第九节）
# ══════════════════════════════════════════════════════════════════

## 连接 DialogueManager 的事件与对话结束信号
func _connect_story_signals() -> void:
	DialogueManager.event_triggered.connect(_on_event_triggered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


## 初始化隐藏交互点状态列表
func _init_hidden_interact_states() -> void:
	_hidden_interact_states.clear()
	for entry in HIDDEN_INTERACT_NODES:
		_hidden_interact_states.append({
			"grid":        entry["grid"],
			"scene_id":    entry["scene_id"],
			"hint":        entry["hint"],
			"triggered":   false,
			"is_signpost": entry.get("is_signpost", false),
			"alt_scene_id": entry.get("alt_scene_id", ""),
			"alt_phase":   entry.get("alt_phase", -1),
		})


## 检测玩家是否靠近隐藏交互点（距离≤1格）
func _check_hidden_interact_proximity() -> void:
	if DialogueManager.is_active:
		if _nearby_hidden_interact != -1:
			_nearby_hidden_interact = -1
			if _current_entrance == "":
				_enter_hint.hide()
		return
	var pg := Vector2i(
		int(_player.global_position.x / TILE_SIZE),
		int(_player.global_position.y / TILE_SIZE)
	)
	for i in _hidden_interact_states.size():
		var state = _hidden_interact_states[i]
		if state["triggered"]:
			continue
		var bg: Vector2i = state["grid"]
		if abs(pg.x - bg.x) <= 1 and abs(pg.y - bg.y) <= 1:
			_nearby_hidden_interact = i
			_enter_hint.text = state["hint"]
			_enter_hint.show()
			return
	## 离开所有隐藏交互点范围，隐藏提示
	if _nearby_hidden_interact != -1:
		_nearby_hidden_interact = -1
		if _current_entrance == "":
			_enter_hint.hide()


## 处理对话中的 event 节点
func _on_event_triggered(event_name: String) -> void:
	match event_name:

		"morning_done":
			## morning对话结束标记，由ShopScene处理
			## TownScene不需要处理，直接放行
			DialogueManager.finish_event()

		"start_chapter_end_a":
			## 章末路径A：一起走
			DialogueManager.finish_event()
			GameData.chapter_end_path = "a"
			SceneTransition.change_scene(
				"res://scenes/ChapterEndScene.tscn")

		"start_chapter_end_b":
			## 章末路径B：先回去看爹
			## letter场景已在ShopScene播放
			## 此事件由ShopScene处理，TownScene放行即可
			DialogueManager.finish_event()
			GameData.chapter_end_path = "b"

		"return_home_final":
			## after_battle_coin版本选"先回去看爹"时触发
			## 此时phase是4，ShopScene需要phase==5才走看信流程
			## 必须先advance_phase再切场景
			DialogueManager.finish_event()
			if GameData.story_phase == 4:
				GameData.advance_phase()
			SceneTransition.change_scene(
				"res://scenes/ShopScene.tscn")

		"trigger_battle":
			## 战斗触发，由TempleScene处理
			## TownScene收到时直接放行
			DialogueManager.finish_event()

		"test_first_done":
			## 测验师第一段对话结束，激活测灵石交互
			DialogueManager.finish_event()
			_stone_interactable = true

		"test_pause_pre_verdict":
			## ts_01 "灵石纹丝不动" → 暗化 + BGM 渐止 + 静默 1.5s → ts_02
			## v40.8: 改回克制路线
			##   - dim 0.45 / 2.0s sine (温柔, 见 _show_test_dim_overlay)
			##   - BGM 不压低, 直接 fade out 到 0 / 2.0s
			##     ("音乐不见了"比"音乐变小了"更克制, 配合主角"装作没事走开"的气质)
			##   - 移除 sense sfx (sfx 会引入"事件感", 对克制气质有害)
			_show_test_dim_overlay()
			AudioManager.fade_bgm_to(0.0, 2.0)
			await get_tree().create_timer(1.5).timeout
			if not is_inside_tree():
				return
			DialogueManager.finish_event()

		"test_pause_post_verdict":
			## ts_02 "无灵根" 之后 → 沉淀 2.0s → ts_03
			## 让"无灵根"三个字停留在玩家脑里 (v40.8 移除 sfx)
			await get_tree().create_timer(2.0).timeout
			if not is_inside_tree():
				return
			DialogueManager.finish_event()

		"get_cinnamon":
			UIManager.add_item("cinnamon")
			_sync_vendor_b_return_dialogue()
			DialogueManager.finish_event()

		"buy_heal_potion":
			if GameData.spend_gold(10):
				GameData.heal_potions += 1
				_show_bubble("买下了。", _player.global_position + Vector2(0, -48))
			else:
				_show_bubble("灵石不够……", _player.global_position + Vector2(0, -48))
			UIManager.refresh_hp()
			DialogueManager.finish_event()

		"buy_incense":
			if GameData.spend_gold(20):
				GameData.incenses += 1
				_show_bubble("买下了。", _player.global_position + Vector2(0, -48))
			else:
				_show_bubble("灵石不够……", _player.global_position + Vector2(0, -48))
			UIManager.refresh_hp()
			DialogueManager.finish_event()

		"buy_talisman":
			if GameData.spend_gold(15):
				GameData.talismans += 1
				_show_bubble("买下了。", _player.global_position + Vector2(0, -48))
			else:
				_show_bubble("灵石不够……", _player.global_position + Vector2(0, -48))
			UIManager.refresh_hp()
			DialogueManager.finish_event()

		_:
			## 其他所有事件默认放行
			DialogueManager.finish_event()


func _sync_vendor_b_return_dialogue() -> void:
	var vendor_b = get_node_or_null("NPCLayer/NPC_Vendor_B")
	if vendor_b == null:
		return
	if "cinnamon" in GameData.unlocked_old_items:
		vendor_b.dialogue_scene_id_after = "vendor_b_return"
	else:
		vendor_b.dialogue_scene_id_after = "vendor_b_return_no_cinnamon"


## 处理完整对话场景结束
func _on_dialogue_ended(scene_id: String) -> void:
	match scene_id:
		"morning":
			## morning结束，推进到phase1，玩家可以出门
			if GameData.story_phase == 0:
				GameData.advance_phase()
		"market":
			## 老婆婆神秘消失，使用disappear()完整移除
			GameData.got_charm = true
			if not GameData.triggered_events.has("market_done"):
				GameData.triggered_events.append("market_done")
			## 平安符加入背包，让玩家看得见摸得着
			UIManager.add_item("charm")
			var old_woman = get_node_or_null("NPCLayer/NPC_OldWoman")
			if old_woman:
				old_woman.disappear()
			## 清除Player的NPC缓存，消除残留提示
			var player = get_node_or_null("Player")
			if player:
				player._nearby_npcs.clear()
				player.interact_label.hide()
		"test":
			## test第一段结束，phase推进已移到test_stone
			pass
		"test_stone":
			## 测灵失败演出收尾：先慢慢恢复世界（暗化淡出 + 切到 phase 3 的 BGM）
			## 再推进 phase / 触发符灵 —— 避免"对话框关闭就立刻亮回去"的割裂
			_hide_test_dim_overlay(2.5)
			## v40.8: 不再恢复到 town_day, 改切 shop_return (低落钢琴感)
			## 心绪都从 phase 1 切到 phase 3 了, 背景音也该换色调
			AudioManager.play_bgm("shop_return", 2.5)

			## 测灵石对话结束，推进phase到3（跳过phase 2，走set_phase接口）
			if GameData.story_phase == 1:
				GameData.set_phase(3)
			## 符灵第一声延迟到 dim 淡出后才响（原 1.5s → 3.0s, 给画面恢复留时间）
			get_tree().create_timer(3.0).timeout.connect(
				func(): CharmSpirit.try_whisper("after_test_fail"), CONNECT_ONE_SHOT)
			## 记录测验师已触发，读取其自身配置的after对话，不硬编码字符串
			var examiner = get_node_or_null("NPCLayer/NPC_Examiner")
			if examiner:
				var examiner_key: String = examiner._get_save_key() + "_triggered"
				if not GameData.triggered_events.has(examiner_key):
					GameData.triggered_events.append(examiner_key)
				examiner.dialogue_scene_id = "examiner_after"
		"after_battle":
			## after_battle对话已由TempleScene接管，此处不重复推进phase
			pass
		"return_home":
			pass
		"letter":
			## 看完爹的信，触发章末路径B结束
			## start_chapter_end_b事件已在对话内处理
			pass
		"after_battle_coin":
			## after_battle_coin对话已由TempleScene接管，此处不重复推进phase
			pass
		"fortune_teller_coin":
			GameData.got_coin = true
			UIManager.add_item("coin")
			var ft_npc_end = get_node_or_null("NPCLayer/NPC_FortuneTeller")
			if ft_npc_end:
				ft_npc_end.dialogue_scene_id = ""
				ft_npc_end.is_triggered = true


# ══════════════════════════════════════════════════════════════════
# 十四、剧情触发检测
# ══════════════════════════════════════════════════════════════════

## 测灵失败演出：在画面上叠一层缓慢淡入的暗色遮罩
## CanvasLayer.layer = 5 (在世界 0/1 之上, 在 DialogueBox layer=10 之下)
## 让对话框文字和角花等装饰仍然清晰, 但镇子的明亮被压住, 制造"这一刻不是日常"的潜意识
func _show_test_dim_overlay() -> void:
	if _test_dim_canvas != null and is_instance_valid(_test_dim_canvas):
		return  # 已存在, 不重复创建
	_test_dim_canvas = CanvasLayer.new()
	_test_dim_canvas.layer = 5
	add_child(_test_dim_canvas)

	_test_dim_overlay = ColorRect.new()
	# 暗色冷调 (略带蓝紫), 不是纯黑——纯黑会像 SceneTransition 转场
	_test_dim_overlay.color = Color(0.04, 0.05, 0.10, 0.0)
	_test_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_test_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_test_dim_canvas.add_child(_test_dim_overlay)

	# v40.8: 回归克制 (0.45 alpha / 2.0s sine)
	# v40.7 的 0.7+0.8s 砸下来太"事件感", 与主角"装作没事走开"的克制气质冲突
	# 改回温柔的 0.45 + 2.0s sine, 让"世界悄悄安静下来"而不是"砸一下"
	var tw := create_tween()
	tw.tween_property(_test_dim_overlay, "color:a", 0.45, 2.0)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## 测灵失败演出收尾：暗色遮罩缓慢淡出, 世界恢复明亮
func _hide_test_dim_overlay(duration: float = 2.5) -> void:
	if _test_dim_overlay == null or not is_instance_valid(_test_dim_overlay):
		return
	var overlay := _test_dim_overlay
	var canvas  := _test_dim_canvas
	_test_dim_overlay = null
	_test_dim_canvas  = null
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.0, duration)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(canvas):
			canvas.queue_free()
	)


## 创建夜晚渐变遮罩层（默认透明，剧情触发后缓慢变暗）
func _setup_night_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	_night_overlay = ColorRect.new()
	_night_overlay.color = Color(0.0, 0.05, 0.15, 0.0)
	_night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_night_overlay)
	## 如果夜晚已触发，直接恢复暗色状态并隐藏所有NPC
	if GameData.night_triggered:
		_night_triggered = true
		_night_overlay.color.a = 0.45
		_hide_all_npcs_for_night()
		if GameData.story_phase < 5:
			_setup_night_vendor()
		if GameData.story_phase >= 3 and GameData.story_phase < 5:
			_setup_well_heal_area()


## 测灵广场检测：story_phase==1时
## 玩家走进广场范围，测验师NPC变为可交互状态
## 不再自动触发test对话，改由玩家主动按E和测验师交互
func _check_plaza_trigger() -> void:
	## 广场触发已由NPC_Examiner的dialogue_scene_id处理
	## 此函数保留但不再执行任何逻辑，防止自动触发
	pass


## 测灵石交互检测：test第一段结束后激活，玩家按E触碰
func _check_stone_interaction() -> void:
	if not _stone_interactable or _stone_used:
		return
	if DialogueManager.is_active:
		return
	var stone = get_node_or_null("PlazaLayer/TestingStone")
	if stone == null:
		return
	var area = stone.get_node_or_null("Area2D")
	if area == null:
		return
	## 检查玩家是否在感应区内
	var bodies = area.get_overlapping_bodies()
	for body in bodies:
		if body is CharacterBody2D:
			## 显示交互提示
			_enter_hint.text = "按 E 触碰"
			_enter_hint.show()
			return
	## 不在范围内则隐藏提示
	if _current_entrance == "":
		_enter_hint.hide()


## story_phase==3时玩家走回杂货铺门口自动触发旁白"灯还亮着"
func _check_return_home_trigger() -> void:
	## 走到杂货铺门口触发旁白"灯还亮着"，不在此播return_home对话
	## return_home对话由ShopScene._start_return_home_flow()负责
	if DialogueManager.is_active or GameData.triggered_events.has("light_still_on"):
		return
	var pg := Vector2i(
		int(_player.global_position.x / TILE_SIZE),
		int(_player.global_position.y / TILE_SIZE)
	)
	if _in_range(pg, Vector2i(6, 11)):
		GameData.triggered_events.append("light_still_on")
		DialogueManager.start_scene("light_still_on")


## 夜行氛围旁白：经过榕树/古井时自动触发，一次性
func _check_night_walk_triggers() -> void:
	if DialogueManager.is_active:
		return
	var pg := Vector2i(
		int(_player.global_position.x / TILE_SIZE),
		int(_player.global_position.y / TILE_SIZE))
	## 榕树格(17,16)：用 ±1 容差，与 FORCE_TRIGGER_NODES 保持一致
	if not GameData.triggered_events.has("night_walk_tree"):
		if abs(pg.x - 17) <= 1 and abs(pg.y - 16) <= 1:
			GameData.triggered_events.append("night_walk_tree")
			DialogueManager.start_scene("night_walk_tree")
			return
	## 古井格(22,17)：用 ±1 容差
	if not GameData.triggered_events.has("night_walk_well"):
		if abs(pg.x - 22) <= 1 and abs(pg.y - 17) <= 1:
			GameData.triggered_events.append("night_walk_well")
			DialogueManager.start_scene("night_walk_well")
			return


## 夜晚时隐藏所有NPC，完整移除视觉、碰撞、交互
func _hide_all_npcs_for_night() -> void:
	## 隐藏NPCLayer下所有NPC
	var npc_layer = get_node_or_null("NPCLayer")
	if npc_layer:
		for npc in npc_layer.get_children():
			if npc.has_method("disappear"):
				npc.disappear()
	## 强制清空玩家NPC缓存，防止已消失的NPC仍可被按E触发
	if is_instance_valid(_player):
		_player._nearby_npcs.clear()
		_player.interact_label.hide()
	## 隐藏PlazaLayer下所有节点（围观者+测灵石）
	## 递归处理，确保碰撞体和感应区全部禁用
	var plaza_layer = get_node_or_null("PlazaLayer")
	if plaza_layer:
		_hide_node_recursive(plaza_layer)


## 递归隐藏节点及其所有子节点，同时禁用碰撞体和感应区
func _hide_node_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is StaticBody2D:
			child.set_deferred("collision_layer", 0)
			child.set_deferred("collision_mask", 0)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
		if child is CanvasItem:
			child.hide()
		if child.get_child_count() > 0:
			_hide_node_recursive(child)


## 触发夜晚渐变效果，3秒内屏幕缓慢变暗
func _trigger_night_transition() -> void:
	if GameData.night_triggered:
		return
	GameData.night_triggered = true
	_night_triggered = true
	var tween := create_tween()
	tween.tween_property(_night_overlay, "color:a", 0.45, 1.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)


# ══════════════════════════════════════════════════════════════════
# 十五、气泡对话系统
# ══════════════════════════════════════════════════════════════════

## 初始化气泡状态列表（深拷贝BUBBLE_NODES，加入triggered标记）
func _init_bubble_states() -> void:
	_bubble_states.clear()
	for entry in BUBBLE_NODES:
		_bubble_states.append({
			"grid":     entry["grid"],
			"text":     entry["text"],
			"triggered": false,
		})


## 显示气泡文字：在世界坐标world_pos上方创建/更新Label，显示3秒
func _show_bubble(text: String, world_pos: Vector2) -> void:
	if _bubble_label == null:
		_bubble_label = RichTextLabel.new()
		_bubble_label.bbcode_enabled = true
		_bubble_label.fit_content    = true
		_bubble_label.scroll_active  = false
		_bubble_label.autowrap_mode  = TextServer.AUTOWRAP_OFF
		_bubble_label.add_theme_color_override("default_color", ThemeManager.COLOR_TEXT_PRIMARY)
		_bubble_label.add_theme_font_size_override("normal_font_size",  16)
		_bubble_label.add_theme_font_size_override("italics_font_size", 16)
		_bubble_label.z_index = 10
		add_child(_bubble_label)
	_bubble_label.text = "[i]「" + text + "」[/i]"
	_bubble_label.global_position = world_pos + Vector2(-48.0, -40.0)
	_bubble_label.show()
	_bubble_timer = 3.0


## 隐藏气泡文字
func _hide_bubble() -> void:
	if _bubble_label != null:
		_bubble_label.hide()


## 检测玩家是否靠近气泡节点（距离≤2格），依次触发未触发的气泡
func _check_bubble_triggers() -> void:
	## 有对话进行中，或当前气泡仍在显示，则跳过
	if DialogueManager.is_active or _bubble_timer > 0.0:
		return
	var pg := Vector2i(
		int(_player.global_position.x / TILE_SIZE),
		int(_player.global_position.y / TILE_SIZE)
	)
	for state in _bubble_states:
		if state["triggered"]:
			continue
		var bg: Vector2i = state["grid"]
		if abs(pg.x - bg.x) <= 2 and abs(pg.y - bg.y) <= 2:
			state["triggered"] = true
			var world_pos := Vector2(
				bg.x * TILE_SIZE + TILE_SIZE * 0.5,
				bg.y * TILE_SIZE
			)
			_show_bubble(state["text"], world_pos)
			return


## 药婆剪影：驼背老妇人，灰发 + 深紫长袍 + 侧挂药篓
func _draw_yaopo_silhouette(parent: Node2D) -> void:
	var robe_color := Color(0.32, 0.26, 0.38, 1.0)       # 深紫长袍
	var hair_color := Color(0.78, 0.76, 0.72, 1.0)       # 白灰头发
	var skin_color := Color(0.86, 0.80, 0.72, 1.0)       # 脸色偏黄
	var basket_color := Color(0.48, 0.36, 0.22, 1.0)     # 藤编药篓
	var basket_dark := Color(0.32, 0.22, 0.14, 1.0)      # 药篓编纹

	# 头发（后脑灰白，略往前倾表示驼背）
	var hair := Polygon2D.new()
	hair.polygon = PackedVector2Array([
		Vector2(-5, -20), Vector2(5, -20),
		Vector2(6, -12), Vector2(-6, -12)
	])
	hair.color = hair_color
	parent.add_child(hair)

	# 脸（偏下偏前，驼背的姿态）
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([
		Vector2(-4, -18), Vector2(4, -18),
		Vector2(4, -13), Vector2(-4, -13)
	])
	face.color = skin_color
	parent.add_child(face)

	# 驼背上身：头往前倾，肩膀不对称
	var upper := Polygon2D.new()
	upper.polygon = PackedVector2Array([
		Vector2(-7, -12), Vector2(8, -12),
		Vector2(9, -3), Vector2(-8, -3)
	])
	upper.color = robe_color
	parent.add_child(upper)

	# 长袍下摆（到脚，老人步子小所以下摆窄一点）
	var lower := Polygon2D.new()
	lower.polygon = PackedVector2Array([
		Vector2(-8, -3), Vector2(9, -3),
		Vector2(8, 16), Vector2(-7, 16)
	])
	lower.color = robe_color
	parent.add_child(lower)

	# 左袖
	var sleeve_l := Polygon2D.new()
	sleeve_l.polygon = PackedVector2Array([
		Vector2(-7, -11), Vector2(-10, -8),
		Vector2(-9, -2), Vector2(-7, -2)
	])
	sleeve_l.color = robe_color
	parent.add_child(sleeve_l)

	# 右臂提着药篓，袖子往下垂
	var sleeve_r := Polygon2D.new()
	sleeve_r.polygon = PackedVector2Array([
		Vector2(8, -11), Vector2(11, -8),
		Vector2(12, 2), Vector2(9, 2)
	])
	sleeve_r.color = robe_color
	parent.add_child(sleeve_r)

	# 右手药篓（主体 + 编纹）
	var basket_body := Polygon2D.new()
	basket_body.polygon = PackedVector2Array([
		Vector2(9, 2), Vector2(16, 2),
		Vector2(15, 12), Vector2(10, 12)
	])
	basket_body.color = basket_color
	parent.add_child(basket_body)

	# 药篓提手
	var basket_handle := Polygon2D.new()
	basket_handle.polygon = PackedVector2Array([
		Vector2(10, 2), Vector2(11, -1),
		Vector2(14, -1), Vector2(15, 2)
	])
	basket_handle.color = basket_dark
	parent.add_child(basket_handle)

	# 药篓横纹
	var basket_stripe := Polygon2D.new()
	basket_stripe.polygon = PackedVector2Array([
		Vector2(9, 6), Vector2(16, 6),
		Vector2(15, 7), Vector2(10, 7)
	])
	basket_stripe.color = basket_dark
	parent.add_child(basket_stripe)


## 创建夜晚药婆商人节点
## 位置：格(35,26)，像素(1120,832)，废庙入口左上方
func _setup_night_vendor() -> void:
	## 防止重复创建
	if get_node_or_null("NightVendor") != null:
		return

	var vendor := Node2D.new()
	vendor.name = "NightVendor"
	vendor.position = Vector2(1120, 832)
	add_child(vendor)

	## 药婆剪影：驼背老妇人 + 药篓
	_draw_yaopo_silhouette(vendor)

	## 头顶名字Label
	var label := Label.new()
	label.text = "药婆"
	label.position = Vector2(-16, -42)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", ThemeManager.COLOR_ACCENT_GOLD)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	vendor.add_child(label)

	## 物理碰撞体（阻止玩家穿透）
	var body := StaticBody2D.new()
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(20, 36)
	body_shape.shape = body_rect
	body.add_child(body_shape)
	vendor.add_child(body)

	## 交互感应区
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var area_shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(60, 60)
	area_shape.shape = area_rect
	area.add_child(area_shape)
	vendor.add_child(area)

	area.body_entered.connect(
		func(body_node):
			if not body_node is CharacterBody2D:
				return
			## 初次靠近：气泡提示（不锁定移动），用meta避免lambda闭包捕获问题
			if not vendor.get_meta("bubble_shown", false):
				vendor.set_meta("bubble_shown", true)
				_show_bubble("「没灵石？镇外废庙里游荡的邪祟身上多得是。就看你有没有命去拿。」",
					vendor.global_position + Vector2(-80, -48))
			## 显示按E提示
			_near_vendor = true
			_enter_hint.text = "按 E 购买"
			_enter_hint.show()
	)
	area.body_exited.connect(
		func(body_node):
			if body_node is CharacterBody2D:
				_near_vendor = false
				if _current_entrance == "":
					_enter_hint.hide()
	)

	## 将vendor_talked存入节点meta，供E键处理读取
	vendor.set_meta("vendor_talked", false)


## 处理药婆E键交互（在_unhandled_input里调用）
## 注意：此函数由_unhandled_input检测后调用，不独立触发
func _try_vendor_interact() -> bool:
	var vendor = get_node_or_null("NightVendor")
	if vendor == null:
		return false
	## 双重检测：距离优先（Area2D动态创建后overlapping列表可能未及时更新）
	var player_near: bool = false
	## 先用距离检测（48px内视为靠近）
	if _player.global_position.distance_to(vendor.global_position) <= 48.0:
		player_near = true
	## 距离不够时再用Area2D重叠检测兜底
	if not player_near:
		var area = vendor.get_node_or_null("Area2D")
		if area:
			for body_node in area.get_overlapping_bodies():
				if body_node is CharacterBody2D:
					player_near = true
					break
	if not player_near:
		return false
	var talked: bool = vendor.get_meta("vendor_talked", false)
	vendor.set_meta("vendor_talked", true)
	var scene_id: String = "night_vendor_return" if talked else "night_vendor_shop"
	DialogueManager.start_scene(scene_id)
	return true


## 创建古井回血感应区
## 位置：格(21,16)中心，像素(688,528)
func _setup_well_heal_area() -> void:
	## 防止重复创建
	if get_node_or_null("WellHealArea") != null:
		return

	var well_node := Node2D.new()
	well_node.name = "WellHealArea"
	well_node.position = Vector2(688, 528)
	add_child(well_node)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect2 := RectangleShape2D.new()
	rect2.size = Vector2(48, 48)
	shape.shape = rect2
	area.add_child(shape)
	well_node.add_child(area)

	area.body_entered.connect(
		func(body_node):
			if not body_node is CharacterBody2D:
				return
			if not GameData.well_used_today \
					and GameData.player.hp < GameData.player.max_hp:
				_enter_hint.text = "按 E 喝水"
				_enter_hint.show()
			else:
				## 已用过或满血时不显示提示
				if _current_entrance == "":
					_enter_hint.hide()
	)
	area.body_exited.connect(
		func(body_node):
			if body_node is CharacterBody2D:
				if _current_entrance == "":
					_enter_hint.hide()
	)
