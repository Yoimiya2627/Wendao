## BattleUI.gd
## 战斗界面控制器
## 三按钮：攻击 / 技能（展开子菜单）/ 感应
## 技能子菜单：蓄势（初始）/ 淬血（始终可用）/ 感应（stones_read≥1）
extends Control

# ── 节点引用 ─────────────────────────────────────────────────
@onready var enemy_name_label : Label         = $EnemyPanel/EnemyNameLabel
@onready var enemy_hp_bar     : ProgressBar   = $EnemyPanel/EnemyHPBar
@onready var enemy_hp_label   : Label         = $EnemyPanel/EnemyHPLabel

@onready var player_name_label: Label         = $PlayerPanel/PlayerNameLabel
@onready var player_hp_bar    : ProgressBar   = $PlayerPanel/PlayerHPBar
@onready var player_hp_label  : Label         = $PlayerPanel/PlayerHPLabel

@onready var attack_button    : Button        = $SkillPanel/AttackButton
@onready var skill_button     : Button        = $SkillPanel/SkillButton
@onready var defend_button    : Button        = $SkillPanel/DefendButton
@onready var item_button      : Button        = $SkillPanel/ItemButton

@onready var log_text         : RichTextLabel = $LogPanel/LogText

# ── 战斗状态 ─────────────────────────────────────────────────
var _battle : BattleManager = null
var _enemy  : Character     = null

## 技能子菜单是否展开
var _skill_menu_open: bool = false
## 动态创建的技能子菜单节点
var _skill_menu: Control = null

## BOSS第二阶段是否已触发旁白
var _phase2_dialogue_done: bool = false


func _ready() -> void:
	## 通知UIManager进入战斗，隐藏常驻UI
	UIManager.on_battle_start()
	_set_buttons_disabled(true)

	## 主按钮连接
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_menu_toggle)
	defend_button.pressed.connect(_on_defend_pressed)
	item_button.pressed.connect(_on_item_pressed)

	## 订阅DialogueManager信号
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.event_triggered.connect(_on_event_triggered)

	## 按钮重命名
	attack_button.text = "攻击"
	skill_button.text  = "技能 ▲"
	defend_button.text = "感应"

	_show_battle_ui(true)
	_start_battle()


func _exit_tree() -> void:
	## 断开 AutoLoad 单例信号，防止跨场景泄漏
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	if DialogueManager.event_triggered.is_connected(_on_event_triggered):
		DialogueManager.event_triggered.disconnect(_on_event_triggered)


# ── 对话链控制 ────────────────────────────────────────────────

## 对话结束回调：BOSS演出旁白结束后恢复按钮
func _on_dialogue_ended(scene_id: String) -> void:
	match scene_id:
		"boss_phase2_start":
			## 第二阶段旁白结束，恢复战斗按钮
			_set_buttons_disabled(false)
		"boss_awakening":
			## 觉醒独白结束，胜利切场景
			GameData.battle_won = true
			UIManager.on_battle_end()
			await get_tree().create_timer(0.5).timeout
			if not is_inside_tree():
				return
			SceneTransition.change_scene("res://scenes/TempleScene.tscn")
		"battle_loss":
			## 失败独白结束，切回废庙安全坐标
			UIManager.on_battle_end()
			await get_tree().create_timer(0.5).timeout
			if not is_inside_tree():
				return
			SceneTransition.change_scene("res://scenes/TempleScene.tscn")

## 对话事件回调
func _on_event_triggered(_event_name: String) -> void:
	DialogueManager.finish_event()


# ── 战斗初始化 ────────────────────────────────────────────────

