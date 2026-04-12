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

## 剑穗视觉成长（动态创建，根据 stones_read 数量改变颜色和光晕）
var _sword_tassel_visual: Node2D = null
var _sword_tassel_glow: Polygon2D = null
var _sword_tassel_core: Polygon2D = null
var _last_glow_level: int = -1   ## 上次刷新时的 stones_read 计数，避免每帧重建tween
var _sword_tassel_tween: Tween = null  ## 缓存tween，防止堆叠


func _ready() -> void:
	interact_label.hide()
	interact_area.area_entered.connect(_on_npc_enter)
	interact_area.area_exited.connect(_on_npc_exit)
	_setup_sword_tassel_visual()


func _exit_tree() -> void:
	if _sword_tassel_tween and _sword_tassel_tween.is_valid():
		_sword_tassel_tween.kill()
	_sword_tassel_tween = null


func _physics_process(_delta: float) -> void:
	# 剑穗视觉成长：每物理帧检查 stones_read 数量是否变化（开销忽略不计）
	_refresh_sword_tassel_glow()

	# 对话进行中或场景切换黑屏期间禁止移动（修复3：防止幽灵移动）
	if DialogueManager.is_active or SceneTransition.is_transitioning:
		# DEBUG: 每秒打印一次卡住原因（避免刷屏）
		if Engine.get_physics_frames() % 60 == 0:
			print("Player BLOCKED — is_active=%s  is_transitioning=%s" % [
				DialogueManager.is_active, SceneTransition.is_transitioning])
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


# ── 剑穗视觉成长 ──────────────────────────────────────────────

## 创建剑穗视觉节点（角色右下角，纯几何形状无需美术）
func _setup_sword_tassel_visual() -> void:
	_sword_tassel_visual = Node2D.new()
	_sword_tassel_visual.name = "SwordTasselVisual"
	## 角色 Body polygon 是 -12,-20 到 12,14，剑穗放在右侧外缘以免被覆盖
	_sword_tassel_visual.position = Vector2(16, 8)
	_sword_tassel_visual.z_index = 2
	add_child(_sword_tassel_visual)

	## 外层光晕（菱形顶点，默认完全透明）
	_sword_tassel_glow = Polygon2D.new()
	_sword_tassel_glow.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)
	])
	_sword_tassel_glow.color = Color(0.95, 0.85, 0.55, 0.0)
	_sword_tassel_visual.add_child(_sword_tassel_glow)

	## 内核（小矩形穗子主体，初始暗色）
	_sword_tassel_core = Polygon2D.new()
	_sword_tassel_core.polygon = PackedVector2Array([
		Vector2(-2, -4), Vector2(2, -4), Vector2(2, 4), Vector2(-2, 4)
	])
	_sword_tassel_core.color = Color(0.45, 0.30, 0.20, 1.0)
	_sword_tassel_visual.add_child(_sword_tassel_core)

	## 默认隐藏，等玩家拿到旧剑穗后才显示
	_sword_tassel_visual.visible = false


## 每帧检查 stones_read 数量是否变化，变化时更新视觉
func _refresh_sword_tassel_glow() -> void:
	if _sword_tassel_visual == null:
		return
	## 没拿到剑穗前不显示
	var has_tassel: bool = "sword_tassel" in GameData.unlocked_old_items
	if not has_tassel:
		_sword_tassel_visual.visible = false
		return
	_sword_tassel_visual.visible = true

	var glow_level: int = 0
	for v in GameData.stones_read:
		if v:
			glow_level += 1

	if glow_level == _last_glow_level:
		return
	var is_first_set := (_last_glow_level == -1)
	_last_glow_level = glow_level

	## 根据感应等级（0-4）调整内核颜色和外光晕透明度
	var core_colors := [
		Color(0.45, 0.30, 0.20, 1.0),  ## 0：暗棕（普通）
		Color(0.65, 0.45, 0.25, 1.0),  ## 1：泛红
		Color(0.85, 0.65, 0.35, 1.0),  ## 2：泛金
		Color(0.95, 0.80, 0.45, 1.0),  ## 3：明亮
		Color(1.00, 0.92, 0.65, 1.0),  ## 4：金白
	]
	var glow_alphas := [0.0, 0.15, 0.30, 0.50, 0.75]
	var idx: int = clamp(glow_level, 0, 4)
	var target_core: Color = core_colors[idx]
	var target_glow: Color = Color(0.95, 0.85, 0.55, glow_alphas[idx])

	## 场景切换后第一次设置：直接赋值，避免从默认值跳变
	if is_first_set:
		_sword_tassel_core.color = target_core
		_sword_tassel_glow.color = target_glow
		return

	## 后续变化用 Tween 缓动（kill 旧 tween 防止堆叠）
	if _sword_tassel_tween and _sword_tassel_tween.is_valid():
		_sword_tassel_tween.kill()
	_sword_tassel_tween = create_tween().set_parallel(true)
	_sword_tassel_tween.tween_property(
		_sword_tassel_core, "color", target_core, 0.6
	).set_ease(Tween.EASE_OUT)
	_sword_tassel_tween.tween_property(
		_sword_tassel_glow, "color", target_glow, 0.6
	).set_ease(Tween.EASE_OUT)
