## BattleUI.gd
## 战斗界面控制器（协调层）
## 视觉演出 → BattleEffects.gd | 技能子菜单 → BattleSkillMenu.gd
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
@onready var _particles       : Node          = $BattleParticles

@onready var _enemy_portrait_slot : Node2D    = $EnemyPortraitSlot
@onready var _player_portrait_slot: Node2D    = $PlayerPortraitSlot

# ── 子模块 ───────────────────────────────────────────────────
var _effects   : Node = null
var _skill_menu: Node = null

# ── 战斗状态 ─────────────────────────────────────────────────
var _battle : BattleManager = null
var _enemy  : Character     = null

var _phase2_dialogue_done: bool = false
var _phase2_in_progress: bool   = false

var _boss_breathing_tween: Tween = null
var _visuals_playing: bool = false

var _prev_player_hp: int = 0
var _prev_enemy_hp: int  = 0

var _player_hp_tween: Tween = null
var _enemy_hp_tween: Tween  = null


func _ready() -> void:
	UIManager.on_battle_start()
	_set_buttons_disabled(true)

	if UIManager and UIManager.has_signal("font_scale_changed"):
		if not UIManager.font_scale_changed.is_connected(_on_font_scale_changed):
			UIManager.font_scale_changed.connect(_on_font_scale_changed)
		_apply_font_scale_to_log(UIManager.get_font_scale_factor())

	## 初始化子模块
	_effects = load("res://scripts/BattleEffects.gd").new()
	_effects.name = "BattleEffects"
	add_child(_effects)
	_effects.setup($PlayerPanel, $EnemyPanel, self)
	_effects.setup_battle_tassel()

	_skill_menu = load("res://scripts/BattleSkillMenu.gd").new()
	_skill_menu.name = "BattleSkillMenu"
	add_child(_skill_menu)
	_skill_menu.setup(skill_button, self)
	_skill_menu.action_requested.connect(_execute_action)

	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	item_button.pressed.connect(_on_item_pressed)

	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.event_triggered.connect(_on_event_triggered)

	attack_button.text = "攻击"
	skill_button.text  = "技能 ▲"
	defend_button.text = "感应"

	_show_battle_ui(true)
	_start_battle()


func _exit_tree() -> void:
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	if DialogueManager.event_triggered.is_connected(_on_event_triggered):
		DialogueManager.event_triggered.disconnect(_on_event_triggered)
	if UIManager and UIManager.has_signal("font_scale_changed") \
			and UIManager.font_scale_changed.is_connected(_on_font_scale_changed):
		UIManager.font_scale_changed.disconnect(_on_font_scale_changed)


# ── 对话链控制 ────────────────────────────────────────────────

func _on_dialogue_ended(scene_id: String) -> void:
	match scene_id:
		"boss_phase2_start":
			_phase2_in_progress = false
			_set_buttons_disabled(false)
		"boss_awakening":
			GameData.battle_won = true
			UIManager.on_battle_end()
			await get_tree().create_timer(0.5).timeout
			if not is_inside_tree():
				return
			SceneTransition.change_scene("res://scenes/TempleScene.tscn")
		"battle_loss", "battle_loss_wolf", "battle_loss_toad", \
		"battle_loss_boss_p1", "battle_loss_boss_p2":
			UIManager.on_battle_end()
			await get_tree().create_timer(0.5).timeout
			if not is_inside_tree():
				return
			SceneTransition.change_scene("res://scenes/TempleScene.tscn")

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
	_build_player_portrait()
	_build_enemy_portrait()

	if GameData.current_enemy_id == "boss":
		AudioManager.play_bgm("battle_boss_p1", 3.0)
	else:
		AudioManager.play_bgm("battle_normal", 3.0)

	if not GameData.triggered_events.has("tutorial_first_battle"):
		GameData.triggered_events.append("tutorial_first_battle")
		print("BattleUI: 播放教学旁白")
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree() or _battle == null:
			return
		DialogueManager.start_scene("tutorial_first_battle")
		await DialogueManager.dialogue_ended
		if not is_inside_tree() or _battle == null:
			return
	else:
		print("BattleUI: 教学已触发，跳过")

	print("BattleUI: 开局延迟前 is_active=%s" % DialogueManager.is_active)

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or _battle == null:
		return
	print("BattleUI: 调用 turn_start, is_active=%s" % DialogueManager.is_active)
	_battle.turn_start()


