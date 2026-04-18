## UIManager.gd
## 全局UI管理器 AutoLoad单例
## 负责常驻HP条、心绪面板、旧物背包三件套
## 战斗期间由BattleUI显式调用on_battle_start()/on_battle_end()控制显隐
extends Node

# ── 物品数据 ──────────────────────────────────────────────────
const ITEM_DATA := {
	"sword_tassel": {
		"name": "旧剑穗",
		"desc": "柜台角落压了许久的旧物。\n大鱼从门缝叼进来的。\n穗绳上的结扎得很紧，不像是丢掉的东西。"
	},
	"cinnamon": {
		"name": "桂皮",
		"desc": "爹让顺路买的。\n口袋里压着，有股淡淡的香气。"
	},
	"coin": {
		"name": "铜钱",
		"desc": "正反两面都是正面。\n算命先生说，天道遇上这枚，\n只能认输。"
	},
}

## 物品显示顺序（固定槽位）
const ITEM_ORDER := ["sword_tassel", "cinnamon", "coin"]

## 功法数据（固定顺序显示）
const SKILL_DATA := {
	"charge": {
		"name": "蓄势",
		"desc": "凝神内敛，跳过本回合。\n下一击破甲×2。",
		"unlock": "初始即悟。",
	},
	"bite": {
		"name": "淬血",
		"desc": "以血淬剑，自损10HP。\n血量越低，伤害越重。",
		"unlock": "初始即悟。",
	},
	"sense": {
		"name": "感应",
		"desc": "观法则于微末，\n本回合受伤减半，\n下一击无视防御×1.2。",
		"unlock": "需先阅读废庙碑文。",
	},
}

## 功法显示顺序（固定槽位）
const SKILL_ORDER := ["charge", "bite", "sense"]

# ── 心绪文字 ──────────────────────────────────────────────────
const MOOD_TEXTS := {
	0: "今天去测灵根。\n爹说不管测出什么，\n记得回来吃饭。",
	1: "去广场看看吧。\n听说太平宗今年来人了。",
	2: "没测出来。\n回家吧。",
	3: "回来了。没测出来。\n镇子还是那个镇子。",
	4: "废庙里有什么。\n旧剑穗烫手，\n爹说别怕，门会开的。",
	5: "走出来了。\n不知道接下来去哪。",
}

# ── 节点引用 ──────────────────────────────────────────────────
var _canvas       : CanvasLayer
var _hp_panel     : Panel
var _hp_name      : Label
var _hp_text      : Label
var _hp_bar       : ColorRect      ## 进度条填充部分
var _hp_bar_bg    : ColorRect      ## 进度条背景
var _gold_text    : Label          ## 灵石数量

var _mood_panel        : Panel
var _mood_text         : Label
var _mood_toggle_btn   : Label
var _mood_collapsed    : bool = false
var _mood_sep          : ColorRect

var _bag_button   : Button         ## 右下角展开按钮
var _bag_panel    : Panel          ## 展开后的背包面板
var _bag_slots    : Array[Button]  ## 6个格子按钮
var _bag_desc     : Label          ## 描述文字
var _bag_open     : bool = false   ## 背包是否展开

var _skill_button : Button
var _skill_panel  : Panel
var _skill_slots  : Array[Button] = []
var _skill_desc   : Label
var _skill_open   : bool = false

## 战斗中是否隐藏主UI
var _in_battle    : bool = false

## 公开只读属性：外部模块（如 VirtualJoystick）查询战斗状态
var in_battle: bool:
	get: return _in_battle

## 字号缩放变化信号（设置面板调整时触发，DialogueBox等监听）
signal font_scale_changed(scale_factor: float)


func _ready() -> void:
	## 确保UIManager在游戏暂停状态下仍能响应ESC输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	## 加载设置（音量、文字速度等）
	load_settings_from_file()
	_build_ui()
	_refresh_mood(GameData.story_phase)
	_refresh_hp()
	_rebuild_bag()
	## 监听剧情阶段变化，自动更新心绪面板
	GameData.story_phase_changed.connect(_refresh_mood)
	## 默认隐藏主UI，等待具体场景显式唤醒（防止主菜单显示游戏UI）
	call_deferred("hide_main_hud")


# ══════════════════════════════════════════════════════════════
# 公开接口
# ══════════════════════════════════════════════════════════════

## 刷新HP显示（战斗回合结束、古井回血后调用）
func refresh_hp() -> void:
	_refresh_hp()


## 添加物品到旧物背包
func add_item(item_id: String) -> void:
	if item_id in GameData.unlocked_old_items:
		return
	GameData.unlocked_old_items.append(item_id)
	_rebuild_bag()


## 读档后全量同步UI状态（由TownScene._ready()调用）
func refresh_all_data() -> void:
	show_main_hud()  ## 进入游戏时显式唤醒HUD
	_refresh_hp()
	_rebuild_bag()
	_refresh_mood(GameData.story_phase)
	_rebuild_skill_panel()
	## 延迟一帧同步Hash，确保get_tree().current_scene已被引擎正式赋值
	call_deferred("_update_saved_hash")


