## ChapterEndScene.gd
## 章末画面：黑底白字，逐行显示文字后淡出
## 所有UI节点在_ready()里动态创建
extends Node2D

## 路径A的文字
const TEXT_A_LINE1_WITH_CHARM := "她带了那张平安符，腰间是装了半壶水的葫芦，还有那支旧剑穗。"
const TEXT_A_LINE1_NO_CHARM := "她带了腰间装了半壶水的葫芦，还有那支旧剑穗。"
const TEXT_A_LINE2 := "走出废庙的时候，她没有回头。"
const TEXT_A_LINE3 := "身后，碎玉镇的灯火一盏一盏亮起来。铺子的那盏也亮着——打水叔今晚会来，给年年和大鱼添食。"

## 路径B的文字
const TEXT_B_LINE1 := "一封没有署名的信。"
const TEXT_B_LINE2 := "一碗早就凉透的饭。"
const TEXT_B_LINE3 := "第二天一早，她收拾好东西。年年还在睡，她没叫醒它。大鱼从后院回来，蹭了蹭她的脚，又走了。她数了数灶下的鱼干，犹豫了一下，又加了几条。后窗留了一线，锁了门，钥匙压在门口的石板下——打水叔会懂。"

## 动态创建的节点引用
var _line1  : Label
var _line2  : Label
var _line3  : Label
var _title  : Label
var _font_regular : Font
var _font_bold    : Font
var _canvas : CanvasLayer


func _ready() -> void:
	## 隐藏常驻UI（HP条/心绪/背包），章末画面全屏显示
	UIManager.on_battle_start()
	AudioManager.play_bgm_once("chapter_end", 2.5)
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

	## 字号根据 UIManager 设置缩放
	var scale_f: float = UIManager.get_font_scale_factor() if UIManager else 1.0
	var line_size: int = int(round(24 * scale_f))
	var title_size: int = int(round(36 * scale_f))

	## Label 开启智能换行，防止长文本横向溢出
	## 固定宽度 900，章末画面居中，足够容纳长句且保留视觉留白
	var line_width: int = 900

	_line1 = Label.new()
	_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line1.custom_minimum_size = Vector2(line_width, 0)
	_line1.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_line1.add_theme_font_override("font", _font_regular)
	_line1.add_theme_font_size_override("font_size", line_size)
	container.add_child(_line1)

	_line2 = Label.new()
	_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line2.custom_minimum_size = Vector2(line_width, 0)
	_line2.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_line2.add_theme_font_override("font", _font_regular)
	_line2.add_theme_font_size_override("font_size", line_size)
	container.add_child(_line2)

	_line3 = Label.new()
	_line3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line3.custom_minimum_size = Vector2(line_width, 0)
	_line3.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_line3.add_theme_font_override("font", _font_regular)
	_line3.add_theme_font_size_override("font_size", line_size)
	container.add_child(_line3)

	## 章节标题间距大一点
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_title.add_theme_font_override("font", _font_bold)
	_title.add_theme_font_size_override("font_size", title_size)
	container.add_child(_title)

	## 初始化文字为空
	_line1.text = ""
	_line2.text = ""
	_line3.text = ""
	_title.text = ""

	await get_tree().process_frame
	_play_ending()


