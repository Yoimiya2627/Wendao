## BattleUI.gd
## 战斗界面控制器
## 启动流程：morning → market → test → temple → [trigger_battle 事件]
##            → 战斗 → after_battle → (选择分支) → letter / 章末
extends Control

# ── 节点引用 ─────────────────────────────────────────────────
@onready var enemy_name_label : Label          = $EnemyPanel/EnemyNameLabel
@onready var enemy_hp_bar     : ProgressBar    = $EnemyPanel/EnemyHPBar
@onready var enemy_hp_label   : Label          = $EnemyPanel/EnemyHPLabel

@onready var player_name_label: Label          = $PlayerPanel/PlayerNameLabel
@onready var player_hp_bar    : ProgressBar    = $PlayerPanel/PlayerHPBar
@onready var player_hp_label  : Label          = $PlayerPanel/PlayerHPLabel

@onready var attack_button    : Button         = $SkillPanel/AttackButton
@onready var skill_button     : Button         = $SkillPanel/SkillButton
@onready var defend_button    : Button         = $SkillPanel/DefendButton

@onready var log_text         : RichTextLabel  = $LogPanel/LogText

# ── 战斗状态 ─────────────────────────────────────────────────
var _battle : BattleManager = null
var _enemy  : Character     = null

# ── 对话链：按顺序播放，temple 后由 trigger_battle 事件接管 ───
const DIALOGUE_CHAIN: Array[String] = ["morning", "market", "test", "temple"]


func _ready() -> void:
	_set_buttons_disabled(true)

	# 连接技能按钮
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	defend_button.pressed.connect(_on_defend_pressed)

	# 订阅 DialogueManager 信号
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.event_triggered.connect(_on_event_triggered)

	# 战斗 UI 先隐藏，等 trigger_battle 事件再显示
	_show_battle_ui(false)

	# 启动第一幕对话
	DialogueManager.start_scene("morning")


# ── 对话链控制 ────────────────────────────────────────────────

## 一个对话场景结束后，自动推进到链中的下一个
## temple 结束后不自动续接——等 trigger_battle 事件触发战斗
func _on_dialogue_ended(scene_id: String) -> void:
	var idx: int = DIALOGUE_CHAIN.find(scene_id)
	if idx >= 0 and idx + 1 < DIALOGUE_CHAIN.size():
		DialogueManager.start_scene(DIALOGUE_CHAIN[idx + 1])


## 响应对话内嵌事件
func _on_event_triggered(event_name: String) -> void:
	match event_name:

		"trigger_battle":
			# 废庙战斗触发：切入战斗界面
			_show_battle_ui(true)
			_start_battle()

		"return_home":
			# 玩家选择先回家：播放家书场景
			DialogueManager.start_scene("letter")

		"chapter_end_path_a":
			# 结局 A：与顾飞白同行
			_show_chapter_end("一路向前，问道长生。")

		"chapter_end_path_b":
			# 结局 B：带着爹的信出发
			_show_chapter_end("带着爹的信，她出发了。")


# ── 战斗初始化 ────────────────────────────────────────────────

func _start_battle() -> void:
	_enemy  = Character.new("妖兽", 80, 12, 3)
	_battle = BattleManager.new()

	_battle.turn_changed.connect(_on_turn_changed)
	_battle.battle_log.connect(_on_battle_log)
	_battle.battle_ended.connect(_on_battle_ended)

	_refresh_player_hp()
	_refresh_enemy_hp()
	_battle.setup(GameData.player, _enemy)


# ── HP 刷新 ──────────────────────────────────────────────────

func _refresh_player_hp() -> void:
	var p: Character = GameData.player
	player_name_label.text  = p.char_name
	player_hp_bar.max_value = p.max_hp
	player_hp_bar.value     = p.hp
	player_hp_label.text    = "HP: %d / %d" % [p.hp, p.max_hp]
	player_hp_bar.modulate  = Color(1.0, 0.3, 0.3) if float(p.hp) / p.max_hp < 0.3 else Color.WHITE


func _refresh_enemy_hp() -> void:
	enemy_name_label.text  = _enemy.char_name
	enemy_hp_bar.max_value = _enemy.max_hp
	enemy_hp_bar.value     = _enemy.hp
	enemy_hp_label.text    = "HP: %d / %d" % [_enemy.hp, _enemy.max_hp]
	enemy_hp_bar.modulate  = Color(1.0, 0.3, 0.3) if float(_enemy.hp) / _enemy.max_hp < 0.3 else Color.WHITE


# ── 技能按钮回调 ─────────────────────────────────────────────

func _on_attack_pressed() -> void:
	_battle.player_action(BattleManager.ActionType.ATTACK)
	_refresh_player_hp()
	_refresh_enemy_hp()


func _on_skill_pressed() -> void:
	_battle.player_action(BattleManager.ActionType.HEAL)
	_refresh_player_hp()
	_refresh_enemy_hp()


func _on_defend_pressed() -> void:
	_battle.player_action(BattleManager.ActionType.SKIP)
	_refresh_player_hp()
	_refresh_enemy_hp()


# ── BattleManager 信号回调 ───────────────────────────────────

func _on_turn_changed(state: BattleManager.TurnState) -> void:
	_set_buttons_disabled(state != BattleManager.TurnState.PLAYER_TURN)


func _on_battle_log(message: String) -> void:
	log_text.append_text(message + "\n")


func _on_battle_ended(player_won: bool) -> void:
	_set_buttons_disabled(true)

	if player_won:
		log_text.append_text(
			"\n[color=gold]【 斩妖除魔，道心更进一步！获得 50 经验、20 灵石。】[/color]\n")
		GameData.gain_exp(50)
		GameData.gain_gold(20)
		# 停顿 1.5 秒让玩家看到战斗结果，再切回对话
		await get_tree().create_timer(1.5).timeout
		_show_battle_ui(false)
		DialogueManager.start_scene("after_battle")
	else:
		log_text.append_text(
			"\n[color=red]【 落败，修为受损，就此离去。】[/color]\n")


# ── 内部辅助 ─────────────────────────────────────────────────

func _set_buttons_disabled(disabled: bool) -> void:
	attack_button.disabled = disabled
	skill_button.disabled  = disabled
	defend_button.disabled = disabled


## 切换战斗 UI 四个面板的可见性（对话期间隐藏，战斗期间显示）
func _show_battle_ui(show_ui: bool) -> void:
	$EnemyPanel.visible  = show_ui
	$PlayerPanel.visible = show_ui
	$LogPanel.visible    = show_ui
	$SkillPanel.visible  = show_ui


## 章节结束：在屏幕中央叠加一个半透明遮罩和提示文字
func _show_chapter_end(subtitle: String) -> void:
	# 深色遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 章末文字
	var label := Label.new()
	label.text = "——  第一幕  终  ——\n\n" + subtitle
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 30)
	add_child(label)
