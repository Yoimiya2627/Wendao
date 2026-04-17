## BattleEffects.gd
## 战斗视觉演出：面板闪红、屏幕震动、全屏白光、剑穗动画
extends Node

var _player_panel: Control = null
var _enemy_panel: Control  = null
var _root_ctrl: Control    = null

var _white_overlay: ColorRect = null

var _battle_tassel_node: Node2D  = null
var _battle_tassel_glow: Polygon2D = null
var _battle_tassel_core: Polygon2D = null

var _player_hp_tween: Tween = null
var _enemy_hp_tween: Tween  = null
var _shake_tween: Tween     = null

var _original_pos: Vector2      = Vector2.ZERO
var _original_pos_saved: bool   = false


func setup(player_panel: Control, enemy_panel: Control, root_ctrl: Control) -> void:
	_player_panel = player_panel
	_enemy_panel  = enemy_panel
	_root_ctrl    = root_ctrl

	_white_overlay = ColorRect.new()
	_white_overlay.name = "WhiteOverlay"
	_white_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_white_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_white_overlay)


## 初始化剑穗视觉（PlayerPanel 右上角）
func setup_battle_tassel() -> void:
	if not ("sword_tassel" in GameData.unlocked_old_items):
		return
	_battle_tassel_node = Node2D.new()
	_battle_tassel_node.name = "BattleSwordTassel"
	_battle_tassel_node.position = Vector2(520, 30)
	_player_panel.add_child(_battle_tassel_node)

	_battle_tassel_glow = Polygon2D.new()
	_battle_tassel_glow.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(15, 0), Vector2(0, 18), Vector2(-15, 0)
	])
	_battle_tassel_glow.color = Color(0.95, 0.85, 0.55, 0.0)
	_battle_tassel_node.add_child(_battle_tassel_glow)

	_battle_tassel_core = Polygon2D.new()
	_battle_tassel_core.polygon = PackedVector2Array([
		Vector2(-3, -10), Vector2(3, -10), Vector2(3, 10), Vector2(-3, 10)
	])
	_battle_tassel_core.color = Color(0.45, 0.30, 0.20, 1.0)
	_battle_tassel_node.add_child(_battle_tassel_core)

	refresh_battle_tassel(true)


## 同步剑穗视觉到当前感应等级；instant=true 时直接赋值不缓动
func refresh_battle_tassel(instant: bool = false) -> void:
	if _battle_tassel_node == null or _battle_tassel_core == null or _battle_tassel_glow == null:
		return
	var glow_level: int = 0
	for v in GameData.stones_read:
		if v:
			glow_level += 1

	var core_colors := [
		Color(0.45, 0.30, 0.20, 1.0),
		Color(0.65, 0.45, 0.25, 1.0),
		Color(0.85, 0.65, 0.35, 1.0),
		Color(0.95, 0.80, 0.45, 1.0),
		Color(1.00, 0.92, 0.65, 1.0),
	]
	var glow_alphas := [0.0, 0.20, 0.40, 0.60, 0.85]
	var idx: int = clamp(glow_level, 0, 4)
	var target_core: Color = core_colors[idx]
	var target_glow: Color = Color(0.95, 0.85, 0.55, glow_alphas[idx])

	if instant:
		_battle_tassel_core.color = target_core
		_battle_tassel_glow.color = target_glow
		return

	var tw := _root_ctrl.create_tween().set_parallel(true)
	tw.tween_property(_battle_tassel_core, "color", target_core, 0.6)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_battle_tassel_glow, "color", target_glow, 0.6)\
		.set_ease(Tween.EASE_OUT)


## 觉醒一击时剑穗爆发
func battle_tassel_awaken_burst() -> void:
	if _battle_tassel_node == null:
		return
	var tw := _root_ctrl.create_tween().set_parallel(true)
	tw.tween_property(_battle_tassel_core, "color", Color(1, 1, 1, 1), 0.3)
	tw.tween_property(
		_battle_tassel_glow, "scale", Vector2(3.5, 3.5), 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(
		_battle_tassel_glow, "color", Color(1, 1, 1, 0.95), 0.3
	)


## 面板闪色后回白
func flash_panel(panel: Control, flash_color: Color) -> void:
	var tw := _root_ctrl.create_tween()
	tw.tween_property(panel, "modulate", flash_color, 0.08)
	tw.tween_property(panel, "modulate", Color.WHITE, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## 屏幕震动
func shake_screen() -> void:
	if not _original_pos_saved:
		_original_pos = _root_ctrl.position
		_original_pos_saved = true
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		_root_ctrl.position = _original_pos
	_shake_tween = _root_ctrl.create_tween()
	for i in range(6):
		var offset := Vector2(randf_range(-8, 8), randf_range(-6, 6))
		_shake_tween.tween_property(_root_ctrl, "position", _original_pos + offset, 0.04)
	_shake_tween.tween_property(_root_ctrl, "position", _original_pos, 0.04)


## 全屏白光闪烁（觉醒演出）
func flash_white() -> void:
	if _white_overlay == null or not is_instance_valid(_white_overlay):
		return
	_white_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_white_overlay.show()
	var tw := _root_ctrl.create_tween()
	tw.tween_property(_white_overlay, "color:a", 0.9, 0.12)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.3)
	tw.tween_property(_white_overlay, "color:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## HP 条平滑动画（外部提供 tween 缓存引用以防堆叠）
func tween_hp_bar(bar: ProgressBar, target: float, cached_tween: Tween) -> Tween:
	if cached_tween and cached_tween.is_valid():
		cached_tween.kill()
	var tw := _root_ctrl.create_tween()
	tw.tween_property(bar, "value", target, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return tw
