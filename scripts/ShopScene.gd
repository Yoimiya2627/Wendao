## ShopScene.gd
## 苏家杂货铺室内场景控制器
## 视口：1280×720，Camera2D zoom=2.0（室内全景）
## 处理三种状态：
##   phase 0  = morning清晨开场
##   phase 3  = 测灵失败回家
##   phase 5  = 战斗后回家看信（路径B）
extends Node2D

# ── 对话场景ID ──────────────────────────────────────
const _DIALOGUE_BROKEN_BOWL    := "bowl_interact"
const _DIALOGUE_FATHERS_LETTER := "letter"
const _DIALOGUE_RETURN_HOME    := "return_home"
const _DIALOGUE_NIANNIAN_COMFORT := "niannian_comfort"
const _DIALOGUE_DAYU_COMFORT     := "dayu_comfort"

# ── 节点引用 ──────────────────────────────────────────
@onready var _exit_area          : Area2D          = $ExitArea
@onready var _exit_hint          : Label           = $Player/ExitHintLabel
@onready var _interact_hint      : Label           = $Player/InteractHintLabel
@onready var _spawn_point        : Node2D          = $SpawnPoint
@onready var _player             : CharacterBody2D = $Player
@onready var _broken_bowl        : Node2D          = $Interactables/BrokenBowl
@onready var _fathers_letter     : Node2D          = $Interactables/FathersLetter
@onready var _broken_bowl_area   : Area2D          = $Interactables/BrokenBowl/Area2D
@onready var _fathers_letter_area: Area2D          = $Interactables/FathersLetter/Area2D
@onready var _npc_niannian       : Node2D          = $NPCLayer/NPC_Niannian
@onready var _npc_dayu           : Node2D          = $NPCLayer/NPC_Dayu
@onready var _npc_suming         : Node2D          = $NPCLayer/NPC_SuMing

# ── 回家状态下猫咪的门口坐标 ──────────────────────────
## 年年门口内侧位置（靠近出口，静静等待）
const NIANNIAN_RETURN_POS : Vector2 = Vector2(80, 240)
## 大鱼门口附近位置（活泼，在旁边晃悠）
const DAYU_RETURN_POS     : Vector2 = Vector2(240, 285)

# ── 运行时状态 ────────────────────────────────────────
var _nearby_interactables : Array[String] = []
var _current_interactable : String = ""
var _player_in_exit       : bool   = false

## 回家流程中猫咪是否已经可以互动
var _cats_interactable    : bool   = false
## 年年是否已经安慰过
var _niannian_comforted   : bool   = false
## 大鱼是否已经安慰过
var _dayu_comforted       : bool   = false
## 旧剑穗旁白是否已触发
var _sword_tassel_triggered : bool = false
## 大鱼靠近旁白是否已触发
var _dayu_approach_triggered : bool = false
## 夜晚出门是否已触发（防止重复）
var _night_leave_triggered : bool = false


func _ready() -> void:
	_exit_hint.hide()
	_interact_hint.hide()
	## 优先恢复手动存档时的玩家坐标，否则用默认 SpawnPoint
	if GameData.saved_player_position != Vector2.ZERO:
		_player.global_position = GameData.saved_player_position
		GameData.saved_player_position = Vector2.ZERO
	else:
		_player.global_position = _spawn_point.global_position
	_setup_camera()

	## 根据story_phase决定走哪条流程
	match GameData.story_phase:
		0:
			_start_morning_flow()
			AudioManager.play_bgm("shop_morning")
		3:
			_start_return_home_flow()
			AudioManager.play_bgm("shop_return")
		4:
			## phase 4（BOSS战后、章末前）：正常进入但不触发任何流程
			## 玩家理论上不会在此phase进入ShopScene，防御性处理
			UIManager.show_main_hud()
			AudioManager.play_bgm("shop_return")
		5:
			_start_letter_flow()
			AudioManager.play_bgm("shop_return")
		_:
			## 防御性兜底：非预期phase不触发任何流程，只显示HUD+BGM
			UIManager.show_main_hud()
			AudioManager.play_bgm("shop_morning")

	## 连接出口区域信号
	_exit_area.body_entered.connect(_on_exit_body_entered)
	_exit_area.body_exited.connect(_on_exit_body_exited)

	## 连接破碗感应信号
	_broken_bowl_area.body_entered.connect(
		_on_interactable_entered.bind(_DIALOGUE_BROKEN_BOWL))
	_broken_bowl_area.body_exited.connect(
		_on_interactable_exited.bind(_DIALOGUE_BROKEN_BOWL))

	## 连接爹的信感应信号
	_fathers_letter_area.body_entered.connect(
		_on_interactable_entered.bind(_DIALOGUE_FATHERS_LETTER))
	_fathers_letter_area.body_exited.connect(
		_on_interactable_exited.bind(_DIALOGUE_FATHERS_LETTER))

	## 订阅对话事件和结束信号
	DialogueManager.event_triggered.connect(_on_event_triggered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	## 读档进ShopScene时，若morning已结束则显示UI
	if GameData.story_phase >= 1:
		UIManager.show_main_hud()
		UIManager.refresh_all_data()

	_spawn_ambient_particles()
	_apply_floor_texture()


## 给杂货铺地板挂水墨木纹 shader（暖棕基底 + 横向木纹）
func _apply_floor_texture() -> void:
	var floor_rect := get_node_or_null("Background/Floor")
	if floor_rect == null: return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground_texture.gdshader")
	mat.set_shader_parameter("base_color", floor_rect.color)
	mat.set_shader_parameter("grain", 0.04)
	mat.set_shader_parameter("blot", 0.08)
	mat.set_shader_parameter("blot_scale", 4.0)
	mat.set_shader_parameter("wood_grain", 0.14)
	mat.set_shader_parameter("wood_freq", 20.0)
	floor_rect.material = mat


func _spawn_ambient_particles() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var p := CPUParticles2D.new()
	p.amount               = 25
	p.lifetime             = 5.0
	p.explosiveness        = 0.0
	p.randomness           = 1.0
	p.direction            = Vector2(0.3, -1.0)
	p.spread               = 45.0
	p.gravity              = Vector2(5.0, -15.0)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 15.0
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 3.0
	p.color                = Color(0.95, 0.85, 0.60, 0.20)
	p.emission_shape       = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640.0, 360.0)
	p.position             = Vector2(640.0, 360.0)
	layer.add_child(p)