## 供外部在感应解锁后调用，重建功法格子
func refresh_skill_panel() -> void:
	_rebuild_skill_panel()


## 隐藏主HUD（主菜单、战斗中调用）
func hide_main_hud() -> void:
	if is_instance_valid(_hp_panel):
		_hp_panel.hide()
	if is_instance_valid(_mood_panel):
		_mood_panel.hide()
	if is_instance_valid(_bag_button):
		_bag_button.hide()
	if _bag_open and is_instance_valid(_bag_panel):
		_bag_open = false
		_bag_panel.hide()
	if is_instance_valid(_skill_button):
		_skill_button.hide()
	if _skill_open and is_instance_valid(_skill_panel):
		_skill_open = false
		_skill_panel.hide()


## 显示主HUD（大地图探索时调用）
func show_main_hud() -> void:
	if _in_battle:
		return
	if is_instance_valid(_hp_panel):
		_hp_panel.show()
	if is_instance_valid(_mood_panel):
		_mood_panel.show()
	if is_instance_valid(_bag_button):
		_bag_button.show()
	if is_instance_valid(_skill_button):
		_skill_button.show()


## 战斗开始时隐藏主UI（由BattleUI._ready()调用）
func on_battle_start() -> void:
	_in_battle = true
	hide_main_hud()


## 战斗结束时恢复主UI
func on_battle_end() -> void:
	_in_battle = false
	show_main_hud()
	_refresh_hp()


# ══════════════════════════════════════════════════════════════
# UI构建
# ══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	## 创建CanvasLayer，layer=50确保在对话框(10)之上，SceneTransition(128)之下
	_canvas = CanvasLayer.new()
	_canvas.layer = 50
	add_child(_canvas)

	_build_hp_panel()
	_build_mood_panel()
	_build_bag()
	_build_skill_panel()


## 构建左上角HP条
func _build_hp_panel() -> void:
	_hp_panel = Panel.new()
	_hp_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hp_panel.offset_right  = 168.0
	_hp_panel.offset_bottom = 72.0
	_hp_panel.position      = Vector2(8.0, 8.0)

	var style := StyleBoxFlat.new()
	style.bg_color              = ThemeManager.COLOR_PANEL_BG
	style.border_width_bottom   = 1
	style.border_color          = ThemeManager.COLOR_PANEL_BORDER
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	_hp_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_hp_panel)

	## 名字Label
	_hp_name = Label.new()
	_hp_name.text     = "苏云晚"
	_hp_name.position = Vector2(8.0, 4.0)
	_hp_name.add_theme_font_size_override("font_size", 13)
	_hp_name.add_theme_color_override("font_color", ThemeManager.COLOR_ACCENT_GOLD)
	_hp_panel.add_child(_hp_name)

	## 数字Label
	_hp_text = Label.new()
	_hp_text.position = Vector2(8.0, 22.0)
	_hp_text.add_theme_font_size_override("font_size", 12)
	_hp_text.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58, 1.0))
	_hp_panel.add_child(_hp_text)

	## 进度条背景
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color    = Color(0.15, 0.10, 0.10, 1.0)
	_hp_bar_bg.position = Vector2(8.0, 42.0)
	_hp_bar_bg.size     = Vector2(148.0, 8.0)
	_hp_panel.add_child(_hp_bar_bg)

	## 进度条填充
	_hp_bar = ColorRect.new()
	_hp_bar.color    = Color(0.72, 0.18, 0.18, 1.0)
	_hp_bar.position = Vector2(8.0, 42.0)
	_hp_bar.size     = Vector2(148.0, 8.0)
	_hp_panel.add_child(_hp_bar)

	## 灵石Label
	_gold_text = Label.new()
	_gold_text.position = Vector2(8.0, 54.0)
	_gold_text.add_theme_font_size_override("font_size", 12)
	_gold_text.add_theme_color_override("font_color", ThemeManager.COLOR_ACCENT_GOLD)
	_hp_panel.add_child(_gold_text)


