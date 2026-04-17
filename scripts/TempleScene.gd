## TempleScene.gd
## 废庙室内场景控制器
## 三个房间：入口大厅(0,0) / 左厢房(-600,0) / 右厢房(600,0)
## 空间平移法：房间物理隔离，切换时传送玩家坐标+更新摄像机Limit
extends Node2D

@onready var _exit_area     : Area2D          = $ExitArea
@onready var _exit_hint     : Label           = $UILayer/ExitHintLabel
@onready var _spawn_point   : Node2D          = $SpawnPoint
@onready var _player        : CharacterBody2D = $Player
@onready var _monolith      : Node2D          = $Monolith
@onready var _interact_hint : Label           = $UILayer/InteractHintLabel

## 碑文场景ID
const STONE_SCENE_IDS: Array = [
	"temple_stone_1",
	"temple_stone_2",
	"temple_stone_3",
	"temple_stone_4"
]

## 幽影狼数据
const WOLF_DATA: Dictionary = {
	"name": "幽影狼",
	"hp": 60,
	"atk": 10,
	"def": 2
}

## 石皮蟾数据
const TOAD_DATA: Dictionary = {
	"name": "石皮蟾",
	"hp": 100,
	"atk": 14,
	"def": 5
}

## 虚形魇数据（BOSS）
const BOSS_DATA: Dictionary = {
	"name": "虚形魇",
	"hp": 120,
	"atk": 16,
	"def": 4
}

## 运行时状态
var _stones_read: Array[bool] = []
var _monolith_activated: bool = false
var _nearby_stone: int = -1
var _near_monolith: bool = false
var _player_in_exit: bool = false
var _gufei_visible: bool = false
var _near_gufei: bool = false
var _npc_gufei: Node2D = null

## 当前所在房间
var _current_room: String = "main"

## 门的靠近状态
var _near_door_left: bool = false
var _near_door_right: bool = false
var _near_door_back: bool = false

## 幽影狼节点引用
var _wolf_left: Node2D = null
var _wolf_right: Node2D = null

## 内殿/BOSS间门的靠近状态
var _near_door_inner: bool = false
var _near_door_boss: bool = false
var _near_door_back_inner: bool = false
var _near_door_back_boss: bool = false

## 内殿/BOSS间首次进入标志（触发一次性氛围旁白）
## _inner_hall_entered / _boss_room_entered 已迁移至 GameData.triggered_events 持久化

## 石皮蟾战前旁白是否已触发
var _toad_approach_triggered: bool = false

## 石皮蟾节点引用
var _toad: Node2D = null
## 是否靠近石皮蟾
var _near_toad: bool = false

## 废庙隐藏交互点触发状态
var _tally_triggered: bool = false
var _remnant4_triggered: bool = false
var _near_tally: bool = false
var _near_remnant4: bool = false


