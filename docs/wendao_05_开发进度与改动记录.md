# 《问道》第七版文档
# 开发进度 · 改动记录 · 待办清单

---

## 一、当前完成状态（最新）

### 链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ 完整可测 | 猫咪互动、针线篓均正常 |
| 链路二 测灵广场 | ✅ 完整可测 | 两段式、飘字、围观NPC |
| 链路三 回家流程 | ✅ 完整可测 | 猫咪安慰、夜晚切换正常 |
| 链路四 废庙流程 | ✅ 五房间完整可测 | 幽影狼×2、石皮蟾、BOSS |
| 链路五 章末流程 | ✅ 完整可测 | 路径A/B均验证通过 |

### 本轮新增完成（第七版）

**一致性修复（新增）**
- TeaScene.gd：修复测灵前老江湖不可对话，phase<3 时恢复 `old_wanderer` 对话
- chapter1.json：老江湖去程台词改为测灵前语境，去除“测出来什么/无灵根”时序冲突
- TempleScene.gd：碑文已读后按E不再重播；`sense_unlocked_hint` 改为一次性触发，修复可重复刷“感应·已领悟”
- chapter1.json + TownScene.gd：香料摊回程文案按是否买桂皮动态切换（`vendor_b_return` / `vendor_b_return_no_cinnamon`）
- BattleUI.gd：战斗 BGM 进场淡入延长至 3.0 秒，缓解“突然过响”
- chapter1.json + ChapterEndScene.gd：章末“平安符”文案去穿帮（无符走中性文案）
- GameData.gd + TownScene.gd + ChapterEndScene.gd：新增 `got_charm` 持久化分支，章末路径A按是否拿到平安符切换首句文案

**Bug修复（4个）**
- BattleManager.gd：BOSS第二阶段固定伤害12→10
- BattleUI.gd：删除gain_exp()调用，普通胜利改为灵石奖励
- TempleScene.gd：读档后石碑Area2D+碰撞体正确恢复
- DialogueManager.gd：空事件节点兜底advance()防假死

**药婆商人系统**
- 位置：格(35,26)，夜晚(night_triggered=true)且story_phase<5时刷出
- 消耗品：伤药10灵石/定神香20灵石/辟邪符15灵石，无限购买
- 购买反馈：灵石足够→气泡"买下了。"，不足→气泡"灵石不够……"
- 对话循环：JSON内部next指回choice节点，选"算了不买"才退出
- chapter1.json新增：night_vendor_shop、night_vendor_return

**古井回血系统**
- 位置：格(21,16)中心，像素(688,528)
- 触发条件：夜晚+phase3-4+未用过今日额度+HP未满
- 回血量：ceil(max_hp * 0.3)
- 重置时机：每次进入TownScene._ready()重置well_used_today=false
- chapter1.json新增：well_heal

**基础UI三件套**
- UIManager.gd：新建AutoLoad单例，CanvasLayer layer=50
- HP条：左上角，苏云晚 HP x/x + 进度条，低血量变深红
- 心绪面板：右侧，第一人称独白，随story_phase_changed信号自动更新
- 旧物背包：右下角"囊"按钮展开，6格，点击看描述，仅叙事道具
- 战斗中：BattleUI._ready()调用on_battle_start()隐藏，结束时on_battle_end()恢复
- 读档同步：TownScene._ready()末尾调用UIManager.refresh_all_data()

**已确认设计决策补充**
- 幽影狼：碰触强制战斗（不需要按E确认），设计已确认不更改
- 消耗品不放旧物背包：旧物面板仅限叙事道具，消耗品只记录在GameData
- 信号方案技术债：未来加主菜单时，将TownScene._ready()的
  UIManager.refresh_all_data()改为GameData.data_loaded信号驱动

---

## 二、chapter1.json 场景清单（共85个）

**核心剧情**
morning、market、test、test_stone、after_battle、after_battle_coin、letter、
activation_monologue（旧版保留）、activation_monologue_stubborn、
activation_monologue_warm、temple（旧版保留）

**回家流程**
return_home、niannian_comfort、dayu_comfort、sword_tassel_hint、
light_still_on、dayu_approach、niannian_after、dayu_after、bowl_interact_return

**NPC对话（去程）**
suming、niannian、dayu、niannian_morning、dayu_morning、
fortune_teller、aunts_before、water_carrier_before、dog_before、guard、
teahouse_before、bowl_interact、examiner_after、vendor_a、vendor_b、vendor_c

**NPC对话（回程）**
fortune_teller_return、fortune_teller_coin、aunts_return、
water_carrier_return、dog_return、celebration_boy、guard_return、
teahouse_after、old_wanderer_return、vendor_a_return、vendor_b_return、vendor_c_return

**茶馆NPC**
storyteller、disciple_a、disciple_b、old_wanderer

**废庙**
temple_stone_1、temple_stone_2、temple_stone_3、temple_stone_4、monster_approach、
inner_hall_enter、stone_toad_approach、boss_room_enter、boss_phase2_start、boss_awakening

**夜晚流程**
night_walk_tree、night_walk_well、temple_entrance_night、night_exit（废弃保留）

**章末**
chapter_end_a（废弃保留）、chapter_end_b（废弃保留）

**战斗失败**
battle_loss_stubborn、battle_loss_warm

**隐藏探索**
transmission_array、tally_marks、
remnant_page_1、remnant_page_2、remnant_page_3、remnant_page_4、
old_sword_tassel

**公告栏**
notice_board_before、notice_board_after

**药婆商人**
night_vendor_shop、night_vendor_return

**古井回血**
well_heal

---

## 三、GameData变量完整清单

```gdscript
# 玩家
var player: Character

# 进度
var current_chapter: int = 1
var gold: int = 0
var exp: int = 0        ## 保留但不再使用（EXP系统已废弃）
var level: int = 1      ## 保留但不再使用（升级系统已废弃）
var story_phase: int = 0
var morning_triggered: bool = false

# 场景
var last_scene: String = ""

# 持久化事件
var triggered_events: Array[String] = []
var bowl_interacted: bool = false
var stones_read: Array[bool] = [false, false, false, false]
var night_triggered: bool = false

# 道心系统
var dao_heart_stubborn: int = 0
var dao_heart_warm: int = 0

# 道具
var got_coin: bool = false

# 章末
var chapter_end_path: String = ""

# 战斗
var battle_won: bool = false
var temple_dungeon_state: Dictionary = {
    "wolf_left_defeated": false,
    "wolf_right_defeated": false,
    "toad_defeated": false,
}
var current_enemy_id: String = ""
var current_enemy_data: Dictionary = {}
var last_player_position: Vector2 = Vector2.ZERO

# 消耗品库存
var heal_potions: int = 0
var incenses: int = 0
var talismans: int = 0

# 古井
var well_used_today: bool = false  ## 不存档，每次进TownScene重置

# 旧物背包
var unlocked_old_items: Array[String] = []
```

---

## 四、story_phase状态机

```
phase 0：游戏启动，ShopScene，morning未触发
phase 1：morning结束，可出门探索
phase 2：已废弃（跳过）
phase 3：测灵失败，回程模式，回家流程
phase 4：废庙战斗触发（激活独白→战斗）
phase 5：战斗结束，after_battle对话结束
```

推进规则：只能通过advance_phase()递增，禁止直接赋值。
test_stone结束时一次推进两步（1→3），跳过废弃的phase2。

---

## 五、灵石数值（已确认）

**掉落：**
- 幽影狼：8灵石/只（打两只=16）
- 石皮蟾：18灵石

**消耗品价格：**
- 伤药（恢复30HP）：10灵石
- 定神香（开局感应就绪）：20灵石
- 辟邪符（免疫一次中毒）：15灵石

**设计意图：**
打完两只狼+蟾=34灵石，买一套伤药+辟邪符=25灵石，
剩9块进BOSS。资源略紧，玩家需要做取舍。

---

## 六、文件修改记录（第七版完整）

```
scripts/GameData.gd        新增消耗品库存变量、well_used_today、
                           unlocked_old_items，存档/读档均已处理
scripts/BattleManager.gd   BOSS第二阶段fixed_dmg 12→10
scripts/BattleUI.gd        删除gain_exp调用，改灵石掉落逻辑，
                           新增UIManager.on_battle_start/end调用，
                           _refresh_all_hp加UIManager.refresh_hp()
scripts/UIManager.gd       新建，HP条+心绪面板+旧物背包全局UI
scripts/TownScene.gd       新增药婆(_setup_night_vendor)、
                           古井(_setup_well_heal_area)、
                           购买事件处理(buy_heal_potion等)、
                           UIManager.refresh_all_data()
scripts/ShopScene.gd       旧剑穗交互加UIManager.add_item
scripts/TempleScene.gd     读档恢复石碑Area2D+碰撞体
scripts/DialogueManager.gd 空事件节点兜底advance()
data/chapter1.json         新增night_vendor_shop、night_vendor_return、
                           well_heal、vendor_b加get_cinnamon事件节点，
                           共85个场景
```

---

## 七、待完成任务

### 下一阶段：功法栏
- 替代技能页，战斗外可查看
- 显示已解锁/未解锁技能
- 未解锁显示"（未悟）"和解锁条件
- 预留空槽位给第二章
- 解锁时屏幕浮现独白

### 后续阶段（按优先级）
1. 存档系统重构
   - 四文件隔离（auto/manual×2/crossroad）
   - 启动界面（继续/读档/新游戏）
   - 同步将UIManager.refresh_all_data()
     改为GameData.data_loaded信号驱动（技术债）

2. 战斗消耗品
   - BattleUI加道具按钮
   - 伤药/定神香/辟邪符战斗中实际效果

3. 先手机制补完
   - 幽影狼/虚形魇怪物先手
   - 石皮蟾玩家先手

4. 设置界面
   - 背景音乐音量
   - 音效音量
   - 文字速度
   - 全屏/窗口切换

5. 视听包装（等美术阶段）
   - 顿帧/震动/光影/音效
   - 虚拟摇杆+Android适配
   - 美术资源替换
   - 背景音乐和音效

---

## 八、已确认设计决策（不可推翻）

- 移除EXP/升级系统，改为五层叙事化成长体系
- 功法栏替代技能页，战斗外可查看，战斗内按钮反映状态
- 旧物背包，无数值加成，物品只影响剧情文本
- 消耗品不放旧物背包，仅在GameData记录数量
- 心绪面板替代任务栏，用第一人称独白指引玩家
- 存档四文件隔离，自动存档不覆盖手动存档
- 幽影狼碰触强制战斗（已确认，不需要按E）
- 虚形魇怪物先手，石皮蟾玩家先手
- 战斗内容扩充：大地图夜晚药婆购买+古井免费回血
- 血条显示数字（HP x/x格式）
- 道心UI不对玩家显示，只在底层记录
- 装备系统保留单槽位，旧剑穗三阶段成长
- 打怪给灵石，灵石买消耗品，形成资源循环
- 游戏定位：先完成第一章让她玩，根据反馈再决定第二章

---

## 九、开发规范（保持不变）

- story_phase只通过advance_phase()推进，禁止直接赋值
- 所有NPC消失统一调用disappear()
- 场景切换统一用SceneTransition.change_scene()
- 对话内容全部在chapter1.json，不硬编码在脚本里
- 存档只在玩家主动离开场景时触发，战斗中不存档
- 信号作用域：每个场景在_ready()连接DialogueManager信号，
  场景切换后自动断开
- UIManager公开接口：refresh_hp()/refresh_all_data()/
  add_item()/on_battle_start()/on_battle_end()
- UIManager.refresh_all_data()目前在TownScene._ready()调用，
  未来加主菜单时改为GameData.data_loaded信号驱动


---

---

## 第八版改动记录

### Bug修复（27项）

**BattleManager.gd**
- `_do_player_bite()` 两处 `var self_dmg := min()` 返回Variant导致战斗瞬间闪退，改为显式 `int` 类型
- `_calc_enemy_dmg()` 里 `var actual := max()` 同类问题，改为显式 `int` 类型
- 所有 `var dmg :=`、`var roll :=`、`var steal :=`、`var fixed_dmg :=` 等Variant推断全部加显式类型

**UIManager.gd**
- `on_battle_start/end` 里直接操作节点，节点释放后崩溃，加 `is_instance_valid()` 保护
- 旧物背包描述文字溢出边界，高度改为72加 `clip_text=true`，面板 `offset_top` 改为-276
- 新增灵石显示：HP面板高度56→72，新增 `_gold_text` Label，`_refresh_hp()` 同步刷新灵石

**TownScene.gd**
- 药婆 `bubble_shown` lambda闭包捕获无效，改用 `vendor.set_meta("bubble_shown")`
- 药婆"按E购买"提示被 `_check_entrance_proximity()` 覆盖，新增 `_near_vendor` 标志优先处理
- 夜晚NPC消失后仍可被按E触发，`_hide_all_npcs_for_night()` 末尾强制清空 `_player._nearby_npcs`
- `_try_vendor_interact()` 用 `get_overlapping_bodies()` 可能为空，改为距离48px兜底检测
- `GameData.stones_read` 直接赋值无类型Array导致类型错误，改为 `Array([...], TYPE_BOOL, "", null)`
- `triggered_events`、`unlocked_old_items` 读档赋值同类类型问题，同样修复

**GameData.gd**
- 玩家名字"无名散修"改为"苏云晚"
- `load_data()` 三处数组赋值类型不匹配，全部改为强类型Array

**BattleUI.gd**
- 普通胜利后 `UIManager.on_battle_end()` 在await前调用，移到await后
- `_get_safe_respawn_pos()` 缺少 `"boss"` 分支，补充 `Vector2(240, -370)`
- 战败时 `current_enemy_id` 提前清空导致走兜底分支，移到 `last_player_position` 赋值后

**TempleScene.gd**
- 内殿门 `body_entered` 只触发一次，读完碑文后无法解锁，新增 `_process()` 实时检测内殿门和BOSS门
- 内殿摄像机 `limit_bottom` 设置错误，玩家不可见，改为0
- `_detect_current_room()` 判断边界错误，`inner` 改为 `py < -50`，`boss` 改为 `py < -320`
- BOSS门解锁条件缺少 `toad_defeated` 检查，补充三处（`_process`、`body_entered`、`_unhandled_input`）
- BOSS战进入时 `advance_phase()` 导致战败返回误触发胜利流程，移到 `after_battle` 对话结束时推进
- 打完BOSS顾飞白在大厅(120,270)，玩家在BOSS间，改为(120,-450)
- 打完BOSS后石碑仍可重复触发BOSS战，石碑交互加 `boss_defeated` 守卫
- 碑文感应区与BOSS门重叠，感应区从 `32x32` 改为 `48x48`
- Stone4下移至 `y=-190`，石皮蟾下移至 `y=-110`

**TempleScene.tscn**
- 内殿/BOSS间Background节点盖住玩家色块，所有Background节点加 `z_index = -1`
- 门视觉色块从绿色调试色改为暗褐色 `Color(0.35, 0.28, 0.20, 0.6)`

**ChapterEndScene.gd**
- 章末画面HP条/心绪/背包未隐藏，`_ready()` 开头调用 `UIManager.on_battle_start()`

