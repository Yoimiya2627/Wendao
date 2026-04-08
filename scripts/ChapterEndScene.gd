## ChapterEndScene.gd
## 章末画面：黑底白字，逐行显示文字后淡出
## 所有UI节点在_ready()里动态创建
extends Node2D

## 路径A的文字
const TEXT_A_LINE1 := "她只带了那张平安符，还有腰间装了半壶水的葫芦。"
const TEXT_A_LINE2 := "走出废庙的时候，她没有回头。"

## 路径B的文字
const TEXT_B_LINE1 := "一封没有署名的信。"
const TEXT_B_LINE2 := "一碗早就凉透的饭。"

## 动态创建的节点引用
var _line1  : Label
var _line2  : Label
var _title  : Label
var _font_regular : Font
var _font_bold    : Font
var _canvas : CanvasLayer


func _ready() -> void:
	## 隐藏常驻UI（HP条/心绪/背包），章末画面全屏显示
	UIManager.on_battle_start()
	## 创建黑色全屏背景
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(bg)

	## 创建文字容器（居中）
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical   = Control.GROW_DIRECTION_BOTH
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	_canvas.add_child(container)

	## 创建三个Label
	_font_regular = load("res://assets/fonts/NotoSerifSC-Regular.ttf")
	_font_bold    = load("res://assets/fonts/NotoSerifSC-Bold.ttf")

	_line1 = Label.new()
	_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line1.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_line1.add_theme_font_override("font", _font_regular)
	_line1.add_theme_font_size_override("font_size", 18)
	container.add_child(_line1)

	_line2 = Label.new()
	_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line2.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_line2.add_theme_font_override("font", _font_regular)
	_line2.add_theme_font_size_override("font_size", 18)
	container.add_child(_line2)

	## 章节标题间距大一点
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_title.add_theme_font_override("font", _font_bold)
	_title.add_theme_font_size_override("font_size", 24)
	container.add_child(_title)

	## 初始化文字为空
	_line1.text = ""
	_line2.text = ""
	_title.text = ""

	await get_tree().process_frame
	_play_ending()


func _play_ending() -> void:
	## 根据GameData.chapter_end_path判断走哪条路径
	var line1_text := TEXT_A_LINE1
	var line2_text := TEXT_A_LINE2
	if GameData.chapter_end_path == "b":
		line1_text = TEXT_B_LINE1
		line2_text = TEXT_B_LINE2

	## 逐行显示
	await _show_line(_line1, line1_text)
	await get_tree().create_timer(0.5).timeout
	await _show_line(_line2, line2_text)
	await get_tree().create_timer(1.5).timeout

	## 淡入显示章节标题
	_title.text = "第一章·问道"
	var tween := create_tween()
	tween.tween_property(
		_title,
		"theme_override_colors/font_color:a",
		1.0,
		1.5
	).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await get_tree().create_timer(2.0).timeout

	## 显示悬念钩子文字
	await get_tree().create_timer(1.0).timeout
	var hook := Label.new()
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.0))
	hook.add_theme_font_override("font", _font_regular)
	hook.add_theme_font_size_override("font_size", 14)
	hook.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hook.offset_top = -120.0
	hook.text = "「有人动了手脚。那个人，认识你。」"
	_canvas.add_child(hook)
	## 淡入钩子文字
	var hook_tween := create_tween()
	hook_tween.tween_property(
		hook,
		"theme_override_colors/font_color:a",
		0.85,
		2.0
	).set_ease(Tween.EASE_IN_OUT)
	await hook_tween.finished
	## 停留后淡出
	await get_tree().create_timer(3.0).timeout
	var fade_tween := create_tween()
	fade_tween.tween_property(
		hook,
		"theme_override_colors/font_color:a",
		0.0,
		1.5
	).set_ease(Tween.EASE_IN_OUT)
	await fade_tween.finished
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


## 逐字显示一行文字
func _show_line(label: Label, text: String) -> void:
	label.text = ""
	for ch in text:
		label.text += ch
		await get_tree().create_timer(0.05).timeout