## 构建右侧心绪面板
func _build_mood_panel() -> void:
	_mood_panel = Panel.new()
	_mood_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mood_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_mood_panel.offset_left   = -188.0
	_mood_panel.offset_top    = 8.0
	_mood_panel.offset_right  = -8.0
	_mood_panel.offset_bottom = 180.0

	var style := StyleBoxFlat.new()
	style.bg_color    = ThemeManager.COLOR_PANEL_BG
	style.border_width_bottom = 1
	style.border_color        = ThemeManager.COLOR_PANEL_BORDER
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	_mood_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_mood_panel)

	## 标题
	var title := Label.new()
	title.text     = "心绪"
	title.position = Vector2(10.0, 6.0)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.50, 0.45, 1.0))
	_mood_panel.add_child(title)

	## 折叠按钮（Label 形式，与标题同排同字号、可点击）
	_mood_toggle_btn = Label.new()
	_mood_toggle_btn.text = "收"
	_mood_toggle_btn.position = Vector2(155.0, 6.0)
	_mood_toggle_btn.add_theme_font_size_override("font_size", 12)
	_mood_toggle_btn.add_theme_color_override("font_color", Color(0.55, 0.50, 0.45, 1.0))
	_mood_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_mood_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mood_toggle_btn.gui_input.connect(_on_mood_toggle_input)
	_mood_panel.add_child(_mood_toggle_btn)

	## 分隔线
	_mood_sep = ColorRect.new()
	_mood_sep.color    = Color(ThemeManager.COLOR_TEXT_WARM.r, ThemeManager.COLOR_TEXT_WARM.g, ThemeManager.COLOR_TEXT_WARM.b, 0.3)
	_mood_sep.position = Vector2(8.0, 24.0)
	_mood_sep.size     = Vector2(164.0, 1.0)
	_mood_panel.add_child(_mood_sep)

	## 正文
	_mood_text = Label.new()
	_mood_text.position      = Vector2(10.0, 30.0)
	_mood_text.size          = Vector2(160.0, 140.0)
	_mood_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mood_text.add_theme_font_size_override("font_size", 16)
	_mood_text.add_theme_color_override("font_color", ThemeManager.COLOR_TEXT_SECONDARY)
	_mood_panel.add_child(_mood_text)


func _on_mood_toggle_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_mood_collapsed = not _mood_collapsed
	if _mood_collapsed:
		_mood_sep.hide()
		_mood_text.hide()
		_mood_panel.offset_bottom = _mood_panel.offset_top + 28.0
		_mood_toggle_btn.text = "展"
	else:
		_mood_sep.show()
		_mood_text.show()
		_mood_panel.offset_bottom = _mood_panel.offset_top + 172.0
		_mood_toggle_btn.text = "收"


## 构建右下角旧物背包
func _build_bag() -> void:
	## 展开按钮（常驻右下角）
	_bag_button = Button.new()
	_bag_button.text = "囊"
	_bag_button.focus_mode = Control.FOCUS_NONE
	_bag_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_bag_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bag_button.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_bag_button.offset_left   = -44.0
	_bag_button.offset_top    = -44.0
	_bag_button.offset_right  = -8.0
	_bag_button.offset_bottom = -8.0

	## 囊按钮风格由 ThemeManager 全局主题提供，不再本地覆盖
	_bag_button.add_theme_font_size_override("font_size", 14)
	_bag_button.pressed.connect(_toggle_bag)
	_canvas.add_child(_bag_button)

	## 背包展开面板（默认隐藏）
	_bag_panel = Panel.new()
	_bag_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_bag_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bag_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_bag_panel.offset_left   = -216.0
	_bag_panel.offset_top    = -320.0
	_bag_panel.offset_right  = -8.0
	_bag_panel.offset_bottom = -56.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color  = ThemeManager.COLOR_PANEL_BG
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_color        = ThemeManager.COLOR_PANEL_BORDER
	panel_style.corner_radius_top_left     = 4
	panel_style.corner_radius_top_right    = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left  = 4
	_bag_panel.add_theme_stylebox_override("panel", panel_style)
	_canvas.add_child(_bag_panel)

	## 标题
	var bag_title := Label.new()
	bag_title.text     = "旧 物"
	bag_title.position = Vector2(10.0, 6.0)
	bag_title.add_theme_font_size_override("font_size", 13)
	bag_title.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55, 1.0))
	_bag_panel.add_child(bag_title)

	## 分隔线
	var sep2 := ColorRect.new()
	sep2.color    = Color(0.95, 0.90, 0.75, 0.3)
	sep2.position = Vector2(8.0, 26.0)
	sep2.size     = Vector2(188.0, 1.0)
	_bag_panel.add_child(sep2)

	## 6个格子（2行×3列）
	_bag_slots.clear()
	for i in 6:
		var col := i % 3
		@warning_ignore("integer_division")
		var row := i / 3
		var slot := Button.new()
		slot.position = Vector2(8.0 + col * 64.0, 34.0 + row * 64.0)
		slot.size     = Vector2(58.0, 58.0)
		slot.clip_text = true

		slot.add_theme_font_size_override("font_size", 12)

		var idx := i
		slot.pressed.connect(func(): _on_slot_pressed(idx))
		_bag_panel.add_child(slot)
		_bag_slots.append(slot)

	## 描述区分隔线
	var sep3 := ColorRect.new()
	sep3.color    = Color(0.95, 0.90, 0.75, 0.3)
	sep3.position = Vector2(8.0, 168.0)
	sep3.size     = Vector2(188.0, 1.0)
	_bag_panel.add_child(sep3)

	## 描述文字
	_bag_desc = Label.new()
	_bag_desc.position      = Vector2(10.0, 174.0)
	_bag_desc.size          = Vector2(184.0, 108.0)
	_bag_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_desc.clip_text     = true
	_bag_desc.add_theme_font_size_override("font_size", 12)
	_bag_desc.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62, 1.0))
	_bag_desc.text = "点击物品查看描述。"
	_bag_panel.add_child(_bag_desc)

	_bag_panel.hide()