func _ready() -> void:
	_stones_read = GameData.stones_read.duplicate()
	_exit_hint.hide()
	_interact_hint.hide()
	_setup_camera()
	_exit_area.body_entered.connect(_on_exit_body_entered)
	_exit_area.body_exited.connect(_on_exit_body_exited)
	DialogueManager.event_triggered.connect(_on_event_triggered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_connect_stone_areas()
	## BGM 由 SceneTransition._auto_play_bgm() 统一触发（SCENE_BGM_MAP["TempleScene"]）
	_spawn_ambient_particles()

	## 碑文位置分配：
	## Stone1→入口大厅，Stone2→左厢房，Stone3→右厢房，Stone4→内殿
	$Stones/Stone1.position = Vector2(80, 220)
	$Stones/Stone2.position = Vector2(-360, 80)
	$Stones/Stone3.position = Vector2(840, 80)
	$Stones/Stone4.position = Vector2(240, -190)
	## 主石碑移到BOSS间中央，作为最终觉醒触发点
	_monolith.position = Vector2(240, -520)

	## Stone4在内殿，默认显示
	## 石皮蟾存活时靠近会触发战前旁白，不依赖碑文感应区阻挡
	var stone4 = get_node_or_null("Stones/Stone4")
	if stone4:
		stone4.show()
		var stone4_area = stone4.get_node_or_null("Area2D")
		if stone4_area:
			stone4_area.monitoring = true
			stone4_area.monitorable = true
		var stone4_collider = stone4.get_node_or_null("StoneCollider/StoneShape")
		if stone4_collider:
			stone4_collider.set_deferred("disabled", false)

	## 战斗返回处理：先标记击败，再清空
	if GameData.battle_won and GameData.current_enemy_id != "":
		var defeated_id := GameData.current_enemy_id
		GameData.temple_dungeon_state[defeated_id + "_defeated"] = true
		GameData.current_enemy_id = ""
		GameData.battle_won = false

	## 创建幽影狼（已击败的不创建）
	_setup_wolves()

	## 碑文视觉更新
	_update_stone_visuals()

	## 默认禁用石碑感应区，四块碑文读完后再启用
	var monolith_area = get_node_or_null("Monolith/Area2D")
	if monolith_area:
		monolith_area.monitoring = false
		monolith_area.monitorable = false
	## 默认禁用石碑碰撞体
	var monolith_collider = get_node_or_null("Monolith/MonolithCollider/MonolithShape")
	if monolith_collider:
		monolith_collider.set_deferred("disabled", true)

	## 根据story_phase或boss_defeated决定初始化路径
	var boss_defeated: bool = GameData.temple_dungeon_state.get("boss_defeated", false)
	if boss_defeated and GameData.story_phase == 3:
		_monolith_activated = true
		_monolith.hide()
		_setup_gufei()
		## 打完BOSS顾飞白刚刷出、对话尚未开始，是最干净的存档节点
		## 写入crossroad槽，供玩家读档后重新体验章末分歧
		GameData.save_to_file("crossroad")
	elif GameData.story_phase >= 4:
		_monolith_activated = true
		_monolith.hide()
	elif GameData.stones_read.all(func(v): return v):
		_monolith.show()
		## 读档恢复：四块碑文已全读，重新启用石碑感应区和碰撞体
		var monolith_area_restore = get_node_or_null("Monolith/Area2D")
		if monolith_area_restore:
			monolith_area_restore.monitoring = true
			monolith_area_restore.monitorable = true
		var monolith_collider_restore = get_node_or_null("Monolith/MonolithCollider/MonolithShape")
		if monolith_collider_restore:
			monolith_collider_restore.set_deferred("disabled", false)

	## 恢复玩家坐标：战斗返回用last_player_position，否则用SpawnPoint
	if GameData.last_player_position != Vector2.ZERO:
		_player.global_position = GameData.last_player_position
		GameData.last_player_position = Vector2.ZERO
		_detect_current_room()
	else:
		_player.global_position = _spawn_point.global_position

	_update_camera_for_room()
	_setup_doors()
	_setup_inner_doors()
	_setup_toad()
	_update_inner_door_lock()
	_setup_temple_hidden_interacts()
	_apply_floor_texture()
	## 读档直接进入TempleScene时（不经过TownScene），确保主HUD显示
	UIManager.show_main_hud()


## 给废庙各房间的石地板挂 shader（石纹基底，无木纹，低频色斑更强）
func _apply_floor_texture() -> void:
	for bg_name in ["Background", "BackgroundLeft", "BackgroundRight"]:
		var floor_rect := get_node_or_null(bg_name + "/Floor")
		if floor_rect == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/ground_texture.gdshader")
		mat.set_shader_parameter("base_color", floor_rect.color)
		mat.set_shader_parameter("grain", 0.045)
		mat.set_shader_parameter("blot", 0.22)
		mat.set_shader_parameter("blot_scale", 4.5)
		mat.set_shader_parameter("wood_grain", 0.0)
		mat.set_shader_parameter("wood_freq", 0.0)
		floor_rect.material = mat


func _spawn_ambient_particles() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var p := CPUParticles2D.new()
	p.amount               = 15
	p.lifetime             = 7.0
	p.explosiveness        = 0.0
	p.randomness           = 1.0
	p.direction            = Vector2(0.1, -1.0)
	p.spread               = 25.0
	p.gravity              = Vector2(2.0, -5.0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min     = 1.5
	p.scale_amount_max     = 4.0
	p.color                = Color(0.60, 0.55, 0.70, 0.15)
	p.emission_shape       = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640.0, 360.0)
	p.position             = Vector2(640.0, 360.0)
	layer.add_child(p)


func _exit_tree() -> void:
	if DialogueManager.event_triggered.is_connected(_on_event_triggered):
		DialogueManager.event_triggered.disconnect(_on_event_triggered)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)


