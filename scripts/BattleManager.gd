## BattleManager.gd
## 战斗管理器：负责回合流转、行动调度、胜负判定
## 支持：幽影狼 / 石皮蟾 / 虚形魇（BOSS两阶段）三种敌人AI
## 三技能：蓄势（破甲×2）、淬血（以血换伤）、感应（看破反制×1.2）
##
## 回合制设计：每回合玩家先选择行动，再按先手顺序结算双方行动。
## 怪物先手（幽影狼/虚形魇）= 玩家选完后，敌方先结算再玩家结算。
## 玩家先手（石皮蟾）= 玩家选完后，玩家先结算再敌方结算。
class_name BattleManager
extends RefCounted

# ── 回合状态枚举 ──────────────────────────────────────
enum TurnState {
	PLAYER_TURN,
	BATTLE_END,
	WAITING_FOR_AWAKENING,  ## 等待玩家主动触发觉醒一击
}

# ── 玩家行动类型枚举 ──────────────────────────────────
enum ActionType {
	ATTACK,  ## 普通攻击
	CHARGE,  ## 蓄势：跳过本回合，下一击伤害×2且无视防御
	BITE,    ## 淬血：自损10HP，造成 ATK×1.5+已损失HP×0.5 的真实伤害
	SENSE,   ## 感应：本回合减伤50%，下一击无视防御且×1.2
	USE_POTION,  ## 使用伤药：恢复30HP，消耗本回合
}

# ── 信号 ──────────────────────────────────────────────
signal turn_changed(state: TurnState)
signal battle_log(message: String)
signal battle_ended(player_won: bool)
signal boss_phase2_started()       ## BOSS进入第二阶段时发出
signal awakening_triggered()       ## 觉醒一击触发时发出
signal ready_for_awakening()       ## 第三回合到达，等待玩家点击触发

# ── 战斗参与者 ────────────────────────────────────────
var player: Character
var enemy: Character

# ── 回合状态 ──────────────────────────────────────────
var current_state: TurnState = TurnState.PLAYER_TURN

# ── 先手标记 ──────────────────────────────────────────
var _enemy_first: bool = false     ## true=敌方先结算，false=玩家先结算

# ── 玩家技能状态 ──────────────────────────────────────
var _charged: bool = false      ## 蓄势：下一击×2真实伤害
var _sensing: bool = false      ## 感应：本回合受伤减半
var _sense_buff: bool = false   ## 感应后增益：下一击无视防御×1.2

# ── BOSS阶段状态 ──────────────────────────────────────
var _is_boss_fight: bool = false
var _boss_phase2: bool = false
var _boss_phase2_turns: int = 0    ## 第二阶段玩家存活回合数（回合开始时递增）
var _awakening_done: bool = false

# ── 怪物特技状态（预警机制）──────────────────────────
var _wolf_charging: bool = false   ## 幽影狼蓄力：下回合必定残影突袭
var _wolf_howling: bool = false    ## 幽影狼嚎叫：下回合攻击×1.5
var _toad_shell: bool = false      ## 石皮蟾硬壳：受普通攻击减伤50%
## 石皮蟾收缩预备：下回合将进入硬壳
var _toad_preshell: bool = false
## 石皮蟾硬壳持续回合计数
var _toad_shell_turns: int = 0
var _boss_blur: bool = false       ## 虚形魇模糊：免疫玩家攻击（当前生效中）
var _boss_blur_next: bool = false  ## 虚形魇模糊预告：下回合生效

# ── 持续伤害 ──────────────────────────────────────────
var _player_poison: int = 0        ## 中毒层数，每回合扣5HP并递减1层


## 初始化战斗（不触发任何回合，由 BattleUI 调用 turn_start() 开始）
func setup(p_player: Character, p_enemy: Character) -> void:
	player = p_player
	enemy  = p_enemy
	_is_boss_fight = (enemy.char_name == "虚形魇")
	## 先手机制：幽影狼和虚形魇怪物先手，石皮蟾玩家先手
	match enemy.char_name:
		"幽影狼", "虚形魇":
			_enemy_first = true
		_:
			_enemy_first = false
	current_state = TurnState.PLAYER_TURN
	_log("⚔️  战斗开始！%s vs %s" % [player.char_name, enemy.char_name])
	## 定神香被动：战斗开始时自动生效，首击无视防御×1.2
	if GameData.incenses > 0:
		GameData.incenses -= 1
		_sense_buff = true
		_log("[color=gold]【 定神香燃起，凝神静气，感应已就绪。】[/color]")