# ── HP 刷新 ──────────────────────────────────────────────────

func _refresh_player_hp() -> void:
	var p: Character = GameData.player
	player_name_label.text  = p.char_name
	player_hp_bar.max_value = p.max_hp
	player_hp_label.text    = "HP: %d / %d" % [p.hp, p.max_hp]
	player_hp_bar.modulate  = Color(1.0, 0.3, 0.3) if float(p.hp) / p.max_hp < 0.3 else Color.WHITE
	_player_hp_tween = _effects.tween_hp_bar(player_hp_bar, float(p.hp), _player_hp_tween)


func _refresh_enemy_hp() -> void:
	enemy_name_label.text  = _enemy.char_name
	enemy_hp_bar.max_value = _enemy.max_hp
	enemy_hp_label.text    = "HP: %d / %d" % [_enemy.hp, _enemy.max_hp]
	enemy_hp_bar.modulate  = Color(1.0, 0.3, 0.3) if float(_enemy.hp) / _enemy.max_hp < 0.3 else Color.WHITE
	_enemy_hp_tween = _effects.tween_hp_bar(enemy_hp_bar, float(_enemy.hp), _enemy_hp_tween)


func _refresh_all_hp() -> void:
	_refresh_player_hp()
	_refresh_enemy_hp()
	UIManager.refresh_hp()
	_refresh_item_button()


# ── 主按钮回调 ───────────────────────────────────────────────

func _on_attack_pressed() -> void:
	_skill_menu.close()
	_execute_action(BattleManager.ActionType.ATTACK)


func _on_item_pressed() -> void:
	_skill_menu.close()
	_execute_action(BattleManager.ActionType.USE_POTION)


func _refresh_item_button() -> void:
	item_button.text = "伤药 (×%d)" % GameData.heal_potions
	var p := GameData.player
	var can_use: bool = (
		GameData.heal_potions > 0
		and p.hp < p.max_hp
	)
	item_button.disabled = not can_use


func _on_defend_pressed() -> void:
	_skill_menu.close()
	if not _skill_menu.is_sense_unlocked():
		log_text.append_text("[color=gray]【 混沌灵根尚未感应到法则……需先阅读碑文。】[/color]\n")
		return
	_execute_action(BattleManager.ActionType.SENSE)


# ── BattleManager 信号回调 ───────────────────────────────────

func _on_turn_changed(state: BattleManager.TurnState) -> void:
	var is_player_turn := state == BattleManager.TurnState.PLAYER_TURN
	print("_on_turn_changed: state=%s is_active=%s phase2=%s vis=%s" % [
		state, DialogueManager.is_active, _phase2_in_progress, _visuals_playing])
	if is_player_turn and (DialogueManager.is_active or _phase2_in_progress \
			or _visuals_playing):
		_set_buttons_disabled(true)
	else:
		_set_buttons_disabled(not is_player_turn)
	# 演出进行中不刷新 HP 条（由演出序列自己按时机刷）
	if not _visuals_playing:
		_refresh_all_hp()


func _on_battle_log(message: String) -> void:
	if message.is_empty():
		return
	log_text.append_text(message + "\n")
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var scroll := log_text.get_v_scroll_bar()
	if scroll:
		scroll.value = scroll.max_value


func _on_battle_ended(player_won: bool) -> void:
	_set_buttons_disabled(true)
	_skill_menu.close()

	if player_won:
		if GameData.current_enemy_id == "boss":
			return
		AudioManager.play_sfx("victory")
		AudioManager.fade_bgm_to(0.0, 1.5)
		var loot_gold := 8 if GameData.current_enemy_id.begins_with("wolf") else 18
		log_text.append_text(
			"\n[color=gold]【 获得 %d 灵石。】[/color]\n" % loot_gold)
		GameData.gain_gold(loot_gold)
		AudioManager.play_sfx("gold_gain")
		GameData.battle_won = true
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree():
			return
		UIManager.on_battle_end()
		SceneTransition.change_scene("res://scenes/TempleScene.tscn")
	else:
		_set_buttons_disabled(true)
		AudioManager.play_sfx("defeat")
		AudioManager.fade_bgm_to(0.15, 1.0)
		GameData.player.hp = GameData.player.max_hp
		var defeated_by := GameData.current_enemy_id
		var was_boss_p2 := _battle._boss_phase2 if _battle else false
		GameData.battle_won = false
		var safe_pos := _get_safe_respawn_pos()
		GameData.last_player_position = safe_pos
		GameData.current_enemy_id = ""
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		var loss_scene := _get_battle_loss_scene(defeated_by, was_boss_p2)
		DialogueManager.start_scene(loss_scene)


