## ShopScene.gd
## 苏家杂货铺室内场景控制器
## 视口：1280×720，Camera2D zoom=2.0（室内全景，无需滚动）
## 退出时设置 GameData.last_scene，使用 SceneTransition 返回碎玉镇
extends Node2D

@onready var _exit_area  : Area2D = $ExitArea
@onready var _exit_hint  : Label  = $UILayer/ExitHintLabel
@onready var _spawn_point: Node2D = $SpawnPoint
@onready var _player     : CharacterBody2D = $Player

## 玩家当前是否在出口触发区内
var _player_in_exit: bool = false


func _ready() -> void:
	_exit_hint.hide()
	# 从 SpawnPoint 节点读取出生坐标，进入场景后玩家站在出口附近
	_player.global_position = _spawn_point.global_position
	# 调整摄像机为室内模式：zoom=2.0，锁定在场景范围内，无平滑滚动
	_setup_camera()

	# 用 body_entered/exited 跟踪玩家位置，按 E 才切换场景
	_exit_area.body_entered.connect(_on_exit_area_body_entered)
	_exit_area.body_exited.connect(_on_exit_area_body_exited)

	# 场景启动时触发清晨开场对话（仅 phase 0 时）
	if not GameData.morning_triggered:
		# 提前标记，防止同帧重复触发
		GameData.morning_triggered = true
		# 等待一帧，确保 DialogueBox 等子节点完成 _ready
		await get_tree().process_frame
		DialogueManager.start_scene("morning")


## 设置室内摄像机参数，覆盖 Player.tscn 里的 TownScene 专用设置
func _setup_camera() -> void:
	var cam: Camera2D = $Player/Camera2D
	# zoom=2.0：可视区域 640×360，480×320 的小房间基本填满屏幕
	cam.zoom = Vector2(2.0, 2.0)
	# 场景尺寸 480×320，相机锁定在此范围内不越界
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = 480
	cam.limit_bottom = 320
	# 室内小场景无需平滑滚动
	cam.position_smoothing_enabled = false
	# 强制摄像机立即跟上玩家当前位置，防止进场时出现漂移
	cam.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	# 不在出口区域或对话进行中时忽略
	if not _player_in_exit or DialogueManager.is_active:
		return
	# E 键触发离开（not echo 防止长按重复）
	if event is InputEventKey \
			and event.keycode == KEY_E \
			and event.pressed \
			and not event.echo:
		# 记录来源场景，TownScene._ready() 读取后放置到正确出生点
		GameData.last_scene = "shop"
		SceneTransition.change_scene("res://scenes/TownScene.tscn")


## 玩家进入出口区域：显示"按 E 离开"提示
func _on_exit_area_body_entered(body: Node2D) -> void:
	# CharacterBody2D 即玩家；NPC 用 StaticBody2D，不会误触发
	if body is CharacterBody2D:
		_player_in_exit = true
		_exit_hint.show()


## 玩家离开出口区域：隐藏提示
func _on_exit_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = false
		_exit_hint.hide()