### 新增功能
- **KEY_5调试快捷键**（TownScene.gd）：一键跳转废庙内殿，stones_read前三块设为true，幽影狼已击败，石皮蟾存活，phase=3，落点y=-51
- **灵石数量显示**（UIManager.gd）：HP面板下方金色字体实时显示灵石数

### 当前完成状态更新

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 五房间+三种妖兽+BOSS两阶段全部可测 |
| 链路五 章末流程 | ✅ | 路径A/B均验证通过，章末UI已修复 |

### 已确认设计决策（新增）
- 虚形魇"形态模糊"机制废弃，待改为"虚影分裂"（下回合必定侵蚀吸血，等美术阶段补视觉）
- 石皮蟾必须击败才能进BOSS间（已实装）
- BOSS战失败返回BOSS间入口，不重置任何进度
- 顾飞白在BOSS间等待，打完BOSS直接对话走章末

### 待完成任务（按优先级）
1. 虚影分裂机制（替换虚形魇形态模糊行动）
2. 整除警告清理（TownScene.gd大量 `int(x)/TILE_SIZE`）
3. `exp` 变量名冲突 + 废弃EXP系统清理（GameData.gd）
4. 存档系统重构（四文件隔离+主菜单）
5. 战斗消耗品（BattleUI加道具按钮）
6. 功法栏（替代技能页）
7. 虚拟摇杆 + Android适配
8. 美术资源替换
9. 背景音乐和音效

---

## 第九版改动记录

### Bug修复（补充第八版之后）

**DialogueBox.gd**
- _input()：等待选择且逐字完成时，确认键和鼠标点击
  统一放行，修复键盘输入被吞噬导致选项卡死

**ShopScene.gd**
- _check_sword_tassel()：await后加is_inside_tree()检查，
  防止场景切换后访问已释放对象崩溃
- _unhandled_input()：旧剑穗交互条件从phase==0改为phase<3，
  修复Phase1幽灵交互

**BattleManager.gd**
- _do_player_attack()：普通攻击和破甲攻击统一走
  take_damage_raw(raw_dmg)，修复石皮蟾硬壳减伤失效
- _enemy_action_boss_phase1()：吸血前加player.is_alive()守卫，
  防止侵蚀致死后仍触发BOSS二阶段

**TempleScene.gd**
- _ready()：顾飞白生成条件拆分为两个分支：
  boss_defeated and phase==3 → 生成顾飞白
  phase>=4 → 仅隐藏石碑，不生成顾飞白
  修复顾飞白无限刷出问题

**ChapterEndScene.gd**
- _play_ending()：末尾补充await fade_tween.finished
  和get_tree().quit()，修复章末永久黑屏

### 新增功能

**战斗消耗品**
涉及文件：BattleManager.gd / BattleUI.gd / BattleScene.tscn
- ActionType新增USE_POTION
- 伤药：主动使用，恢复30HP，消耗本回合
- 定神香：战斗开始时被动生效，扣1个，设_sense_buff=true，
  首击无视防御×1.2
- 辟邪符：石皮蟾挂毒前被动拦截，两处均已处理
  （硬壳喷毒+普通毒液）
- BattleUI新增ItemButton，显示"伤药(×N)"
- _refresh_item_button()：满血或无药时置灰
- _set_buttons_disabled(true)时强制锁定道具按钮，
  false时按血量库存重新判断

**先手机制**
涉及文件：BattleManager.gd / BattleUI.gd
- 幽影狼/虚形魇：怪物先手（ENEMY_TURN）
- 石皮蟾及其他：玩家先手（PLAYER_TURN）
- _start_battle()顺序调整：先setup()再_refresh_all_hp()，
  修复怪物先手扣血后UI血条不同步

**功法栏**
涉及文件：UIManager.gd
- 右下角新增"悟"按钮，与"囊"并列
- 面板标题"感 悟"，三个技能槽纵向排列
- 解锁条件：蓄势初始、咬牙dao_heart≥1、感应stones_read≥1
- 未解锁显示"技能名（未悟）"并附解锁条件提示
- 与背包面板双向互斥显示
- 战斗中隐藏，战斗结束恢复
- refresh_all_data()同步重建功法槽

**存档系统重构**
涉及文件：GameData.gd / TownScene.gd / ShopScene.gd /
          TeaScene.gd / TempleScene.gd
- 单文件save.json改为四槽位：
  save_auto.json / save_manual_1.json /
  save_manual_2.json / save_crossroad.json
- save_to_file(slot_name="auto")
- load_from_file(slot_name="auto")
- delete_save(slot_name="auto")
- 新增has_save(slot_name) → bool
- 新增get_save_preview(slot_name) → Dictionary
  返回字段：phase / gold / name
- TownScene._ready()删除读档调用，职能移交MainMenuScene
- ShopScene出门/TeaScene离开/TownScene进废庙前
  均写入"auto"槽
- TempleScene顾飞白生成后写入"crossroad"槽

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 消耗品/先手机制已实装 |
| 链路五 章末流程 | ✅ | 章末黑屏已修复 |

### 待完成任务（按优先级）

1. **MainMenuScene**（下一个任务）
   - 新建MainMenuScene.tscn + MainMenuScene.gd
   - 按钮：继续游戏 / 读取存档 / 新游戏 / 退出
   - 继续游戏：读auto槽，按last_scene决定进哪个场景
   - 读取存档：展开选manual_1或manual_2
   - 新游戏：重置GameData，切ShopScene，不清除manual槽
   - project.godot主场景改为MainMenuScene
   - 进入场景判断逻辑：
     last_scene == "shop"   → ShopScene
     last_scene == "tea"    → TeaScene
     last_scene == "temple" → TempleScene
     其他                   → TownScene

2. **UIManager ESC系统菜单**
   - 监听ui_cancel（ESC键）呼出系统面板
   - 按钮：继续 / 存入槽1 / 存入槽2 / 返回主菜单
   - 战斗中（_in_battle==true）和对话中
     （DialogueManager.is_active==true）：
     隐藏存档按钮，只显示继续和返回主菜单

3. 虚拟摇杆 + Android适配
4. 美术资源替换
5. 背景音乐和音效

### 已确认设计决策（新增）
- crossroad存档触发点：TempleScene顾飞白生成后、对话前
- 手动存档入口：ESC系统菜单（不绑NPC，不在主菜单转存）
- 战斗中和对话中ESC：隐藏存档按钮，只显示继续和返回主菜单
- 自动存档四个埋点：
  ShopScene出门 / TeaScene离开 /
  TownScene进废庙前 / TempleScene顾飞白生成后

---

## 已知Bug待修复清单（全量审查记录，暂不处理）

### 🔴 会影响测试的Bug

**BUG-01：`_return_home_triggered` 跨场景重置** ✅ 已修复（第十版）
- 文件：`scripts/TownScene.gd`
- 函数：`_check_return_home_trigger()`
- 现象：story_phase==3时，玩家进茶馆再出来回到TownScene，
  走到杂货铺门口(6,11)会再次触发"灯还亮着"旁白。
- 原因：`_return_home_triggered`是TownScene局部变量，
  场景重新实例化后重置为false。
- 修复方案：将已触发状态移入`GameData.triggered_events`，
  改为`GameData.triggered_events.has("light_still_on")`判断。
- 触发条件：phase3 → 进茶馆 → 出茶馆 → 走回杂货铺门口。

---

### 🟡 不影响当前测试的隐患

**BUG-04：UIManager `_can_save_in_current_scene()` 类型推断错误** ✅ 已修复（第十二版）
- 影响：UIManager加载失败，导致UI全部不可见、ESC无反应、入口检测失效、NPC气泡不显示，四个问题同根同源
- 修复：`var scene_name := scene.name` 改为 `var scene_name: String = scene.name`

**BUG-02：`boss_defeated`字段旧存档兼容** ✅ 已修复（第十版）
- 文件：`scripts/GameData.gd`
- 函数：`load_data()`
- 现象：旧版存档（第七版之前）读入后`temple_dungeon_state`
  可能缺少`boss_defeated`字段。
- 影响：全新游戏不受影响，`TempleScene`已有`.get("boss_defeated", false)`
  兜底保护，当前测试安全。
- 修复方案：`load_data()`里对`temple_dungeon_state`做merge，
  补全缺失字段的默认值。

**BUG-03：`ShopScene`直接操作`SceneTransition._overlay`** ✅ 已修复（第十版）
- 文件：`scripts/ShopScene.gd`
- 函数：`_trigger_night_and_leave()`
- 现象：`SceneTransition._overlay.modulate.a = 1.0`
  访问了AutoLoad单例的约定私有变量。
- 影响：目前可运行，违反封装规范。
- 修复方案：在`SceneTransition.gd`新增`set_overlay_opaque()`公开接口。

---

### 🟢 规范性问题（不影响运行）

**WARN-01：TownScene整除警告** ✅ 已修复（第十版）
- 文件：`scripts/TownScene.gd`
- 现象：`int(_player.global_position.x) / TILE_SIZE`
  在Godot 4里产生整除Warning（约5-6处）。
- 修复方案：改为`int(_player.global_position.x / TILE_SIZE)`。

**WARN-02：EXP/升级系统未清理** ✅ 已修复（第十版）
- 文件：`scripts/GameData.gd`
- 现象：`gain_exp()`/`_level_up()`/`exp`/`level`变量仍保留，
  存档读写也包含这些字段，增加认知负担。
- 修复方案：删除相关函数和变量，存档字段同步清理。

**WARN-03：BattleUI注释与实际不符** ✅ 已修复（第十三版）
- 文件：`scripts/BattleUI.gd`
- 现象：头部注释写"三按钮：攻击/技能/防御"，
  实际第三个按钮text是"感应"。
- 修复：更新注释为"三按钮：攻击/技能/感应"。

---

## 第十版改动记录

### Bug修复与技术债清理

**BUG-01 修复（TownScene.gd）**
- `_return_home_triggered` 局部变量改为 `GameData.triggered_events.has("light_still_on")`
- 删除局部变量声明，触发后写入triggered_events持久化

**BUG-03 修复（SceneTransition.gd / ShopScene.gd）**
- SceneTransition新增 `set_overlay_opaque()` 公开接口
- ShopScene改为调用公开接口，不再直接访问 `_overlay` 私有变量

**WARN-01 修复（TownScene.gd）**
- 所有 `int(x) / TILE_SIZE` 改为 `int(x / TILE_SIZE)`，共5处

**WARN-02 修复（GameData.gd）**
- 删除 `exp` / `level` 变量声明
- 删除 `gain_exp()` / `_level_up()` 函数
- `save_data()` / `load_data()` 同步移除相关字段

**BUG-02 修复（GameData.gd）**
- `load_data()` 中 `temple_dungeon_state` 改为merge加载
- 兼容缺少 `boss_defeated` 字段的旧存档

### 新增功能

**GameData.gd — `reset_to_default()`**
- 新增全量重置函数，所有字段恢复初始值
- 末尾发出 `story_phase_changed` 信号同步UI

**MainMenuScene（新建）**
- 新建 `scenes/MainMenuScene.tscn` + `scripts/MainMenuScene.gd`
- 功能：继续游戏 / 读取存档 / 新游戏 / 退出
- 无auto存档时"继续游戏"置灰，无manual存档时"读取存档"置灰
- 新游戏有存档时弹二次确认面板（纯色块，非系统原生Dialog）
- 读取存档弹槽位选择面板，显示"第一章 灵石X"
- `project.godot` 主场景改为MainMenuScene

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 新增，读档/新游戏/退出均已实装 |

### 待完成任务（按优先级）

1. ESC系统菜单（UIManager监听ui_cancel，战斗/对话中隐藏存档按钮）
2. 虚拟摇杆 + Android适配
3. 美术资源替换
4. 背景音乐和音效

---

## 第十一版改动记录

### 新增功能

**ESC系统菜单（UIManager.gd）**
- UIManager._ready()新增 process_mode = Node.PROCESS_MODE_ALWAYS
- 监听 ui_cancel（ESC键）呼出/关闭系统菜单
- 呼出时 get_tree().paused = true，关闭时恢复
- 所有菜单节点和按钮均设 PROCESS_MODE_ALWAYS，确保暂停后可响应
- 存档按钮仅在可存档场景实例化（TempleScene/BattleScene/对话中不实例化）
- 空槽直接存入，有存档弹二次确认面板
- 返回主菜单弹二次确认面板
- 共用确认面板，mode字段区分

**SceneTransition.gd**
- _ready() 新增 process_mode = Node.PROCESS_MODE_ALWAYS
- 确保游戏暂停状态下场景切换动画仍能正常执行

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 新增完成 |

### 待完成任务（按优先级）

1. 虚拟摇杆 + Android适配
2. 美术资源替换
3. 背景音乐和音效

---

## 第十二版改动记录

### Bug修复

**UIManager.gd — _can_save_in_current_scene() 类型推断错误**
- 错误：var scene_name := scene.name 无法推断类型，导致UIManager解析失败
- 影响：UIManager作为AutoLoad加载异常，导致UI全部不可见、ESC无反应、
  入口检测失效、NPC气泡不显示，四个问题同根同源
- 修复：改为 var scene_name: String = scene.name 显式类型声明

---

## 第十三版改动记录

### Bug修复（第一轮测试员反馈，共12条）

---

#### T-01：场景切换后剧情重置 ✅

**涉及文件：** NPC.gd / TownScene.gd / TownScene.tscn

**根因：** NPC的消失状态和对话切换状态只存在于节点内存，
场景销毁重建后全部归零。

**修复：**
- NPC.gd 新增 `_get_save_key()` 函数，生成"场景名+节点名"的唯一Key
- NPC.gd `disappear()` 写入 `GameData.triggered_events` 持久化消失状态
- NPC.gd 新增 `restore_state_from_save()` 函数，供场景_ready()调用恢复状态
- TownScene.gd `_ready()` 新增NPC状态恢复循环
- TownScene.gd `test_stone` 分支去硬编码，改用 `dialogue_scene_id_after`
- TownScene.tscn NPC_Examiner 补填 `dialogue_scene_id_after = "examiner_after"`

---

#### T-02：存档覆盖失败 / 串档 ✅

**涉及文件：** GameData.gd / MainMenuScene.gd / UIManager.gd

**根因：**
1. Windows下 `DirAccess.rename_absolute` 无法覆盖已存在文件，静默失败
2. `last_scene` 同时承担"出生门判定"和"读档跳转场景"两个职责，导致读档进错场景
3. 新游戏时只重置内存，不清理磁盘旧存档，旧版本存档残留

**修复：**
- GameData.gd `save_to_file()` rename前先删除旧文件
- GameData.gd 新增 `saved_scene_name` 字段，存档时记录真实场景名
- GameData.gd `save_data()` / `load_data()` / `reset_to_default()` 同步处理新字段
- MainMenuScene.gd `_enter_last_scene()` 改用 `saved_scene_name` 而非 `last_scene`
- MainMenuScene.gd `_start_new_game()` 新增清理auto和crossroad槽磁盘文件

---

#### T-03：测完灵根回来找不到任务道具 ✅

**涉及文件：** ShopScene.gd / chapter1.json

**根因：**
1. 旧剑穗是可选道具，早晨未拿则回家流程缺少关键道具
2. 爹的便条没有在回家对话里出现，玩家不知道旧剑穗烫手意味着去废庙
3. 猫咪安慰状态是局部变量，切场景后重置，造成死锁