func _on_boss_phase2_started() -> void:
	_phase2_in_progress = true
	_set_buttons_disabled(true)
	_skill_menu.close()
	AudioManager.play_bgm("battle_boss_p2", 2.0)
	# 停止呼吸动画，切换到二阶段冰冷方块
	if _boss_breathing_tween and _boss_breathing_tween.is_valid():
		_boss_breathing_tween.kill()
	_enemy_portrait_slot.scale = Vector2.ONE
	for child in _enemy_portrait_slot.get_children():
		child.queue_free()
	_draw_block(_enemy_portrait_slot, Vector2(110, 180),
		Color(0.06, 0.08, 0.20, 1.0),
		Color(0.90, 0.96, 1.00, 1.0))  # 冰白眼
	await get_tree().process_frame
	DialogueManager.start_scene("boss_phase2_start")


func _on_ready_for_awakening() -> void:
	_set_buttons_disabled(true)
	_skill_menu.close()

	if _boss_breathing_tween and _boss_breathing_tween.is_valid():
		_boss_breathing_tween.kill()

	var tween_out := create_tween().set_parallel(true)
	tween_out.tween_property($SkillPanel,  "modulate:a", 0.0, 0.5)
	tween_out.tween_property($PlayerPanel, "modulate:a", 0.0, 0.5)
	tween_out.tween_property($EnemyPanel,  "modulate:a", 0.0, 0.5)
	tween_out.tween_property($LogPanel,    "modulate:a", 0.0, 0.5)
	tween_out.tween_property(_enemy_portrait_slot,  "modulate:a", 0.0, 0.5)
	tween_out.tween_property(_player_portrait_slot, "modulate:a", 0.0, 0.5)
	await tween_out.finished

	$SkillPanel.hide()
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return

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

	var tween_in := create_tween()
	tween_in.tween_property(awaken_btn, "modulate:a", 1.0, 0.8)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	await tween_in.finished

	awaken_btn.pressed.connect(func():
		awaken_btn.disabled = true
		awaken_btn.queue_free()
		_battle.execute_awakening()
	)


func _on_awakening_triggered() -> void:
	_set_buttons_disabled(true)
	_skill_menu.close()
	AudioManager.stop_bgm(0.3)
	AudioManager.play_sfx("awakening_flash")
	_effects.battle_tassel_awaken_burst()
	_effects.flash_white()
	_effects.shake_screen()
	log_text.append_text(
		"\n[color=gold]【 混沌灵根，觉醒。】[/color]\n")
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	AudioManager.play_bgm_once("awakening", 1.0)
	DialogueManager.start_scene("boss_awakening")


# ── 内部辅助 ─────────────────────────────────────────────────

func _set_buttons_disabled(disabled: bool) -> void:
	attack_button.disabled = disabled
	skill_button.disabled  = disabled
	if disabled:
		defend_button.disabled = true
	else:
		defend_button.disabled = not _skill_menu.is_sense_unlocked()
	if disabled:
		item_button.disabled = true
	else:
		_refresh_item_button()


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


func _get_battle_loss_scene(enemy_id: String, boss_p2: bool) -> String:
	if enemy_id == "boss":
		return "battle_loss_boss_p2" if boss_p2 else "battle_loss_boss_p1"
	if enemy_id.begins_with("wolf"):
		return "battle_loss_wolf"
	if enemy_id == "toad":
		return "battle_loss_toad"
	return "battle_loss"


# ── 战斗演出（委托到 BattleEffects） ─────────────────────────

