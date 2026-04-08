## MainMenuScene.gd
## 主菜单场景：继续游戏 / 读取存档 / 新游戏 / 退出
## 所有UI程序化构建，后期由美术资产覆盖
extends Control

# ── 字体资源 ──────────────────────────────────────────
const FONT_BOLD    = preload("res://assets/fonts/NotoSerifSC-Bold.ttf")
const FONT_REGULAR = preload("res://assets/fonts/NotoSerifSC-Regular.ttf")

# ── 节点引用 ──────────────────────────────────────────
var _canvas        : CanvasLayer
var _confirm_panel : Panel = null   ## 新游戏二次确认面板
var _slot_panel    : Panel = null   ## 读取存档槽位面板

## 按钮引用（供动态更新状态用）
var _btn_continue  : Button
var _btn_load      : Button
var _btn_new       : Button
var _btn_quit      : Button


func _ready() -> void:
	_build_ui()
	## 从游戏中返回主菜单时，确保游戏HUD隐藏
	if UIManager.has_method("hide_main_hud"):
		UIManager.hide_main_hud()


# ══════════════════════════════════════════════════════
# UI 构建
# ══════════════════════════════════════════════════════

func _build_ui() -> void:
	## 黑色全屏背景
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(bg)

	## 居中容器
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical   = Control.GROW_DIRECTION_BOTH
	center.alignment       = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	_canvas.add_child(center)

	## 标题：问道
	var title := Label.new()
	title.text                 = "问道"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80, 1.0))
	center.add_child(title)

	## 副标题：第一章·碎玉镇
	var subtitle := Label.new()
	subtitle.text                 = "第一章·碎玉镇"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", FONT_REGULAR)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.55, 0.48, 1.0))
	center.add_child(subtitle)

	## 标题与按钮之间的间距
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	center.add_child(spacer)

	## 四个按钮
	_btn_continue = _create_menu_btn("继续游戏")
	_btn_load     = _create_menu_btn("读取存档")
	_btn_new      = _create_menu_btn("新游戏")
	_btn_quit     = _create_menu_btn("退出")
	center.add_child(_btn_continue)
	center.add_child(_btn_load)
	center.add_child(_btn_new)
	center.add_child(_btn_quit)

	## 按钮连接
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_load.pressed.connect(_on_load_pressed)
	_btn_new.pressed.connect(_on_new_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)

	## 根据存档状态更新按钮可用性
	_refresh_button_states()


## 创建统一风格的菜单按钮
func _create_menu_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(200, 44)
	btn.add_theme_font_override("font", FONT_REGULAR)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color",          Color(0.90, 0.85, 0.75, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38, 1.0))

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.08, 0.06, 0.05, 0.0)
	style.border_width_bottom = 1
	style.border_color        = Color(0.45, 0.38, 0.28, 0.0)
	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   style)
	btn.add_theme_stylebox_override("pressed", style)
	return btn


## 根据存档状态刷新按钮可用性
func _refresh_button_states() -> void:
	_btn_continue.disabled = not GameData.has_save("auto")
	_btn_load.disabled     = not (GameData.has_save("manual_1") or GameData.has_save("manual_2"))


# ══════════════════════════════════════════════════════
# 按钮回调
# ══════════════════════════════════════════════════════

## 继续游戏：读取auto槽，按last_scene决定进哪个场景
func _on_continue_pressed() -> void:
	if not GameData.load_from_file("auto"):
		return
	_enter_last_scene()


## 读取存档：弹出槽位选择面板
func _on_load_pressed() -> void:
	if _slot_panel != null:
		return
	_build_slot_panel()


## 新游戏：有存档时弹确认，无存档直接开始
func _on_new_pressed() -> void:
	var has_any := (
		GameData.has_save("auto")     or
		GameData.has_save("manual_1") or
		GameData.has_save("manual_2") or
		GameData.has_save("crossroad")
	)
	if has_any:
		_build_confirm_panel()
	else:
		_start_new_game()


## 退出游戏
func _on_quit_pressed() -> void:
	get_tree().quit()


# ══════════════════════════════════════════════════════
# 新游戏确认面板（纯色块，非系统原生Dialog）
# ══════════════════════════════════════════════════════

func _build_confirm_panel() -> void:
	if _confirm_panel != null:
		return

	_confirm_panel = Panel.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_confirm_panel.offset_left   = -160.0
	_confirm_panel.offset_top    = -80.0
	_confirm_panel.offset_right  = 160.0
	_confirm_panel.offset_bottom = 80.0

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.06, 0.04, 0.04, 0.97)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = Color(0.45, 0.36, 0.24, 0.8)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	_confirm_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_confirm_panel)

	var msg := Label.new()
	msg.text                 = "确认开始新游戏？\n当前进度将不会保留。"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg.offset_top   = 20.0
	msg.offset_left  = -140.0
	msg.offset_right = 140.0
	msg.add_theme_font_override("font", FONT_REGULAR)
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 1.0))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_panel.add_child(msg)

	var btn_ok := Button.new()
	btn_ok.text = "确认"
	btn_ok.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_ok.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_ok.offset_left   = -100.0
	btn_ok.offset_top    = -52.0
	btn_ok.offset_right  = -4.0
	btn_ok.offset_bottom = -12.0
	btn_ok.add_theme_font_override("font", FONT_REGULAR)
	btn_ok.add_theme_font_size_override("font_size", 16)
	btn_ok.pressed.connect(_on_confirm_new_game)
	_confirm_panel.add_child(btn_ok)

	var btn_cancel := Button.new()
	btn_cancel.text = "取消"
	btn_cancel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_cancel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_cancel.offset_left   = 4.0
	btn_cancel.offset_top    = -52.0
	btn_cancel.offset_right  = 100.0
	btn_cancel.offset_bottom = -12.0
	btn_cancel.add_theme_font_override("font", FONT_REGULAR)
	btn_cancel.add_theme_font_size_override("font_size", 16)
	btn_cancel.pressed.connect(_close_confirm_panel)
	_confirm_panel.add_child(btn_cancel)


