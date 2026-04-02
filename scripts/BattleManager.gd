## BattleManager.gd
## 战斗管理器：负责回合流转、行动调度、胜负判定
class_name BattleManager
extends RefCounted

# ── 回合状态枚举 ──────────────────────────────────
enum TurnState {
	PLAYER_TURN,  ## 玩家行动阶段
	ENEMY_TURN,   ## 敌方行动阶段
	BATTLE_END,   ## 战斗结束
}

# ── 玩家行动类型枚举 ──────────────────────────────
enum ActionType {
	ATTACK,  ## 普通攻击
	HEAL,    ## 治疗（消耗法力或道具）
	SKIP,    ## 跳过回合
}

# ── 信号 ──────────────────────────────────────────
signal turn_changed(state: TurnState)        ## 回合切换时发出
signal battle_log(message: String)           ## 战斗日志，供 UI 订阅
signal battle_ended(player_won: bool)        ## 战斗结束时发出

# ── 战斗参与者 ────────────────────────────────────
var player: Character  ## 玩家角色
var enemy: Character   ## 敌方角色

# ── 当前回合状态 ──────────────────────────────────
var current_state: TurnState = TurnState.PLAYER_TURN


## 初始化战斗，传入双方角色。
func setup(p_player: Character, p_enemy: Character) -> void:
	player = p_player
	enemy  = p_enemy
	current_state = TurnState.PLAYER_TURN
	_log("⚔️  战斗开始！%s vs %s" % [player.char_name, enemy.char_name])
	turn_start()


## 每回合开始时调用，广播当前回合状态。
func turn_start() -> void:
	match current_state:
		TurnState.PLAYER_TURN:
			_log("── 玩家回合 ──")
			turn_changed.emit(current_state)
		TurnState.ENEMY_TURN:
			_log("── 敌方回合 ──")
			turn_changed.emit(current_state)
			# 敌方回合由管理器自动执行
			enemy_action()
		TurnState.BATTLE_END:
			turn_changed.emit(current_state)


## 玩家执行行动。action_type 对应 ActionType 枚举。
## 行动完成后检查胜负，若战斗未结束则切换到敌方回合。
func player_action(action_type: ActionType) -> void:
	if current_state != TurnState.PLAYER_TURN:
		push_warning("BattleManager: 当前不是玩家回合，忽略行动。")
		return

	match action_type:
		ActionType.ATTACK:
			var dmg: int = enemy.take_damage(player.atk)
			_log("%s 攻击 %s，造成 %d 点伤害（%s 剩余 %d HP）" % [
				player.char_name, enemy.char_name, dmg, enemy.char_name, enemy.hp])

		ActionType.HEAL:
			# 恢复量为攻击力的一半，至少 10 点
			var amount: int = max(player.atk / 2, 10)
			var actual: int = player.heal(amount)
			_log("%s 运转灵气，恢复 %d HP（当前 %d/%d）" % [
				player.char_name, actual, player.hp, player.max_hp])

		ActionType.SKIP:
			_log("%s 蓄势待发，跳过本回合。" % player.char_name)

	_check_battle_end()

	if current_state != TurnState.BATTLE_END:
		current_state = TurnState.ENEMY_TURN
		turn_start()


## 敌方行动：简单随机 AI。
## 70% 概率普通攻击；若自身 HP < 30% 则有 30% 概率治疗自身。
func enemy_action() -> void:
	if current_state != TurnState.ENEMY_TURN:
		return

	var roll: float = randf()  # [0.0, 1.0)
	var low_hp: bool = enemy.hp < enemy.max_hp * 0.3

	if low_hp and roll < 0.3:
		# 低血量时有概率治疗
		var amount: int = max(enemy.atk / 2, 8)
		var actual: int = enemy.heal(amount)
		_log("%s 吞服丹药，恢复 %d HP（当前 %d/%d）" % [
			enemy.char_name, actual, enemy.hp, enemy.max_hp])
	else:
		# 普通攻击玩家
		var dmg: int = player.take_damage(enemy.atk)
		_log("%s 攻击 %s，造成 %d 点伤害（%s 剩余 %d HP）" % [
			enemy.char_name, player.char_name, dmg, player.char_name, player.hp])

	_check_battle_end()

	if current_state != TurnState.BATTLE_END:
		current_state = TurnState.PLAYER_TURN
		turn_start()


# ── 内部辅助 ─────────────────────────────────────

## 检查战斗是否结束，若有一方死亡则设置状态并发出信号。
func _check_battle_end() -> void:
	if not enemy.is_alive():
		current_state = TurnState.BATTLE_END
		_log("🎉 %s 已被击败，%s 胜利！" % [enemy.char_name, player.char_name])
		battle_ended.emit(true)
	elif not player.is_alive():
		current_state = TurnState.BATTLE_END
		_log("💀 %s 已陷入弥留，战斗失败。" % player.char_name)
		battle_ended.emit(false)


## 发出战斗日志信号，同时打印到控制台。
func _log(msg: String) -> void:
	print(msg)
	battle_log.emit(msg)
