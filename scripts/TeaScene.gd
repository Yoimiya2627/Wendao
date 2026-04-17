## TeaScene.gd
## 悠然茶馆室内场景控制器
## 视口：1280×720，Camera2D zoom=2.0
## NPC phase控制：
##   phase 1：掌柜(before)、说书人、两个弟子、老江湖(old_wanderer)
##   phase 3+：掌柜(after)、老江湖(old_wanderer_return)，其余消失
##             老江湖会在玩家进门后主动冒出气泡
extends Node2D

@onready var _exit_area      : Area2D          = $ExitArea
@onready var _exit_hint      : Label           = $UILayer/ExitHintLabel
@onready var _spawn_point    : Node2D          = $SpawnPoint
@onready var _player         : CharacterBody2D = $Player

## NPC节点引用
@onready var _npc_keeper     : Node2D = $NPCLayer/NPC_TeahouseBoss
@onready var _npc_storyteller: Node2D = $NPCLayer/NPC_Storyteller
@onready var _npc_disciple_a : Node2D = $NPCLayer/NPC_DiscipleA
@onready var _npc_disciple_b : Node2D = $NPCLayer/NPC_DiscipleB
@onready var _npc_wanderer   : Node2D = $NPCLayer/NPC_OldWanderer

var _player_in_exit: bool = false

## 老江湖气泡Label（phase3动态创建）
var _wanderer_bubble: Label = null
## 气泡是否已显示过（只显示一次）
var _bubble_shown: bool = false


func _ready() -> void:
	_exit_hint.hide()
	## 优先恢复手动存档时的玩家坐标，否则用默认 SpawnPoint
	if GameData.saved_player_position != Vector2.ZERO:
		_player.global_position = GameData.saved_player_position
		GameData.saved_player_position = Vector2.ZERO
	else:
		_player.global_position = _spawn_point.global_position
	_setup_camera()
	_exit_area.body_entered.connect(_on_exit_body_entered)
	_exit_area.body_exited.connect(_on_exit_body_exited)
	DialogueManager.event_triggered.connect(_on_event_triggered)
	_setup_npcs_by_phase()
	_apply_floor_texture()
	## BGM 由 SceneTransition._auto_play_bgm() 统一触发（SCENE_BGM_MAP["TeaScene"]）


## 给茶馆地板挂水墨木纹 shader（深棕木地 + 更细密的横纹）
func _apply_floor_texture() -> void:
	var floor_rect := get_node_or_null("Background/Floor")
	if floor_rect == null: return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground_texture.gdshader")
	mat.set_shader_parameter("base_color", floor_rect.color)
	mat.set_shader_parameter("grain", 0.022)
	mat.set_shader_parameter("blot", 0.08)
	mat.set_shader_parameter("blot_scale", 3.5)
	mat.set_shader_parameter("wood_grain", 0.18)
	mat.set_shader_parameter("wood_freq", 28.0)
	floor_rect.material = mat


func _exit_tree() -> void:
	if DialogueManager.event_triggered.is_connected(_on_event_triggered):
		DialogueManager.event_triggered.disconnect(_on_event_triggered)


func _setup_camera() -> void:
	var cam: Camera2D = $Player/Camera2D
	cam.zoom = Vector2(2.0, 2.0)
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = 480
	cam.limit_bottom = 320
	cam.position_smoothing_enabled = false
	cam.reset_smoothing()


## 根据story_phase控制NPC显示和对话内容
func _setup_npcs_by_phase() -> void:
	var phase := GameData.story_phase

	if phase >= 3:
		## 测灵失败后：说书人离开，太平宗弟子留在茶馆歇脚
		_npc_storyteller.disappear()
		## 弟子甲乙切换为回程怜悯对话（保留剧情冲击力）
		_npc_disciple_a.dialogue_scene_id = "disciple_a"
		_npc_disciple_b.dialogue_scene_id = "disciple_b"
		## 老江湖换为回程对话
		_npc_wanderer.dialogue_scene_id = "old_wanderer_return"
		## 进门后短暂延迟，老江湖冒出气泡主动打破沉默
		_show_wanderer_bubble_delayed()
	else:
		## 正常探索阶段（phase 1）：显式赋值去程对话，防止状态残留
		_npc_disciple_a.dialogue_scene_id = "disciple_a_before"
		_npc_disciple_b.dialogue_scene_id = "disciple_b_before"
		## 老江湖去程对话：测灵前可选互动
		_npc_wanderer.dialogue_scene_id = "old_wanderer"


## 延迟0.8秒后显示老江湖气泡，3秒后自动消失
func _show_wanderer_bubble_delayed() -> void:
	await get_tree().create_timer(0.8).timeout

	## 安全防护：玩家在0.8秒内切出场景时，场景节点已离树，立刻终止防止崩溃
	if not is_inside_tree():
		return

	## 对话进行中不显示，防止冲突
	if DialogueManager.is_active or _bubble_shown:
		return
	if GameData.triggered_events.has("wanderer_bubble_shown"):
		return

	_bubble_shown = true
	GameData.triggered_events.append("wanderer_bubble_shown")
	_wanderer_bubble = Label.new()
	_wanderer_bubble.text = "「丫头，过来坐坐吧。」"
	_wanderer_bubble.add_theme_font_size_override("font_size", 13)
	_wanderer_bubble.add_theme_color_override(
		"font_color", Color(0.75, 0.68, 0.55, 1.0))

	## 使用global_position防止NPCLayer坐标偏移导致气泡错位
	add_child(_wanderer_bubble)
	_wanderer_bubble.global_position = \
		_npc_wanderer.global_position + Vector2(-60, -40)

	## 3秒后淡出消失
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(_wanderer_bubble):
		var tween := create_tween()
		tween.tween_property(
			_wanderer_bubble,
			"modulate:a",
			0.0,
			0.8
		).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		if is_instance_valid(_wanderer_bubble):
			_wanderer_bubble.queue_free()
			_wanderer_bubble = null


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not (event.keycode == KEY_E and event.pressed and not event.echo):
		return
	if DialogueManager.is_active:
		return
	if _player_in_exit:
		GameData.last_scene = "tea"
		GameData.saved_player_position = Vector2.ZERO
		GameData.save_to_file("auto")
		SceneTransition.change_scene("res://scenes/TownScene.tscn")
		get_viewport().set_input_as_handled()


func _on_event_triggered(_event_name: String) -> void:
	DialogueManager.finish_event()


func _on_exit_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = true
		_exit_hint.show()


func _on_exit_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = false
		_exit_hint.hide()