**修复：**
- ShopScene.gd `_start_return_home_flow()` 强制补发旧剑穗（兜底）
- ShopScene.gd 猫咪交互状态全部持久化到 `GameData.triggered_events`
  （niannian_comforted / dayu_comforted / dayu_approach_triggered /
  sword_tassel_triggered / return_home_done）
- ShopScene.gd 新增防死锁：剑穗旁白已触发时恢复玩家交互权限
- ShopScene.gd `_check_sword_tassel()` 补全完整持久化逻辑
- chapter1.json return_home 场景末尾新增便条节点（rh_note_01~03）
  内容：「若旧剑穗发热，去废庙，别怕。门会开的。」

---

#### T-04：打开包裹时人物跟着走 ✅

**涉及文件：** UIManager.gd

**根因：** 打开背包/功法栏时未暂停游戏，键盘输入同时被角色接收。
`_close_esc_menu()` 有硬编码 `get_tree().paused = false`，
导致背包开着时关ESC菜单会强制解除暂停。

**修复：**
- UIManager.gd 新增 `_update_pause_state()` 函数作为唯一暂停控制源
  逻辑：`paused = _esc_open or _bag_open or _skill_open`
- `_toggle_bag()` / `_toggle_skill_panel()` 末尾调用 `_update_pause_state()`
- `_open_esc_menu()` / `_close_esc_menu()` 去掉硬编码paused，改调 `_update_pause_state()`

额外修复：囊/悟按钮设置 `focus_mode = Control.FOCUS_NONE`，
防止方向键移动焦点误触打开背包/功法栏。

---

#### T-05：混沌灵根未觉醒但技能可用 ✅ Not a Bug / Code Refactored

**结论：** 技能解锁与混沌灵根觉醒是两套独立系统，测试员存在误解。
- 咬牙：道心值≥1解锁（测灵广场做选择后即可）
- 感应：读碑文≥1块解锁
- 混沌灵根觉醒：BOSS战专属剧情，与技能无关

**重构：**
- UIManager.gd `_set_buttons_disabled()` 收拢感应按钮状态检查
  禁用时直接禁用，启用时额外检查 `_is_sense_unlocked()`
- 清理 `_on_turn_changed()` 和 `_on_dialogue_ended()` 中的冗余代码

---

#### T-06：废庙内无法保存 ✅ 设计如此 / 加提示

**结论：** TempleScene和BattleScene禁止存档是设计决策，不是Bug。

**修复：**
- UIManager.gd ESC菜单不可存档场景显示提示文字：
  "（此地气息紊乱，无法刻录神识）"

---

#### T-07：存档后文字没有变化 ✅

**涉及文件：** UIManager.gd

**修复：**
- 存档成功后按钮文字变为"槽位X · 已保存 ✓"并变绿
- 存完档不立刻关闭菜单，让玩家看到反馈

---

#### T-08：存档后返回菜单仍弹"未保存进度将丢失" ✅

**涉及文件：** UIManager.gd

**修复：**
- 新增 `_last_saved_hash` 变量，存档时记录 `JSON.stringify(save_data()).hash()`
- 返回主菜单时对比当前Hash与存档Hash，一致则直接放行
- `refresh_all_data()` 延迟一帧初始化Hash，防止生命周期时间差误报
- 新增 `_update_saved_hash()` 辅助函数

---

#### T-09：NPC对话超前 ✅

**涉及文件：** TeaScene.gd / chapter1.json

**根因：** 太平宗弟子甲乙没有区分去程/回程两套对话，
phase1（测灵前）就能触发测灵失败后的怜悯对话。

**修复：**
- chapter1.json 新增 `disciple_a_before` / `disciple_b_before` 去程对话
  内容：中性闲聊，不涉及测灵结果
- TeaScene.gd `_setup_npcs_by_phase()` 双向显式赋值：
  phase1 → 去程对话（before版）
  phase3 → 回程对话（原版怜悯对话，保留剧情冲击力）
  说书人phase3消失，弟子甲乙phase3留在茶馆

---

#### T-10：键盘操作技能顺序错误 ✅

**涉及文件：** UIManager.gd

**根因：** 囊/悟按钮响应键盘焦点，方向键会在UI控件间移动焦点，
E键触发当前焦点按钮。

**修复：**
- 囊/悟按钮设置 `focus_mode = Control.FOCUS_NONE`（与T-04合并修复）

---

#### T-11：主菜单出现血条和心绪面板 ✅

**涉及文件：** UIManager.gd / MainMenuScene.gd / ShopScene.gd

**根因：** UIManager是AutoLoad，_ready()立刻构建UI并默认显示，
没有场景判断。

**修复：**
- UIManager.gd 重构显隐接口：新增 `hide_main_hud()` / `show_main_hud()`
- `on_battle_start()` / `on_battle_end()` 改为调用通用接口
- UIManager.gd `_ready()` 末尾 `call_deferred("hide_main_hud")` 默认隐藏
- UIManager.gd `refresh_all_data()` 首行调用 `show_main_hud()` 进入游戏时显示
- MainMenuScene.gd `_ready()` 显式调用 `hide_main_hud()`
- ShopScene.gd `_ready()` 新增：phase≥1时调用 `show_main_hud()`
- UIManager.gd `_input()` 新增主菜单场景判断，主菜单下ESC不响应
- ShopScene.gd `morning_done` 事件触发时调用 `show_main_hud()`

---

#### T-12：一开始没有灵石获取渠道 ✅ 引导不足 / 加提示

**结论：** 灵石来源是打废庙妖兽，属于设计如此。
新手引导不足导致玩家困惑。

**修复：**
- TownScene.gd 药婆初次出现气泡改为：
  「没灵石？镇外废庙里游荡的邪祟身上多得是。就看你有没有命去拿。」

---

### 额外优化（测试过程中顺带完成）

- GameData.gd `save_to_file()` 安全写入逻辑强化（rename前删旧文件）
- UIManager.gd 存档系统Hash对比：读档后立刻返回主菜单不误报
- MainMenuScene.gd 新游戏清理auto/crossroad旧存档，手动槽保留
- UIManager.gd `_do_save()` 存档前记录玩家坐标
- GameData.gd 新增 `saved_player_position` 字段
- TownScene.gd `_set_spawn_position()` 优先恢复存档坐标

---

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 便条新增，猫咪状态持久化 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 存档反馈/Hash对比/暂停逻辑重构 |

---

### 文件修改记录（第十三版完整）

```
scripts/NPC.gd               新增_get_save_key()/restore_state_from_save()
                             disappear()加持久化写入
scripts/TownScene.gd         _ready()加NPC状态恢复
                             test_stone分支去硬编码
                             _set_spawn_position()优先恢复存档坐标
                             药婆气泡文案更新
scripts/TownScene.tscn       NPC_Examiner补填dialogue_scene_id_after
scripts/ShopScene.gd         _start_return_home_flow()旧剑穗兜底+状态恢复
                             猫咪状态持久化（5个事件Key）
                             _check_sword_tassel()完整持久化+防死锁
                             morning_done加show_main_hud()
                             _ready()加phase≥1时show_main_hud()
scripts/GameData.gd          save_to_file()rename前删旧文件
                             新增saved_scene_name字段
                             新增saved_player_position字段
                             save_data()/load_data()/reset_to_default()同步
scripts/MainMenuScene.gd     _enter_last_scene()改用saved_scene_name
                             _start_new_game()清理auto/crossroad旧档
scripts/UIManager.gd         新增hide_main_hud()/show_main_hud()
                             on_battle_start/end重构
                             _ready()默认隐藏HUD
                             refresh_all_data()首行show_main_hud()
                             新增_update_pause_state()暂停状态机
                             _toggle_bag/_toggle_skill_panel调用暂停状态机
                             _open/_close_esc_menu去硬编码paused
                             囊/悟按钮focus_mode=FOCUS_NONE
                             新增_last_saved_hash/Hash对比逻辑
                             新增_update_saved_hash()/call_deferred
                             ESC菜单不可存档场景加提示文字
                             _input()主菜单不响应ESC
                             _do_save()记录玩家坐标
scripts/TeaScene.gd          _setup_npcs_by_phase()双向赋值去程/回程对话
data/chapter1.json           return_home新增便条节点rh_note_01~03
                             新增disciple_a_before/disciple_b_before场景
```

---

### 待完成任务（按优先级）

1. 虚拟摇杆 + Android适配
2. 美术资源替换
3. 背景音乐和音效

---

## 第十三版补充改动

### 额外修复与优化

**旧剑穗获取方式修正（ShopScene.gd）**
- 根因：设计文档要求大鱼叼来剑穗时自动给予，
  但代码实现为柜台角落隐形感应区按E获取，与设计不符。
- 修复：
  - 删除 `_setup_sword_tassel_interact()` 函数及所有调用
  - 删除 `_unhandled_input()` 里的旧剑穗检测逻辑
  - `_start_morning_flow()` 设置大鱼对话为 `dayu_morning`
  - `_on_dialogue_ended("dayu_morning")` 自动补发旧剑穗并播放旁白
- 效果：morning流程与大鱼互动结束后，自动获得旧剑穗并触发旁白，
  无需玩家主动寻找隐形交互区。

**WARN-03 修复（BattleUI.gd）**
- 头部注释"三按钮：攻击/技能/防御"改为"三按钮：攻击/技能/感应"

**TeaScene持久化问题确认**
- 经代码审查，TeaScene不存在持久化问题。
- `_setup_npcs_by_phase()` 每次 `_ready()` 调用时直接读取
  `GameData.story_phase` 重建NPC状态，不依赖局部变量，无需修复。

### 文件修改记录（第十三版补充）

```
scripts/ShopScene.gd    删除_setup_sword_tassel_interact()函数
                        删除_unhandled_input()旧剑穗检测逻辑
                        _start_morning_flow()设置大鱼dayu_morning对话
                        _on_dialogue_ended新增dayu_morning分支
scripts/BattleUI.gd     头部注释更新（防御→感应）
```

### 当前链路状态（第十三版最终）

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 旧剑穗获取方式修正为大鱼互动自动给予 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 待完成任务（按优先级）

1. 虚拟摇杆 + Android适配
2. 美术资源替换
3. 背景音乐和音效

---

## 第十四版改动记录

### 新增功能

**觉醒一击改为玩家主动触发（BattleManager.gd / BattleUI.gd）**

设计动机：将BOSS战最高潮时刻从"系统自动演算"改为"玩家主动确认"，
极大提升代入感。这一击由玩家亲手打出，不是旁观。

修改内容：

BattleManager.gd：
- TurnState枚举新增 WAITING_FOR_AWAKENING 状态
- 新增信号 ready_for_awakening()
- turn_start() 第三回合不再自动调用 _do_awakening()，
  改为切换至 WAITING_FOR_AWAKENING 状态并发出信号
- 新增公开接口 execute_awakening()，供BattleUI点击回调后调用

BattleUI.gd：
- 连接新信号 ready_for_awakening
- 新增 _on_ready_for_awakening() 函数：
  · 禁用所有常规战斗按钮
  · 并行Tween淡出四个面板（SkillPanel/PlayerPanel/EnemyPanel/LogPanel）
  · 等待0.8秒情绪铺垫
  · 渐入显示居中大字按钮「——挥出去。」（字号32，暖白色）
  · 玩家点击后调用 execute_awakening()
- _show_battle_ui() 新增四个面板透明度重置，防止战斗结束后残留

TownScene.gd（调试）：
- 新增 KEY_6 调试快捷键，直接进入BOSS战且BOSS血量30/120，
  方便快速验证第二阶段和觉醒流程

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 觉醒一击改为玩家主动触发 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 文件修改记录（第十四版）

```
scripts/BattleManager.gd   新增WAITING_FOR_AWAKENING枚举
                           新增ready_for_awakening信号
                           turn_start()第三回合改为发信号挂起
                           新增execute_awakening()公开接口
scripts/BattleUI.gd        连接ready_for_awakening信号
                           新增_on_ready_for_awakening()
                           _show_battle_ui()补充透明度重置
scripts/TownScene.gd       新增KEY_6调试快捷键
```

### 已完成补充

- ✅ 功法栏（UIManager.gd "悟"按钮，感悟面板，三技能解锁状态展示）
- ✅ 战斗消耗品（伤药/定神香/辟邪符已接入BattleManager和BattleUI）

### 待完成任务（按优先级）

1. 虚拟摇杆 + Android适配
2. 美术资源替换
3. 背景音乐和音效

---

## 第十五版改动记录

### 核心改动：道心值系统移除 + 主角性格重塑

**设计动机：**
经测试员反馈及深度设计评审，确认苏云晚的核心性格为"无所谓权力与力量，
只念着那个家"。原有道心值系统（warm/stubborn二元选择）与该性格定位矛盾，
予以彻底移除。同时重写三个核心情感节点的文本，使人物形象更加统一清晰。

### 文本重写（chapter1.json）

**test_stone场景重写：**
删除原有性格选项分支，改为连续旁白，落点为：
「口袋里的旧剑穗硌着手。」「回家。」
体现苏云晚对测灵结果真正的无所谓——她的心思从来不在这里。

**activation_monologue合并为单一版本：**
删除stubborn/warm两个差分版本，统一为：
「原来如此。」「……妖？」「也不知道管不管用。」「试试吧。」
不是热血，不是隐藏大佬，是一个普通人在不确定结果时决定不跑。

**battle_loss合并为单一版本：**
删除stubborn/warm两个差分版本，统一为：
「她倒下去的时候，脑子里忽然很安静。」
「不知道为什么，想到了家里还开着的那盏灯。」
「她慢慢撑起来。」
因为舍不得，所以站起来了。

### 系统移除（代码层）

**GameData.gd：**
- 删除 dao_heart_stubborn / dao_heart_warm 变量定义
- reset_to_default() / save_data() / load_data() 同步删除
- 删除残留注释「道心系统：记录玩家选择倾向」

**TownScene.gd：**
- 删除 _on_event_triggered() 里的 dao_heart_warm / dao_heart_stubborn 两个分支
- 删除 KEY_6 调试代码里的 GameData.dao_heart_warm = 1

**TempleScene.gd：**
- 激活独白选择逻辑拍平，直接调用 activation_monologue

**BattleUI.gd：**
- 战败独白选择逻辑拍平，直接调用 battle_loss
- _is_bite_unlocked() 改名为 _is_quixue_unlocked()，直接返回 true
- _on_bite_pressed() 改名为 _on_quixue_pressed()
- 按钮文字「咬牙」全部改为「淬血」

**BattleManager.gd：**
- 顶部注释、ActionType枚举注释更新为「淬血」
- _do_player_bite() 改名为 _do_player_quixue()
- 所有 log 文字「咬牙」替换为「淬血」

**UIManager.gd：**
- SKILL_DATA 的 bite 条目：name/desc/unlock 全面更新为「淬血」
- _rebuild_skill_panel() / _on_skill_slot_pressed() 解锁判断改为 true

### 技能改动

**咬牙 → 淬血：**
- 解锁条件：dao_heart≥1 → 初始即有
- 数值不变：自损固定10HP，造成 ATK×1.5+已损失HP×0.5 真实伤害
- 设计意图更新：以血换伤，不是挣扎，是她本来就会这么做