func _process(_delta: float) -> void:
	## 实时检测玩家是否在内殿门感应区内
	## body_entered只触发一次，读完碑文后必须实时刷新才能解锁提示
	if _current_room == "main" and not DialogueManager.is_active:
		var door = get_node_or_null("door_to_inner")
		if door:
			var area = door.get_node_or_null("Area2D")
			if area:
				var player_in_area := false
				for body in area.get_overlapping_bodies():
					if body is CharacterBody2D:
						player_in_area = true
						break
				if player_in_area:
					if GameData.stones_read[1] and GameData.stones_read[2]:
						_near_door_inner = true
						_interact_hint.text = "按 E 进入内殿"
						_interact_hint.show()
					else:
						_near_door_inner = false
						_interact_hint.text = "需先探索左右厢房"
						_interact_hint.show()
				else:
					## 玩家离开感应区，清除标志
					if _near_door_inner:
						_near_door_inner = false
						_interact_hint.hide()

	## 实时检测玩家是否在BOSS门感应区内
	if _current_room == "inner" and not DialogueManager.is_active:
		var door_boss = get_node_or_null("door_to_boss")
		if door_boss:
			var area = door_boss.get_node_or_null("Area2D")
			if area:
				var player_in_area := false
				for body in area.get_overlapping_bodies():
					if body is CharacterBody2D:
						player_in_area = true
						break
				if player_in_area:
					var toad_done: bool = GameData.temple_dungeon_state.get("toad_defeated", false)
					if GameData.stones_read[3] and toad_done:
						_near_door_boss = true
						_interact_hint.text = "按 E 进入最深处"
						_interact_hint.show()
					else:
						_near_door_boss = false
						if not toad_done:
							_interact_hint.text = "需先击败内殿妖兽"
						else:
							_interact_hint.text = "碑文尚未读完"
						_interact_hint.show()
				else:
					if _near_door_boss:
						_near_door_boss = false
						_interact_hint.hide()


func _setup_camera() -> void:
	var cam: Camera2D = $Player/Camera2D
	cam.zoom = Vector2(2.0, 2.0)
	cam.position_smoothing_enabled = false
	cam.reset_smoothing()


## 根据玩家坐标判断当前房间
func _detect_current_room() -> void:
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y
	if py < -320:
		_current_room = "boss"
	elif py < -50:
		_current_room = "inner"
	elif px < -300:
		_current_room = "left"
	elif px > 300:
		_current_room = "right"
	else:
		_current_room = "main"


## 根据当前房间更新摄像机Limit
func _update_camera_for_room() -> void:
	var cam: Camera2D = $Player/Camera2D
	match _current_room:
		"main":
			cam.limit_left   = 0
			cam.limit_top    = 0
			cam.limit_right  = 480
			cam.limit_bottom = 320
		"left":
			cam.limit_left   = -600
			cam.limit_top    = 0
			cam.limit_right  = -120
			cam.limit_bottom = 320
		"right":
			cam.limit_left   = 600
			cam.limit_top    = 0
			cam.limit_right  = 1080
			cam.limit_bottom = 320
		"inner":
			cam.limit_left   = 0
			cam.limit_top    = -320
			cam.limit_right  = 480
			cam.limit_bottom = 0
		"boss":
			cam.limit_left   = 0
			cam.limit_top    = -640
			cam.limit_right  = 480
			cam.limit_bottom = -320
	cam.reset_smoothing()


## 创建幽影狼节点
func _setup_wolves() -> void:
	if not GameData.temple_dungeon_state.get("wolf_left_defeated", false):
		_wolf_left = _create_wolf(Vector2(-360, 120), "wolf_left")
	if not GameData.temple_dungeon_state.get("wolf_right_defeated", false):
		_wolf_right = _create_wolf(Vector2(840, 120), "wolf_right")


## 创建石皮蟾（内殿，守护Stone4）
func _setup_toad() -> void:
	if GameData.temple_dungeon_state.get("toad_defeated", false):
		return
	_toad = _create_toad(Vector2(240, -110), "toad")


