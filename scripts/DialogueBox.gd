## DialogueBox.gd
## 对话框 UI 控制器
## 订阅 DialogueManager 信号，驱动说话人名框、文字逐字效果、选项按钮
extends Control

# ── 节点引用 ─────────────────────────────────────────────────
@onready var speaker_panel     : Panel        = $SpeakerPanel
@onready var speaker_label     : Label        = $SpeakerPanel/SpeakerLabel
@onready var box_panel         : Panel        = $BoxPanel
@onready var dialogue_text     : RichTextLabel = $BoxPanel/DialogueText
@onready var continue_hint     : Label        = $BoxPanel/ContinueHint
@onready var choices_panel     : Panel        = $ChoicesPanel
@onready var choices_container : VBoxContainer = $ChoicesPanel/ChoicesContainer

# ── 字体资源 ─────────────────────────────────────────────────
const _FONT_REGULAR = preload("res://assets/fonts/NotoSerifSC-Regular.ttf")

# ── 逐字显示参数 ──────────────────────────────────────────────
## 每秒显示的字符数
const TYPING_SPEED: float = 35.0

# ── 逐字状态 ─────────────────────────────────────────────────
var _total_chars   : int   = 0      ## 当前文本的总字符数
var _typing_elapsed: float = 0.0    ## 逐字计时累计
var _is_typing     : bool  = false  ## 是否正在逐字显示
var _can_advance   : bool  = false  ## 是否可以推进到下一节点

# ── 闪烁状态 ─────────────────────────────────────────────────
var _blink_time: float = 0.0        ## 继续提示的闪烁时间计数


func _ready() -> void:
	# 修复5：IoC 主动注册，取代 DialogueManager 侧的 find_child 全局搜索
	DialogueManager._dialogue_box = self

	# 信号连接（_ready 里也连，作为备用）
	_ensure_signals_connected()

	# 初始隐藏，等 open_dialogue 或 dialogue_started 信号再显示
	hide()
	choices_panel.hide()
	continue_hint.hide()

	_apply_styles()

	## 监听字号变化（设置菜单调整时实时刷新）
	if UIManager and UIManager.has_signal("font_scale_changed"):
		if not UIManager.font_scale_changed.is_connected(_on_font_scale_changed):
			UIManager.font_scale_changed.connect(_on_font_scale_changed)
		_apply_font_scale(UIManager.get_font_scale_factor())