## 构建右下角功法栏（"悟"按钮，与"囊"并列）
func _build_skill_panel() -> void:
	_skill_button = Button.new()
	_skill_button.text = "悟"
	_skill_button.focus_mode = Control.FOCUS_NONE
	_skill_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skill_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skill_button.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_skill_button.offset_left   = -88.0
	_skill_button.offset_top    = -44.0
	_skill_button.offset_right  = -52.0
	_skill_button.offset_bottom = -8.0

	## 悟按钮风格由 ThemeManager 全局主题提供，不再本地覆盖
	_skill_button.add_theme_font_size_override("font_size", 14)
	_skill_button.pressed.connect(_toggle_skill_panel)
	_canvas.add_child(_skill_button)

	_skill_panel = Panel.new()
	_skill_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skill_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skill_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_skill_panel.offset_left   = -216.0
	_skill_panel.offset_top    = -320.0
	_skill_panel.offset_right  = -8.0
	_skill_panel.offset_bottom = -56.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color  = ThemeManager.COLOR_PANEL_BG
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_color        = ThemeManager.COLOR_PANEL_BORDER
	panel_style.corner_radius_top_left     = 4
	panel_style.corner_radius_top_right    = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left  = 4
	_skill_panel.add_theme_stylebox_override("panel", panel_style)
	_canvas.add_child(_skill_panel)

	var title := Label.new()
	title.text     = "感 悟"
	title.position = Vector2(10.0, 6.0)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55, 1.0))
	_skill_panel.add_child(title)

	var sep := ColorRect.new()
	sep.color    = Color(0.40, 0.32, 0.24, 0.4)
	sep.position = Vector2(8.0, 26.0)
	sep.size     = Vector2(188.0, 1.0)
	_skill_panel.add_child(sep)

	_skill_slots.clear()
	for i in 3:
		var slot := Button.new()
		slot.position  = Vector2(8.0, 34.0 + i * 52.0)
		slot.size      = Vector2(188.0, 46.0)
		slot.clip_text = true
		slot.add_theme_font_size_override("font_size", 13)

		var idx := i
		slot.pressed.connect(func(): _on_skill_slot_pressed(idx))
		_skill_panel.add_child(slot)
		_skill_slots.append(slot)

	var sep2 := ColorRect.new()
	sep2.color    = Color(0.95, 0.90, 0.75, 0.3)
	sep2.position = Vector2(8.0, 194.0)
	sep2.size     = Vector2(188.0, 1.0)
	_skill_panel.add_child(sep2)

	_skill_desc = Label.new()
	_skill_desc.position      = Vector2(10.0, 200.0)
	_skill_desc.size          = Vector2(184.0, 108.0)
	_skill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_desc.clip_text     = true
	_skill_desc.add_theme_font_size_override("font_size", 12)
	_skill_desc.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62, 1.0))
	_skill_desc.text = "点击感悟查看详情。"
	_skill_panel.add_child(_skill_desc)

	_skill_panel.hide()
	_rebuild_skill_panel()


# ══════════════════════════════════════════════════════════════
# 内部刷新函数
# ══════════════════════════════════════════════════════════════

## 刷新HP条显示
## 统一评估并更新游戏暂停状态
## 系统菜单、背包、功法栏任意一个开着就暂停游戏
func _update_pause_state() -> void:
	if _in_battle:
		return  ## 战斗中有独立的暂停逻辑，不干预
	get_tree().paused = _esc_open or _bag_open or _skill_open


func _refresh_hp() -> void:
	if GameData.player == null:
		return
	var p := GameData.player
	_hp_text.text = "HP  %d / %d" % [p.hp, p.max_hp]
	var ratio := float(p.hp) / float(p.max_hp) if p.max_hp > 0 else 0.0
	_hp_bar.size.x = 148.0 * ratio
	## 低血量变深红
	if ratio <= 0.3:
		_hp_bar.color = Color(0.55, 0.08, 0.08, 1.0)
	else:
		_hp_bar.color = Color(0.72, 0.18, 0.18, 1.0)
	## 刷新灵石
	if is_instance_valid(_gold_text):
		_gold_text.text = "灵石  %d" % GameData.gold


## 根据story_phase刷新心绪文字
func _refresh_mood(phase: int) -> void:
	## phase 3 + 夜晚触发后：心绪应切换为废庙相关（而非回程感慨）
	if phase == 3 and GameData.night_triggered:
		_mood_text.text = MOOD_TEXTS[4]
		return
	## 找到最接近且不超过当前phase的key
	var best_key := 0
	for key in MOOD_TEXTS.keys():
		if key <= phase and key >= best_key:
			best_key = key
	_mood_text.text = MOOD_TEXTS[best_key]


## 重建背包格子显示（读档恢复或add_item后调用）
func _rebuild_bag() -> void:
	for i in 6:
		var slot: Button = _bag_slots[i]
		if i < ITEM_ORDER.size():
			var item_id: String = ITEM_ORDER[i]
			if item_id in GameData.unlocked_old_items:
				slot.text = ITEM_DATA[item_id]["name"]
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				slot.text = ""
				slot.modulate = Color(1.0, 1.0, 1.0, 0.3)
		else:
			slot.text = ""
			slot.modulate = Color(1.0, 1.0, 1.0, 0.3)