## 创建单只石皮蟾节点
## 石皮蟾不自动触发战斗，靠近时显示提示，玩家主动按E经旁白进入战斗
func _create_toad(pos: Vector2, toad_id: String) -> Node2D:
	var toad := Node2D.new()
	toad.position = pos
	toad.name = toad_id
	add_child(toad)

	var rect := ColorRect.new()
	rect.color = Color(0.45, 0.42, 0.35, 1)
	rect.offset_left   = -18.0
	rect.offset_top    = -14.0
	rect.offset_right  = 18.0
	rect.offset_bottom = 14.0
	toad.add_child(rect)

	var label := Label.new()
	label.text = "石皮蟾"
	label.position = Vector2(-22, -32)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5, 1))
	toad.add_child(label)

	var phys_body := StaticBody2D.new()
	var phys_shape := CollisionShape2D.new()
	var phys_rect := RectangleShape2D.new()
	phys_rect.size = Vector2(36, 28)
	phys_shape.shape = phys_rect
	phys_body.add_child(phys_shape)
	toad.add_child(phys_body)

	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(80, 60)
	shape.shape = area_rect
	area.add_child(shape)
	toad.add_child(area)

	## 靠近时只设置标志和提示，不自动触发战斗
	area.body_entered.connect(
		func(body):
			if body is CharacterBody2D and _toad != null:
				_near_toad = true
				_interact_hint.text = "按 E 交战"
				_interact_hint.show()
	)
	area.body_exited.connect(
		func(body):
			if body is CharacterBody2D:
				_near_toad = false
				_interact_hint.hide()
	)

	return toad


## 触发石皮蟾战斗
func _trigger_toad_battle(toad_id: String) -> void:
	GameData.current_enemy_id = toad_id
	GameData.current_enemy_data = TOAD_DATA.duplicate()
	GameData.last_player_position = _player.global_position
	SceneTransition.change_scene("res://scenes/BattleScene.tscn")


## 创建内殿和BOSS间的门
func _setup_inner_doors() -> void:
	## 大厅→内殿（大厅顶部中央）
	_create_door(Vector2(240, 60), "door_to_inner")
	## 内殿→大厅
	_create_door(Vector2(240, -20), "door_back_from_inner")
	## 内殿→BOSS间
	_create_door(Vector2(240, -250), "door_to_boss")
	## BOSS间→内殿
	_create_door(Vector2(240, -340), "door_back_from_boss")


## 创建废庙内的隐藏交互点
## 划痕在入口大厅左侧石柱(160,200)，残页四在内殿碑文旁(280,-160)
func _setup_temple_hidden_interacts() -> void:
	## 三百六十五道划痕：入口大厅左侧石柱
	_create_hidden_interact(
		Vector2(160, 200),
		"tally_area",
		func(body):
			if body is CharacterBody2D and not _tally_triggered:
				_near_tally = true
				_interact_hint.text = "按 E 查看"
				_interact_hint.show(),
		func(body):
			if body is CharacterBody2D:
				_near_tally = false
				_interact_hint.hide()
	)
	## 残页四：内殿碑文旁地面（石皮蟾击败后才可读）
	_create_hidden_interact(
		Vector2(280, -160),
		"remnant4_area",
		func(body):
			if body is CharacterBody2D and not _remnant4_triggered:
				_near_remnant4 = true
				_interact_hint.text = "按 E 查看"
				_interact_hint.show(),
		func(body):
			if body is CharacterBody2D:
				_near_remnant4 = false
				_interact_hint.hide()
	)


## 创建单个隐藏交互感应区节点
func _create_hidden_interact(
		pos: Vector2,
		node_name: String,
		on_enter: Callable,
		on_exit: Callable) -> void:
	var node := Node2D.new()
	node.position = pos
	node.name = node_name
	add_child(node)

	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 48)
	shape.shape = rect
	area.add_child(shape)
	node.add_child(area)

	area.body_entered.connect(on_enter)
	area.body_exited.connect(on_exit)


## 根据碑文状态更新内殿门锁定视觉
## 解锁条件：Stone2和Stone3（左右厢房碑文）均已读完
func _update_inner_door_lock() -> void:
	var door = get_node_or_null("door_to_inner")
	if door == null:
		return
	var unlocked: bool = GameData.stones_read[1] and GameData.stones_read[2]
	## 根据锁定状态更新门的视觉颜色
	var door_visual = door.get_node_or_null("ColorRect")
	if door_visual:
		door_visual.color = Color(0.20, 0.35, 0.20, 0.6) if unlocked else Color(0.35, 0.15, 0.10, 0.6)


