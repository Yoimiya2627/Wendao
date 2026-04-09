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

## 演出用：记录行动前的HP，用于检测伤害并触发视觉效果
var _prev_player_hp: int = 0
var _prev_enemy_hp: int = 0

## 全屏白光遮罩（觉醒演出用）
var _white_overlay: ColorRect = null

## 演出用：缓存 tween 引用，防止堆叠
var _player_hp_tween: Tween = null
var _enemy_hp_tween: Tween = null
var _shake_tween: Tween = null

## 屏幕震动原始位置（只在第一次震动前记录）
var _original_pos: Vector2 = Vector2.ZERO
var _original_pos_saved: bool = false


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

	## 创建全屏白光遮罩（初始透明，觉醒时闪白）
	_white_overlay = ColorRect.new()
	_white_overlay.name = "WhiteOverlay"
	_white_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_white_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white_overlay)

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
		"battle_loss", "battle_loss_wolf", "battle_loss_toad", \
		"battle_loss_boss_p1", "battle_loss_boss_p2":
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
	player_hp_label.text    = "HP: %d / %d" % [p.hp, p.max_hp]
	player_hp_bar.modulate  = Color(1.0, 0.3, 0.3) if float(p.hp) / p.max_hp < 0.3 else Color.WHITE
	## HP条平滑过渡（杀掉旧 tween 防止堆叠）
	if _player_hp_tween and _player_hp_tween.is_valid():
		_player_hp_tween.kill()
	_player_hp_tween = create_tween()
	_player_hp_tween.tween_property(player_hp_bar, "value", float(p.hp), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _refresh_enemy_hp() -> void:
	enemy_name_label.text  = _enemy.char_name
	enemy_hp_bar.max_value = _enemy.max_hp
	enemy_hp_label.text    = "HP: %d / %d" % [_enemy.hp, _enemy.max_hp]
	enemy_hp_bar.modulate  = Color(1.0, 0.3, 0.3) if float(_enemy.hp) / _enemy.max_hp < 0.3 else Color.WHITE
	## HP条平滑过渡（杀掉旧 tween 防止堆叠）
	if _enemy_hp_tween and _enemy_hp_tween.is_valid():
		_enemy_hp_tween.kill()
	_enemy_hp_tween = create_tween()
	_enemy_hp_tween.tween_property(enemy_hp_bar, "value", float(_enemy.hp), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## 统一刷新双方HP（敌方行动结束后调用）
func _refresh_all_hp() -> void:
	_refresh_player_hp()
	_refresh_enemy_hp()
	UIManager.refresh_hp()
	_refresh_item_button()


# ── 主按钮回调 ───────────────────────────────────────────────

func _on_attack_pressed() -> void:
	_close_skill_menu()
	_execute_action(BattleManager.ActionType.ATTACK)


## 道具按钮：使用伤药
func _on_item_pressed() -> void:
	_close_skill_menu()
	_execute_action(BattleManager.ActionType.USE_POTION)


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
	_execute_action(BattleManager.ActionType.SENSE)


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
	_execute_action(BattleManager.ActionType.CHARGE)


func _on_quixue_pressed() -> void:
	if not _is_quixue_unlocked():
		return
	_execute_action(BattleManager.ActionType.BITE)


# ── 技能解锁条件 ─────────────────────────────────────────────

func _is_quixue_unlocked() -> bool:
	return true


## 感应解锁：至少读过1块碑文
func _is_sense_unlocked() -> bool:
	return GameData.stones_read.any(func(v): return v)


# ── BattleManager 信号回调 ───────────────────────────────────

func _on_turn_changed(state: BattleManager.TurnState) -> void:
	var is_player_turn := state == BattleManager.TurnState.PLAYER_TURN
	## 对话进行中（BOSS旁白等）不开启按钮，防止竞态
	if is_player_turn and DialogueManager.is_active:
		_set_buttons_disabled(true)
	else:
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
		## 保存敌人ID用于选择失败独白（清空前缓存）
		var defeated_by := GameData.current_enemy_id
		var was_boss_p2 := _battle._boss_phase2 if _battle else false
		## 记录安全坐标和战场状态（在播独白之前就写入，防止对话期间异常）
		GameData.battle_won = false
		var safe_pos := _get_safe_respawn_pos()
		GameData.last_player_position = safe_pos
		GameData.current_enemy_id = ""
		## 短暂停顿后播独白
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		## 根据敌人类型选择差分失败独白
		var loss_scene := _get_battle_loss_scene(defeated_by, was_boss_p2)
		DialogueManager.start_scene(loss_scene)


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


## 觉醒一击触发：全屏白光 + 播放觉醒独白，结束后切场景
func _on_awakening_triggered() -> void:
	_set_buttons_disabled(true)
	_close_skill_menu()
	## 全屏白光演出
	_flash_white()
	_shake_screen()
	log_text.append_text(
		"\n[color=gold]【 混沌灵根，觉醒。】[/color]\n")
	## 等白光到达峰值后再播独白
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
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


## 根据敌人类型和BOSS阶段选择失败独白场景
func _get_battle_loss_scene(enemy_id: String, boss_p2: bool) -> String:
	if enemy_id == "boss":
		return "battle_loss_boss_p2" if boss_p2 else "battle_loss_boss_p1"
	if enemy_id.begins_with("wolf"):
		return "battle_loss_wolf"
	if enemy_id == "toad":
		return "battle_loss_toad"
	return "battle_loss"


# ── 战斗演出 ─────────────────────────────────────────────────

## 统一行动入口：记录HP → 执行行动 → 检测伤害 → 触发演出 → 刷新HP
func _execute_action(action_type: BattleManager.ActionType) -> void:
	_prev_player_hp = GameData.player.hp
	_prev_enemy_hp = _enemy.hp

	_battle.player_action(action_type)

	## 检测伤害并触发对应演出
	var player_took_dmg := GameData.player.hp < _prev_player_hp
	var enemy_took_dmg := _enemy.hp < _prev_enemy_hp
	var player_dmg_amount := _prev_player_hp - GameData.player.hp

	if enemy_took_dmg:
		_flash_panel($EnemyPanel, Color(1.0, 0.2, 0.2))
	if player_took_dmg:
		_flash_panel($PlayerPanel, Color(1.0, 0.2, 0.2))
		if player_dmg_amount >= 15:
			_shake_screen()

	_refresh_all_hp()


## 面板闪红：短暂变色后恢复到白色（不捕获当前色，防止连续闪红时恢复到中间状态）
func _flash_panel(panel: Control, flash_color: Color) -> void:
	var tw := create_tween()
	tw.tween_property(panel, "modulate", flash_color, 0.08)
	tw.tween_property(panel, "modulate", Color.WHITE, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## 屏幕震动：整个UI根节点抖动
func _shake_screen() -> void:
	## 只在第一次记录原始位置，防止震动中再次调用时捕获偏移值
	if not _original_pos_saved:
		_original_pos = position
		_original_pos_saved = true
	## 杀掉旧震动 tween，防止多个同时运行导致位置漂移
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _original_pos
	_shake_tween = create_tween()
	for i in range(6):
		var offset := Vector2(randf_range(-8, 8), randf_range(-6, 6))
		_shake_tween.tween_property(self, "position", _original_pos + offset, 0.04)
	_shake_tween.tween_property(self, "position", _original_pos, 0.04)


## 全屏白光闪烁（觉醒一击演出）
func _flash_white() -> void:
	if _white_overlay == null or not is_instance_valid(_white_overlay):
		return
	_white_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_white_overlay.show()
	var tw := create_tween()
	## 快速闪白
	tw.tween_property(_white_overlay, "color:a", 0.9, 0.12)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	## 维持片刻
	tw.tween_interval(0.3)
	## 缓慢消退
	tw.tween_property(_white_overlay, "color:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


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