## 切换背包展开/收起
func _toggle_bag() -> void:
	if _in_battle:
		return
	## 打开背包时关闭功法栏，互斥显示
	if not _bag_open and _skill_open:
		_skill_open = false
		_skill_panel.hide()
	_bag_open = not _bag_open
	if _bag_open:
		_bag_panel.show()
		_bag_desc.text = "点击物品查看描述。"
	else:
		_bag_panel.hide()
	_update_pause_state()


## 切换功法栏展开/收起，与背包互斥
func _toggle_skill_panel() -> void:
	if _in_battle:
		return
	if not _skill_open and _bag_open:
		_bag_open = false
		_bag_panel.hide()
	_skill_open = not _skill_open
	if _skill_open:
		_skill_panel.show()
		_skill_desc.text = "点击感悟查看详情。"
	else:
		_skill_panel.hide()
	_update_pause_state()


## 重建功法格子显示（解锁状态变化时调用）
func _rebuild_skill_panel() -> void:
	var bite_unlocked  := true
	var sense_unlocked := GameData.stones_read.any(func(v): return v)
	var unlock_states  := [true, bite_unlocked, sense_unlocked]

	for i in 3:
		var slot: Button = _skill_slots[i]
		var skill_id: String = SKILL_ORDER[i]
		var data: Dictionary = SKILL_DATA[skill_id]
		var unlocked: bool = unlock_states[i]

		if unlocked:
			slot.text     = data["name"]
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			slot.text     = data["name"] + "（未悟）"
			slot.modulate = Color(1.0, 1.0, 1.0, 0.45)


## 点击技能格子：显示描述，未解锁时附加解锁条件
func _on_skill_slot_pressed(index: int) -> void:
	var skill_id: String = SKILL_ORDER[index]
	var data: Dictionary = SKILL_DATA[skill_id]
	var bite_unlocked  := true
	var sense_unlocked := GameData.stones_read.any(func(v): return v)
	var unlock_states  := [true, bite_unlocked, sense_unlocked]
	var unlocked: bool = unlock_states[index]

	if unlocked:
		_skill_desc.text = data["desc"]
	else:
		_skill_desc.text = data["desc"] + "\n\n【" + data["unlock"] + "】"


## 点击格子：显示对应物品描述
func _on_slot_pressed(index: int) -> void:
	if index >= ITEM_ORDER.size():
		return
	var item_id: String = ITEM_ORDER[index]
	if item_id not in GameData.unlocked_old_items:
		_bag_desc.text = "——"
		return
	_bag_desc.text = ITEM_DATA[item_id]["desc"]


# ══════════════════════════════════════════════════════════════
# ESC 系统菜单
# ══════════════════════════════════════════════════════════════

## ESC菜单根节点（动态创建，防内存泄漏）
var _esc_panel         : Panel   = null
var _esc_open          : bool    = false

## 公开只读属性：外部模块（如 VirtualJoystick）查询 ESC 菜单状态
var esc_open: bool:
	get: return _esc_open

## 确认面板（覆盖存档 / 返回主菜单 共用）
var _esc_confirm_panel : Panel  = null
var _esc_confirm_mode  : String = ""  ## "overwrite_1" / "overwrite_2" / "return_menu"
var _last_saved_hash   : int    = 0  ## 最后一次存档时的数据Hash，用于判断是否有未保存变更


func _input(event: InputEvent) -> void:
	## 主菜单场景不响应ESC
	var scene = get_tree().current_scene
	if scene and String(scene.name) == "MainMenuScene":
		return
	## 监听ESC键
	if event.is_action_pressed("ui_cancel"):
		if _esc_open:
			_close_esc_menu()
		else:
			_open_esc_menu()
		get_viewport().set_input_as_handled()


## 判断当前场景是否允许手动存档
## TempleScene和BattleScene禁止存档
func _can_save_in_current_scene() -> bool:
	if _in_battle:
		return false
	var scene = get_tree().current_scene
	if scene == null:
		return false
	var scene_name: String = String(scene.name)
	if scene_name == "TempleScene" or scene_name == "BattleScene":
		return false
	## 对话进行中不允许存档
	if DialogueManager.is_active:
		return false
	return true


