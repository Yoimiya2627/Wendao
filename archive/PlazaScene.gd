## PlazaScene.gd
## 灵根测试广场场景控制器
extends Node2D

@onready var _exit_area: Area2D = $ExitArea


func _ready() -> void:
	# 连接左侧出口信号
	_exit_area.body_entered.connect(_on_exit_area_body_entered)
	# 连接对话结束信号，用于推进 test → temple 剧情阶段
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	# phase 1 时进入广场自动触发灵根测试
	if GameData.story_phase == 1:
		# 提前置 phase 2，防止 Player.gd 里 PLAZA_RECT 检测在同帧重复触发
		GameData.advance_phase()
		# 等待一帧确保 DialogueBox 等子节点完成 _ready
		await get_tree().process_frame
		DialogueManager.start_scene("test")


## 测试场景结束后推进剧情：phase 2 → 3，稍停后触发废庙场景
## （TownScene.gd 中有相同逻辑，此处保证在广场场景内也能正常推进）
func _on_dialogue_ended(scene_id: String) -> void:
	if scene_id == "test" and GameData.story_phase == 2:
		GameData.advance_phase()
		await get_tree().create_timer(0.8).timeout
		DialogueManager.start_scene("temple")


## 玩家走入左侧出口区域，切换回城镇场景
func _on_exit_area_body_entered(body: Node2D) -> void:
	# 仅响应玩家（CharacterBody2D），排除 NPC 静态体
	if body is CharacterBody2D:
		GameData.last_scene = ""
		SceneTransition.change_scene("res://scenes/TownScene.tscn")