func _execute_action(action_type: BattleManager.ActionType) -> void:
	_prev_player_hp = GameData.player.hp
	_prev_enemy_hp = _enemy.hp

	_visuals_playing = true
	_set_buttons_disabled(true)

	match action_type:
		BattleManager.ActionType.ATTACK:
			AudioManager.play_sfx("attack_hit")
		BattleManager.ActionType.CHARGE:
			AudioManager.play_sfx("charge")
		BattleManager.ActionType.BITE:
			AudioManager.play_sfx("quixue")
		BattleManager.ActionType.SENSE:
			AudioManager.play_sfx("sense")
		BattleManager.ActionType.USE_POTION:
			AudioManager.play_sfx("item_get")

	# 结算伤害（同步），但 HP 条暂时冻结在旧值由演出序列逐步刷新
	_battle.player_action(action_type)

	var player_dmg := _prev_player_hp - GameData.player.hp
	var enemy_dmg := _prev_enemy_hp - _enemy.hp

	# 冻结 HP 条
	player_hp_bar.value = _prev_player_hp
	enemy_hp_bar.value  = _prev_enemy_hp

	# 进入觉醒等待态时整个演出让位给觉醒仪式的淡出
	var awakening_imminent: bool = _battle.current_state \
		== BattleManager.TurnState.WAITING_FOR_AWAKENING

	if action_type == BattleManager.ActionType.USE_POTION:
		_refresh_player_hp()
		await get_tree().create_timer(0.4).timeout
	elif awakening_imminent:
		# 不播放任何演出，直接把 HP 刷到最终值
		pass
	else:
		var player_first: bool = not _battle._enemy_first
		if player_first:
			await _play_player_turn(action_type, enemy_dmg)
			if is_inside_tree() and player_dmg > 0 \
					and _battle.current_state != BattleManager.TurnState.BATTLE_END:
				await _play_enemy_turn(player_dmg)
		else:
			if player_dmg > 0:
				await _play_enemy_turn(player_dmg)
			if is_inside_tree() \
					and _battle.current_state != BattleManager.TurnState.BATTLE_END:
				await _play_player_turn(action_type, enemy_dmg)

	if not is_inside_tree():
		return
	_visuals_playing = false
	_refresh_all_hp()
	# 演出结束后按当前战斗状态恢复按钮
	if _battle != null and _battle.current_state == BattleManager.TurnState.PLAYER_TURN \
			and not DialogueManager.is_active and not _phase2_in_progress:
		_set_buttons_disabled(false)


## 玩家方演出：前冲（攻击类）→ 敌方受击（闪红/飘字/HP 扣）
func _play_player_turn(action_type: BattleManager.ActionType, enemy_dmg: int) -> void:
	var is_attack: bool = action_type == BattleManager.ActionType.ATTACK \
		or action_type == BattleManager.ActionType.BITE
	if is_attack:
		_effects.play_attack_animation(true, _player_portrait_slot, _enemy_portrait_slot)
		await get_tree().create_timer(0.18).timeout
		if not is_inside_tree():
			return

	if enemy_dmg > 0:
		_effects.flash_panel($EnemyPanel, Color(1.0, 0.2, 0.2))
		_effects.flash_node(_enemy_portrait_slot, Color(1.0, 0.35, 0.35))
		AudioManager.play_sfx("enemy_hurt")
		_particles.play_hit($EnemyPanel.get_global_rect().get_center())
		_effects.spawn_damage_number(
			_enemy_portrait_slot.position + Vector2(-10, -40),
			enemy_dmg, false)
		_refresh_enemy_hp()
	elif action_type == BattleManager.ActionType.CHARGE \
			or action_type == BattleManager.ActionType.SENSE:
		_particles.play_skill($PlayerPanel.get_global_rect().get_center())

	await get_tree().create_timer(0.45).timeout