## 打开ESC菜单
func _open_esc_menu() -> void:
	if _esc_open:
		return
	_esc_open = true
	_update_pause_state()

	## 创建半透明遮罩背景
	_esc_panel = Panel.new()
	_esc_panel.set_anchors_preset(Control.PRESET_CENTER)
	_esc_panel.grow_horizontal   = Control.GROW_DIRECTION_BOTH
	_esc_panel.grow_vertical     = Control.GROW_DIRECTION_BOTH
	_esc_panel.offset_left   = -140.0
	_esc_panel.offset_top    = -180.0
	_esc_panel.offset_right  = 140.0
	_esc_panel.offset_bottom = 180.0
	## 菜单自身必须设为ALWAYS，否则paused后无法响应输入
	_esc_panel.process_mode  = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color            = ThemeManager.COLOR_PANEL_BG
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = ThemeManager.COLOR_PANEL_BORDER
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	_esc_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_esc_panel)

	## 标题
	var title := Label.new()
	title.text                 = "菜 单"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top   = 14.0
	title.offset_left  = -120.0
	title.offset_right = 120.0
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.65, 0.58, 0.48, 1.0))
	_esc_panel.add_child(title)

	## 分隔线
	var sep := ColorRect.new()
	sep.color    = Color(0.95, 0.90, 0.75, 0.3)
	sep.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sep.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sep.offset_top    = 38.0
	sep.offset_left   = -120.0
	sep.offset_right  = 120.0
	sep.offset_bottom = 39.0
	_esc_panel.add_child(sep)

	## 按钮容器
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical   = Control.GROW_DIRECTION_BOTH
	vbox.offset_left   = -110.0
	vbox.offset_top    = -110.0
	vbox.offset_right  = 110.0
	vbox.offset_bottom = 150.0
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	_esc_panel.add_child(vbox)

	## 继续按钮（始终显示）
	var btn_resume := _create_esc_btn("继续")
	btn_resume.pressed.connect(_close_esc_menu)
	vbox.add_child(btn_resume)

	## 存档按钮（分场景显隐，仅在允许时实例化，防内存堆积）
	if _can_save_in_current_scene():
		var btn_save1 := _create_esc_btn("存入槽位一")
		btn_save1.pressed.connect(func(): _on_esc_save_pressed("manual_1"))
		vbox.add_child(btn_save1)

		var btn_save2 := _create_esc_btn("存入槽位二")
		btn_save2.pressed.connect(func(): _on_esc_save_pressed("manual_2"))
		vbox.add_child(btn_save2)
	else:
		## 不可存档场景：显示提示文字，让玩家知道原因
		var no_save_label := Label.new()
		no_save_label.text = "（此地气息紊乱，无法刻录神识）"
		no_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_save_label.add_theme_font_size_override("font_size", 13)
		no_save_label.add_theme_color_override("font_color", Color(0.50, 0.45, 0.38, 0.8))
		vbox.add_child(no_save_label)

	## 设置按钮（始终显示）
	var btn_settings := _create_esc_btn("设置")
	btn_settings.pressed.connect(_open_settings_panel)
	vbox.add_child(btn_settings)

	## 返回主菜单按钮（始终显示）
	var btn_menu := _create_esc_btn("返回主菜单")
	btn_menu.pressed.connect(_on_esc_return_menu_pressed)
	vbox.add_child(btn_menu)


## 关闭ESC菜单，恢复游戏
func _close_esc_menu() -> void:
	if not _esc_open:
		return
	_close_esc_confirm()
	_close_settings_panel()  ## 同步关闭设置面板，防止状态泄漏
	if is_instance_valid(_esc_panel):
		_esc_panel.queue_free()
		_esc_panel = null
	_esc_open = false
	_update_pause_state()


## 创建ESC菜单统一风格按钮（风格由 ThemeManager 全局主题提供）
func _create_esc_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(200, 40)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 16)
	return btn


# ── 存档逻辑 ──────────────────────────────────────────────────

## 存档按钮点击：空槽直接存，有存档弹确认
func _on_esc_save_pressed(slot_name: String) -> void:
	if GameData.has_save(slot_name):
		## 槽位已有存档，弹二次确认
		var mode := "overwrite_1" if slot_name == "manual_1" else "overwrite_2"
		var slot_idx = "一" if slot_name == "manual_1" else "二"
		_build_esc_confirm(
			"槽位%s已有存档，\n确认覆盖吗？" % slot_idx,
			mode
		)
	else:
		## 空槽直接存入
		_do_save(slot_name)


## 执行实际存档
func _do_save(slot_name: String) -> void:
	## 存档前记录玩家当前坐标（供读档后恢复位置）
	var scene = get_tree().current_scene
	if scene:
		var player = scene.get_node_or_null("Player")
		if player:
			GameData.saved_player_position = player.global_position
	GameData.save_to_file(slot_name)
	## JSON序列化后取Hash，避免嵌套结构引用地址不同导致误判
	_last_saved_hash = JSON.stringify(GameData.save_data()).hash()
	## UI反馈：更新按钮文字为已保存，不立刻关闭菜单，让玩家看到反馈
	var slot_idx: String = "一" if slot_name == "manual_1" else "二"
	if is_instance_valid(_esc_panel):
		var vbox := _esc_panel.get_node_or_null("VBoxContainer")
		if vbox:
			for child in vbox.get_children():
				if child is Button and slot_idx in child.text:
					child.text = "槽位%s · 已保存 ✓" % slot_idx
					child.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 1.0))
					break


# ── 返回主菜单逻辑 ────────────────────────────────────────────

