## VirtualJoystick.gd
## 虚拟摇杆 AutoLoad 单例
## 仅在移动端显示：左侧摇杆（移动）+ 右下角互动按钮(E) + 菜单按钮(ESC)
## 通过 Input.action_press/release 注入输入，Player.gd 无需修改
extends CanvasLayer

# ── 配置 ──────────────────────────────────────────────────────
const JOYSTICK_RADIUS := 60.0      ## 摇杆活动半径（像素）
const DEAD_ZONE := 15.0            ## 死区半径
const JOYSTICK_MARGIN := Vector2(100, -120)  ## 摇杆中心相对左下角偏移
const BUTTON_SIZE := Vector2(70, 70)
const BUTTON_MARGIN_RIGHT := 40.0  ## 右侧按钮距右边缘
const BUTTON_MARGIN_BOTTOM := 60.0 ## 底部按钮距底边

# ── 节点 ──────────────────────────────────────────────────────
var _joystick_base: Control = null  ## 摇杆底盘
var _joystick_knob: Control = null  ## 摇杆手柄
var _btn_interact: Button = null    ## 互动按钮（E键）
var _btn_menu: Button = null        ## 菜单按钮（ESC）

# ── 状态 ──────────────────────────────────────────────────────
var _joystick_touch_index: int = -1 ## 当前控制摇杆的触摸点ID
var _joystick_origin: Vector2 = Vector2.ZERO  ## 摇杆底盘中心（屏幕坐标）
var _is_mobile: bool = false


func _ready() -> void:
	layer = 100  ## 确保在最顶层
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

	if not _is_mobile:
		## PC端：不创建任何UI，完全不影响
		set_process(false)
		set_process_input(false)
		return

	_create_joystick()
	_create_buttons()


func _process(_delta: float) -> void:
	if not _is_mobile:
		return
	## 战斗/对话/ESC菜单期间隐藏
	var should_hide := UIManager._in_battle \
		or DialogueManager.is_active \
		or UIManager._esc_open
	_joystick_base.visible = not should_hide
	_btn_interact.visible = not should_hide
	_btn_menu.visible = not should_hide

	## 隐藏时释放所有输入
	if should_hide and _joystick_touch_index >= 0:
		_release_all_directions()
		_joystick_touch_index = -1
		_reset_knob()


func _input(event: InputEvent) -> void:
	if not _is_mobile:
		return
	if not _joystick_base.visible:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


# ── 摇杆创建 ──────────────────────────────────────────────────

func _create_joystick() -> void:
	## 底盘（半透明圆形背景）
	_joystick_base = Control.new()
	_joystick_base.name = "JoystickBase"
	_joystick_base.custom_minimum_size = Vector2(JOYSTICK_RADIUS * 2, JOYSTICK_RADIUS * 2)
	_joystick_base.size = Vector2(JOYSTICK_RADIUS * 2, JOYSTICK_RADIUS * 2)
	add_child(_joystick_base)

	var base_bg := ColorRect.new()
	base_bg.color = Color(1.0, 1.0, 1.0, 0.15)
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.add_child(base_bg)

	## 手柄（较小的不透明圆）
	_joystick_knob = Control.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.custom_minimum_size = Vector2(40, 40)
	_joystick_knob.size = Vector2(40, 40)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.add_child(_joystick_knob)

	var knob_bg := ColorRect.new()
	knob_bg.color = Color(1.0, 1.0, 1.0, 0.4)
	knob_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	knob_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_knob.add_child(knob_bg)

	## 定位到左下角
	_update_joystick_position()
	_reset_knob()