## 创建单只幽影狼
func _create_wolf(pos: Vector2, wolf_id: String) -> Node2D:
	var wolf := Node2D.new()
	wolf.position = pos
	wolf.name = wolf_id
	add_child(wolf)

	var rect := ColorRect.new()
	rect.color = Color(0.3, 0.15, 0.4, 1)
	rect.offset_left   = -12.0
	rect.offset_top    = -20.0
	rect.offset_right  = 12.0
	rect.offset_bottom = 20.0
	wolf.add_child(rect)

	var label := Label.new()
	label.text = "幽影狼"
	label.position = Vector2(-20, -38)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1))
	wolf.add_child(label)

	var phys_body := StaticBody2D.new()
	var phys_shape := CollisionShape2D.new()
	var phys_rect := RectangleShape2D.new()
	phys_rect.size = Vector2(24, 40)
	phys_shape.shape = phys_rect
	phys_body.add_child(phys_shape)
	wolf.add_child(phys_body)

	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(60, 60)
	shape.shape = area_rect
	area.add_child(shape)
	wolf.add_child(area)

	area.body_entered.connect(
		func(body):
			if body is CharacterBody2D:
				_trigger_wolf_battle(wolf_id)
	)

	return wolf


## 动态创建房间之间的门
func _setup_doors() -> void:
	_create_door(Vector2(80, 60), "door_to_left")
	_create_door(Vector2(380, 60), "door_to_right")
	_create_door(Vector2(-520, 280), "door_back_from_left")
	_create_door(Vector2(680, 280), "door_back_from_right")


## 创建单个门节点
func _create_door(pos: Vector2, door_id: String) -> void:
	var door := Node2D.new()
	door.position = pos
	door.name = door_id
	add_child(door)

	## 门的视觉色块（暗褐色，替代原调试绿色）
	var door_visual := ColorRect.new()
	door_visual.color = Color(0.35, 0.28, 0.20, 0.6)
	door_visual.offset_left   = -24.0
	door_visual.offset_top    = -16.0
	door_visual.offset_right  = 24.0
	door_visual.offset_bottom = 16.0
	door.add_child(door_visual)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 48)
	shape.shape = rect
	area.add_child(shape)
	door.add_child(area)

	## 门的物理碰撞体（阻止玩家穿过）
	var door_body := StaticBody2D.new()
	var door_shape := CollisionShape2D.new()
	var door_rect := RectangleShape2D.new()
	door_rect.size = Vector2(80, 16)
	door_shape.shape = door_rect
	door_body.add_child(door_shape)
	door.add_child(door_body)

	match door_id:
		"door_to_left":
			area.body_entered.connect(
				func(body):
					print("door_to_left body_entered: ", body.name, " current_room=", _current_room)
					if body is CharacterBody2D and _current_room == "main":
						_near_door_left = true
						_interact_hint.text = "按 E 进入左厢房"
						_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_left = false
						_interact_hint.hide()
			)
		"door_to_right":
			area.body_entered.connect(
				func(body):
					if body is CharacterBody2D and _current_room == "main":
						_near_door_right = true
						_interact_hint.text = "按 E 进入右厢房"
						_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_right = false
						_interact_hint.hide()
			)
		"door_back_from_left", "door_back_from_right":
			area.body_entered.connect(
				func(body):
					if body is CharacterBody2D and (_current_room == "left" or _current_room == "right"):
						_near_door_back = true
						_interact_hint.text = "按 E 返回大厅"
						_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_back = false
						_interact_hint.hide()
			)
		"door_to_inner":
			area.body_entered.connect(
				func(body):
					if body is CharacterBody2D and _current_room == "main":
						if GameData.stones_read[1] and GameData.stones_read[2]:
							_near_door_inner = true
							_interact_hint.text = "按 E 进入内殿"
							_interact_hint.show()
						else:
							_interact_hint.text = "需先探索左右厢房"
							_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_inner = false
						_interact_hint.hide()
			)
		"door_back_from_inner":
			area.body_entered.connect(
				func(body):
					if body is CharacterBody2D and _current_room == "inner":
						_near_door_back_inner = true
						_interact_hint.text = "按 E 返回大厅"
						_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_back_inner = false
						_interact_hint.hide()
			)
		"door_to_boss":
			area.body_entered.connect(
				func(body):
					if body is CharacterBody2D and _current_room == "inner":
						var toad_done: bool = GameData.temple_dungeon_state.get("toad_defeated", false)
						if GameData.stones_read[3] and toad_done:
							_near_door_boss = true
							_interact_hint.text = "按 E 进入最深处"
							_interact_hint.show()
						else:
							if not toad_done:
								_interact_hint.text = "需先击败内殿妖兽"
							else:
								_interact_hint.text = "碑文尚未读完"
							_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_boss = false
						_interact_hint.hide()
			)
		"door_back_from_boss":
			area.body_entered.connect(
				func(body):
					if body is CharacterBody2D and _current_room == "boss":
						_near_door_back_boss = true
						_interact_hint.text = "按 E 返回内殿"
						_interact_hint.show()
			)
			area.body_exited.connect(
				func(body):
					if body is CharacterBody2D:
						_near_door_back_boss = false
						_interact_hint.hide()
			)