func _play_ending() -> void:
	## 字号缩放系数
	var scale_f: float = UIManager.get_font_scale_factor() if UIManager else 1.0
	## 根据GameData.chapter_end_path判断走哪条路径
	var line1_text := TEXT_A_LINE1_WITH_CHARM if GameData.got_charm else TEXT_A_LINE1_NO_CHARM
	var line2_text := TEXT_A_LINE2
	var line3_text := TEXT_A_LINE3
	if GameData.chapter_end_path == "b":
		line1_text = TEXT_B_LINE1
		line2_text = TEXT_B_LINE2
		line3_text = TEXT_B_LINE3

	## 逐行显示（每步 await 后检查场景是否仍存活，防止 ESC→返回主菜单 后操作已释放节点）
	await _show_line(_line1, line1_text)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree(): return
	await _show_line(_line2, line2_text)
	if not is_inside_tree(): return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	await _show_line(_line3, line3_text)
	if not is_inside_tree(): return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return

	## 淡入显示章节标题
	_title.text = "第一章·碎玉镇"
	var tween := create_tween()
	tween.tween_property(
		_title,
		"theme_override_colors/font_color:a",
		1.0,
		1.5
	).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not is_inside_tree(): return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return

	## 符灵尾声（仅 got_charm 玩家可见）
	var coda_lines := CharmSpirit.get_chapter_end_coda()
	if coda_lines.size() > 0:
		## 先淡出前三行白字和章节标题，让符灵尾声独占中央视觉
		var clear_tw := create_tween()
		clear_tw.set_parallel(true)
		clear_tw.tween_property(_line1, "theme_override_colors/font_color:a", 0.0, 1.2)\
			.set_ease(Tween.EASE_IN_OUT)
		clear_tw.tween_property(_line2, "theme_override_colors/font_color:a", 0.0, 1.2)\
			.set_ease(Tween.EASE_IN_OUT)
		clear_tw.tween_property(_line3, "theme_override_colors/font_color:a", 0.0, 1.2)\
			.set_ease(Tween.EASE_IN_OUT)
		clear_tw.tween_property(_title, "theme_override_colors/font_color:a", 0.0, 1.2)\
			.set_ease(Tween.EASE_IN_OUT)
		await clear_tw.finished
		if not is_inside_tree(): return
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree(): return

		await _play_charm_coda(coda_lines)
		if not is_inside_tree(): return
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree(): return

	## 显示悬念钩子文字
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	var hook := Label.new()
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.0))
	hook.add_theme_font_override("font", _font_regular)
	hook.add_theme_font_size_override("font_size", int(round(20 * scale_f)))
	hook.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hook.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hook.offset_left  = -400.0
	hook.offset_right = 400.0
	hook.offset_top   = -120.0
	## v40.10: 原 hook "有人动了手脚。那个人，认识你。" 是 RPG 阴谋型,
	## 与本作散文气质不符。改为内省/转变型——不预告剧情, 只承认变化已发生。
	hook.text = "「走出去的，不是同一个人。」"
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
	if not is_inside_tree(): return
	## 停留后淡出
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree(): return
	var fade_tween := create_tween()
	fade_tween.tween_property(
		hook,
		"theme_override_colors/font_color:a",
		0.0,
		1.5
	).set_ease(Tween.EASE_IN_OUT)
	await fade_tween.finished
	if not is_inside_tree(): return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return

	## 第二章预告
	var preview := Label.new()
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 0.0))
	preview.add_theme_font_override("font", _font_regular)
	preview.add_theme_font_size_override("font_size", int(round(18 * scale_f)))
	preview.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	preview.grow_horizontal = Control.GROW_DIRECTION_BOTH
	preview.offset_left  = -400.0
	preview.offset_right = 400.0
	preview.offset_top   = -80.0
	preview.text = "第二章·藏锋　——　敬请期待"
	_canvas.add_child(preview)
	var preview_tween := create_tween()
	preview_tween.tween_property(
		preview,
		"theme_override_colors/font_color:a",
		0.7,
		1.5
	).set_ease(Tween.EASE_IN_OUT)
	await preview_tween.finished
	if not is_inside_tree(): return
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree(): return

	## 回到主菜单（而非直接退出）
	UIManager.on_battle_end()
	SceneTransition.change_scene("res://scenes/MainMenuScene.tscn")


## 章末符灵尾声：逐句淡入，字号略小，暖色调
func _play_charm_coda(lines: Array[String]) -> void:
	var scale_f: float = UIManager.get_font_scale_factor() if UIManager else 1.0
	var coda_size: int = int(round(18 * scale_f))
	var coda_color := Color(0.92, 0.84, 0.66, 0.0)

	for i in lines.size():
		if not is_inside_tree(): return
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", _font_regular)
		lbl.add_theme_font_size_override("font_size", coda_size)
		lbl.add_theme_color_override("font_color", coda_color)
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lbl.offset_left  = -500.0
		lbl.offset_right =  500.0
		## 最后一句（收束句）偏下一点
		lbl.offset_top  = -60.0 + i * 30.0
		lbl.text = lines[i]
		_canvas.add_child(lbl)

		var tw := create_tween()
		tw.tween_property(lbl, "theme_override_colors/font_color:a", 0.80, 1.2)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if not is_inside_tree(): return
		await get_tree().create_timer(1.6).timeout
		if not is_inside_tree(): return

		## 非最后句：淡出后显示下一句
		if i < lines.size() - 1:
			var tw_out := create_tween()
			tw_out.tween_property(lbl, "theme_override_colors/font_color:a", 0.0, 0.8)\
				.set_ease(Tween.EASE_IN_OUT)
			await tw_out.finished
			if not is_inside_tree(): return
			await get_tree().create_timer(0.4).timeout

	## 最后句额外停留
	await get_tree().create_timer(1.5).timeout


## 逐字显示一行文字
func _show_line(label: Label, text: String) -> void:
	label.text = ""
	for ch in text:
		label.text += ch
		var interval := 0.0
		if UIManager and UIManager.dialogue_skip:
			interval = 0.0
		else:
			interval = UIManager.get_dialogue_char_interval() if UIManager else 0.03
		if interval > 0.0:
			await get_tree().create_timer(interval).timeout