## 每回合开始时调用（始终为 PLAYER_TURN）
func turn_start() -> void:
	if current_state == TurnState.BATTLE_END:
		turn_changed.emit(current_state)
		return

	## 中毒结算
	if _player_poison > 0:
		var poison_dmg: int = 5
		player.take_damage_raw(poison_dmg)
		_player_poison -= 1
		_log("💀 毒液发作，%s 损失 %d HP（剩余 %d 层，当前 %d/%d HP）" % [
			player.char_name, poison_dmg, _player_poison,
			player.hp, player.max_hp])
		_check_battle_end()
		if current_state == TurnState.BATTLE_END:
			return

	## BOSS第二阶段：每个玩家回合开始时计数+1
	## 无论玩家选择什么行动，只要活过这个回合就算撑住了
	if _boss_phase2 and not _awakening_done:
		_boss_phase2_turns += 1
		_log("   （第二阶段第 %d/3 回合……）" % _boss_phase2_turns)
		if _boss_phase2_turns >= 3:
			## 第三回合：挂起状态机，等待玩家主动触发觉醒
			current_state = TurnState.WAITING_FOR_AWAKENING
			ready_for_awakening.emit()
			return

	_log("── 第 %s 回合 ──" % _round_label())
	current_state = TurnState.PLAYER_TURN
	turn_changed.emit(current_state)


## 回合序号标签（用于日志显示）
var _round_count: int = 0
func _round_label() -> String:
	_round_count += 1
	return str(_round_count)


## 玩家执行行动：先准备状态，再按先手顺序结算双方
func player_action(action_type: ActionType) -> void:
	if current_state != TurnState.PLAYER_TURN:
		push_warning("BattleManager: 当前不是玩家回合，忽略行动。")
		return

	_sensing = false

	## ── 第一步：准备玩家选择的状态（不造成伤害的部分） ──
	var player_deals_damage := false
	match action_type:
		ActionType.ATTACK:
			player_deals_damage = true
		ActionType.CHARGE:
			_charged = true
			_log("🌀 %s 凝神蓄势，气息内敛——" % player.char_name)
			_log("   （下一击破甲×2）")
		ActionType.BITE:
			player_deals_damage = true
		ActionType.SENSE:
			_sensing = true
			_sense_buff = true
			_log("👁  %s 运转混沌灵根，感应法则——" % player.char_name)
			_log("   （本回合受伤减半，下一击破甲×1.2）")
			_preview_enemy_action()
		ActionType.USE_POTION:
			GameData.heal_potions -= 1
			var healed: int = player.heal(30)
			_log("[color=lightgreen]【 饮下伤药，恢复 %d HP。（当前 %d/%d HP）】[/color]" % [
				healed, player.hp, player.max_hp])

	## ── 第二步：按先手顺序结算双方行动 ──
	if _enemy_first:
		## 敌方先结算
		_run_enemy_action()
		_check_battle_end()
		if current_state == TurnState.BATTLE_END:
			return
		## 玩家后结算（玩家被打死则不执行）
		if player_deals_damage:
			_resolve_player_damage(action_type)
			_check_battle_end()
			if current_state == TurnState.BATTLE_END:
				return
	else:
		## 玩家先结算
		if player_deals_damage:
			_resolve_player_damage(action_type)
			_check_battle_end()
			if current_state == TurnState.BATTLE_END:
				return
		## 敌方后结算（敌方被打死则不执行）
		_run_enemy_action()
		_check_battle_end()
		if current_state == TurnState.BATTLE_END:
			return

	## ── 第三步：进入下一回合 ──
	turn_start()


## 执行玩家的伤害行动（攻击/淬血）
func _resolve_player_damage(action_type: ActionType) -> void:
	match action_type:
		ActionType.ATTACK:
			_do_player_attack()
		ActionType.BITE:
			_do_player_quixue()