## 切换房间（安全落点防死循环）
func _switch_room(target_room: String) -> void:
	match target_room:
		"main_from_left":
			_current_room = "main"
			_player.global_position = Vector2(80, 100)
		"main_from_right":
			_current_room = "main"
			_player.global_position = Vector2(380, 100)
		"left":
			_current_room = "left"
			_player.global_position = Vector2(-520, 240)
		"right":
			_current_room = "right"
			_player.global_position = Vector2(680, 240)
		"inner":
			_current_room = "inner"
			_player.global_position = Vector2(240, -50)
		"main_from_inner":
			_current_room = "main"
			_player.global_position = Vector2(240, 100)
		"boss":
			_current_room = "boss"
			_player.global_position = Vector2(240, -370)
		"inner_from_boss":
			_current_room = "inner"
			_player.global_position = Vector2(240, -220)
	_update_camera_for_room()
	_interact_hint.hide()
	_near_door_left = false
	_near_door_right = false
	_near_door_back = false
	_near_door_inner = false
	_near_door_boss = false
	_near_door_back_inner = false
	_near_door_back_boss = false
	_near_toad = false


## 防止战斗触发重入（await期间body_entered可能再次触发）
var _wolf_battle_pending: bool = false

## 触发小怪战斗（不推进story_phase）
func _trigger_wolf_battle(wolf_id: String) -> void:
	if _wolf_battle_pending or SceneTransition.is_transitioning or DialogueManager.is_active:
		return
	_wolf_battle_pending = true
	## 首次遭遇妖兽：播放氛围旁白后再进战斗
	if not GameData.triggered_events.has("monster_approach"):
		GameData.triggered_events.append("monster_approach")
		DialogueManager.start_scene("monster_approach")
		await DialogueManager.dialogue_ended
		if not is_inside_tree():
			return
	GameData.current_enemy_id = wolf_id
	GameData.current_enemy_data = WOLF_DATA.duplicate()
	GameData.last_player_position = _player.global_position
	SceneTransition.change_scene("res://scenes/BattleScene.tscn")


func _connect_stone_areas() -> void:
	for i in 4:
		var area = get_node_or_null("Stones/Stone%d/Area2D" % (i + 1))
		if area:
			area.body_entered.connect(_on_stone_entered.bind(i))
			area.body_exited.connect(_on_stone_exited.bind(i))
	var monolith_area = get_node_or_null("Monolith/Area2D")
	if monolith_area:
		monolith_area.body_entered.connect(_on_monolith_entered)
		monolith_area.body_exited.connect(_on_monolith_exited)