## 敌方演出：前冲 → 玩家受击
func _play_enemy_turn(player_dmg: int) -> void:
	_effects.play_attack_animation(false, _player_portrait_slot, _enemy_portrait_slot)
	await get_tree().create_timer(0.18).timeout
	if not is_inside_tree():
		return

	_effects.flash_panel($PlayerPanel, Color(1.0, 0.2, 0.2))
	_effects.flash_node(_player_portrait_slot, Color(1.0, 0.35, 0.35))
	AudioManager.play_sfx("player_hurt")
	_particles.play_hit($PlayerPanel.get_global_rect().get_center())
	_effects.spawn_damage_number(
		_player_portrait_slot.position + Vector2(-10, -40),
		player_dmg, true)
	if player_dmg >= 15:
		_effects.shake_screen()
	_refresh_player_hp()

	await get_tree().create_timer(0.45).timeout


## 字号变化回调
func _on_font_scale_changed(scale_factor: float) -> void:
	_apply_font_scale_to_log(scale_factor)


func _apply_font_scale_to_log(scale_factor: float) -> void:
	var base_size: int = 14
	var new_size: int = int(round(base_size * scale_factor))
	if log_text:
		log_text.add_theme_font_size_override("normal_font_size", new_size)


## 切换战斗面板可见性
func _show_battle_ui(show_ui: bool) -> void:
	$EnemyPanel.visible  = show_ui
	$PlayerPanel.visible = show_ui
	$LogPanel.visible    = show_ui
	$SkillPanel.visible  = show_ui
	$EnemyPanel.modulate.a  = 1.0
	$PlayerPanel.modulate.a = 1.0
	$SkillPanel.modulate.a  = 1.0
	$LogPanel.modulate.a    = 1.0


# ── 立绘构建（战斗中用简化方块） ─────────────────────────────

func _build_player_portrait() -> void:
	if _player_portrait_slot == null:
		return
	_player_portrait_slot.scale = Vector2.ONE
	_draw_block(_player_portrait_slot, Vector2(90, 150),
		Color(0.32, 0.24, 0.42, 1.0), Color(0.55, 0.42, 0.28, 1.0))


func _build_enemy_portrait() -> void:
	if _enemy_portrait_slot == null:
		return
	_enemy_portrait_slot.scale = Vector2.ONE
	var eid: String = GameData.current_enemy_id
	var size: Vector2
	var body_color: Color
	var accent_color: Color
	if eid == "boss":
		size = Vector2(100, 170)
		body_color = Color(0.18, 0.10, 0.30, 1.0)
		accent_color = Color(0.95, 0.35, 0.45, 1.0)  # 红眼
		_start_boss_phase1_breathing()
	elif eid.begins_with("toad"):
		size = Vector2(140, 110)
		body_color = Color(0.42, 0.38, 0.28, 1.0)
		accent_color = Color(0.85, 0.70, 0.25, 1.0)  # 金黄眼
	else:
		size = Vector2(130, 100)
		body_color = Color(0.25, 0.14, 0.32, 1.0)
		accent_color = Color(0.85, 0.75, 0.35, 1.0)  # 狼眼
	_draw_block(_enemy_portrait_slot, size, body_color, accent_color)


## 绘制一个方块立绘：主体 + 两个小高光（示意眼/光斑）
func _draw_block(parent: Node2D, size: Vector2,
		body_color: Color, accent_color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, hy), Vector2(-hx, hy)
	])
	body.color = body_color
	parent.add_child(body)

	for dx: float in [-hx * 0.35, hx * 0.35]:
		var accent := Polygon2D.new()
		var ar: float = 5.0
		accent.polygon = PackedVector2Array([
			Vector2(dx - ar, -hy * 0.55), Vector2(dx + ar, -hy * 0.55),
			Vector2(dx + ar, -hy * 0.55 + ar * 2),
			Vector2(dx - ar, -hy * 0.55 + ar * 2)
		])
		accent.color = accent_color
		parent.add_child(accent)


## BOSS P1 呼吸动画（缓慢缩放循环，模拟"形态不稳"）
func _start_boss_phase1_breathing() -> void:
	if _boss_breathing_tween and _boss_breathing_tween.is_valid():
		_boss_breathing_tween.kill()
	_boss_breathing_tween = create_tween().set_loops()
	_boss_breathing_tween.tween_property(
		_enemy_portrait_slot, "scale",
		Vector2(1.06, 1.06), 1.6)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_boss_breathing_tween.tween_property(
		_enemy_portrait_slot, "scale",
		Vector2(0.96, 0.96), 1.8)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