func _exit_tree() -> void:
	if DialogueManager.event_triggered.is_connected(_on_event_triggered):
		DialogueManager.event_triggered.disconnect(_on_event_triggered)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)


# ══════════════════════════════════════════════════════
# 三种流程初始化
# ══════════════════════════════════════════════════════

## 清晨流程（phase 0）：触发morning对话
func _start_morning_flow() -> void:
	## 隐藏破碗（如果已交互过）
	if GameData.bowl_interacted:
		## 针线篓视觉保留，只关闭感应区
		_broken_bowl_area.set_deferred("monitoring", false)
	## 隐藏爹的信（清晨不应该有信）
	_fathers_letter.hide()
	_fathers_letter_area.set_deferred("monitoring", false)
	## 旧剑穗：已改为大鱼morning互动结束时自动给予
	## morning阶段大鱼使用专属对话（叼来旧剑穗）
	_npc_dayu.dialogue_scene_id = "dayu_morning"
	## 触发morning对话
	if not GameData.morning_triggered:
		GameData.morning_triggered = true
		await get_tree().process_frame
		if not is_inside_tree():
			return
		DialogueManager.start_scene("morning")


## 回家流程（phase 3）：测灵失败当晚回家
func _start_return_home_flow() -> void:
	## 隐藏爹的信（还没到看信的时候）
	_fathers_letter.hide()
	_fathers_letter_area.set_deferred("monitoring", false)
	## 针线篓视觉保留，只关闭感应区防止重复触发
	## 设计要求：针线篓始终可见，phase==3时旁白也在说"还在原处"
	if GameData.bowl_interacted:
		_broken_bowl_area.set_deferred("monitoring", false)
	## phase==3时爹已离家，隐藏爹的NPC
	## 苏明已离家，完整移除
	_npc_suming.disappear()
	## 关闭Player的NPC交互，防止E键被拦截
	_player.npc_interaction_enabled = false
	_npc_niannian.dialogue_scene_id = ""
	_npc_dayu.dialogue_scene_id = ""
	## 把猫咪移到门口等待位置
	_npc_niannian.position = NIANNIAN_RETURN_POS
	_npc_dayu.position     = DAYU_RETURN_POS

	## 关键道具兜底：无论玩家是否在morning拿了旧剑穗，此处强制补发
	if "sword_tassel" not in GameData.unlocked_old_items:
		UIManager.add_item("sword_tassel")

	## 从持久化状态恢复猫咪交互进度（防止切场景后状态丢失）
	_niannian_comforted      = GameData.triggered_events.has("niannian_comforted")
	_dayu_comforted          = GameData.triggered_events.has("dayu_comforted")
	_dayu_approach_triggered = GameData.triggered_events.has("dayu_approach_triggered")
	_sword_tassel_triggered  = GameData.triggered_events.has("sword_tassel_triggered")

	## 若回家对话已结束，直接激活猫咪互动，跳过重播
	if GameData.triggered_events.has("return_home_done"):
		_cats_interactable = true
		return

	## 等待一帧确保节点就位
	await get_tree().process_frame
	if not is_inside_tree():
		return
	## 自动播放return_home对话（爹不在，饭盛好了）
	DialogueManager.start_scene(_DIALOGUE_RETURN_HOME)


