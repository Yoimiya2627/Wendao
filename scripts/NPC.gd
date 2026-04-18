## NPC.gd
## NPC 基础脚本：靠近显示名字，按 E 触发对话
extends Node2D

## 显示在头顶的名字
@export var npc_name: String = "NPC名"
## 对应 DialogueManager 的场景 ID，空字符串则沉默
@export var dialogue_scene_id: String = ""
## 占位方块颜色，在编辑器/场景实例中可覆盖
@export var body_color: Color = Color(0.70, 0.50, 0.20)
## 人形轮廓类型：generic / woman / old / child / monk
@export var body_shape: String = "generic"
## 触发对话所需的最低剧情阶段（-1 表示不限制）
@export var required_phase: int = -1
@export var dialogue_scene_id_after: String = ""
var is_triggered: bool = false

@onready var _label : Label     = $NameLabel
@onready var _body  : Polygon2D = $Body

var _head: Polygon2D = null


func _ready() -> void:
	_label.text = npc_name
	_label.hide()
	_build_silhouette()
	if required_phase >= 0 and GameData.story_phase < required_phase:
		hide()


func _build_silhouette() -> void:
	if body_shape == "cat":
		_build_cat_silhouette()
		return

	var body_pts: PackedVector2Array
	match body_shape:
		"woman":
			body_pts = PackedVector2Array([
				Vector2(-6, -5), Vector2(6, -5),
				Vector2(10, 20), Vector2(-10, 20)])
		"old":
			## 与generic等宽，仅底部略窄，视觉上接近同等大小
			body_pts = PackedVector2Array([
				Vector2(-10, -5), Vector2(10, -5),
				Vector2(7, 20), Vector2(-7, 20)])
		"monk":
			body_pts = PackedVector2Array([
				Vector2(-9, -5), Vector2(9, -5),
				Vector2(12, 20), Vector2(-12, 20)])
		_:  # generic
			body_pts = PackedVector2Array([
				Vector2(-10, -5), Vector2(10, -5),
				Vector2(8, 20), Vector2(-8, 20)])

	_body.polygon = body_pts
	_body.color = body_color

	_head = Polygon2D.new()
	_head.polygon = _make_ellipse(0.0, -12.0, 6.0, 7.0, 10)
	_head.color = body_color
	add_child(_head)


## 猫形轮廓：圆头 + 尖耳 + 宽低身体
func _build_cat_silhouette() -> void:
	## 身体：矮宽，坐姿感
	_body.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(9, 0),
		Vector2(10, 18), Vector2(-10, 18)])
	_body.color = body_color

	## 头：横向略宽的圆
	_head = Polygon2D.new()
	_head.polygon = _make_ellipse(0.0, -9.0, 7.0, 6.0, 12)
	_head.color = body_color
	add_child(_head)

	## 左耳
	var ear_l := Polygon2D.new()
	ear_l.polygon = PackedVector2Array([
		Vector2(-3, -15), Vector2(-7, -15), Vector2(-5, -20)])
	ear_l.color = body_color
	add_child(ear_l)

	## 右耳
	var ear_r := Polygon2D.new()
	ear_r.polygon = PackedVector2Array([
		Vector2(3, -15), Vector2(7, -15), Vector2(5, -20)])
	ear_r.color = body_color
	add_child(ear_r)


func _make_ellipse(cx: float, cy: float, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var angle := TAU * i / n
		pts.append(Vector2(cx + rx * cos(angle), cy + ry * sin(angle)))
	return pts


# ── 由 Player 调用 ───────────────────────────────────────────

## 玩家进入范围后显示头顶名字
func show_name_label() -> void:
	_label.show()


## 玩家离开范围后隐藏名字
func hide_name_label() -> void:
	_label.hide()


## 获取全局唯一的 NPC 状态 Key（场景名+节点名，防止跨场景同名NPC冲突）
func _get_save_key() -> String:
	var scene_name: String = String(get_tree().current_scene.name) \
		if get_tree() and get_tree().current_scene else "unknown"
	return "npc_state_" + scene_name + "_" + String(name)


## 完整消失：隐藏视觉、禁用碰撞体、禁用交互区，并持久化消失状态到GameData
## 供TownScene、ShopScene等调用，确保NPC彻底从世界中移除
func disappear() -> void:
	hide()
	var body = get_node_or_null("BodyCollider")
	var area = get_node_or_null("InteractArea")
	if body:
		body.set_deferred("collision_layer", 0)
		body.set_deferred("collision_mask", 0)
	if area:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	## 持久化消失状态，加场景前缀防跨场景同名NPC冲突
	var key := _get_save_key() + "_gone"
	if not GameData.triggered_events.has(key):
		GameData.triggered_events.append(key)


## 供场景_ready()调用，静默恢复NPC状态，不触发额外副作用
func restore_state_from_save() -> void:
	## 1. 恢复消失状态
	if GameData.triggered_events.has(_get_save_key() + "_gone"):
		hide()
		var body = get_node_or_null("BodyCollider")
		var area = get_node_or_null("InteractArea")
		if body:
			body.set_deferred("collision_layer", 0)
			body.set_deferred("collision_mask", 0)
		if area:
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
		return
	## 2. 恢复对话切换状态（利用已有的dialogue_scene_id_after，不硬编码）
	if GameData.triggered_events.has(_get_save_key() + "_triggered"):
		is_triggered = true
		if not dialogue_scene_id_after.is_empty():
			dialogue_scene_id = dialogue_scene_id_after


## 玩家按 E 时触发对话
func interact() -> void:
	print("E pressed, starting dialogue: npc=", npc_name, " scene_id=", dialogue_scene_id)
	if dialogue_scene_id.is_empty():
		return
	if DialogueManager.is_active:
		return
	# 剧情阶段不够时拒绝触发
	if required_phase >= 0 and GameData.story_phase < required_phase:
		print("NPC %s: 需要 phase %d，当前 phase %d，暂不触发" % [npc_name, required_phase, GameData.story_phase])
		return
	var scene_id: String = dialogue_scene_id
	if GameData.story_phase >= 3 and not dialogue_scene_id_after.is_empty():
		scene_id = dialogue_scene_id_after
	DialogueManager.start_scene(scene_id)
	## 注意：不在这里自动写 _triggered key。
	## 绝大多数 NPC 的 before/after 切换应由 phase（或业务层显式控制）决定，
	## 而非"玩家按过一次 E"。之前的自动持久化会导致大婶/打水人/守卫等
	## 在 phase 1 聊过一次后，scene reload 后变成回程对话。
	## 真正需要"事件一次性切换"的 NPC（测验师）由 TownScene 在 test_stone 完成时显式写入。
