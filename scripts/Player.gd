## Player.gd
## 玩家控制：8方向移动 + NPC 交互检测
extends CharacterBody2D

const SPEED := 150.0

## 当前进入互动范围的 NPC 列表（支持多个同时在范围内时取最后进入的）
var _nearby_npcs: Array = []

## 是否允许NPC交互（ShopScene猫咪流程时关闭）
var npc_interaction_enabled: bool = true

@onready var interact_label: Label  = $InteractLabel
@onready var interact_area : Area2D = $InteractArea


func _ready() -> void:
	interact_label.hide()
	interact_area.area_entered.connect(_on_npc_enter)
	interact_area.area_exited.connect(_on_npc_exit)


func _physics_process(_delta: float) -> void:
	# 对话进行中或场景切换黑屏期间禁止移动（修复3：防止幽灵移动）
	if DialogueManager.is_active or SceneTransition._is_transitioning:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 修复4：get_vector 原生处理死区与斜向归一化
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	# E 键触发交互（not echo 防止长按重复触发）
	if event is InputEventKey \
			and event.keycode == KEY_E \
			and event.pressed \
			and not event.echo:
		if npc_interaction_enabled:
			var npc := _get_nearest_npc()
			if npc:
				npc.interact()
				# 修复1：截断事件，防止冒泡到 TownScene 触发场景切换
				get_viewport().set_input_as_handled()


func _get_nearest_npc() -> Node:
	# 修复2：过滤已被引擎释放的悬空节点（剧情杀 / 动态刷新的 NPC）
	_nearby_npcs = _nearby_npcs.filter(func(n): return is_instance_valid(n))
	if _nearby_npcs.is_empty():
		return null
	var nearest: Node = _nearby_npcs[0]
	var min_dist: float = global_position.distance_squared_to(nearest.global_position)
	for npc in _nearby_npcs.slice(1):
		var d: float = global_position.distance_squared_to(npc.global_position)
		if d < min_dist:
			min_dist = d
			nearest = npc
	return nearest


# ── 互动范围检测 ─────────────────────────────────────────────

## NPC 的 InteractArea 进入玩家的 InteractArea 时触发
func _on_npc_enter(area: Area2D) -> void:
	var npc: Node = area.get_parent()
	# 鸭子类型：检查父节点是否有 interact 方法（即是否是 NPC）
	if not npc.has_method("interact"):
		return
	_nearby_npcs.append(npc)
	npc.show_name_label()
	interact_label.show()


## NPC 的 InteractArea 离开时触发
func _on_npc_exit(area: Area2D) -> void:
	var npc: Node = area.get_parent()
	if npc not in _nearby_npcs:
		return
	npc.hide_name_label()
	_nearby_npcs.erase(npc)
	# 若范围内还有其他 NPC，保持提示显示
	if _nearby_npcs.is_empty():
		interact_label.hide()