## 看信流程（phase 5，路径B）：战斗后回家看爹的信
func _start_letter_flow() -> void:
	## phase 5 不应再允许猫咪NPC交互，避免空对话场景ID
	_player.npc_interaction_enabled = false
	_npc_niannian.dialogue_scene_id = ""
	_npc_dayu.dialogue_scene_id = ""
	## 隐藏破碗
	_broken_bowl.hide()
	_broken_bowl_area.set_deferred("monitoring", false)
	_npc_suming.disappear()
	_npc_niannian.position = NIANNIAN_RETURN_POS
	_npc_dayu.position = DAYU_RETURN_POS
	## 显示爹的信
	_fathers_letter.show()
	## 等待一帧
	await get_tree().process_frame
	if not is_inside_tree():
		return
	## 自动播放letter对话
	DialogueManager.start_scene(_DIALOGUE_FATHERS_LETTER)


# ══════════════════════════════════════════════════════
# 摄像机设置
# ══════════════════════════════════════════════════════

func _setup_camera() -> void:
	var cam: Camera2D = $Player/Camera2D
	cam.zoom = Vector2(2.0, 2.0)
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = 480
	cam.limit_bottom = 320
	cam.position_smoothing_enabled = false
	cam.reset_smoothing()


# ══════════════════════════════════════════════════════
# 帧更新
# ══════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	## 回家流程：猫咪可互动后，检测玩家靠近大鱼自动触发旁白
	if GameData.story_phase == 3 \
			and _cats_interactable \
			and not _dayu_approach_triggered \
			and not DialogueManager.is_active:
		if _is_near(_npc_dayu.global_position):
			_dayu_approach_triggered = true
			if not GameData.triggered_events.has("dayu_approach_triggered"):
				GameData.triggered_events.append("dayu_approach_triggered")
			DialogueManager.start_scene("dayu_approach")


# ══════════════════════════════════════════════════════
# 输入处理
# ══════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not (event.keycode == KEY_E and event.pressed and not event.echo):
		return
	if DialogueManager.is_active:
		return

	## 回家状态下：按E和猫咪互动
	if GameData.story_phase == 3 and _cats_interactable:
		if _is_near(_npc_niannian.global_position):
			if not _niannian_comforted:
				_niannian_comforted = true
				DialogueManager.start_scene(_DIALOGUE_NIANNIAN_COMFORT)
			else:
				DialogueManager.start_scene("niannian_after")
			get_viewport().set_input_as_handled()
			return
		if _dayu_approach_triggered and _is_near(_npc_dayu.global_position):
			if not _dayu_comforted:
				_dayu_comforted = true
				DialogueManager.start_scene(_DIALOGUE_DAYU_COMFORT)
			else:
				DialogueManager.start_scene("dayu_after")
			get_viewport().set_input_as_handled()
			return

	## 道具交互优先
	if not _current_interactable.is_empty():
		if _current_interactable == _DIALOGUE_BROKEN_BOWL:
			if GameData.bowl_interacted:
				return
			GameData.bowl_interacted = true
			## 针线篓视觉保留，只关闭感应区防止重复触发
			_broken_bowl_area.set_deferred("monitoring", false)
			## phase==3时触发回家版旁白，不触发有爹说话的原版
			if GameData.story_phase == 3:
				DialogueManager.start_scene("bowl_interact_return")
				get_viewport().set_input_as_handled()
				return
		DialogueManager.start_scene(_current_interactable)
		get_viewport().set_input_as_handled()
		return

	## 出口离开
	if _player_in_exit:
		if GameData.story_phase == 3:
			## 回家状态下出门：触发夜晚渐变后切回TownScene
			_trigger_night_and_leave()
		else:
			## 正常离开，保存存档
			GameData.last_scene = "shop"
			GameData.saved_player_position = Vector2.ZERO
			GameData.save_to_file("auto")
			SceneTransition.change_scene("res://scenes/TownScene.tscn")
		get_viewport().set_input_as_handled()


# ══════════════════════════════════════════════════════
# 对话事件和结束回调
# ══════════════════════════════════════════════════════

func _on_event_triggered(event_name: String) -> void:
	match event_name:
		"morning_done":
			GameData.advance_phase()
			DialogueManager.finish_event()
			## morning结束，玩家可出门，此时显示游戏UI
			UIManager.show_main_hud()
			UIManager.add_item("sword_tassel")
		"night_begin":
			## night_begin事件已从JSON移除
			## 此分支保留作兜底，直接放行
			DialogueManager.finish_event()
		"start_chapter_end_b":
			## letter场景结束，触发章末路径B
			DialogueManager.finish_event()
			GameData.chapter_end_path = "b"
			SceneTransition.change_scene(
				"res://scenes/ChapterEndScene.tscn")
		_:
			DialogueManager.finish_event()


