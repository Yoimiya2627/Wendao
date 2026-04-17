## ButtonAnimator.gd
## AutoLoad：自动为场景中所有按钮添加悬停/按下缓动动画
## 悬停放大 1.04x，按下压缩 0.94x，松开弹回，风格轻盈克制
extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_apply_to_tree(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_setup(node as Button)


func _apply_to_tree(node: Node) -> void:
	if node is Button:
		_setup(node as Button)
	for child in node.get_children():
		_apply_to_tree(child)


func _setup(btn: Button) -> void:
	if btn.has_meta("_btn_anim"):
		return
	btn.set_meta("_btn_anim", true)
	btn.mouse_entered.connect(_hover_in.bind(btn))
	btn.mouse_exited.connect(_hover_out.bind(btn))
	btn.button_down.connect(_press.bind(btn))
	btn.button_up.connect(_release.bind(btn))


func _sync_pivot(btn: Button) -> void:
	if btn.size != Vector2.ZERO:
		btn.pivot_offset = btn.size * 0.5


func _hover_in(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	_sync_pivot(btn)
	var tw := btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)


func _hover_out(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	_sync_pivot(btn)
	var tw := btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.15)


func _press(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	_sync_pivot(btn)
	var tw := btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07)


func _release(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	_sync_pivot(btn)
	var tw := btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.10)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
