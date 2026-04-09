## UIManager.gd
## 全局UI管理器 AutoLoad单例
## 负责常驻HP条、心绪面板、旧物背包三件套
## 战斗期间由BattleUI显式调用on_battle_start()/on_battle_end()控制显隐
extends Node

# ── 物品数据 ──────────────────────────────────────────────────
const ITEM_DATA := {
	"sword_tassel": {
		"name": "旧剑穗",
		"desc": "大鱼叼来的，不知道从哪捡的。\n穗子有点旧，但手感不错。"
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

var _mood_panel   : Panel
var _mood_text    : Label

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


func _ready() -> void:
	## 确保UIManager在游戏暂停状态下仍能响应ESC输入
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	style.bg_color              = Color(0.06, 0.04, 0.04, 0.88)
	style.border_width_bottom   = 1
	style.border_color          = Color(0.40, 0.32, 0.24, 0.6)
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
	_hp_name.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 1.0))
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
	_gold_text.add_theme_color_override("font_color", Color(0.85, 0.75, 0.40, 1.0))
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
	style.bg_color    = Color(0.06, 0.04, 0.04, 0.82)
	style.border_width_bottom = 1
	style.border_color        = Color(0.40, 0.32, 0.24, 0.5)
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

	## 分隔线
	var sep := ColorRect.new()
	sep.color    = Color(0.40, 0.32, 0.24, 0.4)
	sep.position = Vector2(8.0, 24.0)
	sep.size     = Vector2(164.0, 1.0)
	_mood_panel.add_child(sep)

	## 正文
	_mood_text = Label.new()
	_mood_text.position      = Vector2(10.0, 30.0)
	_mood_text.size          = Vector2(160.0, 140.0)
	_mood_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mood_text.add_theme_font_size_override("font_size", 13)
	_mood_text.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 1.0))
	_mood_panel.add_child(_mood_text)


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

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color  = Color(0.10, 0.08, 0.06, 0.90)
	btn_style.border_width_top    = 1
	btn_style.border_width_bottom = 1
	btn_style.border_width_left   = 1
	btn_style.border_width_right  = 1
	btn_style.border_color        = Color(0.45, 0.36, 0.24, 0.8)
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left  = 4
	_bag_button.add_theme_stylebox_override("normal",   btn_style)
	_bag_button.add_theme_stylebox_override("hover",    btn_style)
	_bag_button.add_theme_stylebox_override("pressed",  btn_style)
	_bag_button.add_theme_font_size_override("font_size", 14)
	_bag_button.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 1.0))
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
	panel_style.bg_color  = Color(0.07, 0.05, 0.04, 0.93)
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_color        = Color(0.45, 0.36, 0.24, 0.7)
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
	sep2.color    = Color(0.40, 0.32, 0.24, 0.4)
	sep2.position = Vector2(8.0, 26.0)
	sep2.size     = Vector2(188.0, 1.0)
	_bag_panel.add_child(sep2)

	## 6个格子（2行×3列）
	_bag_slots.clear()
	for i in 6:
		var col := i % 3
		var row := i / 3
		var slot := Button.new()
		slot.position = Vector2(8.0 + col * 64.0, 34.0 + row * 64.0)
		slot.size     = Vector2(58.0, 58.0)
		slot.clip_text = true

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color    = Color(0.10, 0.08, 0.07, 0.9)
		slot_style.border_width_top    = 1
		slot_style.border_width_bottom = 1
		slot_style.border_width_left   = 1
		slot_style.border_width_right  = 1
		slot_style.border_color        = Color(0.35, 0.28, 0.20, 0.6)
		slot_style.corner_radius_top_left     = 3
		slot_style.corner_radius_top_right    = 3
		slot_style.corner_radius_bottom_right = 3
		slot_style.corner_radius_bottom_left  = 3
		slot.add_theme_stylebox_override("normal",  slot_style)
		slot.add_theme_stylebox_override("hover",   slot_style)
		slot.add_theme_stylebox_override("pressed", slot_style)
		slot.add_theme_font_size_override("font_size", 12)
		slot.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 1.0))

		var idx := i
		slot.pressed.connect(func(): _on_slot_pressed(idx))
		_bag_panel.add_child(slot)
		_bag_slots.append(slot)

	## 描述区分隔线
	var sep3 := ColorRect.new()
	sep3.color    = Color(0.40, 0.32, 0.24, 0.4)
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

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color  = Color(0.10, 0.08, 0.06, 0.90)
	btn_style.border_width_top    = 1
	btn_style.border_width_bottom = 1
	btn_style.border_width_left   = 1
	btn_style.border_width_right  = 1
	btn_style.border_color        = Color(0.45, 0.36, 0.24, 0.8)
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left  = 4
	_skill_button.add_theme_stylebox_override("normal",   btn_style)
	_skill_button.add_theme_stylebox_override("hover",    btn_style)
	_skill_button.add_theme_stylebox_override("pressed",  btn_style)
	_skill_button.add_theme_font_size_override("font_size", 14)
	_skill_button.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 1.0))
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
	panel_style.bg_color  = Color(0.07, 0.05, 0.04, 0.93)
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_color        = Color(0.45, 0.36, 0.24, 0.7)
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
		slot.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 1.0))

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color    = Color(0.10, 0.08, 0.07, 0.9)
		slot_style.border_width_top    = 1
		slot_style.border_width_bottom = 1
		slot_style.border_width_left   = 1
		slot_style.border_width_right  = 1
		slot_style.border_color        = Color(0.35, 0.28, 0.20, 0.6)
		slot_style.corner_radius_top_left     = 3
		slot_style.corner_radius_top_right    = 3
		slot_style.corner_radius_bottom_right = 3
		slot_style.corner_radius_bottom_left  = 3
		slot.add_theme_stylebox_override("normal",  slot_style)
		slot.add_theme_stylebox_override("hover",   slot_style)
		slot.add_theme_stylebox_override("pressed", slot_style)

		var idx := i
		slot.pressed.connect(func(): _on_skill_slot_pressed(idx))
		_skill_panel.add_child(slot)
		_skill_slots.append(slot)

	var sep2 := ColorRect.new()
	sep2.color    = Color(0.40, 0.32, 0.24, 0.4)
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

