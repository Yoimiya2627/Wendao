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
const ENTRANCE_TEMPLE_GRID : Vector2i = Vector2i(37, 28)

## 入口触发检测半径（格子数，±1格均可触发提示）
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
const SPAWN_FROM_TEMPLE : Vector2 = Vector2(1184, 928)
## 默认出生点：主干道交叉口格(20,14)
const SPAWN_DEFAULT     : Vector2 = Vector2(640,  448)

# ══════════════════════════════════════════════════════════════════
# 四、节点引用（@onready 在 _ready() 前自动赋值）
# ══════════════════════════════════════════════════════════════════

@onready var _tile_map    : TileMap         = $TownMap
@onready var _player      : CharacterBody2D = $Player
@onready var _spawn_point : Node2D          = $SpawnPoint
@onready var _enter_hint  : Label           = $UILayer/EnterHintLabel

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


# ══════════════════════════════════════════════════════════════════
# 六、生命周期
# ══════════════════════════════════════════════════════════════════

func _ready() -> void:
	# 规则七：游戏首次启动（story_phase==0）直接切换至杂货铺
	# 开场对话在ShopScene内触发，TownScene不做任何初始化
	if not GameData.morning_triggered:
		await _wait_for_transition()
		SceneTransition.change_scene("res://scenes/ShopScene.tscn")
		return

	# 执行顺序（规范第八节）：① 建地图 → ② 设出生点 → ③ 设摄像机 → ④ 连信号
	_build_tileset_and_map()
	_set_spawn_position()
	_setup_camera()
	_connect_story_signals()
	_initialized = true


func _process(delta: float) -> void:
	# 未初始化时跳过（story_phase==0重定向期间）
	if not _initialized:
		return
	# 冷却倒计时
	if _transition_timer > 0.0:
		_transition_timer -= delta
	# 每帧检测玩家与入口的距离，更新提示标签
	_check_entrance_proximity()


func _unhandled_input(event: InputEvent) -> void:
	# 未初始化或没有靠近任何入口时忽略
	if not _initialized or _current_entrance == "":
		return
	# E 键触发入口进入（not echo 防止长按重复）
	if event is InputEventKey \
			and event.keycode == KEY_E \
			and event.pressed \
			and not event.echo:
		# 延迟一帧执行：让同一帧内的 NPC 交互优先（NPC.interact()会先设置 is_active）
		call_deferred("_try_enter_scene", _current_entrance)


# ══════════════════════════════════════════════════════════════════
# 七、出生点系统（规范第五节）
# ══════════════════════════════════════════════════════════════════

## 根据 GameData.last_scene 决定玩家进入 TownScene 后的出生位置
func _set_spawn_position() -> void:
	var pos: Vector2
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

	# 玩家当前格坐标（整数除法向下取整）
	var pg := Vector2i(
		int(_player.global_position.x) / TILE_SIZE,
		int(_player.global_position.y) / TILE_SIZE
	)

	# 按优先级依次检测三个入口
	if _in_range(pg, ENTRANCE_SHOP_GRID):
		_set_entrance_hint("shop")
		return

	if _in_range(pg, ENTRANCE_TEA_GRID):
		_set_entrance_hint("tea")
		return

	if _in_range(pg, ENTRANCE_TEMPLE_GRID):
		# 废庙特殊规则：story_phase < 3 时大门紧锁
		if GameData.story_phase < 3:
			_enter_hint.text = "大门紧锁"
			_enter_hint.show()
			_current_entrance = ""
		else:
			_set_entrance_hint("temple")
		return

	# 不靠近任何入口，隐藏提示
	_set_entrance_hint("")


## 判断玩家格坐标是否在指定入口格的 ±ENTRANCE_RANGE 范围内
func _in_range(player_grid: Vector2i, entrance_grid: Vector2i) -> bool:
	return abs(player_grid.x - entrance_grid.x) <= ENTRANCE_RANGE \
		and abs(player_grid.y - entrance_grid.y) <= ENTRANCE_RANGE


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
	if _transition_timer > 0.0 or SceneTransition._is_transitioning:
		return
	_transition_timer = TRANSITION_COOLDOWN
	match entrance:
		"shop":
			SceneTransition.change_scene("res://scenes/ShopScene.tscn")
		"tea":
			SceneTransition.change_scene("res://scenes/TeaScene.tscn")
		"temple":
			SceneTransition.change_scene("res://scenes/TempleScene.tscn")


## 等待 SceneTransition 当前过渡动画完成（供 story_phase==0 重定向使用）
func _wait_for_transition() -> void:
	while SceneTransition._is_transitioning:
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
	_draw_map()


## 将 img 从 x_off 起的32×32区域涂为纯色（带1px深色边框增加网格感）
func _fill_tile(img: Image, x_off: int, color: Color) -> void:
	var border_color := color.darkened(0.2)
	for x in TILE_SIZE:
		for y in TILE_SIZE:
			var is_edge := (x == 0 or x == TILE_SIZE - 1 or y == 0 or y == TILE_SIZE - 1)
			img.set_pixel(x_off + x, y, border_color if is_edge else color)


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


# ══════════════════════════════════════════════════════════════════
# 十三、剧情信号（保持不变，规范第九节）
# ══════════════════════════════════════════════════════════════════

## 连接 DialogueManager 的事件与对话结束信号
func _connect_story_signals() -> void:
	DialogueManager.event_triggered.connect(_on_event_triggered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


## 处理对话中的 event 节点
## 第一阶段：仅做占位，不推进任何 story_phase
## 第四阶段（剧情触发系统）再补充完整逻辑
func _on_event_triggered(_event_name: String) -> void:
	pass  # 第四阶段实现


## 处理完整对话场景结束
## 第一阶段：仅做占位，不强制跳转任何场景，由玩家自由行走推进剧情
## 第四阶段（剧情触发系统）再补充完整逻辑
func _on_dialogue_ended(_scene_id: String) -> void:
	pass  # 第四阶段实现