func _create_buttons() -> void:
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))

	## 互动按钮（E键替代）
	_btn_interact = Button.new()
	_btn_interact.name = "BtnInteract"
	_btn_interact.text = "互动"
	_btn_interact.custom_minimum_size = BUTTON_SIZE
	_btn_interact.size = BUTTON_SIZE
	_btn_interact.position = Vector2(
		viewport_size.x - BUTTON_SIZE.x - BUTTON_MARGIN_RIGHT,
		viewport_size.y - BUTTON_SIZE.y * 2 - BUTTON_MARGIN_BOTTOM - 10)
	_btn_interact.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_btn_interact.focus_mode = Control.FOCUS_NONE
	_btn_interact.button_down.connect(_on_interact_pressed)
	_btn_interact.button_up.connect(_on_interact_released)
	add_child(_btn_interact)

	## 菜单按钮（ESC替代）
	_btn_menu = Button.new()
	_btn_menu.name = "BtnMenu"
	_btn_menu.text = "菜单"
	_btn_menu.custom_minimum_size = BUTTON_SIZE
	_btn_menu.size = BUTTON_SIZE
	_btn_menu.position = Vector2(
		viewport_size.x - BUTTON_SIZE.x - BUTTON_MARGIN_RIGHT,
		viewport_size.y - BUTTON_SIZE.y - BUTTON_MARGIN_BOTTOM)
	_btn_menu.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_btn_menu.focus_mode = Control.FOCUS_NONE
	_btn_menu.button_down.connect(_on_menu_pressed)
	_btn_menu.button_up.connect(_on_menu_released)
	add_child(_btn_menu)


# ── 摇杆定位 ──────────────────────────────────────────────────

func _update_joystick_position() -> void:
	var viewport_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	_joystick_origin = Vector2(
		JOYSTICK_MARGIN.x,
		viewport_size.y + JOYSTICK_MARGIN.y)
	_joystick_base.position = _joystick_origin - Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS)


func _reset_knob() -> void:
	## 手柄回到底盘中心
	_joystick_knob.position = Vector2(
		JOYSTICK_RADIUS - _joystick_knob.size.x / 2,
		JOYSTICK_RADIUS - _joystick_knob.size.y / 2)


# ── 触摸处理 ──────────────────────────────────────────────────

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		## 检查触摸点是否在摇杆区域内（左半屏）
		var viewport_w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
		if event.position.x < viewport_w * 0.4 and _joystick_touch_index < 0:
			_joystick_touch_index = event.index
			_update_joystick_direction(event.position)
	else:
		## 抬起：如果是摇杆的触摸点，释放方向
		if event.index == _joystick_touch_index:
			_release_all_directions()
			_joystick_touch_index = -1
			_reset_knob()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _joystick_touch_index:
		return
	_update_joystick_direction(event.position)


func _update_joystick_direction(touch_pos: Vector2) -> void:
	var dir := touch_pos - _joystick_origin
	var dist := dir.length()

	## 更新手柄视觉位置（限制在底盘半径内）
	var clamped := dir
	if dist > JOYSTICK_RADIUS:
		clamped = dir.normalized() * JOYSTICK_RADIUS
	_joystick_knob.position = Vector2(
		JOYSTICK_RADIUS + clamped.x - _joystick_knob.size.x / 2,
		JOYSTICK_RADIUS + clamped.y - _joystick_knob.size.y / 2)

	## 死区内：释放所有方向
	if dist < DEAD_ZONE:
		_release_all_directions()
		return

	## 归一化方向
	var norm := dir.normalized()
	var threshold := 0.4  ## 对角线灵敏度

	## 水平方向
	if norm.x < -threshold:
		Input.action_press("ui_left")
		Input.action_release("ui_right")
	elif norm.x > threshold:
		Input.action_press("ui_right")
		Input.action_release("ui_left")
	else:
		Input.action_release("ui_left")
		Input.action_release("ui_right")

	## 垂直方向
	if norm.y < -threshold:
		Input.action_press("ui_up")
		Input.action_release("ui_down")
	elif norm.y > threshold:
		Input.action_press("ui_down")
		Input.action_release("ui_up")
	else:
		Input.action_release("ui_up")
		Input.action_release("ui_down")


func _release_all_directions() -> void:
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")


# ── 按钮回调 ──────────────────────────────────────────────────

func _on_interact_pressed() -> void:
	## 模拟E键按下
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	ev.echo = false
	Input.parse_input_event(ev)


func _on_interact_released() -> void:
	## 模拟E键释放
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = false
	Input.parse_input_event(ev)


func _on_menu_pressed() -> void:
	## 模拟ESC键按下
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)


func _on_menu_released() -> void:
	## 模拟ESC键释放
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = false
	Input.parse_input_event(ev)