### 文件修改记录（第十五版）

```
data/chapter1.json         test_stone场景重写
                           activation_monologue合并（删除stubborn/warm两版）
                           battle_loss合并（删除stubborn/warm两版）
                           ts_choice dao_heart事件节点随场景删除
scripts/GameData.gd        删除dao_heart变量/存读档/残留注释
scripts/TownScene.gd       删除dao_heart事件处理分支
                           删除KEY_6调试里的dao_heart_warm赋值
scripts/TempleScene.gd     激活独白选择逻辑拍平
scripts/BattleUI.gd        战败独白拍平/咬牙→淬血/解锁条件改初始
scripts/BattleManager.gd   函数改名/注释更新/log文字替换
scripts/UIManager.gd       SKILL_DATA更新/解锁条件改true
docs/wendao_01_设计文档.md  战斗失败描述更新/存档字段删道心值/技能表更新
docs/wendao_04_战斗与世界观设计文档.md  淬血替换/道心值段落删除/BOSS流程更新
```

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | test_stone重写，无选项分支 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | activation_monologue合并 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 待完成任务（按优先级）

1. 虚拟摇杆 + Android适配
2. 美术资源替换
3. 背景音乐和音效

---

## 第十六版（2026-04-09）

### 主题：战斗系统回合制重构 + BUG修复

### 核心改动

**1. 感应+蓄势叠加BUG修复（BattleManager.gd）**
- 修复：`_charged` 和 `_sense_buff` 同时为 true 时，`elif` 导致感应增益被静默丢弃
- 修复后：新增 `if _charged and _sense_buff` 分支，伤害 = `atk × 2 × 1.2`
- 对应日志：「蓄势感应双发」

**2. 文案统一：蓄势"下回合" → "下一击"**
- BattleManager.gd 战斗日志：`（下回合攻击将破甲×2）` → `（下一击破甲×2）`
- BattleUI.gd 技能 tooltip：`下回合攻击×2且破甲` → `下一击×2且破甲`
- 统一与代码实际行为一致（flag 可跨回合保留直到攻击）

**3. 回合制重构：双方同回合结算（BattleManager.gd 重写）**

旧模式：`PLAYER_TURN → ENEMY_TURN` 交替，敌方先手时一进战斗就被打
新模式：每回合始终从玩家选择开始，确认后按先手顺序结算双方行动

- 删除 `ENEMY_TURN` 状态枚举，敌方行动嵌入 `player_action()` 内部
- 新增 `_enemy_first: bool` 先手标记，`setup()` 根据怪物名设置
- `player_action()` 重构为完整回合执行器：
  - 第一步：准备玩家状态（感应/蓄势/喝药等）
  - 第二步：按先手顺序结算（敌先手=敌→玩家，玩家先手=玩家→敌）
  - 每步结算后检查死亡，死方不再行动
  - 第三步：双方存活则 `turn_start()` 进入下一回合
- 新增 `_run_enemy_action()`：纯 AI 执行，不做状态转换
- 删除 `enemy_action()`、`execute_enemy_turn()` 旧接口
- 日志显示「── 第 N 回合 ──」替代原来的「── 玩家回合 ──」「── 敌方回合 ──」

BattleUI.gd 配套改动：
- `_start_battle()`：setup 后延迟 1 秒再调 `turn_start()`（开局对峙画面）
- 删除 `_on_turn_changed()` 中 ENEMY_TURN 延迟分支

**4. 虚形魇模糊预告制修复（BattleManager.gd）**
- 修复：同回合制下，敌方设置模糊后玩家同回合攻击就落空，玩家无法看到预警再反应
- 修复后：`_boss_blur` 拆分为 `_boss_blur`（当前生效）和 `_boss_blur_next`（预告）
  - 敌方行动设置 `_boss_blur_next = true`
  - 下回合 `_run_enemy_action()` 开头：`_boss_blur = _boss_blur_next; _boss_blur_next = false`
  - 预警回合玩家攻击正常命中，下回合才真正免疫
- 感应预告也同步检查 `_boss_blur or _boss_blur_next`

**5. 模糊跨回合持续BUG修复（BattleManager.gd）**
- 修复：玩家连续不攻击时 `_boss_blur` 无限期挂着
- 修复后：`_run_enemy_action()` 开头每回合重置，blur 只持续一个回合

**6. 技能子菜单定位BUG修复（BattleUI.gd）**
- 修复：`Control.new()` 无布局能力，两个按钮重叠在左上角
- 修复后：改为 `VBoxContainer.new()`，定位到技能按钮左侧弹出

### 文件修改记录（第十六版）

```
scripts/BattleManager.gd   回合制重构（全文重写）
                           感应+蓄势叠加修复
                           蓄势文案"下一击"统一
                           模糊预告制+跨回合修复
scripts/BattleUI.gd        开局延迟+ENEMY_TURN分支删除
                           技能子菜单VBoxContainer定位
                           蓄势tooltip文案统一
```

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 战斗系统重构 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 待完成任务（按优先级）

1. 虚拟摇杆 + Android适配
2. 美术资源替换
3. 背景音乐和音效

---

## 第十七版（2026-04-09）

### 主题：战斗演出效果 + 虚拟摇杆 + 测试员BUG修复（7项）

### 新增功能

**1. 战斗演出效果（BattleUI.gd）**
- 受伤面板闪红：玩家/敌人受伤时对应 Panel 闪红 0.08s → 0.25s 缓出恢复
- 屏幕震动：单次受伤 ≥15 点时 UI 根节点随机抖动 6 次
- HP 条平滑过渡：0.3s EASE_OUT 缓动，替代瞬间跳变
- 觉醒全屏白光：0.12s 闪白 → 0.3s 维持 → 0.8s 消退，配合屏幕震动
- 统一行动入口 `_execute_action()`：记录 HP → 执行 → 检测伤害差值 → 触发演出

**2. 虚拟摇杆（VirtualJoystick.gd，AutoLoad 单例）**
- PC 端自动隐藏（零开销），Android 端显示
- 左侧摇杆：触屏拖动控制移动，通过 Input.action_press/release 注入，Player.gd 零改动
- 右下角互动按钮（模拟 E 键）+ 菜单按钮（模拟 ESC）
- 战斗/对话/ESC 菜单期间自动隐藏并释放输入
- 支持多点触控（event.index 区分触摸点）

### BUG修复（7项）

**BUG-1：茶馆/杂货铺存档后读档出生位置错误**
- 现象：茶馆存档 → 读档 → 出门后出现在杂货铺门口（而非茶馆门口）
- 根因：ESC 菜单存档记录了室内坐标（saved_player_position），场景离开时的自动存档没有清除该值，TownScene 用室内坐标作为大地图出生点
- 修复：TeaScene / ShopScene / TownScene（进废庙前）离开时存档前清除 saved_player_position

**BUG-2：药婆购买后灵石UI不刷新**
- 现象：有 16 灵石，买了伤药成功但左上角仍显示 16，再买提示"灵石不够"
- 根因：buy_heal_potion / buy_incense / buy_talisman 三个事件处理器没有调用 UIManager.refresh_hp()
- 修复：三个购买分支都加 UIManager.refresh_hp()

**BUG-3：心绪面板夜晚不更新**
- 现象：夜晚准备去废庙时，心绪仍显示"回来了。没测出来。镇子还是那个镇子。"
- 根因：MOOD_TEXTS 只按 story_phase 选择，phase 3 没有区分夜晚前后；缺少 phase 2 条目
- 修复：_refresh_mood() 增加 night_triggered 差分（phase 3 + 夜晚 → 显示废庙相关心绪）；补充 phase 2 心绪

**BUG-4：内殿/BOSS间对话重复触发**
- 现象：出废庙再进来，进入内殿或 BOSS 间时入场对话重新播放
- 根因：_inner_hall_entered / _boss_room_entered 是脚本局部变量，每次进场景重置为 false
- 修复：迁移至 GameData.triggered_events 持久化

**BUG-5：打完BOSS后重读碑文导致石碑重新出现**
- 现象：BOSS 击败后出废庙再进 → 读 Stone4 → BOSS 间石碑重新出现
- 根因：_check_all_stones_read() 无条件调用 _monolith.show()，不检查 boss_defeated
- 修复：增加 boss_defeated 判断，已击败时不再显示石碑

**BUG-6：战斗演出 tween 堆叠/位置漂移**
- 现象：连续受伤时 HP 条抖动、闪红恢复到错误颜色、屏幕震动后 UI 位置偏移
- 根因：HP tween 堆叠、_flash_panel 捕获中间态颜色、_shake_screen 捕获偏移中的位置
- 修复：HP tween 新建前 kill 旧的；闪红恢复到固定 Color.WHITE；震动位置只记录一次 + kill 旧 tween

**BUG-7：虚拟摇杆按钮只发 press 不发 release**
- 现象：按互动/菜单按钮后，按键在 Input 系统中永久保持"按下"状态
- 修复：button_up 信号连接释放事件

### 体验优化

**淬血低血量提示**
- 当自损被压制（< 10 HP）时，战斗日志额外提示："（气血不足，淬血自损被压制到 X 点）"
- 帮助玩家理解淬血不会自杀的保底机制

### 文件修改记录（第十七版）

```
scripts/BattleUI.gd          战斗演出（闪红/震动/HP缓动/白光）
                             tween堆叠修复
                             _execute_action统一入口
scripts/BattleManager.gd     淬血低血量日志提示
scripts/VirtualJoystick.gd   新增：虚拟摇杆AutoLoad
scripts/TempleScene.gd       内殿/BOSS间对话持久化
                             石碑重现修复
scripts/TownScene.gd         药婆购买UI刷新
                             进废庙存档清坐标
scripts/TeaScene.gd          离开时存档清坐标
scripts/ShopScene.gd         离开时存档清坐标
scripts/UIManager.gd         心绪夜晚差分 + phase 2 补充
project.godot                注册VirtualJoystick AutoLoad
```

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 存档坐标修复 |
| 链路四 废庙流程 | ✅ | 对话持久化 + 石碑修复 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 待完成任务（按优先级）

1. 美术资源替换

---

## 第二十五版（2026-04-14）—— 战斗边界修复 + 剑穗叙事重排

### 一、Bug修复（5项）

| 文件 | 修复内容 |
|------|----------|
| `scripts/ChapterEndScene.gd` | `_show_line()` 逐字显示接入 `dialogue_skip`；并修复 `UIManager` 判空顺序（先判空后调用） |
| `scripts/TempleScene.gd` | `_trigger_wolf_battle()` 增加 `SceneTransition.is_transitioning` + `DialogueManager.is_active` 守卫，防止幽影狼战斗重入 |
| `scripts/ShopScene.gd` | `_start_letter_flow()` 补齐 phase5 NPC 交互关闭：禁用玩家NPC交互并清空年年/大鱼 `dialogue_scene_id` |
| `scripts/BattleManager.gd` | `USE_POTION` 改为先结算（扣药+回血+turn_start后 return），修复敌先手下“死亡后回血”顺序漏洞 |
| `scripts/BattleUI.gd` | `_on_battle_log()` 在 `await process_frame` 后补 `is_inside_tree()` 守卫，避免跨场景访问已释放节点 |

### 二、叙事与数据调整

**`data/chapter1.json`**
- `morning` 场景在 `m_05` 与 `m_07` 之间新增 `m_05b`、`m_05c`，将旧剑穗获取改为主线自动叙事
- `dayu_morning` 改为纯猫咪互动（`dm_01`~`dm_04`），移除剑穗相关叙述
- 删除整段 `old_sword_tassel` 场景（已不可达且与新版叙事冲突）

**`scripts/ShopScene.gd`**
- `morning_done` 事件新增 `UIManager.add_item("sword_tassel")`，将旧剑穗发放时机固定到 morning 主线
- `dayu_morning` 对话结束回调改为仅保留兜底发放，不再触发额外旧剑穗独白

**`scripts/UIManager.gd`**
- `ITEM_DATA["sword_tassel"]["desc"]` 更新为新版设定文案：
  - 柜台角落压了许久的旧物
  - 大鱼从门缝叼进来
  - 穗绳结扎很紧，不像被丢弃

### 三、文件修改记录（第二十五版）

```
data/chapter1.json           morning新增 m_05b/m_05c
                             dayu_morning 改写为纯猫咪互动
                             删除 old_sword_tassel 场景
scripts/ChapterEndScene.gd   章末逐字显示接入 dialogue_skip + 判空顺序修复
scripts/TempleScene.gd       幽影狼战斗触发重入守卫补齐
scripts/ShopScene.gd         phase5 NPC交互关闭 + sword_tassel 发放时机调整
scripts/BattleManager.gd     USE_POTION 先结算，修复死亡后回血顺序问题
scripts/BattleUI.gd          battle_log await 后 is_inside_tree() 防护
scripts/UIManager.gd         sword_tassel 道具描述更新为新版设定
```
2. 背景音乐和音效

> 注：存档系统已完成四文件隔离（auto/manual_1/manual_2/crossroad）+ 主菜单选档，无需重构。

---

## 第二十六版（2026-04-15）—— 美术全面优化

### 主题：水墨渲染 / 粒子特效 / 立绘剪影 / 装饰物 / 按钮动画

### 一、Shader 与粒子
- `shaders/ink_wash.gdshader`：纸纹噪声 + 横纹扫描线，参数可调
- `scripts/BattleParticles.gd`（新）：命中墨点飞溅 + 技能金色爆裂，layer=6

### 二、UI 装饰
- `DialogueBox.gd`：对话框顶部金色分割线 + 四角 ◆ 装饰 + 角色剪影立绘
- `scripts/PortraitControl.gd`（新）：程序化 `_draw()` 半身剪影，无需外部图片
- `scripts/ButtonAnimator.gd`（新，AutoLoad）：全局按钮悬停/按下 Tween 动画

### 三、场景粒子与装饰
- `ShopScene.gd` / `TempleScene.gd`：环境尘埃/雾气粒子，CanvasLayer layer=1
- `TownScene.gd`：TileMap 格子颜色噪声扰动 + 老榕树/古井/公告栏 `Polygon2D` 装饰

### 四、Bug 修复
- `BattleUI.gd` match 语法修正
- `DialogueBox.gd` 角装饰判重
- `ButtonAnimator.gd` pivot 保护

---

## 第二十七版（2026-04-15）—— 代码清理 + BattleUI 拆分 + 内容健康检查

### 一、代码清理
- `.gitignore` 补充 `*.bak` / `*.uid` / `tools/` / `docs/word_export/`
- 删除 `scripts/BattleUI.gd.bak`

### 二、BattleUI 拆分
`scripts/BattleUI.gd`（766 行）拆为协调层 + 两个新文件：
- `scripts/BattleEffects.gd`（新，约 130 行）：视觉特效（flash_panel / shake_screen / flash_white / tassel 动画 / HP tween）
- `scripts/BattleSkillMenu.gd`（新，约 80 行）：技能子菜单（按钮创建 / 焦点导航 / sense 解锁查询）
- `BattleUI.gd` 减至约 270 行，只做事件调度与 UI 状态协调