func _update_stone_visuals() -> void:
	for i in 4:
		var stone = get_node_or_null("Stones/Stone%d" % (i + 1))
		if stone == null:
			continue
		var rect = stone.get_node_or_null("ColorRect")
		if rect == null:
			continue
		if GameData.stones_read[i]:
			rect.modulate = Color(1.0, 0.85, 0.3, 1.0)
		else:
			rect.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _setup_gufei() -> void:
	if _npc_gufei != null:
		return
	_gufei_visible = true

	_npc_gufei = Node2D.new()
	_npc_gufei.position = Vector2(120, -450)
	add_child(_npc_gufei)

	var npc_body := ColorRect.new()
	npc_body.offset_left   = -10.0
	npc_body.offset_top    = -18.0
	npc_body.offset_right  = 10.0
	npc_body.offset_bottom = 18.0
	npc_body.color = Color(0.75, 0.80, 0.85, 1)
	_npc_gufei.add_child(npc_body)

	var label := Label.new()
	label.text = "顾飞白"
	label.position = Vector2(-20, -36)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_npc_gufei.add_child(label)

	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(48, 56)
	shape.shape = area_rect
	area.add_child(shape)
	_npc_gufei.add_child(area)
	area.body_entered.connect(_on_gufei_entered)
	area.body_exited.connect(_on_gufei_exited)

	var phys_body := StaticBody2D.new()
	var phys_shape := CollisionShape2D.new()
	var phys_rect := RectangleShape2D.new()
	phys_rect.size = Vector2(20, 36)
	phys_shape.shape = phys_rect
	phys_body.add_child(phys_shape)
	_npc_gufei.add_child(phys_body)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not (event.keycode == KEY_E and event.pressed and not event.echo):
		return
	if DialogueManager.is_active:
		return

	## 靠近碑文：检查幽影狼是否存活
	if _nearby_stone >= 0:
		if _stones_read[_nearby_stone]:
			_interact_hint.text = "这块碑文已经读过了"
			_interact_hint.show()
			get_viewport().set_input_as_handled()
			return
		var wolf_blocking := false
		if _current_room == "left" and _wolf_left != null:
			wolf_blocking = true
		elif _current_room == "right" and _wolf_right != null:
			wolf_blocking = true
		if wolf_blocking:
			_interact_hint.text = "先击退幽影狼！"
			return
		_stones_read[_nearby_stone] = true
		GameData.stones_read[_nearby_stone] = true
		DialogueManager.start_scene(STONE_SCENE_IDS[_nearby_stone])
		_update_stone_visuals()
		_check_all_stones_read()
		_update_inner_door_lock()
		get_viewport().set_input_as_handled()
		return

	## 划痕交互（入口大厅，任何时候可读）
	if _near_tally and not _tally_triggered:
		_tally_triggered = true
		_near_tally = false
		_interact_hint.hide()
		DialogueManager.start_scene("tally_marks")
		get_viewport().set_input_as_handled()
		return

	## 残页四（内殿，石皮蟾击败后才可读）
	if _near_remnant4 and not _remnant4_triggered:
		if GameData.temple_dungeon_state.get("toad_defeated", false):
			_remnant4_triggered = true
			_near_remnant4 = false
			_interact_hint.hide()
			DialogueManager.start_scene("remnant_page_4")
			get_viewport().set_input_as_handled()
			return
		else:
			_interact_hint.text = "有什么东西压在石头下面……"
			get_viewport().set_input_as_handled()

	## 靠近石皮蟾：按E触发战前旁白，旁白结束后自动进入战斗
	if _near_toad and _toad != null:
		if not _toad_approach_triggered:
			_toad_approach_triggered = true
			_interact_hint.hide()
			DialogueManager.start_scene("stone_toad_approach")
		get_viewport().set_input_as_handled()
		return

	## 靠近石碑：按E激活（BOSS已击败则不再触发）
	if _near_monolith and not _monolith_activated:
		var boss_done: bool = GameData.temple_dungeon_state.get("boss_defeated", false)
		if not boss_done:
			_monolith_activated = true
			DialogueManager.start_scene("activation_monologue")
		get_viewport().set_input_as_handled()
		return

	## 靠近顾飞白：按E触发对话
	if _near_gufei and _gufei_visible:
		_gufei_visible = false
		_interact_hint.hide()
		var scene_id: String
		if GameData.got_coin:
			scene_id = "after_battle_coin"
		else:
			scene_id = "after_battle"
		DialogueManager.start_scene(scene_id)
		get_viewport().set_input_as_handled()
		return

	## 靠近门：按E切换房间
	if _near_door_left and _current_room == "main":
		_switch_room("left")
		get_viewport().set_input_as_handled()
		return
	if _near_door_right and _current_room == "main":
		_switch_room("right")
		get_viewport().set_input_as_handled()
		return
	if _near_door_back and _current_room != "main":
		if _current_room == "left":
			_switch_room("main_from_left")
		elif _current_room == "right":
			_switch_room("main_from_right")
		get_viewport().set_input_as_handled()
		return

	if _near_door_inner and _current_room == "main":
		if GameData.stones_read[1] and GameData.stones_read[2]:
			_switch_room("inner")
			if not GameData.triggered_events.has("inner_hall_entered"):
				GameData.triggered_events.append("inner_hall_entered")
				await get_tree().process_frame
				if not is_inside_tree():
					return
				DialogueManager.start_scene("inner_hall_enter")
		get_viewport().set_input_as_handled()
		return

	if _near_door_back_inner and _current_room == "inner":
		_switch_room("main_from_inner")
		get_viewport().set_input_as_handled()
		return

	if _near_door_boss and _current_room == "inner":
		var toad_done: bool = GameData.temple_dungeon_state.get("toad_defeated", false)
		if GameData.stones_read[3] and toad_done:
			_switch_room("boss")
			if not GameData.triggered_events.has("boss_room_entered"):
				GameData.triggered_events.append("boss_room_entered")
				await get_tree().process_frame
				if not is_inside_tree():
					return
				DialogueManager.start_scene("boss_room_enter")
		get_viewport().set_input_as_handled()
		return

	if _near_door_back_boss and _current_room == "boss":
		_switch_room("inner_from_boss")
		get_viewport().set_input_as_handled()
		return

	## 出口：按E离开废庙
	if _player_in_exit:
		GameData.last_scene = "temple"
		GameData.save_to_file("auto")
		SceneTransition.change_scene("res://scenes/TownScene.tscn")
		get_viewport().set_input_as_handled()