## 普通攻击（含蓄势/感应破甲、怪物防御状态检查）
func _do_player_attack() -> void:
	## 虚形魇形态模糊免疫
	if _boss_blur:
		_boss_blur = false
		_charged = false
		_sense_buff = false
		_log("👻 攻击穿透了虚影，没有造成任何伤害！")
		return

	var ignore_def: bool = _charged or _sense_buff
	var raw_dmg: int
	if _charged and _sense_buff:
		raw_dmg = int(player.atk * 2 * 1.2)   ## 蓄势+感应叠加
	elif _charged:
		raw_dmg = player.atk * 2
	elif _sense_buff:
		raw_dmg = int(player.atk * 1.2)
	else:
		raw_dmg = max(player.atk - enemy.def, 1)

	## 石皮蟾硬壳判定（在raw_dmg计算后、伤害结算前）
	if _toad_shell and not ignore_def:
		raw_dmg = max(raw_dmg / 2, 1)
		_toad_shell = false
		_toad_shell_turns = 0
		_log("🛡️  击中硬壳，伤害被大幅削弱！（建议蓄势破甲）")
	elif _toad_shell and ignore_def:
		_toad_shell = false
		_toad_shell_turns = 0
		_log("💥 真实伤害直接贯穿了硬壳！")

	## BOSS第二阶段：攻击有伤害但血量锁定（演出用，实际由turn_start计数）
	if _boss_phase2 and not _awakening_done:
		_log("⚔️  %s 挥出去，造成了 %d 点伤害——" % [player.char_name, raw_dmg])
		_log("   但那道伤口转眼就合上了。")
		_charged = false
		_sense_buff = false
		return

	## 正常伤害结算
	var dmg: int = enemy.take_damage_raw(raw_dmg)

	if _charged and _sense_buff:
		_log("💥✨ %s 蓄势感应双发，造成 %d 点真实伤害！（%s 剩余 %d HP）" % [
			player.char_name, dmg, enemy.char_name, enemy.hp])
	elif _charged:
		_log("💥 %s 蓄势破甲，造成 %d 点真实伤害！（%s 剩余 %d HP）" % [
			player.char_name, dmg, enemy.char_name, enemy.hp])
	elif _sense_buff:
		_log("✨ %s 看破规律，造成 %d 点伤害（%s 剩余 %d HP）" % [
			player.char_name, dmg, enemy.char_name, enemy.hp])
	else:
		var _stones_any: bool = GameData.stones_read.any(func(v): return v)
		if _stones_any:
			_log("⚔️  剑穗边缘泛起微光，她挥出去，造成 %d 点伤害（%s 剩余 %d HP）" % [
				dmg, enemy.char_name, enemy.hp])
		else:
			_log("⚔️  她甩出剑穗，狠狠抽在它身上，造成 %d 点伤害（%s 剩余 %d HP）" % [
				dmg, enemy.char_name, enemy.hp])

	_charged = false
	_sense_buff = false

	## BOSS第一阶段：血量降至50%触发第二阶段
	if _is_boss_fight and not _boss_phase2:
		if float(enemy.hp) / enemy.max_hp <= 0.5:
			_enter_boss_phase2()


## 淬血：自损10HP，造成 ATK×1.5+已损失HP×0.5 的真实伤害
func _do_player_quixue() -> void:
	## 虚形魇形态模糊：淬血也无法命中，但仍扣自身HP（强行发力反噬）
	if _boss_blur:
		_boss_blur = false
		var self_dmg: int = min(10, player.hp - 1)
		player.hp -= self_dmg
		_log("👻 强行发力，但攻击穿透了虚影……（自损 %d HP，当前 %d/%d HP）" % [
			self_dmg, player.hp, player.max_hp])
		_charged = false
		return

	var self_dmg: int = min(10, player.hp - 1)
	player.hp -= self_dmg
	_log("%s 淬血，自损 %d HP！（当前 %d/%d HP）" % [
		player.char_name, self_dmg, player.hp, player.max_hp])

	if not player.is_alive():
		_check_battle_end()
		return

	var lost_hp: int = player.max_hp - player.hp
	var raw_dmg: int = int(player.atk * 1.5 + lost_hp * 0.5)

	## BOSS第二阶段：淬血也锁血
	if _boss_phase2 and not _awakening_done:
		_log("🩸 %s 淬血挥出 %d 点伤害——但那道伤口转眼就合上了。" % [
			player.char_name, raw_dmg])
		_charged = false
		return

	var dmg: int = enemy.take_damage_raw(raw_dmg)
	_log("🩸 %s 以命换伤，造成 %d 点真实伤害！（%s 剩余 %d HP）" % [
		player.char_name, dmg, enemy.char_name, enemy.hp])

	_charged = false

	if _is_boss_fight and not _boss_phase2:
		if float(enemy.hp) / enemy.max_hp <= 0.5:
			_enter_boss_phase2()