func _on_dialogue_ended(scene_id: String) -> void:
	match scene_id:
		"morning":
			## morning结束，phase已由morning_done事件推进
			pass

		"dayu_morning":
			## 剑穗已由morning主线对话自动给予，此处仅作兜底去重
			UIManager.add_item("sword_tassel")

		"return_home":
			## 回家对话结束
			## 激活猫咪互动，玩家可以按E和年年大鱼互动
			## 夜晚渐变由玩家走到出口按E触发
			_cats_interactable = true
			## 持久化：防止切场景后重播
			if not GameData.triggered_events.has("return_home_done"):
				GameData.triggered_events.append("return_home_done")
			## 注意：NPC交互暂时保持关闭
			## 等两只猫都安慰完，_check_sword_tassel()里重新开启

		"niannian_comfort":
			## 年年安慰结束，持久化后检查大鱼是否也安慰过
			_niannian_comforted = true
			if not GameData.triggered_events.has("niannian_comforted"):
				GameData.triggered_events.append("niannian_comforted")
			_check_sword_tassel()

		"dayu_comfort":
			## 大鱼安慰结束，持久化后检查是否触发剑穗旁白
			_dayu_comforted = true
			if not GameData.triggered_events.has("dayu_comforted"):
				GameData.triggered_events.append("dayu_comforted")
			_check_sword_tassel()

		"letter":
			## 看完爹的信，start_chapter_end_b事件
			## 已在对话内处理，此处不需要额外操作
			pass


## 检查是否触发旧剑穗烫手旁白
## 两只猫都安慰过之后才触发
func _check_sword_tassel() -> void:
	if _sword_tassel_triggered:
		return
	if not (_niannian_comforted and _dayu_comforted):
		return
	_sword_tassel_triggered = true
	if not GameData.triggered_events.has("sword_tassel_triggered"):
		GameData.triggered_events.append("sword_tassel_triggered")
	## 重新启用Player的NPC交互
	_player.npc_interaction_enabled = true
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	## 双重安全锁：
	## 1. 若玩家在等待期间触发了离开场景，不再播放旁白
	## 2. 若玩家触发了其他对话（针线篓等），不强行覆盖
	if _night_leave_triggered or DialogueManager.is_active:
		return
	DialogueManager.start_scene("sword_tassel_hint")


# ══════════════════════════════════════════════════════
# 工具函数
# ══════════════════════════════════════════════════════

## 判断玩家是否靠近指定位置（距离≤48px）
func _is_near(target_pos: Vector2) -> bool:
	return _player.global_position.distance_to(target_pos) <= 48.0


# ── 道具感应回调 ──────────────────────────────────────

func _on_interactable_entered(body: Node2D, dialogue_id: String) -> void:
	if not body is CharacterBody2D:
		return
	_nearby_interactables.append(dialogue_id)
	_current_interactable = dialogue_id
	_interact_hint.show()
	_exit_hint.hide()


func _on_interactable_exited(body: Node2D, dialogue_id: String) -> void:
	if not body is CharacterBody2D:
		return
	_nearby_interactables.erase(dialogue_id)
	if _nearby_interactables.is_empty():
		_current_interactable = ""
		_interact_hint.hide()
		if _player_in_exit:
			_exit_hint.show()
	else:
		_current_interactable = _nearby_interactables.back()


# ── 出口检测回调 ──────────────────────────────────────

func _on_exit_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = true
		if _current_interactable.is_empty():
			_exit_hint.show()


func _on_exit_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_exit = false
		_exit_hint.hide()


## 回家状态出门：1.5秒黑屏渐变后切回TownScene夜晚状态
func _trigger_night_and_leave() -> void:
	## 防止重复触发
	if _night_leave_triggered:
		return
	_night_leave_triggered = true
	## 创建黑屏遮罩
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	## 1.5秒渐变到全黑
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	await tween.finished
	## 画面已全黑，直接把SceneTransition遮罩设为不透明，跳过重复淡出
	SceneTransition.set_overlay_opaque()
	## 标记夜晚已触发
	GameData.night_triggered = true
	GameData.last_scene = "shop"
	## 夜晚出门氛围旁白（黑屏上播放，一次性）
	if not GameData.triggered_events.has("night_exit"):
		GameData.triggered_events.append("night_exit")
		DialogueManager.start_scene("night_exit")
		await DialogueManager.dialogue_ended
		if not is_inside_tree():
			return
	SceneTransition.change_scene("res://scenes/TownScene.tscn")
