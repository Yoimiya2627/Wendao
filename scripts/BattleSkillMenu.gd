## BattleSkillMenu.gd
## 技能子菜单：展开/收起、按钮创建、解锁条件判断
extends Node

signal action_requested(action_type: int)

var _skill_button: Button  = null
var _parent: Control       = null

var _skill_menu_open: bool = false
var _skill_menu: Control   = null


func setup(skill_button: Button, parent: Control) -> void:
	_skill_button = skill_button
	_parent       = parent
	_skill_button.pressed.connect(_on_skill_menu_toggle)


## 切换子菜单展开/收起
func _on_skill_menu_toggle() -> void:
	if _skill_menu_open:
		close()
	else:
		_open()


func _open() -> void:
	_skill_menu_open = true
	_skill_button.text = "技能 ▼"

	_skill_menu = VBoxContainer.new()
	_skill_menu.name = "SkillMenu"
	_skill_menu.add_theme_constant_override("separation", 6)
	_parent.add_child(_skill_menu)

	var btn_rect: Rect2 = _skill_button.get_global_rect()
	_skill_menu.global_position = Vector2(
		btn_rect.position.x - 130,
		btn_rect.position.y)

	var bite_btn := _create_skill_btn(
		"淬血", "淬血：自损10HP，血量越低伤害越重", true,
		func(): action_requested.emit(BattleManager.ActionType.BITE))
	_skill_menu.add_child(bite_btn)

	var charge_btn := _create_skill_btn(
		"蓄势", "蓄势：跳过本回合，下一击×2且破甲", true,
		func(): action_requested.emit(BattleManager.ActionType.CHARGE))
	_skill_menu.add_child(charge_btn)

	charge_btn.focus_neighbor_top    = bite_btn.get_path()
	charge_btn.focus_neighbor_bottom = bite_btn.get_path()
	charge_btn.focus_neighbor_left   = charge_btn.get_path()
	charge_btn.focus_neighbor_right  = charge_btn.get_path()
	bite_btn.focus_neighbor_top      = charge_btn.get_path()
	bite_btn.focus_neighbor_bottom   = charge_btn.get_path()
	bite_btn.focus_neighbor_left     = bite_btn.get_path()
	bite_btn.focus_neighbor_right    = bite_btn.get_path()

	charge_btn.grab_focus()


func close() -> void:
	_skill_menu_open = false
	_skill_button.text = "技能 ▲"
	if _skill_menu != null and is_instance_valid(_skill_menu):
		_skill_menu.queue_free()
		_skill_menu = null


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
		close()
		callback.call()
	)
	return btn


## 感应解锁：至少读过1块碑文
func is_sense_unlocked() -> bool:
	return GameData.stones_read.any(func(v): return v)
