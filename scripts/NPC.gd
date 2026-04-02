## NPC.gd
## NPC 基础脚本：靠近显示名字，按 E 触发对话
extends Node2D

## 显示在头顶的名字
@export var npc_name: String = "NPC名"
## 对应 DialogueManager 的场景 ID，空字符串则沉默
@export var dialogue_scene_id: String = ""
## 占位方块颜色，在编辑器/场景实例中可覆盖
@export var body_color: Color = Color(0.70, 0.50, 0.20)
## 触发对话所需的最低剧情阶段（-1 表示不限制）
@export var required_phase: int = -1

@onready var _label : Label     = $NameLabel
@onready var _body  : Polygon2D = $Body


func _ready() -> void:
	_label.text = npc_name
	_label.hide()
	_body.color = body_color


# ── 由 Player 调用 ───────────────────────────────────────────

## 玩家进入范围后显示头顶名字
func show_name_label() -> void:
	_label.show()


## 玩家离开范围后隐藏名字
func hide_name_label() -> void:
	_label.hide()


## 玩家按 E 时触发对话
func interact() -> void:
	print("E pressed, starting dialogue: npc=", npc_name, " scene_id=", dialogue_scene_id)
	if dialogue_scene_id.is_empty():
		return
	if DialogueManager.is_active:
		return
	# 剧情阶段不够时拒绝触发
	if required_phase >= 0 and GameData.story_phase < required_phase:
		print("NPC %s: 需要 phase %d，当前 phase %d，暂不触发" % [npc_name, required_phase, GameData.story_phase])
		return
	DialogueManager.start_scene(dialogue_scene_id)