func _close_confirm_panel() -> void:
	if _confirm_panel != null:
		_confirm_panel.queue_free()
		_confirm_panel = null


func _on_confirm_new_game() -> void:
	_close_confirm_panel()
	_start_new_game()


# ══════════════════════════════════════════════════════
# 读取存档槽位面板
# ══════════════════════════════════════════════════════

func _build_slot_panel() -> void:
	_slot_panel = Panel.new()
	_slot_panel.set_anchors_preset(Control.PRESET_CENTER)
	_slot_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_slot_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_slot_panel.offset_left   = -160.0
	_slot_panel.offset_top    = -100.0
	_slot_panel.offset_right  = 160.0
	_slot_panel.offset_bottom = 100.0

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.06, 0.04, 0.04, 0.97)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = Color(0.45, 0.36, 0.24, 0.8)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	_slot_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_slot_panel)

	var title := Label.new()
	title.text                 = "选择存档"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top   = 12.0
	title.offset_left  = -140.0
	title.offset_right = 140.0
	title.add_theme_font_override("font", FONT_REGULAR)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.65, 0.58, 0.48, 1.0))
	_slot_panel.add_child(title)

	## 槽位一
	var btn_slot1 := _create_slot_btn("manual_1", "槽位一")
	btn_slot1.set_anchors_preset(Control.PRESET_CENTER)
	btn_slot1.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_slot1.offset_left   = -140.0
	btn_slot1.offset_top    = -52.0
	btn_slot1.offset_right  = 140.0
	btn_slot1.offset_bottom = -12.0
	btn_slot1.pressed.connect(func(): _on_load_slot("manual_1"))
	_slot_panel.add_child(btn_slot1)

	## 槽位二
	var btn_slot2 := _create_slot_btn("manual_2", "槽位二")
	btn_slot2.set_anchors_preset(Control.PRESET_CENTER)
	btn_slot2.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_slot2.offset_left   = -140.0
	btn_slot2.offset_top    = 4.0
	btn_slot2.offset_right  = 140.0
	btn_slot2.offset_bottom = 44.0
	btn_slot2.pressed.connect(func(): _on_load_slot("manual_2"))
	_slot_panel.add_child(btn_slot2)

	## 返回按钮
	var btn_back := Button.new()
	btn_back.text = "返回"
	btn_back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_back.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_back.offset_left   = -60.0
	btn_back.offset_top    = -52.0
	btn_back.offset_right  = 60.0
	btn_back.offset_bottom = -12.0
	btn_back.add_theme_font_override("font", FONT_REGULAR)
	btn_back.add_theme_font_size_override("font_size", 16)
	btn_back.pressed.connect(_close_slot_panel)
	_slot_panel.add_child(btn_back)


## 创建存档槽按钮，显示预览信息（只显示章节和灵石，隐藏phase细节）
func _create_slot_btn(slot_name: String, slot_label: String) -> Button:
	var btn := Button.new()
	btn.add_theme_font_override("font", FONT_REGULAR)
	btn.add_theme_font_size_override("font_size", 15)

	if GameData.has_save(slot_name):
		var preview := GameData.get_save_preview(slot_name)
		btn.text     = "%s   第一章   灵石%d" % [
			slot_label,
			preview.get("gold", 0)
		]
		btn.disabled = false
	else:
		btn.text     = "%s   （空）" % slot_label
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38, 1.0))

	return btn


func _close_slot_panel() -> void:
	if _slot_panel != null:
		_slot_panel.queue_free()
		_slot_panel = null


func _on_load_slot(slot_name: String) -> void:
	_close_slot_panel()
	if not GameData.load_from_file(slot_name):
		return
	_enter_last_scene()


# ══════════════════════════════════════════════════════
# 场景跳转辅助
# ══════════════════════════════════════════════════════

## 新游戏：重置数据，切入ShopScene
func _start_new_game() -> void:
	## 新游戏时清理auto和crossroad槽磁盘文件，手动槽保留
	GameData.delete_save("auto")
	GameData.delete_save("crossroad")
	GameData.reset_to_default()
	SceneTransition.change_scene("res://scenes/ShopScene.tscn")


## 读档后按saved_scene_name决定进哪个场景
func _enter_last_scene() -> void:
	var target: String
	## 使用saved_scene_name（存档时的真实场景），不用last_scene（出生门判定变量）
	match GameData.saved_scene_name:
		"ShopScene":    target = "res://scenes/ShopScene.tscn"
		"TeaScene":     target = "res://scenes/TeaScene.tscn"
		"TempleScene":  target = "res://scenes/TempleScene.tscn"
		"BattleScene":  target = "res://scenes/BattleScene.tscn"
		_:              target = "res://scenes/TownScene.tscn"
	SceneTransition.change_scene(target)