## 觉醒一击内部实现
func _do_awakening() -> void:
	_awakening_done = true
	_log("✨ 她什么都没想，只是挥出去——")
	_log("   剑穗在黑暗里划出一道白光。")
	enemy.hp = 0
	awakening_triggered.emit()
	_check_battle_end()


## 供BattleUI调用的公开接口：玩家点击觉醒按钮后执行
func execute_awakening() -> void:
	if current_state != TurnState.WAITING_FOR_AWAKENING:
		return
	_do_awakening()


## 感应预告（在日志里提示玩家当前怪物状态）
func _preview_enemy_action() -> void:
	if _wolf_charging:
		_log("   【预感】它下回合将爆发「残影突袭」——重击×2！")
		return
	if _wolf_howling:
		_log("   【预感】它下回合将发动强击——攻击力×1.5！")
		return
	if _toad_preshell:
		_log("   【预感】它正在收缩——下回合「硬壳」即将成型，立刻蓄势！")
		return
	if _toad_shell:
		_log("   【预感】它正处于「硬壳」防御——建议蓄势破甲！")
		return
	if _boss_blur or _boss_blur_next:
		_log("   【预感】它形态模糊——攻击将落空！")
		return
	match enemy.char_name:
		"幽影狼":
			_log("   【预感】它下回合动作平平……")
		"石皮蟾":
			_log("   【预感】它蠢蠢欲动……")
		"虚形魇":
			if _boss_phase2:
				_log("   【预感】它只是看着你——冷漠而机械。")
			else:
				_log("   【预感】深渊般的注视……")
		_:
			_log("   【预感】感应到对方的下一个动作……")


## 供UI调用的预告接口（返回字符串）
func preview_enemy_action() -> String:
	if _wolf_charging:
		return "⚠️ 蓄力完毕，即将发动「残影突袭」！"
	if _wolf_howling:
		return "⚠️ 嚎叫完毕，下回合强击×1.5！"
	if _toad_preshell:
		return "⚠️ 正在收缩！下回合进入「硬壳」，立刻蓄势！"
	if _toad_shell:
		return "⚠️ 处于「硬壳」状态，建议蓄势破甲！"
	if _boss_blur or _boss_blur_next:
		return "⚠️ 形态模糊，攻击将落空！"
	return ""


## 敌方行动（纯执行AI，不做状态转换）
func _run_enemy_action() -> void:
	## 预告模糊 → 正式生效（上回合预警，本回合才真正免疫攻击）
	## 若上回合玩家未攻击消耗掉 _boss_blur，也会被 _boss_blur_next 覆盖（自然过期）
	_boss_blur = _boss_blur_next
	_boss_blur_next = false

	if _boss_phase2:
		_enemy_action_boss_phase2()
		return

	match enemy.char_name:
		"幽影狼":
			_enemy_action_wolf()
		"石皮蟾":
			_enemy_action_toad()
		"虚形魇":
			_enemy_action_boss_phase1()
		_:
			_enemy_action_default()


