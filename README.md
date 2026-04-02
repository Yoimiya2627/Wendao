# 问道 · 回合制修仙游戏

Godot 4 回合制修仙 RPG 项目。

## 项目结构

```
wendao/
├── project.godot          # Godot 项目配置（1280×720，AutoLoad: GameData）
├── scripts/
│   ├── Character.gd       # 角色基础类（所有战斗单位继承）
│   ├── BattleManager.gd   # 战斗管理器（回合流转、AI、胜负判定）
│   └── GameData.gd        # 全局单例（玩家数据、存读档、升级）
├── scenes/                # 场景文件（待创建）
└── assets/                # 美术资源（待添加）
```

## 核心脚本说明

### Character.gd
角色基础类，`class_name Character`，继承 `RefCounted`。

| 属性 | 类型 | 说明 |
|------|------|------|
| `char_name` | String | 角色名称 |
| `hp` / `max_hp` | int | 当前 / 最大生命值 |
| `atk` | int | 攻击力 |
| `def` | int | 防御力（减伤） |

| 方法 | 返回 | 说明 |
|------|------|------|
| `take_damage(amount)` | int | 承受伤害，返回实际扣血量 |
| `heal(amount)` | int | 治疗，返回实际恢复量 |
| `is_alive()` | bool | 判断是否存活 |

### BattleManager.gd
战斗管理器，`class_name BattleManager`，继承 `RefCounted`。

**回合状态枚举 `TurnState`**
- `PLAYER_TURN` — 玩家行动
- `ENEMY_TURN` — 敌方行动
- `BATTLE_END` — 战斗结束

**玩家行动枚举 `ActionType`**
- `ATTACK` — 普通攻击
- `HEAL` — 治疗自身
- `SKIP` — 跳过回合

**信号**
- `turn_changed(state)` — 回合切换
- `battle_log(message)` — 战斗文本（供 UI 订阅）
- `battle_ended(player_won)` — 战斗结束

**敌方 AI**：低血量（< 30%）时 30% 概率治疗自身，否则普通攻击。

### GameData.gd
AutoLoad 全局单例，节点路径 `/root/GameData`。

- 持有 `player: Character` 实例
- `gain_exp(amount)` / `_level_up()` — 经验与升级
- `gain_gold(amount)` / `spend_gold(amount)` — 灵石管理
- `save_data() -> Dictionary` / `load_data(data)` — 存读档序列化

## 快速开始

1. 用 Godot 4 打开 `project.godot`
2. 创建主场景 `scenes/Main.tscn`，挂载战斗 UI 脚本
3. 在战斗脚本中实例化 `BattleManager`，订阅信号，调用 `setup()` 启动战斗

```gdscript
var manager := BattleManager.new()
var enemy   := Character.new("妖兽", 80, 12, 3)
manager.battle_log.connect(func(msg): $Log.text += msg + "\n")
manager.battle_ended.connect(func(won): print("玩家胜利：", won))
manager.setup(GameData.player, enemy)

# 玩家点击"攻击"按钮时：
manager.player_action(BattleManager.ActionType.ATTACK)
```