### 三、内容健康检查
对 `data/chapter1.json` 做量化审计（408 节点 / 4 选择节点 / 2 真实分支），输出《内容健康检查报告》。结论：当前形态更接近线性 VN 而非 RPG，缺少玩家选择驱动的分支——为 v28 起的 RPG 化改造铺路。

---

## 第二十八版（2026-04-16）—— 垂直切片：分支基础设施 + morning 父亲选择 + letter 回响

### 主题：为 RPG 化改造铺设基础设施，先验证一条完整支付链

### 一、基础设施（Phase 0）
- `GameData.gd` 新增 `narrative_flags: Dictionary = {}`，持久化进存档（`save_data` / `load_data` / `reset_to_default` 同步）
- `DialogueManager.gd`：
  - `_go_to_node()` 支持节点字段 `if_flag`（条件跳转）和 `set_flag`（节点级 flag 写入）
  - `make_choice()` 处理选项携带的 `set_flag`
  - 支持"纯跳转节点"——有 `if_flag` 无 `text` 时自动透传到 `next`
  - `_end` 与空 `next` 统一走 `_end_scene()`

### 二、内容（Phase 1 首个切片）
- **morning**：`m_08b` 选择——「嗯。爹你也吃。」(`father_morning_warm`) / 沉默点头(`father_morning_silent`)
- **letter**：`lt_06b` if_flag 节点——`father_morning_warm` 命中时显示 `lt_06c_warm` 额外回响独白

---

## 第二十九版（2026-04-16）—— Phase 1 剩余选择节点全量植入

### 一、内容改动（`data/chapter1.json`）
- **test_stone**：`ts_05c` 选择——握紧剑穗(`self_test_calm`) / 快步走开(`self_test_hurt`)
- **temple**：`tp_07b` 选择——挡在路前(`self_temple_brave`) / 手在抖但没退(`self_temple_scared`)
- **letter**：`lt_11b` 选择——「知道了，爹」/「我会回来的」(`father_letter_promise_return`)
- **after_battle** / **after_battle_coin**：`ab_07b` 三选一追问顾飞白（`gu_pressed_who` / `gu_pressed_where` / 沉默），`ab_choice` 写入 `path_ending` flag（`"follow"` / `"return"`）

### 二、Phase 1 完成后 narrative_flags 清单（10 个）
`father_morning_warm/silent`, `self_test_calm/hurt`, `self_temple_brave/scared`, `father_letter_promise_return`, `gu_pressed_who/where`, `path_ending`

---

## 第三十版（2026-04-16）—— Phase 2 性格雕刻 + requires_flag 基础设施

### 一、基础设施
`DialogueBox.gd` `_show_choices()` 加 `requires_flag` 过滤：
- 按钮按需显示，保留原始 choice 数组索引传给 `DialogueManager`
- 过滤后按钮序号与数据索引解耦

### 二、内容（Phase 2）
- **market**：`mk_07b` 选择——掏灵石(`self_market_proud` + `town_paid_old_lady`) / 道谢
- **vendor_b**：`vb_01b` 选择——买桂皮 / 回来再买(`father_cinnamon_forgot`)；**return_home**：`rh_04b` if_flag 回响（灶台无桂皮味）
- **aunts_return**：`ar_08` 选择——回头看(`town_aunts_confronted`) / 沉默走开
- **teahouse_before**：`tb_05b` 选择——「他想去吗？」(`self_teahouse_curious`) /「家里人呢？」
- **disciple_b**：`db_b07` 选择——「碎玉镇挺好」(`requires_flag: self_test_calm`) / 沉默（条件可见选项首秀）
- **celebration_boy**：`cb_06b` 选择——点头笑(`town_celebration_smile`) / 移开视线

### 三、Phase 2 新增 narrative_flags（7 个）
`self_market_proud`, `town_paid_old_lady`, `father_cinnamon_forgot`, `town_aunts_confronted`, `self_teahouse_curious`, `town_disciple_calm_reply`, `town_celebration_smile`

---

## 第三十一版（2026-04-17）—— Phase 3 lore / 探索回响

### 主题：探索回报型分支与 if_flag 回响链

### 一、内容改动（`data/chapter1.json`）
- **bowl_interact**：`bi_07` 选择——记住「她」(`mother_bowl_lingered`) / 转身走开
- **old_wanderer**：`ow_10b` 选择——追问(`lore_wanderer_asked`) / 点头不再问；新增 `ow_10c/d` 老人答话
- **fortune_teller**：`ft_06b` 选择——追问(`lore_fortune_pressed`) / 沉默；新增 `ft_06c/d`
- **fortune_teller_coin**：`ftc_04b` if_flag 节点——`lore_fortune_pressed` 命中插入 `ftc_04c` 额外回响
- **tally_marks**：`tm_06` 后插入双层 if_flag 链——`mother_bowl_lingered`→`tm_06b` + `lore_wanderer_asked`→`tm_06c`
- **transmission_array**：`ta_05` 后插入 if_flag——`mother_bowl_lingered`→`ta_05b`
- **remnant_page_1~4**：每张残页末节 set_flag 写入 `lore_page_1_read` ~ `lore_page_4_read`
- **boss_room_enter**：`bre_05b` 后插入 if_flag——`lore_page_3_read`→`bre_05c`（残页字句浮现）

### 二、Phase 3 新增 narrative_flags
`mother_bowl_lingered`, `lore_wanderer_asked`, `lore_fortune_pressed`, `lore_page_1_read` ~ `lore_page_4_read`

---

## 第三十二版（2026-04-17）—— Phase 4：觉醒一击家之回响链

### 主题：全章叙事高潮——主角"只为家"的道在觉醒瞬间兑付

### 一、设计基调
主角苏云晚的道心核心：**外部仙途 / 灵根 / lore 一概无所谓，心中只有那个小家（爹 + 年年 + 大鱼）**。觉醒一击前的意识流不是"我是什么样的人"的性格回顾，而是"我要回去见他们"的纯粹冲动。

### 二、内容改动（`boss_awakening`）
在 `ba_06`（爹放下饭碗的背影）与 `ba_06b`（便条"别怕"）之间插入三条"家之回响"链，沿用现有单 flag `if_flag` 链式机制，不改引擎：

| Flag | 回响台词 | 对应行为 |
|---|---|---|
| `father_morning_warm` | 今早爹伸手添饭时顿了一下。她说过"你也吃"。 | 早上对爹说"你也吃" |
| `father_cinnamon_forgot` | 灶台上那包桂皮还没买回去。 | 没去集市买桂皮 |
| `father_letter_promise_return` | 信上写过四个字——"会回来的"。 | 回信承诺回家 |

### 三、刻意不纳入觉醒回响的 flag
- `self_test_calm/hurt` / `self_temple_brave/scared` —— 外部事件对主角只是任务，不构成她的内核
- `mother_bowl_lingered` —— 母亲是另一层缺席伏线，应在其他时刻兑付
- `lore_*` / `town_*` / `gu_*` —— 与"只为家"的道无关

### 四、极端情况
- 全命中：7 段蒙太奇（年年 → 大鱼 → 爹背影 → 今早话 → 桂皮 → 会回来 → 别怕）
- 零命中：跟原版一致（年年 → 大鱼 → 爹背影 → 别怕）——沉默派玩家不凭空多出什么

---

## 第三十三版（2026-04-18）—— 按"主角的道"基调审查 Phase 1-3 台词（17 处）

### 主题：按 v32 确立的角色基调反向收紧 Phase 1-3 已植入文本

### 一、基调原则
主角不煽情、不自我表演、不做形而上联想，只记家里的事；外部 lore 作为画面浮现而非主角思考。

### 二、改动明细

**Phase 1 相关（4 处）**
- `morning` `m_09`：去掉"鼻子一酸"，改为"和往常没什么两样"
- `test_stone` `ts_05c[1]`：去掉"希望谁都别看她"的受伤感
- `temple` `tp_07b[0]`：去掉"深吸一口气"的表演感
- `after_battle` / `after_battle_coin` `ab_07b[0][1]`：缩至「谁？」/「通向什么？」

**Phase 2 相关（6 处）**
- `market` `mk_07b[0]`：「不能白拿」→「我给钱」（去书面语）
- `market` `mk_07b[1]`：去掉煽情「……」
- `return_home` `rh_04c`：「忽然想起——忘了」→「早上那一摊，她没买」
- `aunts_return` `ar_09`：去掉"三秒之后"精确计时
- `disciple_b` `db_b06`：「比骂还难受」→「觉得有点堵」
- `celebration_boy` `cb_07`：「她也移开视线」→「她继续走」（修复选项[0]逻辑）

**Phase 3 相关（7 处）**
- `bowl_interact` `bi_07[0]`：去掉"在心里默默"
- `old_wanderer` `ow_10b[0]`：去掉"老人家见过那种"套话
- `fortune_teller` `ft_06b[0]`：去掉"既然看出来了"冗余
- `tally_marks` `tm_06b`：删除"是否也曾……刻下什么"哲学联想
- `tally_marks` `tm_06c`：「大概也是这样……」→「有些人活着，是为了等」
- `transmission_array` `ta_05b`：删除"都是同一种等待"作者总结
- `boss_room_enter` `bre_05c`：删除"写下它们的人也曾站在这里"史学联想

---

### 当前链路状态（v33 后）

- Phase 0-4 RPG 化改造全部落地
- `data/chapter1.json` 选择节点：约 22 个（从 v27 的 4 个增至 22）
- `narrative_flags` 共约 22 个，持久化进存档
- 觉醒一击支持 0~3 段动态回响（家之回响链）
- 主角"只为家"的道在 v32-v33 两轮迭代中立住

### 待完成任务（按优先级）
1. 端到端试玩——验证所有分支触发（沉默派 vs 全选项派两条路径）
2. Opus 待做：第二章规划与角色/修炼路线设计文档
3. 远期：第二章内容制作

---

## 第三十四版（2026-04-18）—— morning 对话修正 + flag 兑付补强（6 处）

### 一、morning 对话修正

用户试玩发现 `m_08b` 选项[0]「嗯。爹你也吃。」不合逻辑——爹在门口嘱咐她出门，并非共餐。另外 `m_09` 开头与 `m_08b` 引导文"爹向来不多说话"重复。

重新定位：主角"无所谓/只为家"基调下**她不会多说话**，温度应由动作承载。

- `morning` `m_08b` 选项[0]：「嗯。爹你也吃。」→ （她点了点头，在门口多停了一下）
- `morning` `m_08b` 选项[1]：（沉默地点了点头）→ （她点了点头）
- `morning` `m_09` 去掉开头重复的"爹向来不多说话"
- `boss_awakening` `ba_cb_father` 同步：从"爹伸手添饭"画面改为"今早她出门前，在门口多停了一下"
- `letter` `lt_06c_warm` 同步：改为"她想起今早在门口多停的那一下"

**设计要义**：选项差别只在"有没有留恋那一秒"，那一秒是全部的温度。

### 二、flag 兑付补强（6 处）

#### 2.1 现状诊断
v33 结束时 22 个 `narrative_flags` 中，仅 10 处有回响兑付，12 个 flag 在第一章内无反馈点——玩家对约半数选项"没感知"。

#### 2.2 兑付新增

**① `lore_page_1_read` 降低 boss_room_enter 触发门槛**
`bre_05_lore_check` 的 `if_flag` 从 `lore_page_3_read` 改为 `lore_page_1_read`——读过任何一张残页都触发残页字句浮现。

**② `self_temple_brave` / `self_temple_scared` → after_battle 开头回响**
`ab_01` 后插入双 if_flag 链（`after_battle` / `after_battle_coin` 两场景同步）：
- brave 命中 `ab_01_brave`：挡在路前的那一下，现在还在手里。
- scared 命中 `ab_01_scared`：从庙门口开始，这手就没停下来过。

**③ `self_test_hurt` → letter 开头**
`letter.start` 从 `lt_01` 改为 `lt_00_check`；新增：
- `lt_00_hurt`：下午石台上那些目光，她还记得。

**④⑤ `gu_pressed_who` / `gu_pressed_where` + `self_teahouse_curious` → ab_choice 前回响链**
`ab_08`（after_battle）/ `abc_coin_06`（after_battle_coin）到 `ab_choice` 之间插入 3 段 if_flag 链：
- `ab_recall_who`：他没答她那句「谁」。
- `ab_recall_where`：他没答清那句「通向什么」。
- `ab_recall_boy`：那个被太平宗带走的少年。

**⑦ `town_celebration_smile` → return_home 开头**
`return_home.start` 从 `rh_01` 改为 `rh_00_check`；新增：
- `rh_00_boy`：路过那少年家门口时，灯笼还亮着。

#### 2.3 原提案中取消的一条（⑥）
`self_market_proud` → letter 碰符回响：**审查后取消**，`mk_07c` 已经当场兑付（老婆婆连人带篮子与灵石一同消失），再加晚上回响是冗余。

### 三、flag 兑付总表（v34 后完整清单）

#### 已兑付 flag（16 回响点 + 1 真·分支）

| Flag | 来源 | 兑付位置 |
|---|---|---|
| `father_morning_warm` | `morning/m_08b[0]` | `letter/lt_06c_warm` + `boss_awakening/ba_cb_father` |
| `father_cinnamon_forgot` | `vendor_b/vb_01b[1]` | `return_home/rh_04c` + `boss_awakening/ba_cb_cinnamon` |
| `father_letter_promise_return` | `letter/lt_11b[1]` | `boss_awakening/ba_cb_promise` |
| `self_test_calm` | `test_stone/ts_05c[0]` | `disciple_b/db_b07`（`requires_flag` 解锁选项） |
| `self_test_hurt` | `test_stone/ts_05c[1]` | `letter/lt_00_hurt` ⭐ v34 新增 |
| `self_temple_brave` | `temple/tp_07b[0]` | `after_battle*/ab_01_brave` ⭐ v34 新增 |
| `self_temple_scared` | `temple/tp_07b[1]` | `after_battle*/ab_01_scared` ⭐ v34 新增 |
| `town_paid_old_lady` | `market/mk_07b[0]` | `market/mk_07c`（当场·老婆婆消失） |
| `self_teahouse_curious` | `teahouse_before/tb_05b[0]` | `after_battle*/ab_recall_boy` ⭐ v34 新增 |
| `gu_pressed_who` | `after_battle*/ab_07b[0]` | `ab_07c` 当场 + `ab_recall_who` ⭐ v34 新增 |
| `gu_pressed_where` | `after_battle*/ab_07b[1]` | `ab_07d` 当场 + `ab_recall_where` ⭐ v34 新增 |
| `mother_bowl_lingered` | `bowl_interact/bi_07[0]` | `tally_marks/tm_06b` + `transmission_array/ta_05b` |
| `lore_wanderer_asked` | `old_wanderer/ow_10b[0]` | `tally_marks/tm_06c` |
| `lore_fortune_pressed` | `fortune_teller/ft_06b[0]` | `fortune_teller_coin/ftc_04c` |
| `lore_page_1_read` | `remnant_page_1/rp1_03` | `boss_room_enter/bre_05c` ⭐ v34 门槛放宽 |
| `town_celebration_smile` | `celebration_boy/cb_06b[0]` | `return_home/rh_00_boy` ⭐ v34 新增 |
| `path_ending` | `after_battle*/ab_choice` | 章末真·分支（follow / return） |

