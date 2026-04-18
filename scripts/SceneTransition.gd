extends CanvasLayer

# 场景切换管理器（AutoLoad 单例）
# 使用黑色遮罩实现淡入淡出效果，切换时长 0.3 秒

const FADE_DURATION := 0.3

## 场景根节点名称 → [BGM文件名, 淡入时长] 映射表
## 只登记 BGM 固定不变的场景；含条件分支的场景自行管理：
##   TownScene   : 白天/夜晚分差，由场景脚本判断
##   ShopScene   : story_phase 决定 BGM，由场景脚本判断
##   BattleScene : boss 阶段动态切换，由 BattleUI 管理
##   ChapterEndScene: play_bgm_once（不循环），由场景脚本管理
const SCENE_BGM_MAP: Dictionary = {
	"MainMenuScene" : ["main_menu",      1.5],
	"TeaScene"      : ["tea_house",      1.5],
	"TempleScene"   : ["temple_explore", 1.5],
}

var _overlay: ColorRect
var _tween: Tween
var _is_transitioning := false

## 公开只读属性：外部模块（如 Player）通过此属性查询切换状态，
## 避免直接访问 _is_transitioning 造成耦合
var is_transitioning: bool:
	get: return _is_transitioning


func _ready() -> void:
	## 确保场景切换动画在游戏暂停状态下仍能正常执行
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 置于最高层，确保遮罩覆盖所有内容
	layer = 128

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	add_child(_overlay)


## 切换到指定场景路径，带淡出→淡入效果
func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	## 切场景前强制终止对话，防止 DialogueManager.is_active 跨场景残留导致玩家卡死
	DialogueManager.force_stop()

	# 淡出：画面变黑。若上层（如 ShopScene 夜晚渐变）已把遮罩置为不透明，
	# 跳过本次淡出，避免 0.3s 纯黑屏的冗余等待。
	if _overlay.modulate.a < 0.99:
		await _fade(1.0)

	## 二次 force_stop：淡出期间旧场景的 _process 可能因状态变更
	## 而自动触发新对话（如 TownScene 的夜行旁白），导致 is_active 残留
	DialogueManager.force_stop()

	# 切换场景
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition: 无法加载场景 %s（错误码 %d）" % [path, err])
		# 出错也要把遮罩还原，避免画面卡黑
		await _fade(0.0)
		_is_transitioning = false
		return

	# 等待新场景完成初始化再淡入
	# 两帧等待：change_scene_to_file 内部用 call_deferred 换场景，
	# 第一帧可能在旧场景帧尾触发，第二帧确保新场景 _ready() 已执行完毕
	await get_tree().process_frame
	await get_tree().process_frame

	# 根据映射表自动播放 BGM（不在表中的场景自行管理）
	_auto_play_bgm()

	# 淡入：遮罩消失
	await _fade(0.0)

	_is_transitioning = false


## 内部：将遮罩透明度补间到目标值
func _fade(target_alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	## TWEEN_PAUSE_PROCESS：无论游戏是否暂停、节点process_mode如何，tween始终运行
	## 防止 finished 信号因暂停/帧异常而永久挂起，导致 _is_transitioning 无法重置
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	await _tween.finished


## 将遮罩直接设为完全不透明（供ShopScene夜晚渐变衔接使用）
func set_overlay_opaque() -> void:
	_overlay.modulate.a = 1.0


## 根据当前场景名称查表播放 BGM
## 不在 SCENE_BGM_MAP 中的场景静默跳过，由其自身脚本处理
func _auto_play_bgm() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if SCENE_BGM_MAP.has(scene.name):
		var entry: Array = SCENE_BGM_MAP[scene.name]
		AudioManager.play_bgm(entry[0], entry[1])