func _check_all_stones_read() -> void:
	var boss_done: bool = GameData.temple_dungeon_state.get("boss_defeated", false)
	if GameData.stones_read[0] and GameData.stones_read[1] and GameData.stones_read[2] and GameData.stones_read[3] and not boss_done:
		_monolith.show()
		## 四块碑文全读完，启用石碑感应区
		var monolith_area = get_node_or_null("Monolith/Area2D")
		if monolith_area:
			monolith_area.monitoring = true
			monolith_area.monitorable = true
		## 四块碑文全读完，启用石碑碰撞体
		var monolith_collider = get_node_or_null("Monolith/MonolithCollider/MonolithShape")
		if monolith_collider:
			monolith_collider.set_deferred("disabled", false)
	## 每次读完碑文都更新内殿门的锁定视觉
	_update_inner_door_lock()


func _on_event_triggered(event_name: String) -> void:
	match event_name:
		"trigger_battle":
			## 不在进入战斗时推进phase，防止战败返回时误触发胜利流程
			## phase推进移到after_battle对话结束时（_on_dialogue_ended）
			GameData.current_enemy_id = "boss"
			GameData.current_enemy_data = BOSS_DATA.duplicate()
			GameData.last_player_position = _player.global_position
			DialogueManager.finish_event()
			SceneTransition.change_scene("res://scenes/BattleScene.tscn")
		"start_chapter_end_a":
			DialogueManager.finish_event()
			GameData.chapter_end_path = "a"
			SceneTransition.change_scene("res://scenes/ChapterEndScene.tscn")
		"return_home_final":
			DialogueManager.finish_event()
			if GameData.story_phase == 4:
				GameData.advance_phase()
			SceneTransition.change_scene("res://scenes/ShopScene.tscn")
		_:
			DialogueManager.finish_event()


func _on_dialogue_ended(scene_id: String) -> void:
	# 碑文阅读：首次解锁感应时给予提示
	if scene_id in ["temple_stone_1", "temple_stone_2",
					"temple_stone_3", "temple_stone_4"]:
		var total_read := 0
		for state in GameData.stones_read:
			if state:
				total_read += 1
		if total_read == 1 and not GameData.triggered_events.has("sense_unlocked_hint_shown"):
			GameData.triggered_events.append("sense_unlocked_hint_shown")
			await get_tree().create_timer(0.5).timeout
			if not is_inside_tree():
				return
			DialogueManager.start_scene("sense_unlocked_hint")

	if scene_id == "sense_unlocked_hint":
		UIManager.refresh_skill_panel()

	match scene_id:
		"stone_toad_approach":
			## 战前旁白结束，确认石皮蟾仍存活才触发战斗
			if _toad != null:
				_trigger_toad_battle("toad")
		"after_battle", "after_battle_coin":
			## BOSS战胜利后推进phase（从3到4）
			if GameData.story_phase == 3:
				GameData.advance_phase()


func _on_stone_entered(body: Node2D, index: int) -> void:
	if body is CharacterBody2D:
		_nearby_stone = index
		if not _stones_read[index]:
			_interact_hint.text = "按 E 阅读碑文"
			_interact_hint.show()


func _on_stone_exited(body: Node2D, index: int) -> void:
	if body is CharacterBody2D and _nearby_stone == index:
		_nearby_stone = -1
		_interact_hint.hide()


func _on_monolith_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_near_monolith = true
		if not _monolith_activated:
			_interact_hint.text = "按 E 触碰石碑"
			_interact_hint.show()


func _on_monolith_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_near_monolith = false
		_interact_hint.hide()


func _on_gufei_entered(body: Node2D) -> void:
	if body is CharacterBody2D and _gufei_visible:
		_near_gufei = true
		_interact_hint.text = "按 E 交谈"
		_interact_hint.show()


func _on_gufei_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_near_gufei = false
		_interact_hint.hide()


func _on_exit_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = true
		_exit_hint.show()


func _on_exit_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = false
		_exit_hint.hide()