#### 未兑付 flag（5 个，明确留给第二章）

| Flag | 来源 | 第二章兑付意图 |
|---|---|---|
| `father_morning_silent` | `morning/m_08b[1]` | 作为 `father_morning_warm` 的补集，第二章父女重逢场景的反向回响 |
| `self_market_proud` | `market/mk_07b[0]` | "老婆婆是谁" lore 揭示的入口（与 `town_paid_old_lady` 成对出现） |
| `town_aunts_confronted` | `aunts_return/ar_08[0]` | 第二章回访碎玉镇时大婶反应的差异 |
| `town_disciple_calm_reply` | `disciple_b/db_b07[0]` | 第二章与太平宗关系设定 |
| `lore_page_2_read` / `lore_page_3_read` / `lore_page_4_read` | `remnant_page_2/3/4` | 天道 lore 深揭示的分层门槛（当前仅用 page_1 作入门触发） |

### 四、统计（v34 后）

| 指标 | v27 | v33 | v34 |
|---|---|---|---|
| 选择节点数 | 4 | 22 | 22 |
| 真·分支 | 2 | 1 | 1 |
| 回响点 | 0 | 10 | **16** |
| 沉默 flag | N/A | 12 | 5（全部标注第二章意图） |
| `narrative_flags` 总数 | 0 | 22 | 22 |

### 五、文件修改记录（v34）

```
data/chapter1.json    morning m_08b/m_09 对话修正
                      boss_awakening ba_cb_father 同步
                      letter lt_06c_warm 同步 + lt_00_hurt 新增
                      after_battle/after_battle_coin ab_01 分支回响
                      after_battle/after_battle_coin ab_recall 链
                      boss_room_enter lore 触发门槛放宽
                      return_home rh_00_boy 路过少年家
```

### 六、待完成任务（按优先级）

1. **端到端试玩**——按以下路径覆盖：
   - 全沉默路径（所有选项选沉默派）：验证基础流程无假死
   - 全温暖路径（所有选项选有 flag 的那个）：验证 16 处回响全部浮现
   - 章末 A / B 两条分支路径
2. **Opus 待做：第二章规划**（未来的兑付蓝图）
   - 5 个沉默 flag 的兑付场景设计（父女重逢 / 碎玉镇回访 / 老婆婆身份揭示 / 太平宗关系 / 天道 lore 深揭示）
   - 主线结构（跟顾飞白路径 vs 独自行动路径的差异化）
3. **Opus 待做：修炼路线文档**——技能树 / 境界划分 / 战斗系统成长线
4. **远期**：第二章内容制作

---

## 第十八版（2026-04-10）

### 主题：叙事深化 + 伏笔串联 + 全局审查修复

### 一、叙事内容改动

**1. 战斗失败独白差分（4版）**
- 新增 `battle_loss_wolf`：幽影狼（恐惧→捡起剑穗）
- 新增 `battle_loss_toad`：石皮蟾（挫败→不服）
- 新增 `battle_loss_boss_p1`：虚形魇第一阶段（被碾压→剑穗在等她）
- 新增 `battle_loss_boss_p2`：虚形魇第二阶段（"白光没有来"→差一点就够到了）
- BattleUI.gd：`_get_battle_loss_scene()` 根据 enemy_id + boss_phase2 自动选择对应独白

**2. 苏明伏笔加强（return_home）**
- rh_03：碗筷摆了两副，第二副没动过
- rh_04：改为"他从一开始就没打算留下来吃"
- rh_note_03：新增"她低头看了看手里的剑穗。它确实在发热——但爹是怎么知道的？"

**3. 剑穗伏笔串联**
- `dayu_morning` 加 dm_06："穗绳上的结扎得很紧，不像是丢掉的东西。"
- `boss_awakening` 加 ba_06b："还有那张便条上的字——「别怕。」"
- `old_wanderer_return` 加 owr_03/owr_03b：老江湖看到剑穗欲言又止

**4. 顾飞白出场重写**
- `boss_room_enter` 加 bre_05b：BOSS间酒气暗示（"有人在某个角落里坐了很久"）
- `after_battle` + `after_battle_coin`：重写出场（墙角/没有鞘的剑/"比你早"/看剑穗认出又移开）
- 铜钱版加 abc_coin_06："他说这句话的时候，手指碰了一下腰间的剑柄，又放下了。"

**5. 章末画面补完（ChapterEndScene.gd）**
- 路径A加第三行："身后，碎玉镇的灯火一盏一盏亮起来。"
- 路径B加第三行："第二天一早，她收拾好东西，锁了门。钥匙放在年年够不到的地方。"
- 悬念钩子后新增："第二章·藏锋　——　敬请期待"淡入
- `get_tree().quit()` 改为回主菜单

**6. 夜行氛围链路接入（5个原孤立场景）**
- `night_exit`：ShopScene 夜晚黑屏后、切场景前播放
- `night_walk_tree`：TownScene 经过榕树格(17,16)自动触发
- `night_walk_well`：TownScene 经过古井格(22,17)自动触发
- `temple_entrance_night`：TownScene 进废庙时播放，await 结束后再切场景
- `monster_approach`：TempleScene 首次触碰幽影狼前播放

### 二、BUG修复（4项）

**BUG-1：guard_return 守卫对话未切换**
- 现象：测灵回来后守卫对话无变化
- 根因：TownScene.tscn 中 `dialogue_scene_id_after = "guard"`（和 before 一样）
- 修复：改为 `"guard_return"`

**BUG-2：ShopScene phase==4 fallthrough**
- 现象：phase 4 时进杂货铺会触发 morning 流程
- 根因：match 无 phase 4 分支，落入 `_:` 默认执行 morning
- 修复：加 `4:` 分支，只显示 HUD 不触发流程

**BUG-3：story_phase 直接赋值破坏封装**
- 现象：TownScene test_stone 处 `GameData.story_phase = 3` 绕过了 advance_phase()
- 修复：GameData.gd 新增 `set_phase(target)` 公开接口；TownScene 改用 `GameData.set_phase(3)`

**BUG-4：BOSS第二阶段旁白期间按钮竞态**
- 现象：boss_phase2_started 的 await 挂起后，turn_changed 同步开启按钮，旁白期间玩家可点击
- 根因：`_on_boss_phase2_started()` 的 await 让出控制权，`_on_turn_changed(PLAYER_TURN)` 重新启用按钮
- 修复：`_on_turn_changed()` 检查 `DialogueManager.is_active`，对话进行中不启用按钮

### 三、防御性修复（2项）

**BUG-5：TownScene 进废庙 await 后缺安全检查**
- 位置：`_enter_scene("temple")` 中 await dialogue_ended 后
- 修复：加 `if not is_inside_tree(): return`

**BUG-6：TempleScene 幽影狼信号重入**
- 现象：monster_approach await 期间玩家离开再进入，body_entered 再次触发 _trigger_wolf_battle
- 修复：加 `_wolf_battle_pending` 重入锁

### 文件修改记录（第十八版）

```
data/chapter1.json           战斗失败独白×4
                             return_home碗筷/剑穗伏笔
                             dayu_morning剑穗细节
                             boss_awakening便条闪回
                             old_wanderer_return剑穗欲言又止
                             boss_room_enter酒气暗示
                             after_battle/after_battle_coin出场重写+铜钱细节
scripts/BattleUI.gd          失败独白选择逻辑
                             BOSS旁白按钮竞态修复
scripts/BattleManager.gd     淬血低血量日志
scripts/ChapterEndScene.gd   路径A/B第三行+第二章预告+回主菜单
scripts/TownScene.gd         夜行氛围触发(tree/well/temple)
                             story_phase改用set_phase()
                             进废庙await安全检查
scripts/TempleScene.gd       monster_approach触发+重入锁
scripts/ShopScene.gd         night_exit触发+phase4分支
scripts/GameData.gd          新增set_phase()接口
scenes/TownScene.tscn        guard_return配置修复
```

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 剑穗伏笔加强 |
| 链路二 测灵广场 | ✅ | set_phase封装 |
| 链路三 回家流程 | ✅ | 碗筷/便条伏笔 |
| 链路四 废庙流程 | ✅ | 顾飞白重写+失败独白+夜行氛围+竞态修复 |
| 链路五 章末流程 | ✅ | 路径A/B补完+第二章预告 |
| 主菜单 | ✅ | 章末回主菜单 |
| ESC系统菜单 | ✅ | 无变化 |

### 待完成任务（按优先级）

1. 美术资源替换
2. 背景音乐和音效

---

## 第十九版（2026-04-11）

### 主题：苏云晚性格刻画 + 剑穗视觉成长 + 战斗教学引导

### 一、苏云晚破防瞬间（5处）

核心设计思路：她的"破防"不是情绪外露，是被生活的小细节拉回。她对修仙、命运、生死都无所谓，但偶尔会想起家里的某个具体细节。

**1. test_stone 加 ts_05b**
> "她想，今天可以早点回家吃饭了。"
- 测灵失败的瞬间，她真实的反应不是失望，是"可以早点回家"。揭示她对测灵的根本态度。

**2. boss_phase2_start 加 bp2_05b**
> "她想，桌上那两副碗筷，应该早就凉了吧。"
- BOSS 锁血时，她想的不是怎么赢，是家里桌上那两副没动过的碗筷。
- 呼应 return_home 的细节"碗筷摆了两副，第二副没有动过"。

**3. battle_loss_boss_p2 加 blb2_03b**
> "她想，年年今晚没人喂了。"
- 生死边缘，她想的不是命，是猫。

**4. light_still_on 加 ls_02**
> "她加快了脚步。"
- 看到家的灯还亮着，她不说话，加快脚步。动作代替情绪。

**5. return_home 加 rh_05b（妈妈伏笔加强）**
> "她看了一眼那件围裙。已经很久了，谁都没有再穿过它。"
- 把模糊的氛围细节变成明确的母亲指向。

### 二、剑穗视觉成长（Player.gd）

**实现机制：**
- Player 节点动态创建 SwordTasselVisual（Polygon2D 组合，位置 16,8 z_index=2）
- 外层菱形光晕 + 内层矩形剑穗主体
- 检测 `unlocked_old_items` 判断是否显示
- 检测 `stones_read` 数量（0-4）决定颜色等级：
  - 0 块：暗棕，无光晕
  - 1 块：泛红，15% 光晕
  - 2 块：泛金，30% 光晕
  - 3 块：明亮，50% 光晕
  - 4 块：金白，75% 光晕
- 0.6s EASE_OUT tween 缓动到目标颜色
- 防御性设计：tween 缓存防堆叠 / 场景切换首次直接赋值不跳变

### 三、战斗教学引导

**新增 tutorial_first_battle 场景**（5个旁白节点），融入叙事的引导：
> "她第一次和妖兽对峙。手心出汗。"
> "脑子里却很清楚——"
> "〔攻击〕是直来直去；〔技能〕里藏着「蓄势」和「淬血」，一个先收着再放，一个以血换伤。"
> "至于〔感应〕——她还看不见。那是道纹的事，她现在还摸不到。"
> "她试着深呼吸。"

**触发机制：**
- BattleUI.\_start_battle() 检查 triggered_events.has("tutorial_first_battle")
- 首次进入战斗时，setup 完成后播放教学旁白，旁白结束后再开始第一回合

**关键设计**：教学只介绍当前能用的技能（蓄势/淬血），明确说"感应还看不见"——避免玩家点击禁用按钮的困惑，同时埋下后续解锁的伏笔。

### 四、自检发现并修复的问题

| 问题 | 修复 |
|------|------|
| 教学旁白宣称"感应"可用，但首战未解锁 | 改为"她还看不见" |
| ColorRect 在 Node2D 下渲染层级问题 | 改用 Polygon2D |
| 场景切换剑穗颜色跳变 | 第一次设置直接赋值，不用 tween |
| 剑穗 Tween 堆叠 | 缓存 tween 引用，新建前 kill |
| 剑穗位置在 Body 内部被覆盖 | 移到右侧外缘(16,8) z_index=2 |

### 文件修改记录（第十九版）

```
data/chapter1.json           破防5处+教学场景
                             tutorial_first_battle新增
                             ts_05b/bp2_05b/blb2_03b/ls_02/rh_05b
scripts/Player.gd            剑穗视觉成长（Polygon2D）
                             stones_read 联动光晕
scripts/BattleUI.gd          首次战斗触发教学旁白
```

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 加破防瞬间 |
| 链路三 回家流程 | ✅ | 妈妈伏笔加强 |
| 链路四 废庙流程 | ✅ | 战斗教学+破防瞬间+剑穗视觉 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 待完成任务（按优先级）

1. 战斗中剑穗视觉同步（BattleScene 加剑穗节点）
2. AudioManager 框架（BGM + 音效）
3. 设置菜单（文字速度/已读跳过/字号）
4. 美术资源替换

---

## 第二十版（2026-04-12）

### 一、Bug 修复（7个）

| 问题 | 修复位置 | 说明 |
|------|----------|------|
| BOSS第二阶段按钮竞态开启 | `BattleUI.gd` | `_on_boss_phase2_started()` 与 `turn_changed` 信号之间存在一帧竞态窗口，旁白未接管前按钮已重新开启。新增 `_phase2_in_progress` 标志，旁白接管前持续锁定按钮 |
| 战败瞬间血条跳满 | `BattleUI.gd` | 战败回调中 `GameData.player.hp` 恢复满值后立即调用了 `_refresh_player_hp()`，导致血条在死亡画面闪回满格。移除即时刷新，让血条停留在 0 直到下一场景 |
| 镇子入口判定失效 | `TownScene.gd` | `ENTRANCE_RANGE` 为 0 时，从商铺/茶馆/废庙返回带 1 格偏移的生成点脱离了入口范围，玩家偶现卡在门口。改为 1 |
| 榕树/古井触发偶发失效 | `TownScene.gd` | 精确格匹配导致玩家站在相邻格时触发失败。改为 ±1 容差（`abs(pg.x - tx) <= 1 and abs(pg.y - ty) <= 1`） |
| 跨场景对话残留锁死战斗按钮 | `DialogueManager.gd` | 场景切换时 `is_active` 未被清除，进入战斗场景后 `_on_turn_changed` 误判对话进行中，按钮永久锁死。新增 `force_stop()` 方法，`SceneTransition` 切场景前调用 |
| `.name` 属性 StringName 类型拼接报错 | `NPC.gd` / `GameData.gd` / `UIManager.gd` | 部分节点的 `.name` 返回 StringName，字符串拼接时触发隐式类型错误。统一加 `String()` 强转 |
| ESC 设置面板被裁剪 | `UIManager.gd` | 设置项增多后底部按钮超出面板边界。`_esc_panel.offset_top` 从 `-140` 调整为 `-180` |

### 二、新增功能

**AudioManager（新文件 `scripts/AudioManager.gd`）**
- 全局单例，管理 BGM 和 SFX 播放
- BGM 支持淡入淡出（`play_bgm(id, fade_in)` / `stop_bgm(fade_out)`），同一曲目重复调用不重启
- SFX 即发即忘（`play_sfx(id)`）
- 各场景已接入的 BGM：`main_menu` / `town_day` / `town_night` / `shop_morning` / `shop_return` / `temple_explore` / `battle_normal` / `battle_boss_p1` / `battle_boss_p2` / `awakening` / `chapter_end`
- 战斗音效：`attack_hit` / `charge` / `quixue` / `sense` / `item_get` / `enemy_hurt` / `player_hurt` / `victory` / `defeat` / `gold_gain` / `awakening_flash`

