## TeaScene.gd
## 云烟茶馆室内场景（第三阶段将完善内部布局和掌柜NPC）
## 视口：1280×720，Camera2D zoom=1.0
extends Node2D

@onready var _exit_area: Area2D = $ExitArea


func _ready() -> void:
	_setup_camera()
	_exit_area.body_entered.connect(_on_exit_area_body_entered)


## 室内摄像机：zoom=1.0，覆盖 Player.tscn 的 TownScene 专用设置
func _setup_camera() -> void:
	var cam: Camera2D = $Player/Camera2D
	cam.zoom = Vector2(1.0, 1.0)
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = 1280
	cam.limit_bottom = 720
	cam.position_smoothing_enabled = false


## 玩家走入出口区域，设置来源后切换回碎玉镇
func _on_exit_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GameData.last_scene = "tea"
		SceneTransition.change_scene("res://scenes/TownScene.tscn")
