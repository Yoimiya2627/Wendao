extends CanvasLayer

# 场景切换管理器（AutoLoad 单例）
# 使用黑色遮罩实现淡入淡出效果，切换时长 0.3 秒

const FADE_DURATION := 0.3

var _overlay: ColorRect
var _tween: Tween
var _is_transitioning := false


func _ready() -> void:
	# 置于最高层，确保遮罩覆盖所有内容
	layer = 128

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	add_child(_overlay)


## 切换到指定场景路径，带淡出→淡入效果
func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# 淡出：画面变黑
	await _fade(1.0)

	# 切换场景
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition: 无法加载场景 %s（错误码 %d）" % [path, err])
		# 出错也要把遮罩还原，避免画面卡黑
		await _fade(0.0)
		_is_transitioning = false
		return

	# 等待新场景完成初始化再淡入
	await get_tree().process_frame

	# 淡入：遮罩消失
	await _fade(0.0)

	_is_transitioning = false


## 内部：将遮罩透明度补间到目标值
func _fade(target_alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	await _tween.finished