func _exit_tree() -> void:
	if UIManager and UIManager.has_signal("font_scale_changed") \
			and UIManager.font_scale_changed.is_connected(_on_font_scale_changed):
		UIManager.font_scale_changed.disconnect(_on_font_scale_changed)
	if DialogueManager.dialogue_started.is_connected(on_dialogue_started):
		DialogueManager.dialogue_started.disconnect(on_dialogue_started)
	if DialogueManager.dialogue_ended.is_connected(on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(on_dialogue_ended)
	if DialogueManager.node_changed.is_connected(on_node_changed):
		DialogueManager.node_changed.disconnect(on_node_changed)


## 字号变化回调
func _on_font_scale_changed(scale_factor: float) -> void:
	_apply_font_scale(scale_factor)


## 应用字号缩放到对话文字（三种字型统一基准 18px，旁白靠 [i] 斜体视觉区分）
func _apply_font_scale(scale_factor: float) -> void:
	var size: int = int(round(18 * scale_factor))
	if dialogue_text:
		dialogue_text.add_theme_font_size_override("normal_font_size",  size)
		dialogue_text.add_theme_font_size_override("bold_font_size",    size)
		dialogue_text.add_theme_font_size_override("italics_font_size", size)
	if speaker_label:
		speaker_label.add_theme_font_size_override("font_size", size)


## 由 NPC 直接调用，绕开信号时序问题
## 在连接信号后立即启动对话，不依赖外部 _ready 执行顺序
func open_dialogue(scene_id: String) -> void:
	_ensure_signals_connected()
	DialogueManager.start_scene(scene_id)


func _ensure_signals_connected() -> void:
	if not DialogueManager.dialogue_started.is_connected(on_dialogue_started):
		DialogueManager.dialogue_started.connect(on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(on_dialogue_ended)
	if not DialogueManager.node_changed.is_connected(on_node_changed):
		DialogueManager.node_changed.connect(on_node_changed)


func _apply_styles() -> void:
	if not is_instance_valid(box_panel) or not is_instance_valid(speaker_panel):
		push_warning("DialogueBox: 节点引用无效，跳过样式初始化")
		return

	# 主对话面板：深紫背景（0.92透明度让深紫色可见）+ 顶部暖白细边框
	var box_bg := ThemeManager.COLOR_BG_DARK
	box_bg.a = 0.92
	var box_style := StyleBoxFlat.new()
	box_style.bg_color         = box_bg
	box_style.border_width_top = 1
	box_style.border_color     = ThemeManager.COLOR_BORDER
	box_panel.add_theme_stylebox_override("panel", box_style)

	# 继续提示：暖金色（动画在 _process 里驱动）
	continue_hint.add_theme_color_override("font_color", ThemeManager.COLOR_ACCENT_GOLD)

	# 说话人名框：深紫背景（0.85透明度）+ 左侧3px金色竖线 + 金色文字
	var speaker_bg := ThemeManager.COLOR_BG_DARK
	speaker_bg.a = 0.85
	var speaker_style := StyleBoxFlat.new()
	speaker_style.bg_color            = speaker_bg
	speaker_style.border_width_left   = 3
	speaker_style.border_width_top    = 0
	speaker_style.border_width_right  = 0
	speaker_style.border_width_bottom = 0
	speaker_style.border_color        = ThemeManager.COLOR_ACCENT_GOLD
	speaker_style.corner_radius_top_right    = 3
	speaker_style.corner_radius_bottom_right = 3
	speaker_panel.add_theme_stylebox_override("panel", speaker_style)
	speaker_label.add_theme_color_override("font_color", ThemeManager.COLOR_ACCENT_GOLD)
	speaker_label.add_theme_font_size_override("font_size", 18)

	# 对话正文：暖白色，全部 18px（旁白靠 [i] 斜体视觉区分，不再靠字号）
	dialogue_text.add_theme_color_override("default_color", ThemeManager.COLOR_TEXT_PRIMARY)
	dialogue_text.add_theme_font_size_override("normal_font_size",  18)
	dialogue_text.add_theme_font_size_override("bold_font_size",    18)
	dialogue_text.add_theme_font_size_override("italics_font_size", 18)


func _process(delta: float) -> void:
	# ── 逐字推进 ──────────────────────────────────────────────
	if _is_typing:
		_typing_elapsed += delta
		## 文字速度由 UIManager 设置控制（慢/中/快）
		var interval: float = UIManager.get_dialogue_char_interval() if UIManager else 0.03
		var current_speed: float = 1.0 / interval if interval > 0.0 else TYPING_SPEED
		var target: int = int(_typing_elapsed * current_speed)
		if target >= _total_chars:
			# 所有字符已显示完毕
			dialogue_text.visible_characters = -1
			_is_typing = false
			_on_typing_finished()
		else:
			dialogue_text.visible_characters = target
		return

	# ── 继续提示：透明度渐变 + 上下轻微浮动 ────────────────────
	if continue_hint.visible:
		_blink_time += delta
		var t := sin(_blink_time * TAU * 0.9)
		continue_hint.modulate.a  = 0.55 + 0.45 * (t * 0.5 + 0.5)
		continue_hint.offset_top    = -36.0 + t * 3.0
		continue_hint.offset_bottom = -10.0 + t * 3.0


func _input(event: InputEvent) -> void:
	if not visible:
		return

	var is_mouse_click: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	)
	var is_confirm_key: bool = event.is_action_pressed("ui_accept")

	if not (is_mouse_click or is_confirm_key):
		return

	# 等待选择且逐字已结束时，留给选项按钮处理，不在这里消耗
	if DialogueManager.waiting_for_choice and not _is_typing:
		return

	if _is_typing:
		# 跳过逐字，立即显示全部文字
		_finish_typing()
	elif _can_advance and not DialogueManager.waiting_for_choice:
		# 推进到下一节点
		AudioManager.play_sfx("dialogue_advance")
		DialogueManager.advance()

	get_viewport().set_input_as_handled()


# ── DialogueManager 直接调用的公开方法（同时也作为信号回调）────

## 对话开始：显示对话框，清空残留选项
func on_dialogue_started(_scene_id: String) -> void:
	print("on_dialogue_started called")
	print("showing DialogueBox")
	show()
	move_to_front()
	_clear_choices()
	continue_hint.hide()
	dialogue_text.text = ""
	print("DialogueBox position: ", position, " size: ", size, " visible: ", visible)


## 对话结束：隐藏整个对话框
func on_dialogue_ended(_scene_id: String) -> void:
	hide()
	_clear_choices()


## 节点变化：更新说话人名、启动逐字效果、处理选项显示
func on_node_changed(node: Dictionary) -> void:
	_clear_choices()
	continue_hint.hide()
	_blink_time = 0.0

	# ── 说话人名框 ──────────────────────────────────────────
	var speaker: String   = node.get("speaker", "")
	var node_type: String = node.get("type", "dialogue")

	if speaker.is_empty() or node_type == "narration":
		speaker_panel.hide()
	else:
		speaker_panel.show()
		speaker_label.text = speaker

	# ── 文字内容：按 type 和 speaker 分三类处理 ─────────────
	var raw_text: String = node.get("text", "")
	var display_text: String

	if node_type == "narration":
		## 旁白：斜体 + COLOR_TEXT_PRIMARY（#f2e6bf），italics_font_size=16px
		display_text = "[i][color=#f2e6bf]" + raw_text + "[/color][/i]"
	elif speaker == "苏云晚":
		## 苏云晚台词：COLOR_ACCENT_GOLD（#d4a857），正体
		display_text = "[color=#d4a857]" + raw_text + "[/color]"
	else:
		## NPC台词：默认 COLOR_TEXT_PRIMARY，正体
		display_text = raw_text

	_start_typing(display_text)


# ── 逐字效果 ─────────────────────────────────────────────────

## 开始逐字显示文本
func _start_typing(text: String) -> void:
	dialogue_text.text = text
	_total_chars       = dialogue_text.get_total_character_count()
	_typing_elapsed    = 0.0
	_can_advance       = false

	if _total_chars == 0:
		# 无文字（纯事件节点路过），直接完成
		_on_typing_finished()
	elif UIManager and UIManager.dialogue_skip:
		# 快进模式开启：立即显示全部文字，跳过逐字动画
		_finish_typing()
	else:
		dialogue_text.visible_characters = 0
		_is_typing = true


## 跳过逐字，立即显示全部文字（玩家按确认键时调用）
func _finish_typing() -> void:
	dialogue_text.visible_characters = -1
	_is_typing = false
	_on_typing_finished()


## 逐字完成后的统一收尾：显示继续提示或选项
func _on_typing_finished() -> void:
	_can_advance = true
	if DialogueManager.waiting_for_choice:
		_show_choices()
	else:
		continue_hint.show()


# ── 选项按钮 ─────────────────────────────────────────────────

## 根据当前节点的 choices 数组，动态生成选项按钮
func _show_choices() -> void:
	var node    : Dictionary = DialogueManager.get_current_node()
	var choices : Array      = node.get("choices", [])

	_clear_choices()

	for i: int in choices.size():
		var btn := Button.new()
		btn.text = choices[i].get("text", "选项 %d" % (i + 1))
		btn.add_theme_font_override("font", _FONT_REGULAR)
		btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_ALL
		# 使用闭包捕获索引 i（注意 GDScript 闭包不捕获外层 var，需用参数传值）
		var idx := i
		btn.pressed.connect(func() -> void: _on_choice_selected(idx))
		choices_container.add_child(btn)

	## 无按钮时不显示空面板（防止对话数据异常导致玩家卡死）
	if choices_container.get_child_count() == 0:
		continue_hint.show()
		return

	choices_panel.show()

	# 让第一个按钮自动获焦（支持手柄/键盘导航）
	choices_container.get_child(0).grab_focus()


## 清除所有选项按钮并隐藏选项面板
func _clear_choices() -> void:
	choices_panel.hide()
	for child in choices_container.get_children():
		child.queue_free()


## 玩家点击选项按钮
func _on_choice_selected(index: int) -> void:
	_clear_choices()
	DialogueManager.make_choice(index)
