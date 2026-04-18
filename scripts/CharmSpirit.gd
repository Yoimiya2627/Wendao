## CharmSpirit.gd
## 平安符器灵——符灵·第一章硬编码版
## 全程不调 API，所有反应基于 GameData flags 查表
## AutoLoad 单例，在 project.godot 中注册
extends Node

const _FONT_REGULAR := preload("res://assets/fonts/NotoSerifSC-Regular.ttf")

## 屏顶耳语 UI 节点
var _whisper_canvas : CanvasLayer
var _whisper_label  : Label
var _whisper_tween  : Tween

## ── 耳语变体表 ───────────────────────────────────────────────
## 每条: [条件key, 条件值, 文案]
## 条件key特殊值：
##   "_default"   永远匹配（兜底）
##   "_has_items" 检查 heal_potions+incenses+talismans > 0
##   其他字符串   在 GameData.narrative_flags 里查
const _WHISPER_LINES := {
	"after_test_fail": [
		["town_paid_old_lady", true,  "……别难过。"],
		["_default",           true,  "……空空的，是吧。"],
	],
	"after_father_talk": [
		["town_paid_old_lady", true,  "你父亲是好人。但他不知道你今天有多重。"],
		["_default",           true,  "你哽住了什么？嘴是用来说话的。"],
	],
	"before_temple": [
		["_has_items", true,  "你做了准备。这是大人会做的事。"],
		["_default",   true,  "你两手空空。是不怕，还是没在意？"],
	],
}

## ── 章末尾声台词库 ───────────────────────────────────────────
## key = "{path}_{paid/not_paid}"
const _CODA := {
	"a_paid": [
		"丫头。",
		"你出门时，心是软的。回来时，多了一道钢。",
		"这条路苦。但你能走完。",
	],
	"a_not_paid": [
		"你拿走我的时候，没多看那位老人一眼。",
		"我以为你是冷的。后来我才知道，你只是不会示弱。",
		"往前走吧。我跟着。",
	],
	"b_paid": [
		"家是先要顾的。",
		"你不是在逃。你是在记住。",
		"明天天亮，再走也不晚。",
	],
	"b_not_paid": [
		"你回头了。",
		"我以为像你这样的人不会回头。",
		"……我看错了。这一步，比往前难。",
	],
}

## 所有分支共用的收束句
const _CODA_CLOSING := "……记得今天。以后会想念这一刻的。"


func _ready() -> void:
	_build_whisper_ui()


func _build_whisper_ui() -> void:
	_whisper_canvas = CanvasLayer.new()
	_whisper_canvas.layer = 60  # 对话框(10)之上，SceneTransition(128)之下
	_whisper_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_whisper_canvas)

	_whisper_label = Label.new()
	_whisper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_whisper_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_whisper_label.offset_top    = 24.0
	_whisper_label.offset_bottom = 64.0
	_whisper_label.add_theme_font_override("font", _FONT_REGULAR)
	_whisper_label.add_theme_font_size_override("font_size", 16)
	_whisper_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 0.0))
	_whisper_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whisper_canvas.add_child(_whisper_label)


# ── 对外接口 ─────────────────────────────────────────────────

## 触发屏顶耳语（不打断行走/对话框），每个 stage 只触发一次
func try_whisper(stage: String) -> void:
	if not GameData.got_charm:
		return
	if _already_done(stage):
		return
	var text := _pick_line(stage)
	if text.is_empty():
		return
	_mark_done(stage)
	_show_whisper(text)


## 返回章末尾声台词数组（3 句分支 + 1 句收束），供 ChapterEndScene 自行播放
## got_charm == false 时返回空数组
func get_chapter_end_coda() -> Array[String]:
	if not GameData.got_charm:
		return []
	var path  := GameData.chapter_end_path
	var paid  := GameData.narrative_flags.get("town_paid_old_lady", false)
	var key   := ("a" if path != "b" else "b") + ("_paid" if paid else "_not_paid")
	var lines : Array[String] = []
	for l: String in _CODA.get(key, _CODA["a_not_paid"]):
		lines.append(l)
	lines.append(_CODA_CLOSING)
	return lines


# ── 内部逻辑 ─────────────────────────────────────────────────

func _pick_line(stage: String) -> String:
	var variants: Array = _WHISPER_LINES.get(stage, [])
	for v in variants:
		var cond_key : String = v[0]
		var cond_val          = v[1]
		var text     : String = v[2]
		match cond_key:
			"_default":
				return text
			"_has_items":
				var has := (GameData.heal_potions + GameData.incenses + GameData.talismans) > 0
				if has == cond_val:
					return text
			_:
				if GameData.narrative_flags.get(cond_key, false) == cond_val:
					return text
	return ""


func _show_whisper(text: String) -> void:
	if _whisper_tween:
		_whisper_tween.kill()
	_whisper_label.text = text
	_whisper_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 0.0))

	_whisper_tween = create_tween()
	_whisper_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_whisper_tween.tween_property(
		_whisper_label, "theme_override_colors/font_color:a", 0.82, 0.9
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_whisper_tween.tween_interval(2.2)
	_whisper_tween.tween_property(
		_whisper_label, "theme_override_colors/font_color:a", 0.0, 1.1
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _already_done(stage: String) -> bool:
	return GameData.charm_spoken_stages.has(stage)


func _mark_done(stage: String) -> void:
	if not GameData.charm_spoken_stages.has(stage):
		GameData.charm_spoken_stages.append(stage)
