## Character.gd
## 角色基础类，所有战斗单位（玩家、敌人）继承此类
class_name Character
extends RefCounted

# ── 基础属性 ──────────────────────────────────────
var char_name: String  ## 角色名称
var hp: int            ## 当前生命值
var max_hp: int        ## 最大生命值
var atk: int           ## 攻击力
var def: int           ## 防御力


func _init(p_name: String, p_max_hp: int, p_atk: int, p_def: int) -> void:
	char_name = p_name
	max_hp    = p_max_hp
	hp        = p_max_hp
	atk       = p_atk
	def       = p_def


# ── 战斗方法 ──────────────────────────────────────

## 承受伤害。扣除防御后若仍有伤害则减少 hp，最低降至 0。
## 返回实际受到的伤害值。
func take_damage(amount: int) -> int:
	var actual: int = max(amount - def, 1)  # 防御减伤，至少造成 1 点
	hp = max(hp - actual, 0)
	return actual


## 治疗。恢复指定量 hp，不超过 max_hp。
## 返回实际恢复量。
func heal(amount: int) -> int:
	var actual: int = min(amount, max_hp - hp)
	hp += actual
	return actual


## 判断角色是否存活。
func is_alive() -> bool:
	return hp > 0


## 返回角色当前状态的可读字符串。
## 使用 Godot 4 虚方法 _to_string()，令 str(obj) / print(obj) 均走此路径。
func _to_string() -> String:
	return "%s  HP:%d/%d  ATK:%d  DEF:%d" % [char_name, hp, max_hp, atk, def]


## 造成真实伤害（无视防御），用于蓄势破甲、淬血、感应破防、毒液
func take_damage_raw(amount: int) -> int:
	var actual: int = max(amount, 1)
	hp = max(hp - actual, 0)
	return actual