**字号缩放实时同步**
- `UIManager.gd` 新增 `font_scale_changed(scale_factor: float)` 信号
- `DialogueBox.gd` 和 `BattleUI.gd` 监听该信号，设置面板调整字号时立即刷新，无需重启场景

**战斗中剑穗视觉（`BattleUI.gd`）**
- 在 `PlayerPanel` 右上角动态创建 Polygon2D 剑穗，反映当前 `stones_read` 等级
- 5 级颜色（暗棕→泛红→泛金→明亮→金白），0.6s EASE_OUT tween 缓动
- 觉醒触发时剑穗爆发：内核变白，光晕菱形放大至 3.5x，先于全屏白光作为光源
- 挂在 PlayerPanel 子树内，渲染层级不会盖过 DialogueBox

**设置持久化（`UIManager.gd`）**
- 新增 `load_settings_from_file()` / `save_settings_to_file()`
- 字号、文字速度、音量等设置跨会话保留

### 三、文件修改记录（第二十版）

```
scripts/AudioManager.gd      新增：全局音频管理单例
scripts/ThemeManager.gd      新增：主题管理器
scripts/BattleUI.gd          bug修复×2（竞态/血条）+ 战斗剑穗视觉 + 全流程BGM/SFX + 字号同步
scripts/DialogueManager.gd   新增 force_stop() 方法
scripts/DialogueBox.gd       字号信号监听
scripts/Player.gd            世界场景剑穗视觉（已含 v19 内容，本版完善）
scripts/UIManager.gd         bug修复×2（类型转换/面板高度）+ 字号信号 + 设置持久化
scripts/NPC.gd               StringName 类型转换 bug 修复
scripts/GameData.gd          StringName 类型转换 bug 修复
scripts/TownScene.gd         bug修复×2（入口范围/触发容差）+ 昼夜BGM + 玩家坐标恢复
scripts/ShopScene.gd         各阶段 BGM 接入
scripts/TempleScene.gd       temple_explore BGM
scripts/MainMenuScene.gd     main_menu BGM
scripts/ChapterEndScene.gd   chapter_end BGM + 字号适配
scripts/SceneTransition.gd   切场景前调用 DialogueManager.force_stop()
```

### 四、当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | BGM接入，无其他变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 昼夜BGM切换 |
| 链路四 废庙流程 | ✅ | 战斗BGM/SFX全接入，剑穗视觉同步，竞态bug修复 |
| 链路五 章末流程 | ✅ | chapter_end BGM |
| 主菜单 | ✅ | main_menu BGM |
| ESC系统菜单 | ✅ | 面板高度修复，设置持久化 |

### 五、待完成任务（按优先级）

1. 美术资源替换（BGM/SFX 实际音频文件）
2. 字号设置面板 UI（当前信号已就绪，缺 UI 入口）
3. 已读跳过功能（文字速度/跳过按钮）

---

## 第二十一版（2026-04-12）—— 全局代码审查与修复

### 审查范围

| 扫描项 | 数量 |
|--------|------|
| GDScript 脚本 | 19 个，约 8000 行，逐文件完整阅读 |
| tscn 场景文件 | 10 个，交叉验证所有节点路径 |
| chapter1.json 对话数据 | 87 个场景，自动化链路验证 |
| project.godot | AutoLoad 顺序 + 输入映射 |
| 交叉验证 | start_scene 引用 × 事件处理 × DialogueBox 实例化 |

### 一、Bug 修复（19个）

**高危：跨场景信号泄漏（6个）**

| 文件 | 修复 |
|------|------|
| `ShopScene.gd` | 新增 `_exit_tree()`，断开 `DialogueManager.event_triggered` + `dialogue_ended` |
| `TeaScene.gd` | 新增 `_exit_tree()`，断开 `DialogueManager.event_triggered` |
| `TempleScene.gd` | 新增 `_exit_tree()`，断开 `DialogueManager.event_triggered` + `dialogue_ended` |
| `TownScene.gd` | 新增 `_exit_tree()`，断开 `DialogueManager.event_triggered` + `dialogue_ended` |
| `BattleUI.gd` | `_exit_tree()` 补充断开 `UIManager.font_scale_changed` |
| `DialogueBox.gd` | 新增 `_exit_tree()`，断开 `UIManager.font_scale_changed` + 三个 `DialogueManager` 信号 |

**中危：逻辑/安全问题（8个）**

| 文件 | 修复 |
|------|------|
| `Player.gd` | 新增 `_exit_tree()`，kill 并清空 `_sword_tassel_tween`，防止离树后 Tween 访问已释放节点 |
| `AudioManager.gd` | Tween 有效性检查从 `is_valid()` 改为 `is_running()`（2 处），修复已完成 Tween 被误判为有效的问题 |
| `BattleUI.gd` | `_refresh_battle_tassel()` 加联合 null 检查（node + core + glow），防止初始化异常时崩溃 |
| `BattleUI.gd` | 觉醒按钮点击回调先 `disabled = true` 再 `queue_free()`，防止同帧二次触发 |
| `GameData.gd` | `load_data()` 玩家核心字段从 `data["key"]` 改为 `data.get("key", default)`，旧版/损坏存档降级而非崩溃 |
| `DialogueBox.gd` | `_show_choices()` 无按钮时 fallback 到 `continue_hint`，防止空选项面板卡死玩家 |
| `BattleManager.gd` | BOSS 侵蚀吸血从固定 `var steal = 15` 改为 `min(15, player.hp)`，修复玩家仅剩 10HP 时 BOSS 凭空多恢复 5HP |
| `ChapterEndScene.gd` | 11 处 `await` 后补充 `is_inside_tree()` 检查，章末画面按 ESC→返回主菜单不再崩溃 |

**低危：防御性增强（3个）**

| 文件 | 修复 |
|------|------|
| `TownScene.gd` | `_wait_for_transition()` while 循环内加 `is_inside_tree()` 防护 |
| `TownScene.tscn` | `EnterHintLabel` rect 从 0×0 改为 120×20，修复 `horizontal_alignment = CENTER` 无效的问题 |
| `chapter1.json` | 删除 `morning` 场景孤立节点 `m_06`（m_05 直接跳 m_07，m_06 不可达） |

### 二、文件修改记录（第二十一版）

```
scripts/ShopScene.gd         +_exit_tree 信号断开
scripts/TeaScene.gd          +_exit_tree 信号断开
scripts/TempleScene.gd       +_exit_tree 信号断开
scripts/TownScene.gd         +_exit_tree 信号断开 + _wait_for_transition 防护
scripts/BattleUI.gd          +font_scale信号断开 + 剑穗null检查 + 觉醒按钮防重复
scripts/DialogueBox.gd       +_exit_tree 信号断开 + choices空面板防护
scripts/Player.gd            +_exit_tree tween清理
scripts/AudioManager.gd      tween判定 is_valid→is_running
scripts/GameData.gd          load_data 防御性读取
scripts/BattleManager.gd     BOSS侵蚀吸血量修正
scripts/ChapterEndScene.gd   11处await安全检查
scenes/TownScene.tscn        EnterHintLabel尺寸修正
data/chapter1.json           删除morning.m_06孤立节点
```

### 三、审查确认项（无问题）

- project.godot AutoLoad 加载顺序符合依赖关系 ✅
- 输入映射全部使用 Godot 内置 action ✅
- 所有 `@onready` / `$Path` / `get_node_or_null` 路径与 tscn 节点树匹配 ✅
- 所有 CollisionShape2D 均有 shape 赋值 ✅
- 所有 `start_scene()` 引用的 scene_id 在 JSON 中存在 ✅
- chapter1.json 87 个场景链路完整，无死链 ✅
- 12 个事件全部有脚本处理（含默认兜底）✅
- 需要对话的场景均有 DialogueBox 实例 ✅

### 四、当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | BOSS侵蚀吸血修正 |
| 链路五 章末流程 | ✅ | await安全检查 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |

### 五、待完成任务（按优先级）

1. 美术资源替换（BGM/SFX 实际音频文件）
2. 字号设置面板 UI（当前信号已就绪，缺 UI 入口）
3. 已读跳过功能（文字速度/跳过按钮）

---

## 第二十二版（2026-04-13）—— BGM 资源接入 + 音频系统修复 + 全局规范整理

### 一、BGM 资源接入（11 首全覆盖）

将 11 首 BGM 文件（`.ogg` / `.mp3`）添加至 `assets/audio/bgm/`，并在 `AudioManager.gd` 配置别名映射，实现所有场景 BGM 零死角覆盖。

**BGM 文件 → 使用场景对照表**

| BGM 名称 | 文件 | 使用场景 |
|----------|------|----------|
| `main_menu` | main_menu.ogg | 主菜单 |
| `town_day` | town_day.ogg | 小镇白天 |
| `town_night` | town_night.ogg | 小镇夜晚 |
| `tea_house` | tea_house.ogg | 茶馆 |
| `temple_explore` | temple_explore.ogg | 废庙探索 |
| `shop_morning` | shop_morning.ogg | 杂货铺清晨（独立文件，移除旧别名） |
| `shop_return` | shop_return.ogg | 杂货铺回程/后续 |
| `battle_normal` → `temple_boss` | temple_boss.mp3 | 普通战斗（别名复用） |
| `battle_boss_p1` | battle_boss_p1.ogg | BOSS 战第一阶段 |
| `battle_boss_p2` | battle_boss_p2.mp3 | BOSS 战第二阶段 |
| `awakening` → `chapter_end` | chapter_end.ogg | 觉醒演出（别名复用，情绪延续到章末） |
| `chapter_end` | chapter_end.ogg | 章节结尾 |

**`AudioManager.gd` BGM_ALIAS 变更：**
- 删除旧别名 `shop_morning → town_day`（shop_morning.ogg 已独立提供）
- 新增 `battle_normal → temple_boss`（普通战斗复用古刹 boss 曲，紧张/压迫层次）
- 新增 `awakening → chapter_end`（觉醒独白与章末钢琴情绪延续，AudioManager 同名不重启逻辑自动衔接）

### 二、音频系统 Bug 修复（6 个）

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| 1 | `AudioManager.gd` | `set_bgm_volume()` 同时覆盖两个播放器 volume_db，crossfade 期间旧播放器音量弹跳 | 改为只更新 `_active_bgm_player` |
| 2 | `AudioManager.gd` | `play_bgm()` 切换时 `_duck_tween` 残留干扰新播放器 | 入口处 kill duck tween |
| 3 | `AudioManager.gd` | crossfade chain 回调在极端时序下可能 stop 掉已切换为活跃的新播放器 | 回调加 `if old_player != _active_bgm_player` 安全判断（lambda 独立变量规避 GDScript 缩进解析问题） |
| 4 | `AudioManager.gd` | `fade_bgm_to()` 与 `_duck_tween` 同时运行时争抢 volume_db | `fade_bgm_to()` 中 kill duck tween |
| 5 | `BattleUI.gd` | 普通战斗胜利 `stop_bgm(1.0)` 后等待 1.5s，产生约 0.5s 无 BGM 静默窗口 | 改为 `fade_bgm_to(0.0, 1.5)`，渐弱与等待时间对齐 |
| 6 | `BattleUI.gd` | 战斗失败 `stop_bgm(1.0)` 完全停止，独白期间无背景音乐 | 改为 `fade_bgm_to(0.15, 1.0)`，保留 15% 音量作为氛围底色 |

### 三、代码规范修复（私有变量访问解耦）

**补充公开只读属性，消除模块间对私有变量的直接访问：**

| 文件 | 新增属性 | 调用方 |
|------|----------|--------|
| `SceneTransition.gd` | `is_transitioning: bool` | `Player.gd` |
| `UIManager.gd` | `in_battle: bool` | `VirtualJoystick.gd` |
| `UIManager.gd` | `esc_open: bool` | `VirtualJoystick.gd` |

### 四、防御性与补全修复（5 个）

| # | 文件 | 修复内容 |
|---|------|----------|
| 1 | `ShopScene.gd` | `match` 默认分支 `_:` 不再触发 morning 流程，只显示 HUD + BGM，防异常 phase 重播对话 |
| 2 | `TempleScene.gd` | `_ready()` 末尾加 `UIManager.show_main_hud()`，读档直接进入废庙时 HUD 正常显示 |
| 3 | `TempleScene.gd` | 离开废庙前补 `GameData.save_to_file("auto")`，防崩溃丢失古刹内进度 |
| 4 | `NPC.gd` | `interact()` 末尾补 `is_triggered` 持久化写入，修复 `restore_state_from_save()` 的 `_triggered` key 有读无写问题 |
| 5 | `NPC.gd` | NPC after 对话切换逻辑保持 `story_phase >= 3`（phase 4/5 实际路径不经过 TownScene NPC，宽容判定更安全） |

### 五、chapter1.json 清理（2 处）

| 项目 | 处理 |
|------|------|
| 删除 `chapter_end_a` / `chapter_end_b` 场景 | 两个场景完全不可达（无任何 `start_scene` 调用），内部 event `chapter_end_path_a/b` 无处理程序，属于早期设计遗留死场景；ChapterEndScene.gd 已硬编码文字，JSON 中此两场景无意义 |
| `sense_unlocked_hint.su_02` 删去 `"next": ""` | 与其他结尾节点风格统一（不写 next 与写空字符串行为完全相同） |

### 六、文件修改记录（第二十二版）

```
scripts/AudioManager.gd      BGM_ALIAS 更新（3处）
                             set_bgm_volume 只更新活跃播放器
                             play_bgm 入口 kill duck tween
                             crossfade chain 回调安全判断（lambda 变量化）
                             fade_bgm_to kill duck tween
scripts/BattleUI.gd          普通胜利 fade_bgm_to(0.0, 1.5)
                             战斗失败 fade_bgm_to(0.15, 1.0)
scripts/SceneTransition.gd   新增 is_transitioning 只读属性
scripts/Player.gd            改用 SceneTransition.is_transitioning
scripts/UIManager.gd         新增 in_battle / esc_open 只读属性
scripts/VirtualJoystick.gd   改用 UIManager.in_battle / esc_open
scripts/ShopScene.gd         默认分支防御性修复
scripts/TempleScene.gd       show_main_hud + 离开时存档
scripts/NPC.gd               interact() 补写 is_triggered 持久化
data/chapter1.json           删除 chapter_end_a / chapter_end_b 死场景
                             su_02 删去 "next": ""
assets/audio/bgm/            新增 11 首 BGM 文件
```

### 七、当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | TempleScene HUD 修复 + 存档补全 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |
| 音频系统 | ✅ | 11 首 BGM 全覆盖，crossfade 竞态修复 |

### 八、待完成任务（按优先级）

1. 美术资源替换
2. 字号设置面板 UI（信号已就绪，缺 UI 入口）
3. 已读跳过功能

---

## 第二十三版（2026-04-13）—— 全文件自审查 + 补漏修复

### 一、审查范围

本轮对全部代码及资源文件逐一人工通读，交叉核对：