func _start_battle() -> void:
	var enemy_name: String = GameData.current_enemy_data.get("name", "妖兽")
	var enemy_hp: int      = GameData.current_enemy_data.get("hp", 80)
	var enemy_atk: int     = GameData.current_enemy_data.get("atk", 12)
	var enemy_def: int     = GameData.current_enemy_data.get("def", 3)
	_enemy = Character.new(enemy_name, enemy_hp, enemy_atk, enemy_def)
	_battle = BattleManager.new()

	_battle.turn_changed.connect(_on_turn_changed)
	_battle.battle_log.connect(_on_battle_log)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.boss_phase2_started.connect(_on_boss_phase2_started)
	_battle.awakening_triggered.connect(_on_awakening_triggered)
	_battle.ready_for_awakening.connect(_on_ready_for_awakening)

	_battle.setup(GameData.player, _enemy)
	_refresh_all_hp()

	## 开局延迟：让玩家看到满状态画面后再开始第一个回合
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or _battle == null:
		return
	_battle.turn_start()


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


## 统一刷新双方HP（敌方行动结束后调用）
func _refresh_all_hp() -> void:
	_refresh_player_hp()
	_refresh_enemy_hp()
	UIManager.refresh_hp()
	_refresh_item_button()


# ── 主按钮回调 ───────────────────────────────────────────────

func _on_attack_pressed() -> void:
	_close_skill_menu()
	_battle.player_action(BattleManager.ActionType.ATTACK)
	_refresh_all_hp()


## 道具按钮：使用伤药
func _on_item_pressed() -> void:
	_close_skill_menu()
	_battle.player_action(BattleManager.ActionType.USE_POTION)
	_refresh_all_hp()


## 刷新道具按钮状态：文字、可用性
func _refresh_item_button() -> void:
	item_button.text = "伤药 (×%d)" % GameData.heal_potions
	var p := GameData.player
	var can_use: bool = (
		GameData.heal_potions > 0
		and p.hp < p.max_hp
	)
	item_button.disabled = not can_use


## 防御按钮：对应感应技能
func _on_defend_pressed() -> void:
	_close_skill_menu()
	## 感应解锁条件：至少读过1块碑文
	if not _is_sense_unlocked():
		log_text.append_text("[color=gray]【 混沌灵根尚未感应到法则……需先阅读碑文。】[/color]\n")
		return
	_battle.player_action(BattleManager.ActionType.SENSE)
	_refresh_all_hp()


# ── 技能子菜单系统 ───────────────────────────────────────────

## 切换技能子菜单的展开/收起
func _on_skill_menu_toggle() -> void:
	if _skill_menu_open:
		_close_skill_menu()
	else:
		_open_skill_menu()


## 打开技能子菜单，动态创建按钮
func _open_skill_menu() -> void:
	_skill_menu_open = true
	skill_button.text = "技能 ▼"

	_skill_menu = VBoxContainer.new()
	_skill_menu.name = "SkillMenu"
	_skill_menu.add_theme_constant_override("separation", 6)
	add_child(_skill_menu)

	## 定位到技能按钮左侧弹出
	var btn_rect: Rect2 = skill_button.get_global_rect()
	_skill_menu.global_position = Vector2(
		btn_rect.position.x - 130,
		btn_rect.position.y)

	var bite_btn := _create_skill_btn(
		"淬血", "淬血：自损10HP，血量越低伤害越重", true, _on_quixue_pressed)
	_skill_menu.add_child(bite_btn)

	var charge_btn := _create_skill_btn(
		"蓄势", "蓄势：跳过本回合，下一击×2且破甲", true, _on_charge_pressed)
	_skill_menu.add_child(charge_btn)

	# 显式锁死焦点导航，防止泄漏到主面板
	charge_btn.focus_neighbor_top    = bite_btn.get_path()
	charge_btn.focus_neighbor_bottom = bite_btn.get_path()
	charge_btn.focus_neighbor_left   = charge_btn.get_path()
	charge_btn.focus_neighbor_right  = charge_btn.get_path()
	bite_btn.focus_neighbor_top      = charge_btn.get_path()
	bite_btn.focus_neighbor_bottom   = charge_btn.get_path()
	bite_btn.focus_neighbor_left     = bite_btn.get_path()
	bite_btn.focus_neighbor_right    = bite_btn.get_path()

	charge_btn.grab_focus()

	## 感应在防御按钮位置，不在子菜单里重复出现