func _on_esc_return_menu_pressed() -> void:
	## JSON字符串Hash对比：当前数据与最后存档完全一致则直接放行
	if JSON.stringify(GameData.save_data()).hash() == _last_saved_hash:
		_do_return_menu()
		return
	_build_esc_confirm(
		"确认返回主菜单？\n当前未保存的进度将丢失。",
		"return_menu"
	)


func _do_return_menu() -> void:
	## 强制重置背包/功法面板状态，防止 _bag_open/_skill_open 残留导致主菜单卡死
	if _bag_open:
		_bag_open = false
		if is_instance_valid(_bag_panel):
			_bag_panel.hide()
	if _skill_open:
		_skill_open = false
		if is_instance_valid(_skill_panel):
			_skill_panel.hide()
	_close_esc_menu()
	SceneTransition.change_scene("res://scenes/MainMenuScene.tscn")


# ── 共用确认面板 ──────────────────────────────────────────────

func _build_esc_confirm(msg_text: String, mode: String) -> void:
	if is_instance_valid(_esc_confirm_panel):
		return
	_esc_confirm_mode = mode

	_esc_confirm_panel = Panel.new()
	_esc_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_esc_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_esc_confirm_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_esc_confirm_panel.offset_left   = -150.0
	_esc_confirm_panel.offset_top    = -80.0
	_esc_confirm_panel.offset_right  = 150.0
	_esc_confirm_panel.offset_bottom = 80.0
	_esc_confirm_panel.process_mode  = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color            = ThemeManager.COLOR_PANEL_BG
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = ThemeManager.COLOR_PANEL_BORDER
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	_esc_confirm_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_esc_confirm_panel)

	var msg := Label.new()
	msg.text                 = msg_text
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg.offset_top   = 18.0
	msg.offset_left  = -130.0
	msg.offset_right = 130.0
	msg.add_theme_font_size_override("font_size", 15)
	msg.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 1.0))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_esc_confirm_panel.add_child(msg)

	var btn_ok := Button.new()
	btn_ok.text         = "确认"
	btn_ok.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_ok.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_ok.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_ok.offset_left   = -120.0
	btn_ok.offset_top    = -52.0
	btn_ok.offset_right  = -4.0
	btn_ok.offset_bottom = -12.0
	btn_ok.add_theme_font_size_override("font_size", 15)
	btn_ok.pressed.connect(_on_esc_confirm_ok)
	_esc_confirm_panel.add_child(btn_ok)

	var btn_cancel := Button.new()
	btn_cancel.text         = "取消"
	btn_cancel.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_cancel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_cancel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_cancel.offset_left   = 4.0
	btn_cancel.offset_top    = -52.0
	btn_cancel.offset_right  = 120.0
	btn_cancel.offset_bottom = -12.0
	btn_cancel.add_theme_font_size_override("font_size", 15)
	btn_cancel.pressed.connect(_close_esc_confirm)
	_esc_confirm_panel.add_child(btn_cancel)


func _close_esc_confirm() -> void:
	if is_instance_valid(_esc_confirm_panel):
		_esc_confirm_panel.queue_free()
		_esc_confirm_panel = null
	_esc_confirm_mode = ""


func _on_esc_confirm_ok() -> void:
	var mode := _esc_confirm_mode
	_close_esc_confirm()
	match mode:
		"overwrite_1":
			_do_save("manual_1")
		"overwrite_2":
			_do_save("manual_2")
		"return_menu":
			_do_return_menu()


func _update_saved_hash() -> void:
	_last_saved_hash = JSON.stringify(GameData.save_data()).hash()


# ══════════════════════════════════════════════════════
# 设置面板（挂在ESC菜单的"设置"子项）
# ══════════════════════════════════════════════════════

const SETTINGS_FILE := "user://settings.json"

## 设置项默认值
var text_speed: int = 1     ## 0=慢 1=中 2=快
var font_scale: int = 1     ## 0=小 1=中 2=大
var dialogue_skip: bool = false  ## 已读对话快进

var _settings_panel: Panel = null


func load_settings_from_file() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		return
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return
	var data: Dictionary = json.data
	text_speed    = int(data.get("text_speed", text_speed))
	font_scale    = int(data.get("font_scale", font_scale))
	dialogue_skip = bool(data.get("dialogue_skip", dialogue_skip))
	## 把音量注入 AudioManager（统一由本文件管理设置文件）
	if data.has("bgm_volume"):
		AudioManager.set_bgm_volume(float(data["bgm_volume"]))
	if data.has("sfx_volume"):
		AudioManager.set_sfx_volume(float(data["sfx_volume"]))