## 幽影狼AI：普通撕咬 / 蓄力预警 / 残影突袭 / 嚎叫预警
func _enemy_action_wolf() -> void:
	if _wolf_charging:
		var dmg: int = _calc_enemy_dmg(int(enemy.atk * 2.0))
		_log("💨 %s 爆发「残影突袭」！造成 %d 点伤害（%s 剩余 %d HP）" % [
			enemy.char_name, dmg, player.char_name, player.hp])
		_wolf_charging = false
		return

	if _wolf_howling:
		var dmg: int = _calc_enemy_dmg(int(enemy.atk * 1.5))
		_log("💥 %s 借嚎叫之势强击，造成 %d 点伤害（%s 剩余 %d HP）" % [
			enemy.char_name, dmg, player.char_name, player.hp])
		_wolf_howling = false
		return

	var roll: int = randi() % 3
	match roll:
		0:
			var dmg: int = _calc_enemy_dmg(enemy.atk)
			_log("%s 撕咬，造成 %d 点伤害（%s 剩余 %d HP）" % [
				enemy.char_name, dmg, player.char_name, player.hp])
		1:
			_wolf_charging = true
			_log("🐺 %s 的身形融入黑暗……（预警：下回合必定「残影突袭」！）" % enemy.char_name)
		2:
			_wolf_howling = true
			_log("🐺 %s 仰天嚎叫，气势大涨！（预警：下回合攻击力×1.5）" % enemy.char_name)


## 石皮蟾AI：收缩预备 / 硬壳防御 / 重击 / 毒液
func _enemy_action_toad() -> void:
	## 收缩预备状态：这回合正式进入硬壳
	if _toad_preshell:
		_toad_preshell = false
		_toad_shell = true
		_toad_shell_turns = 0
		_log("🛡️  %s 背甲完全隆起，进入「硬壳」状态！" % enemy.char_name)
		_log("   （普通攻击将被大幅削弱，蓄势可破甲）")
		return

	## 硬壳状态处理
	if _toad_shell:
		_toad_shell_turns += 1
		## 超过2回合自动解除，本回合转为普通随机攻击（不写return，向下流转）
		if _toad_shell_turns > 2:
			_toad_shell = false
			_toad_shell_turns = 0
			_log("🐸 %s 的硬壳彻底松动，褪去了防御。" % enemy.char_name)
		else:
			## 硬壳维持期间：60%压制攻击，40%喷毒
			var shell_roll: int = randi() % 10
			if shell_roll < 6:
				var dmg: int = _calc_enemy_dmg(int(enemy.atk * 1.2))
				_log("🪨 %s 在硬壳庇护下重压而来，造成 %d 点伤害（%s 剩余 %d HP）" % [
					enemy.char_name, dmg, player.char_name, player.hp])
			else:
				var dmg: int = _calc_enemy_dmg(int(enemy.atk * 0.4))
				if GameData.talismans > 0:
					GameData.talismans -= 1
					_log("[color=gold]【 辟邪符燃尽，化解了毒气！】[/color]")
					_log("☠️  %s 缩在硬壳里喷出毒雾！造成 %d 点伤害，毒气被符箓化解。" % [
						enemy.char_name, dmg])
				else:
					_player_poison = min(_player_poison + 2, 6)
					_log("☠️  %s 缩在硬壳里喷出毒雾！造成 %d 点伤害，附加 2 层中毒（当前 %d 层）" % [
						enemy.char_name, dmg, _player_poison])
			return

	## 正常状态：随机选择行动
	var roll: int = randi() % 4
	match roll:
		0, 1:
			## 权重50%：普通重击
			var dmg: int = _calc_enemy_dmg(int(enemy.atk * 1.3))
			_log("🪨 %s 「重击」！造成 %d 点伤害（%s 剩余 %d HP）" % [
				enemy.char_name, dmg, player.char_name, player.hp])
		2:
			## 权重25%：收缩预备（前摇，下回合进入硬壳）
			_toad_preshell = true
			_log("🐸 %s 身体缓缓收缩，背甲开始隆起——" % enemy.char_name)
			_log("   （预警：下回合将进入「硬壳」状态！建议蓄势备用）")
		3:
			## 权重25%：毒液
			var dmg: int = _calc_enemy_dmg(int(enemy.atk * 0.5))
			if GameData.talismans > 0:
				GameData.talismans -= 1
				_log("[color=gold]【 辟邪符燃尽，化解了毒气！】[/color]")
				_log("☠️  %s 喷吐「毒液」！造成 %d 点伤害，毒气被符箓化解。" % [
					enemy.char_name, dmg])
			else:
				_player_poison = min(_player_poison + 3, 6)
				_log("☠️  %s 喷吐「毒液」！造成 %d 点伤害，附加 3 层中毒（当前 %d 层）" % [
					enemy.char_name, dmg, _player_poison])