## 关闭并清除技能子菜单
func _close_skill_menu() -> void:
	_skill_menu_open = false
	skill_button.text = "技能 ▲"
	if _skill_menu != null and is_instance_valid(_skill_menu):
		_skill_menu.queue_free()
		_skill_menu = null


## 创建技能子菜单按钮
func _create_skill_btn(
		label: String,
		tooltip: String,
		enabled: bool,
		callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.tooltip_text = tooltip
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(120, 40)
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(func():
		_close_skill_menu()
		callback.call()
	)
	return btn


func _on_charge_pressed() -> void:
	_battle.player_action(BattleManager.ActionType.CHARGE)
	_refresh_all_hp()


func _on_quixue_pressed() -> void:
	if not _is_quixue_unlocked():
		return
	_battle.player_action(BattleManager.ActionType.BITE)
	_refresh_all_hp()


# ── 技能解锁条件 ─────────────────────────────────────────────

func _is_quixue_unlocked() -> bool:
	return true


## 感应解锁：至少读过1块碑文
func _is_sense_unlocked() -> bool:
	return GameData.stones_read.any(func(v): return v)


# ── BattleManager 信号回调 ───────────────────────────────────

func _on_turn_changed(state: BattleManager.TurnState) -> void:
	var is_player_turn := state == BattleManager.TurnState.PLAYER_TURN
	_set_buttons_disabled(not is_player_turn)
	_refresh_all_hp()


func _on_battle_log(message: String) -> void:
	if message.is_empty():
		return
	log_text.append_text(message + "\n")
	## 自动滚到底部
	await get_tree().process_frame
	var scroll := log_text.get_v_scroll_bar()
	if scroll:
		scroll.value = scroll.max_value


func _on_battle_ended(player_won: bool) -> void:
	_set_buttons_disabled(true)
	_close_skill_menu()

	if player_won:
		## BOSS战由_on_awakening_triggered负责切场景
		## 收到battle_ended时直接return，防止双重切场景
		if GameData.current_enemy_id == "boss":
			return
		## 普通胜利（幽影狼/石皮蟾）
		var loot_gold := 8 if GameData.current_enemy_id.begins_with("wolf") else 18
		log_text.append_text(
			"\n[color=gold]【 获得 %d 灵石。】[/color]\n" % loot_gold)
		GameData.gain_gold(loot_gold)
		GameData.battle_won = true
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree():
			return
		UIManager.on_battle_end()
		SceneTransition.change_scene("res://scenes/TempleScene.tscn")
	else:
		_set_buttons_disabled(true)
		## 立即恢复满血（独白播放期间视觉上她已经"站起来了"）
		GameData.player.hp = GameData.player.max_hp
		_refresh_player_hp()
		## 记录安全坐标和战场状态（在播独白之前就写入，防止对话期间异常）
		GameData.battle_won = false
		var safe_pos := _get_safe_respawn_pos()
		GameData.last_player_position = safe_pos
		GameData.current_enemy_id = ""
		## 短暂停顿后播独白
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		DialogueManager.start_scene("battle_loss")


## BOSS第二阶段触发：锁定按钮，播放旁白
func _on_boss_phase2_started() -> void:
	_set_buttons_disabled(true)
	_close_skill_menu()
	## 播放第二阶段旁白，旁白结束后_on_dialogue_ended恢复按钮
	await get_tree().process_frame
	DialogueManager.start_scene("boss_phase2_start")


## 第三回合到达：清场UI，渐入觉醒按钮
func _on_ready_for_awakening() -> void:
	_set_buttons_disabled(true)
	_close_skill_menu()

	## 彻底剥离系统感：淡出所有面板（含战斗日志）
	var tween_out := create_tween().set_parallel(true)
	tween_out.tween_property($SkillPanel,  "modulate:a", 0.0, 0.5)
	tween_out.tween_property($PlayerPanel, "modulate:a", 0.0, 0.5)
	tween_out.tween_property($EnemyPanel,  "modulate:a", 0.0, 0.5)
	tween_out.tween_property($LogPanel,    "modulate:a", 0.0, 0.5)
	await tween_out.finished

	## 完全隐藏技能面板
	$SkillPanel.hide()

	## 等待0.8秒，给玩家情绪铺垫空间
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return

	## 渐入显示「——挥出去。」按钮
	var awaken_btn := Button.new()
	awaken_btn.text = "——挥出去。"
	awaken_btn.name = "AwakenButton"
	awaken_btn.set_anchors_preset(Control.PRESET_CENTER)
	awaken_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	awaken_btn.grow_vertical   = Control.GROW_DIRECTION_BOTH
	awaken_btn.offset_left   = -160.0
	awaken_btn.offset_top    = -40.0
	awaken_btn.offset_right  = 160.0
	awaken_btn.offset_bottom = 40.0
	awaken_btn.add_theme_font_size_override("font_size", 32)
	awaken_btn.add_theme_color_override(
		"font_color", Color(0.95, 0.90, 0.75, 1.0))
	awaken_btn.modulate.a = 0.0
	awaken_btn.focus_mode = Control.FOCUS_NONE
	add_child(awaken_btn)

	## 按钮渐入
	var tween_in := create_tween()
	tween_in.tween_property(awaken_btn, "modulate:a", 1.0, 0.8)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	await tween_in.finished

	## 点击后执行觉醒
	awaken_btn.pressed.connect(func():
		awaken_btn.queue_free()
		_battle.execute_awakening()
	)


## 觉醒一击触发：播放觉醒独白，结束后切场景
func _on_awakening_triggered() -> void:
	_set_buttons_disabled(true)
	_close_skill_menu()
	log_text.append_text(
		"\n[color=gold]【 混沌灵根，觉醒。】[/color]\n")
	## 播放觉醒独白，旁白结束后_on_dialogue_ended处理切场景
	await get_tree().process_frame
	DialogueManager.start_scene("boss_awakening")


# ── 内部辅助 ─────────────────────────────────────────────────

func _set_buttons_disabled(disabled: bool) -> void:
	attack_button.disabled = disabled
	skill_button.disabled  = disabled
	## 感应按钮启用时额外检查解锁条件，禁用时直接禁用
	if disabled:
		defend_button.disabled = true
	else:
		defend_button.disabled = not _is_sense_unlocked()
	## 整体强制禁用时同步锁定道具按钮
	## 只有玩家回合放开UI时才根据血量和库存决定是否可用
	if disabled:
		item_button.disabled = true
	else:
		_refresh_item_button()


## 根据敌人ID返回战败后的安全重生坐标
func _get_safe_respawn_pos() -> Vector2:
	match GameData.current_enemy_id:
		"wolf_left":
			return Vector2(-520, 240)
		"wolf_right":
			return Vector2(680, 240)
		"toad":
			return Vector2(240, -80)
		"boss":
			return Vector2(240, -370)
		_:
			return Vector2(32, 270)


## 切换战斗UI四个面板的可见性
func _show_battle_ui(show_ui: bool) -> void:
	$EnemyPanel.visible  = show_ui
	$PlayerPanel.visible = show_ui
	$LogPanel.visible    = show_ui
	$SkillPanel.visible  = show_ui
	## 重置透明度，防止觉醒清场后透明度残留影响下次战斗
	$EnemyPanel.modulate.a  = 1.0
	$PlayerPanel.modulate.a = 1.0
	$SkillPanel.modulate.a  = 1.0
	$LogPanel.modulate.a    = 1.0