## 确认面板（覆盖存档 / 返回主菜单 共用）
var _esc_confirm_panel : Panel  = null
var _esc_confirm_mode  : String = ""  ## "overwrite_1" / "overwrite_2" / "return_menu"
var _last_saved_hash   : int    = 0  ## 最后一次存档时的数据Hash，用于判断是否有未保存变更


func _input(event: InputEvent) -> void:
	## 主菜单场景不响应ESC
	var scene = get_tree().current_scene
	if scene and scene.name == "MainMenuScene":
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
	var scene_name: String = scene.name
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
	_esc_panel.offset_top    = -140.0
	_esc_panel.offset_right  = 140.0
	_esc_panel.offset_bottom = 140.0
	## 菜单自身必须设为ALWAYS，否则paused后无法响应输入
	_esc_panel.process_mode  = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.05, 0.04, 0.03, 0.96)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = Color(0.45, 0.36, 0.24, 0.8)
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
	sep.color    = Color(0.40, 0.32, 0.24, 0.4)
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
	vbox.offset_top    = -60.0
	vbox.offset_right  = 110.0
	vbox.offset_bottom = 110.0
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

	## 返回主菜单按钮（始终显示）
	var btn_menu := _create_esc_btn("返回主菜单")
	btn_menu.pressed.connect(_on_esc_return_menu_pressed)
	vbox.add_child(btn_menu)


## 关闭ESC菜单，恢复游戏
func _close_esc_menu() -> void:
	if not _esc_open:
		return
	_close_esc_confirm()
	if is_instance_valid(_esc_panel):
		_esc_panel.queue_free()
		_esc_panel = null
	_esc_open = false
	_update_pause_state()


## 创建ESC菜单统一风格按钮
func _create_esc_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(200, 40)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75, 1.0))

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.10, 0.08, 0.06, 0.85)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = Color(0.40, 0.32, 0.22, 0.6)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left  = 3
	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   style)
	btn.add_theme_stylebox_override("pressed", style)
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
	style.bg_color            = Color(0.06, 0.04, 0.04, 0.98)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_color        = Color(0.50, 0.38, 0.24, 0.9)
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