## 虚形魇第一阶段AI：虚影爪 / 形态模糊预警 / 侵蚀吸血
func _enemy_action_boss_phase1() -> void:
	var roll: int = randi() % 3
	match roll:
		0:
			var dmg: int = _calc_enemy_dmg(enemy.atk)
			_log("🌑 虚形魇「虚影爪」，造成 %d 点伤害（%s 剩余 %d HP）" % [
				dmg, player.char_name, player.hp])
		1:
			_boss_blur_next = true
			_log("👻 虚形魇形态渐渐模糊……（预警：下回合对其攻击将落空！）")
		2:
			var steal: int = 15
			player.hp = max(player.hp - steal, 0)
			enemy.hp = min(enemy.hp + steal, enemy.max_hp)
			_log("🩸 虚形魇「侵蚀」，吸取 %d HP！（%s 剩余 %d HP）" % [
				steal, player.char_name, player.hp])

	## 侵蚀也可能触发第二阶段（BOSS回血过50%不会，但玩家攻击后可能）
	## 这里只检查玩家死亡（侵蚀不触发phase2，phase2由玩家攻击后检查）


## 进入BOSS第二阶段
func _enter_boss_phase2() -> void:
	_boss_phase2 = true
	_boss_phase2_turns = 0
	_log("")
	_log("━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_log("它看着她。不狂怒，不挣扎。")
	_log("像在等一粒沙子自己沉到水底。")
	_log("━━━━━━━━━━━━━━━━━━━━━━━━━━")
	boss_phase2_started.emit()


## 虚形魇第二阶段：虚无凝视，冷漠机械，固定伤害
func _enemy_action_boss_phase2() -> void:
	var fixed_dmg: int = 10
	var dmg: int = _calc_enemy_dmg(fixed_dmg)
	_log("🌑 它看着她，「虚无凝视」——造成 %d 点伤害（%s 剩余 %d HP）" % [
		dmg, player.char_name, player.hp])


## 默认敌方AI（兜底）
func _enemy_action_default() -> void:
	var roll: float = randf()
	var low_hp: bool = enemy.hp < enemy.max_hp * 0.3
	if low_hp and roll < 0.3:
		var amount: int = max(enemy.atk / 2, 8)
		var actual: int = enemy.heal(amount)
		_log("%s 恢复 %d HP（当前 %d/%d）" % [
			enemy.char_name, actual, enemy.hp, enemy.max_hp])
	else:
		var dmg: int = _calc_enemy_dmg(enemy.atk)
		_log("%s 攻击 %s，造成 %d 点伤害（%s 剩余 %d HP）" % [
			enemy.char_name, player.char_name, dmg, player.char_name, player.hp])


# ── 内部辅助 ─────────────────────────────────────────

## 计算敌方对玩家的实际伤害（含感应减伤50%、玩家防御）
func _calc_enemy_dmg(raw_atk: int) -> int:
	var actual: int = max(raw_atk - player.def, 1)
	if _sensing:
		actual = max(int(actual * 0.5), 1)
		_log("   （感应减伤，实际受到 %d 点）" % actual)
	player.hp = max(player.hp - actual, 0)
	return actual


## 检查战斗是否结束
func _check_battle_end() -> void:
	if not enemy.is_alive():
		current_state = TurnState.BATTLE_END
		_log("🎉 %s 已被击败，%s 胜利！" % [enemy.char_name, player.char_name])
		battle_ended.emit(true)
	elif not player.is_alive():
		current_state = TurnState.BATTLE_END
		_log("💀 %s 已陷入弥留，战斗失败。" % player.char_name)
		battle_ended.emit(false)


## 发出战斗日志信号
func _log(msg: String) -> void:
	print(msg)
	battle_log.emit(msg)