| 扫描项 | 内容 |
|--------|------|
| GDScript 脚本 | 19 个全部重读（含 archive/PlazaScene.gd 确认已归档不活跃） |
| tscn 场景文件 | 12 个全部交叉核对（@onready / $Path / get_node_or_null vs 节点树） |
| Shader | `shaders/ink_wash.gdshader`：5-tap 权重归一化 ✅，vignette/泛黄逻辑正确 ✅ |
| InkWashOverlay.tscn | 独立叠层场景，shader 参数与 uniform 匹配，layer=5 优先级正确 ✅ |
| chapter1.json | 60+ 个 scene_id 引用（脚本 start_scene + tscn NPC dialogue_scene_id + _after）全部在 JSON 中存在 ✅ |

### 二、Bug 修复（1个）

**TownScene.gd — 私有变量访问漏修**

| 位置 | 问题 | 修复 |
|------|------|------|
| `TownScene.gd` 第 561 行 `_enter_scene()` | `SceneTransition._is_transitioning`（直接访问私有变量） | 改为 `SceneTransition.is_transitioning` |
| `TownScene.gd` 第 587 行 `_wait_for_transition()` | 同上 | 同上 |

根因：第二十二版在 SceneTransition.gd 新增 `is_transitioning` 公开属性并修复 Player.gd 时，TownScene.gd 的两处漏未修改。

### 三、审查确认项（无其他问题）

**脚本层面**
- 所有 `@onready` / `$Path` / `get_node_or_null` 路径与对应 tscn 节点树完全匹配 ✅
- TempleScene 的 8 扇门及 2 个隐藏交互点均为动态创建（`_setup_doors` + `_setup_inner_doors` + `_setup_temple_hidden_interacts`），`_process` 中 `get_node_or_null` 正常可达 ✅
- ShopScene / TeaScene 提示 Label 挂载位置不同（ShopScene 挂 Player 下，TeaScene 挂 UILayer 下），两者均与各自脚本 `$` 路径一致 ✅

**数据层面**
- 所有 `dialogue_scene_id_after` 值（9 个）在 JSON 中均有对应场景 ✅
- BattleUI 失败分支返回的 4 个差分场景（`battle_loss_wolf / _toad / _boss_p1 / _boss_p2`）全部存在 ✅
- `temple_stone_1~4` / `boss_phase2_start` / `remnant_page_4` 均存在 ✅

### 四、文件修改记录（第二十三版）

```
scripts/TownScene.gd    _enter_scene() + _wait_for_transition() 两处
                        SceneTransition._is_transitioning → is_transitioning
```

### 五、当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 无变化 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |
| 音频系统 | ✅ | 无变化 |

### 六、待完成任务（按优先级）

1. 美术资源替换
2. 字号设置面板 UI（信号已就绪，缺 UI 入口）
3. 已读跳过功能

---

## 第二十四版（2026-04-13）—— 对话快进接入

### 改动内容

**`DialogueBox.gd` — `_start_typing()` 接入 `dialogue_skip` 开关**

`UIManager.dialogue_skip` 变量、存读档、设置面板 UI 在第二十版已全部实现，
但 `_start_typing()` 从未读取该开关，导致快进功能实际无效。

修复：在 `_start_typing()` 中新增一个分支，当 `UIManager.dialogue_skip == true` 时直接调用 `_finish_typing()`，跳过逐字动画立即显示全部文字。玩家仍需手动按确认/点击推进每个节点。

```
if UIManager and UIManager.dialogue_skip:
    _finish_typing()   ## 立即显示，跳过逐字动画
```

**字号调节状态确认**：经代码审查，字号调节功能在第二十版已完整实现——设置面板有三段切换 UI，`apply_font_scale()` 触发信号，`DialogueBox._ready()` 读取初始值，信号链路完整。待办项可标记为已完成。

### 文件修改记录

```
scripts/DialogueBox.gd   _start_typing() 新增 dialogue_skip 分支（3行）
docs/...记录.md          更新版本记录
```

### 当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 所有链路 | ✅ | 无变化 |
| 对话快进 | ✅ | 已接入，设置面板"已读对话快进"开关现在生效 |
| 字号调节 | ✅ | 确认已完整实现（第二十版） |

### 待完成任务（按优先级）

1. 美术资源替换（程序化剪影已到位，等真实图片资源）

---

## 第三十五版（2026-04-18）—— NPC 剪影系统 + 视觉世界丰富 + 心绪折叠

### 主题：角色可识别性 + 地图活人气息 + UI 可收起性

### 一、NPC 剪影系统（NPC.gd / scenes/*.tscn）

**NPC.gd 新增 `body_shape` 系统**
- `@export var body_shape: String = "generic"`
- `_build_silhouette()` 根据类型分发：cat → `_build_cat_silhouette()`，其余 → 头部椭圆 + 梯形体
- 支持类型：`generic`（通用）/ `woman`（略宽腰）/ `old`（略窄底）/ `monk`（最窄底）/ `cat`（圆头+三角耳+宽低体）
- 全类型头部统一：中心 (0,-12)，rx=6，ry=7——保证视觉一致性，差异仅在体形比例
- 辅助函数 `_make_ellipse(cx,cy,rx,ry,n)` 生成圆形近似点集

**各场景 NPC body_shape 配置**
- ShopScene.tscn：年年/大鱼 `body_shape="cat"`，`scale=Vector2(0.78,0.78)`；苏明 `body_shape="old"`
- TeaScene.tscn：说书人/老江湖 `body_shape="old"`；弟子甲乙 `body_shape="monk"`
- TownScene.tscn：算命先生 `body_shape="old"`；大婶 `body_shape="woman"`；验师 `body_shape="monk"`；香料贩乙 `body_shape="woman"`；老婆婆 `body_shape="old"`

### 二、玩家剪影（Player.gd）

`_build_player_silhouette()` 在 `_ready()` 中调用，样式与 NPC 保持一致：
- 体形：(-10,-5)(10,-5)(7,18)(-7,18)
- 头部：中心 (0,-12)，rx=6，ry=7（与 NPC 完全对齐）
- 同一辅助函数 `_make_ellipse()`

### 三、测灵广场路人剪影（TownScene.gd）

`_build_plaza_silhouettes()` 函数：
- 遍历 PlazaLayer 的子节点（Queue/Pass/Watch 等路人 Node2D）
- 隐藏原始 ColorRect，程序化生成 body + head Polygon2D
- 与 NPC generic 体形保持一致

### 四、心绪面板折叠按钮（UIManager.gd）

- 新增 `_mood_toggle_btn: Label`（text="收"/"展"），位置 (155,6)，字号与"心绪"标题对齐
- `mouse_filter = MOUSE_FILTER_STOP`，`cursor_shape = CURSOR_POINTING_HAND`
- `gui_input` → `_on_mood_toggle_input()`：鼠标左键切换折叠状态
- 折叠：隐藏分割线+心绪文字，panel 高度压至 28px，btn.text="展"
- 展开：恢复显示，panel 高度恢复 172px，btn.text="收"

### 五、地图视觉补充（TownScene.gd）

**老榕树碰撞体**
- `_add_tree()` 新增 StaticBody2D + CollisionShape2D（RectangleShape2D 14×10，offset y=14）
- 玩家现在无法穿过榕树

**老婆婆位置修正**
- TownScene.tscn：NPC_OldWoman 从 (704, 416) 移至 (352, 672)
- 原位置与公告栏重叠；新位置在市场区，符合其 dialogue_scene_id="market" 的叙事定位

**西墙根石板（新隐藏互动点）**
- `_add_west_stone(layer, Vector2(80, 448))` 函数：
  - 主石板多边形 + 高光条 + 裂缝线 + 苔藓块 + 5 根草茎（纯视觉）
  - StaticBody2D 碰撞体（42×14）
- HIDDEN_INTERACT_NODES 注册为路标型（is_signpost=true）：
  - phase < 3：播放 `west_stone_slab`（5节·蹲下看刻痕·"刻字的人大概没想到会有一天看不懂"）
  - phase ≥ 3：播放 `west_stone_slab_after`（3节·石头还在·"被测灵石测过的手印，过几年是不是也会被风磨平？"）
  - set_flag：west_stone_read / west_stone_read_after → narrative_flags（自动持久化）

### 六、文本修正（chapter1.json）

- `m_14`（morning 父亲送别）：英文双引号 `"记得回来吃饭"` → 「记得回来吃饭」
- `rh_note_02`（return_home 便条）：英文双引号 `"会回来的"` → 「会回来的」

### 七、新增设计文档

`docs/wendao_06_有意义互动补全设计.md`：
- 另外 2 个候选互动点（路标/磨石板）的详细设计方案，含 phase 切换文案草稿
- 6 个装饰物方案（当前仅落地石板，其余保留备用）
- 实现顺序、测试验收清单、canonical facts 保护表
- 状态：本版只实现西墙根石板 1 个，其余为备用方案

### 八、文件修改记录（第三十五版）

```
scripts/NPC.gd               新增 body_shape @export
                             _build_silhouette() 分发逻辑
                             _build_cat_silhouette() 新增
                             _make_ellipse() 辅助函数
scripts/Player.gd            _build_player_silhouette() 新增
                             _make_ellipse() 辅助函数
scripts/UIManager.gd         _mood_toggle_btn Label 新增
                             _on_mood_toggle_input() 折叠逻辑
                             _mood_collapsed 状态变量
scripts/TownScene.gd         _build_plaza_silhouettes() 新增
                             _plaza_ellipse() 辅助函数
                             _add_tree() 新增碰撞体
                             _add_west_stone() 新增石板装饰+碰撞
                             HIDDEN_INTERACT_NODES 新增石板条目
scenes/ShopScene.tscn        年年/大鱼 body_shape=cat, scale=0.78
                             苏明 body_shape=old
scenes/TeaScene.tscn         说书人/老江湖 body_shape=old
                             弟子甲乙 body_shape=monk
scenes/TownScene.tscn        NPC_OldWoman 位置 → (352, 672), body_shape=old
                             NPC_FortuneTeller body_shape=old
                             NPC_AuntA body_shape=woman
                             NPC_Examiner body_shape=monk
                             NPC_Vendor_B body_shape=woman
data/chapter1.json           west_stone_slab 场景新增（5节）
                             west_stone_slab_after 场景新增（3节）
                             m_14 / rh_note_02 英文引号 → 「」
docs/wendao_06_...           新建有意义互动补全设计文档
```

### 九、chapter1.json 场景清单更新（v35 新增）

隐藏探索：新增 `west_stone_slab`、`west_stone_slab_after`

### 十、当前链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 引号修正 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 引号修正 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 无变化 |
| 主菜单 | ✅ | 无变化 |
| ESC系统菜单 | ✅ | 无变化 |
| 视觉·NPC剪影 | ✅ | 全场景 NPC + 玩家 + 路人 |
| 视觉·地图 | ✅ | 榕树碰撞 + 西墙石板装饰&互动 |
| UI·心绪折叠 | ✅ | 可收起/展开 |

### 十一、待完成任务（按优先级）

1. icon.svg 补充——导出时缺图标，打包后 exe 显示空白图标
2. 端到端通关测试——验证回程 5 个 FORCE_TRIGGER 能被自然触发
3. 美术资源替换（程序化剪影为占位，等真实图片资源）

---

## v36：立绘接入 + 回归扫描修复

### 一、改动概要

- **新增立绘**：大鱼（wangdayu2.jpg，工笔缅因猫）接入 PortraitControl，与苏云晚统一走真实图片分支
- **章节名统一**：ChapterEndScene 标题从"第一章·问道"改为"第一章·碎玉镇"（与 MainMenuScene 副标题一致）
- **NPC 对话 phase 回退 bug 修复**：NPC.interact() 移除自动写 _triggered key；GameData.load_data() 新增迁移清理旧 _triggered 脏数据
- **老婆婆 phase 3 残留修复**：TownScene._ready() 在 phase≥3 时强制 disappear()
- **黑屏优化**：SceneTransition 跳过冗余淡出（overlay 已不透明时），ShopScene 夜晚淡出时长 1.5s→0.9s
- **文案修正**：market 对话 mk_07b/c 灵石→铜板（开局无灵石逻辑错误）
- **死代码清理**：TownScene.gd、ShopScene.gd 移除已废弃的 night_begin 事件分支
- **校验工具**：新增 tools/validate_chapter1.js，扫描 chapter1.json 断链引用和孤儿场景

### 二、校验工具结果

```
共 87 个 scene，539 个合法 next 目标
[OK] 无断链引用（_end 为 DialogueManager 合法哨兵）
[OK] 所有孤儿 scene 均已通过 GDScript 或 .tscn 入口引用
[INFO] JSON 中无 set_flag 节点（flags 由 GDScript 代码设置）
```

### 三、NPC 配置核查结果

| NPC | required_phase | dialogue_scene_id_after | 切换机制 |
|-----|------|------|------|
| 老婆婆 | -1 | （无） | phase≥3 时 disappear |
| 算命先生 | -1 | fortune_teller_return | phase≥3 自动切 |
| 大婶 | -1 | aunts_return | phase≥3 自动切 |
| 打水人 | -1 | water_carrier_return | phase≥3 自动切 |
| 老狗 | -1 | dog_return | phase≥3 自动切 |
| 守卫 | -1 | guard_return | phase≥3 自动切 |
| 测验师 | -1 | examiner_after | TownScene 显式写 _triggered |
| 摊位甲/乙/丙 | -1 | vendor_*_return | phase≥3 自动切 |

### 四、战斗逃跑确认

无逃跑机制，属**设计意图**（叙事型回合制，失败走 battle_loss_* 对话链返回场景）。

### 五、文件变更清单

```
scripts/PortraitControl.gd    大鱼立绘接入，真实图片分支改为 match 结构
assets/wangdayu2.jpg          大鱼工笔立绘（新增）
scripts/ChapterEndScene.gd    章节标题 "第一章·问道" → "第一章·碎玉镇"
scripts/NPC.gd                interact() 移除自动写 _triggered
scripts/GameData.gd           load_data() 迁移清理 _triggered 脏 key
scenes/TownScene.tscn         NPC_Examiner 补 dialogue_scene_id_after
scripts/TownScene.gd          phase≥3 老婆婆 auto-disappear；移除 night_begin 死代码
scripts/ShopScene.gd          淡出时长 1.5s→0.9s；移除 night_begin 死代码
scripts/SceneTransition.gd    跳过冗余淡出
data/chapter1.json            mk_07b/c 灵石→铜板
tools/validate_chapter1.js    新增 JSON 一致性校验脚本
tools/validate_chapter1.py    同上（Python 版，备用）
```

### 六、链路状态

| 链路 | 状态 | 备注 |
|------|------|------|
| 链路一 morning流程 | ✅ | 无变化 |
| 链路二 测灵广场 | ✅ | 无变化 |
| 链路三 回家流程 | ✅ | 黑屏优化 |
| 链路四 废庙流程 | ✅ | 无变化 |
| 链路五 章末流程 | ✅ | 标题修正 |
| 视觉·立绘 | ✅ | 苏云晚 + 大鱼 均已接入真实图片 |

### 七、待完成任务

1. icon.svg 补充
2. 端到端通关测试
3. 其余角色立绘（年年等）
