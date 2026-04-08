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
