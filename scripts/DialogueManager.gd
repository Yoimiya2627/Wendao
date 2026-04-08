## DialogueManager.gd
## 对话管理器 AutoLoad 单例
## 负责加载 JSON 对话数据、推进节点、处理选择分支与事件触发
## 使用方式：调用 start_scene("scene_id") 启动，订阅信号驱动 UI 与游戏逻辑
extends Node

# ── 信号 ─────────────────────────────────────────────────────
## 场景对话开始，传递场景 ID
signal dialogue_started(scene_id: String)
## 场景对话结束，传递场景 ID
signal dialogue_ended(scene_id: String)
## 当前节点变化（UI 应订阅此信号更新显示）
signal node_changed(node: Dictionary)
## 玩家做出选择，传递所选索引
signal choice_made(choice_index: int)
## 节点内嵌事件触发（战斗、场景跳转等游戏逻辑由外部响应）
signal event_triggered(event_name: String)

# ── 对话数据 ──────────────────────────────────────────────────
var _all_data: Dictionary = {}       ## 从 JSON 加载的全量数据

# ── 运行时状态 ────────────────────────────────────────────────
var _current_scene_id: String = ""   ## 当前场景 ID
var _current_scene: Dictionary = {}  ## 当前场景完整数据
var _current_node: Dictionary = {}   ## 当前对话节点数据

## 对话是否进行中（供外部查询，如禁用移动输入）
var is_active: bool = false
## 是否正在等待玩家选择（此时 advance() 无效）
var waiting_for_choice: bool = false
## 是否正在等待阻塞型事件完成（切场/战斗等）；为 true 时 advance() 被拦截
var is_waiting_event_finish: bool = false

# DialogueBox 节点缓存（懒加载，避免重复 find_child）
var _dialogue_box: Node = null


func _ready() -> void:
	_load_data("res://data/chapter1.json")


# ── 公共 API ─────────────────────────────────────────────────

## 启动指定 ID 的对话场景
func start_scene(scene_id: String) -> void:
	if not _all_data.has("scenes") or not _all_data["scenes"].has(scene_id):
		push_error("DialogueManager: 未找到场景 '%s'" % scene_id)
		return

	_current_scene_id  = scene_id
	_current_scene     = _all_data["scenes"][scene_id]
	is_active               = true
	waiting_for_choice      = false
	is_waiting_event_finish = false

	dialogue_started.emit(scene_id)
	var db := _get_dialogue_box()
	if db: db.on_dialogue_started(scene_id)
	else: push_error("DialogueManager: 未找到 DialogueBox 节点")

	_go_to_node(_current_scene["start"])


## 推进到下一节点（普通对话节点调用；选择等待时无效）
func advance() -> void:
	if not is_active or waiting_for_choice or is_waiting_event_finish:
		return

	var next_id: String = _current_node.get("next", "")
	if next_id.is_empty():
		_end_scene()
	else:
		_go_to_node(next_id)


## 处理玩家选择，choice_index 为 choices 数组的下标
func make_choice(choice_index: int) -> void:
	if not waiting_for_choice:
		push_warning("DialogueManager: 当前不在等待选择状态，忽略。")
		return

	var choices: Array = _current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		push_warning("DialogueManager: 选择索引 %d 越界（共 %d 项）" % [choice_index, choices.size()])
		return

	var chosen: Dictionary = choices[choice_index]
	waiting_for_choice = false
	choice_made.emit(choice_index)

	# 选项本身可携带附加事件（如标记旗帜）
	var choice_event: String = chosen.get("event", "")
	if not choice_event.is_empty():
		event_triggered.emit(choice_event)

	var next_id: String = chosen.get("next", "")
	if next_id.is_empty():
		_end_scene()
	else:
		_go_to_node(next_id)


## 由外部系统（黑屏完成、战斗结束等）调用，释放阻塞型事件锁并继续推进对话
func finish_event() -> void:
	if not is_waiting_event_finish:
		push_warning("DialogueManager: finish_event() 调用时并无阻塞事件在等待，忽略。")
		return
	is_waiting_event_finish = false
	advance()


## 获取当前节点数据（供 UI 查询 choices 等字段）
func get_current_node() -> Dictionary:
	return _current_node


## 获取指定场景的显示标题
func get_scene_title(scene_id: String) -> String:
	if _all_data.has("scenes") and _all_data["scenes"].has(scene_id):
		return _all_data["scenes"][scene_id].get("title", "")
	return ""


## 查询某场景是否存在
func has_scene(scene_id: String) -> bool:
	return _all_data.has("scenes") and _all_data["scenes"].has(scene_id)


# ── 内部：数据加载 ────────────────────────────────────────────

## 从 JSON 文件读取全量对话数据
func _load_data(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: 找不到对话文件 '%s'" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: 无法打开文件 '%s'，错误码 %d" % [path, FileAccess.get_open_error()])
		return

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err  := json.parse(raw)
	if err != OK:
		push_error("DialogueManager: JSON 解析失败（行 %d）：%s" % [
			json.get_error_line(), json.get_error_message()])
		return

	_all_data = json.data
	var scene_count: int = _all_data.get("scenes", {}).size()
	print("DialogueManager: 对话数据加载完毕，共 %d 个场景" % scene_count)


# ── 内部：节点导航 ────────────────────────────────────────────

## 跳转到指定 ID 的节点
## 事件节点使用 await 异步推进，避免阻塞调用帧
func _go_to_node(node_id: String) -> void:
	var nodes: Dictionary = _current_scene.get("nodes", {})
	if not nodes.has(node_id):
		push_error("DialogueManager: 场景 '%s' 中找不到节点 '%s'" % [_current_scene_id, node_id])
		_end_scene()
		return

	_current_node = nodes[node_id]
	var node_type: String = _current_node.get("type", "dialogue")

	match node_type:
		"event":
			# 事件节点：默认全部视为阻塞型事件，由外部调用 finish_event() 释放
			var evt: String = _current_node.get("event", "")
			if not evt.is_empty():
				is_waiting_event_finish = true
				event_triggered.emit(evt)
				# 不再自动 advance()；控制权交给外部系统
			else:
				## 空事件节点兜底：直接推进，防止对话假死
				advance()

		"choice":
			# 选择节点：锁定推进，等待玩家调用 make_choice()
			waiting_for_choice = true
			node_changed.emit(_current_node)
			var db_c := _get_dialogue_box()
			if db_c: db_c.on_node_changed(_current_node)

		_:
			# dialogue / narration：正常发出信号，由 UI 驱动推进
			node_changed.emit(_current_node)
			var db_d := _get_dialogue_box()
			if db_d: db_d.on_node_changed(_current_node)


## 结束当前对话场景，重置所有状态
func _end_scene() -> void:
	is_active          = false
	waiting_for_choice = false
	var ended_id       := _current_scene_id

	_current_scene_id = ""
	_current_scene    = {}
	_current_node     = {}

	dialogue_ended.emit(ended_id)
	var db := _get_dialogue_box()
	if db: db.on_dialogue_ended(ended_id)


## 修复5：DialogueBox 在 _ready 中主动注册，此处直接返回缓存引用
func _get_dialogue_box() -> Node:
	return _dialogue_box