func save_settings_to_file() -> void:
	## 合并 AudioManager 的音量设置一起写入
	var data := {
		"text_speed": text_speed,
		"font_scale": font_scale,
		"dialogue_skip": dialogue_skip,
		"bgm_volume": AudioManager.bgm_volume,
		"sfx_volume": AudioManager.sfx_volume,
	}
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## 打开设置面板
func _open_settings_panel() -> void:
	if is_instance_valid(_settings_panel):
		return

	_settings_panel = Panel.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_settings_panel.offset_left   = -180.0
	_settings_panel.offset_top    = -200.0
	_settings_panel.offset_right  = 180.0
	_settings_panel.offset_bottom = 200.0
	_settings_panel.process_mode  = Node.PROCESS_MODE_ALWAYS

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.078, 0.051, 0.149, 0.96)
	sb.border_color = Color(0.95, 0.90, 0.75, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	_settings_panel.add_theme_stylebox_override("panel", sb)
	_canvas.add_child(_settings_panel)

	## 标题（居中于面板宽度 360px）
	var title := Label.new()
	title.text = "── 设  置 ──"
	title.position = Vector2(0.0, 12.0)
	title.size     = Vector2(360.0, 26.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 1.0))
	_settings_panel.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(24.0, 44.0)
	vbox.size = Vector2(312.0, 332.0)
	vbox.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(vbox)

	## 文字速度
	_add_settings_row(vbox, "文字速度", ["慢", "中", "快"], text_speed,
		func(idx):
			text_speed = idx
			save_settings_to_file())

	## 字号大小
	_add_settings_row(vbox, "字号大小", ["小", "中", "大"], font_scale,
		func(idx):
			font_scale = idx
			save_settings_to_file()
			apply_font_scale())

	## 对话快进
	var skip_idx: int = 1 if dialogue_skip else 0
	_add_settings_row(vbox, "已读对话快进", ["关", "开"], skip_idx,
		func(idx):
			dialogue_skip = (idx == 1)
			save_settings_to_file())

	## 分隔线
	var sep := ColorRect.new()
	sep.color = Color(0.95, 0.90, 0.75, 0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	## BGM 音量
	_add_volume_row(vbox, "背景音乐", AudioManager.bgm_volume,
		func(v):
			AudioManager.set_bgm_volume(v)
			save_settings_to_file())

	## SFX 音量
	_add_volume_row(vbox, "音       效", AudioManager.sfx_volume,
		func(v):
			AudioManager.set_sfx_volume(v)
			save_settings_to_file())

	## 关闭按钮
	var btn_close := Button.new()
	btn_close.text = "关  闭"
	btn_close.custom_minimum_size = Vector2(120, 36)
	btn_close.position = Vector2(120.0, 350.0)
	btn_close.pressed.connect(_close_settings_panel)
	_settings_panel.add_child(btn_close)


## 添加一个三段切换的设置行
func _add_settings_row(parent: VBoxContainer, label_text: String,
		options: Array, current_idx: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 1.0))
	row.add_child(lbl)

	var btn_group: Array[Button] = []
	for i in options.size():
		var btn := Button.new()
		btn.text = options[i]
		btn.custom_minimum_size = Vector2(50, 28)
		btn.toggle_mode = true
		btn.button_pressed = (i == current_idx)
		row.add_child(btn)
		btn_group.append(btn)

	## 互斥逻辑（用 bind 显式传 idx，避免 GDScript for-var 闭包捕获歧义）
	for i in btn_group.size():
		var btn := btn_group[i]
		btn.pressed.connect(_on_settings_btn_pressed.bind(i, btn_group, on_change))


## 设置三段切换按钮的统一回调（idx 通过 bind 传入，避免闭包歧义）
func _on_settings_btn_pressed(idx: int, btn_group: Array, on_change: Callable) -> void:
	for j in btn_group.size():
		btn_group[j].button_pressed = (j == idx)
	on_change.call(idx)
	AudioManager.play_sfx("button_click")


## 添加音量滑条行
func _add_volume_row(parent: VBoxContainer, label_text: String,
		current_value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 1.0))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = current_value
	slider.custom_minimum_size = Vector2(160, 24)
	row.add_child(slider)

	var pct_label := Label.new()
	pct_label.text = "%d%%" % roundi(current_value * 100)
	pct_label.custom_minimum_size = Vector2(40, 0)
	pct_label.add_theme_font_size_override("font_size", 12)
	pct_label.add_theme_color_override("font_color", Color(0.83, 0.66, 0.34, 1.0))
	row.add_child(pct_label)

	slider.value_changed.connect(func(v):
		pct_label.text = "%d%%" % roundi(v * 100)
		on_change.call(v))


## 获取当前字号缩放系数（对话框等可调用）
## 0=小(0.85x), 1=中(1.0x), 2=大(1.20x)
func get_font_scale_factor() -> float:
	match font_scale:
		0:  return 0.85
		1:  return 1.0
		2:  return 1.20
		_:  return 1.0


## 应用字号缩放：触发 font_scale_changed 信号让监听的 UI 组件自行刷新
func apply_font_scale() -> void:
	font_scale_changed.emit(get_font_scale_factor())


func _close_settings_panel() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
		_settings_panel = null


## 获取当前文字速度对应的逐字间隔（供DialogueBox使用）
func get_dialogue_char_interval() -> float:
	match text_speed:
		0:  return 0.06   ## 慢
		1:  return 0.03   ## 中
		2:  return 0.01   ## 快
		_:  return 0.03
