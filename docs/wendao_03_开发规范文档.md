# 《问道》开发规范文档
# 给Claude Code的完整执行指令

---

## 项目基本信息

```
引擎：Godot 4
项目路径：E:/wendao
横屏：1280×720
地图：40×30格，每格32px
```

## 已有文件（禁止修改）

```
scripts/DialogueManager.gd
scripts/DialogueBox.gd
scripts/Character.gd
scripts/BattleManager.gd
scripts/GameData.gd
scripts/SceneTransition.gd
data/chapter1.json（第五阶段才修改）
assets/fonts/NotoSerifSC-Regular.ttf
assets/fonts/NotoSerifSC-Bold.ttf
```

---

# 第一阶段：地图重建

## 任务
重写TownScene.gd和TownScene.tscn

## TileMap层级规范

```
Layer 0：地面层（可行走，纯视觉）
Layer 1：碰撞层（不可行走，建筑外墙）
严禁混用
```

地块定义：
```
地块0：青石板路（灰色）
地块1：草地（绿色）
地块2：铺前土地（棕色）
地块3：集市地面（米黄色）
地块4：深色草地（废庙方向）
地块5：建筑外墙（深棕，Layer1）
地块6：青石板广场（冷灰色）
```

## 地图区域坐标

```
中央区域：
- 老榕树：(20,15)
- 古井：(21,16)
- 老狗NPC：(19,17)
- 公告栏：(22,13)

左上（杂货铺）：
- 建筑外墙Layer1：cols 2-10，rows 2-10
- 铺前土地：cols 1-11，row 11
- 入口触发点：格子(6,11)

右上（测灵广场）：
- 青石板广场地块6：cols 25-38，rows 2-12
- 道纹石碑装饰：(32,7)

左下（集市）：
- 集市地面地块3：cols 2-16，rows 18-28
- 摊位障碍物Layer1：5-6个随机分布

右下（茶馆+废庙）：
- 茶馆建筑Layer1：cols 25-32，rows 18-24
- 茶馆入口：格子(28,24)
- 深色草地：cols 33-39，rows 20-29
- 废庙入口：格子(37,28)

南门：格子(20,29)

主干道：
- 横向：rows 13-15，全宽
- 纵向：cols 18-21，全高
```

## 摄像机规范

```gdscript
Camera2D:
  limit_left = 0
  limit_top = 0
  limit_right = 1280
  limit_bottom = 960
  position_smoothing_enabled = true
  position_smoothing_speed = 5.0
```

## 建筑入口触发规范

```
严禁Area2D自动触发切换场景
必须：玩家走到入口±1格，显示"按E进入"，按E才触发
使用SceneTransition.change_scene()，不用get_tree().change_scene_to_file()

入口列表：
- 杂货铺：格子(6,11) → res://scenes/ShopScene.tscn
- 茶馆：格子(28,24) → res://scenes/TeaScene.tscn
- 废庙：格子(37,28) → res://scenes/TempleScene.tscn
  废庙特殊：story_phase < 3时显示"大门紧锁"，禁止进入
```

## SpawnPoint规范

```
TownScene必须有SpawnPoint节点

返回TownScene的出生位置：
- 从ShopScene返回：格子(6,12)，像素(192,384)
- 从TeaScene返回：格子(28,25)，像素(896,800)
- 从TempleScene返回：格子(37,29)，像素(1184,928)

GameData需要记录last_scene变量
TownScene._ready()读取last_scene决定出生位置
```

## 启动逻辑

```gdscript
# story_phase == 0时直接进ShopScene
if GameData.story_phase == 0:
    SceneTransition.change_scene("res://scenes/ShopScene.tscn")
```

## 第一阶段测试标准

```
✓ 玩家能正常行走，不穿墙，不卡角
✓ 摄像机跟随，不越出边界，无黑边
✓ 走到杂货铺门口出现"按E进入"，按E切换正确
✓ 走到茶馆门口出现"按E进入"，按E切换正确
✓ story_phase < 3时废庙显示"大门紧锁"
✓ 场景切换后玩家在正确SpawnPoint，不在(0,0)
✓ Layer0和Layer1正确分离
✓ 启动story_phase==0直接进ShopScene
✓ 所有切换使用SceneTransition，有淡入淡出
✓ 代码有完整注释
```

---

# 第二阶段：NPC系统

## 任务
在TownScene里添加所有NPC，实现两套对话状态

## NPC坐标列表

```
爹苏明：ShopScene室内，柜台后
年年（布偶猫）：ShopScene室内，门槛处
大鱼（缅因猫）：ShopScene后院
算命先生：格子(8,22)，集市入口
老婆婆：格子(5,24)，集市深处
两个大婶：格子(14,14)，主干道旁
井边打水的人：格子(21,16)，古井旁
老狗：格子(19,17)，老榕树下
铁匠/鱼贩：格子(3,22)，集市边缘
守卫：格子(20,29)，南门
茶馆掌柜：格子(28,24)，茶馆门口
庆祝的少年：格子(12,20)，集市边缘（回程才出现）
测验师：测灵广场，格子(32,7)旁
顾飞白：废庙场景，战斗后出现
```

## NPC交互规范

```gdscript
# 严禁多NPC同时触发
# 使用射线检测，按E触发最近的NPC
# 交互范围：玩家±40px内
# 对话冷却：0.5秒
# 对话进行中：禁止移动，禁止再次触发
```

## NPC双状态系统

```gdscript
# 每个NPC根据story_phase显示不同对话
# story_phase < 3：测试前状态
# story_phase >= 3：测试后状态（回程）

# 在NPC.gd里增加：
@export var dialogue_scene_id_after: String = ""
# 根据story_phase决定用哪个scene_id
```

## 强制触发节点（回程）

```
回程路线上的强制触发（玩家走过去自动触发，不需要按E）：
1. 庆祝的少年：格子(12,20)附近，锁定1秒
2. 两个大婶：格子(14,14)附近，锁定1秒
3. 打水人低头：格子(21,16)附近，不锁定
4. 算命先生收摊：格子(8,22)附近，不锁定
5. 老狗继续睡：格子(19,17)附近，不锁定

每个节点有is_triggered布尔值，只触发一次
```

## 飘字系统规范

```gdscript
# 次要环境细节用飘字（不锁定移动）
# 飘字显示在屏幕上方
# 显示3秒后自动消失
# 不阻断玩家移动
```

## 第二阶段测试标准

```
✓ 所有NPC在正确位置
✓ 按E只触发最近的NPC，不误触其他
✓ 对话进行中玩家不能移动
✓ story_phase < 3和>=3显示不同对话
✓ 回程强制触发节点按顺序触发
✓ 每个触发节点只触发一次
✓ 对话冷却正常工作
```

---

# 第三阶段：场景切换优化

## 任务
完善ShopScene、TeaScene（新建）、TempleScene（新建）

## ShopScene优化

```
出生点：SpawnPoint在室内门口
破碗互动：可选，触发后交互图标消失，不可再触发
退出：走到出口Area2D，自动切换回TownScene
GameData.last_scene = "shop"
```

## TeaScene（新建）

```
简单室内场景
出生点：门口内侧
茶馆掌柜NPC在内部
退出：走到出口，切换回TownScene
GameData.last_scene = "tea"
```

## TempleScene（新建）

```
废庙室内场景
四块道纹碑文，按顺序排列
每块碑文按E阅读，读完后标记is_read
四块全读完：完整石碑发光
石碑按E触发：激活混沌灵根独白→战斗
出生点：废庙门口内侧
story_phase在此推进到3
```

## 第三阶段测试标准

```
✓ ShopScene进出位置正确
✓ 破碗触发一次后不可再触发
✓ TeaScene进出正常
✓ TempleScene四块碑文按顺序可读
✓ 四块读完石碑发光
✓ 触碰石碑触发独白和战斗
✓ 所有场景切换有淡入淡出效果
```

---

# 第四阶段：剧情触发系统

## 任务
实现story_phase管理和所有剧情触发逻辑

## story_phase状态机

```
phase 0：游戏启动，在ShopScene
phase -1：morning对话触发中（防重复）
phase 1：morning结束，可以出门探索
phase 2：进入测灵广场，触发test对话
phase 3：测试结束，回程开始
phase 4：废庙战斗触发
phase 5：战斗结束，遇顾飞白
```

## advance_phase()函数规范

```gdscript
## 统一的阶段推进函数，禁止直接赋值story_phase
func advance_phase() -> void:
    story_phase += 1
    story_phase_changed.emit(story_phase)
    print("GameData: story_phase推进到 ", story_phase)

# 禁止在任何地方写：GameData.story_phase = X
# 只能写：GameData.advance_phase()
```

## 回程触发逻辑

```gdscript
# story_phase == 3时，TownScene切换到"回程模式"
# 回程模式下：
# 1. 特定NPC显示测试后的对话
# 2. 强制触发节点激活
# 3. 玩家走到杂货铺门口自动触发"回家"剧情
```

## 夜晚切换逻辑

```gdscript
# 回家剧情结束后：
# 屏幕缓慢变暗（3秒渐变）
# 旁白：天色已晚
# 废庙方向出现发光提示
# 废庙入口解锁（story_phase已是3，可以进入）
```

## 第四阶段测试标准

```
✓ story_phase只通过advance_phase()推进
✓ morning对话只触发一次
✓ 测试失败后story_phase正确推进到3
✓ 回程强制触发按正确顺序执行
✓ 夜晚渐变效果正常
✓ 废庙在story_phase>=3后可以进入
✓ 所有剧情节点有is_triggered保护
```

---

# 第五阶段：新增对话内容

## 任务
把新写的所有对话补充进chapter1.json

## 当前scenes列表（已完成）

chapter1.json已包含以下49个场景（全部正式内容）：

正式场景（核心剧情）：
morning、market、test、after_battle、
after_battle_coin、letter、activation_monologue、
activation_monologue_stubborn、activation_monologue_warm、
suming、niannian、dayu、temple（已废弃保留）

回家流程：
return_home、niannian_comfort、dayu_comfort、
sword_tassel_hint

NPC对话（去程）：
fortune_teller、aunts_before、water_carrier_before、
dog_before、guard、teahouse_before、
bowl_interact、niannian_morning、dayu_morning

NPC对话（回程）：
fortune_teller_return、aunts_return、
water_carrier_return、dog_return、
celebration_boy、teahouse_after、
old_wanderer_return、guard_return

茶馆NPC：
storyteller、disciple_a、disciple_b、old_wanderer

废庙：
temple_stone_1、temple_stone_2、
temple_stone_3、temple_stone_4、
monster_approach

夜晚流程：
night_walk_tree、night_walk_well、
temple_entrance_night、night_exit（已废弃）

章末：
chapter_end_a、chapter_end_b

## 第五阶段测试标准

```
✓ 所有新增对话在游戏里正确触发
✓ 逐字显示正常
✓ 选择分支正常
✓ 事件触发正常
✓ 没有缺失的scene_id报错
```

---

# 全局代码质量要求

```
1. 所有函数必须有##注释说明用途
2. 所有格子坐标转像素：Vector2(grid_x * 32, grid_y * 32)
3. 禁止魔法数字，坐标定义为常量或有注释
4. 场景切换冷却1秒
5. TownScene._ready()顺序：建地图→设出生点→连信号
6. 所有动态创建的节点场景切换前queue_free()
7. 禁止在_process()里做地图操作
8. 所有UI使用锚点布局，不用固定像素坐标
```

### story_phase实际状态（第二轮更新）
- phase 0：游戏启动，在ShopScene，morning未触发
- phase 1：morning结束，玩家可出门探索
- phase 2：已废弃
- phase 3：测试结束，回程模式，回家流程
- phase 4：BOSS战胜利，after_battle对话结束后推进
  注意：进入BOSS战时不推进phase，防止战败返回误触发胜利流程
- phase 5：战斗结束，after_battle对话结束

### 新增GameData变量（第二轮）
temple_dungeon_state: Dictionary = {
    "wolf_left_defeated": false,
    "wolf_right_defeated": false,
}
current_enemy_id: String = ""
current_enemy_data: Dictionary = {}
last_player_position: Vector2 = Vector2.ZERO

### 废庙房间布局（空间平移法）最终确认版
- 入口大厅：坐标(0,0)，SpawnPoint(32,270)
- 左厢房：坐标(-600,0)，Stone2在(-360,80)，幽影狼在(-360,120)
- 右厢房：坐标(600,0)，Stone3在(840,80)，幽影狼在(840,120)
- 内殿：坐标(0,-320)，Stone4(240,-190)，石皮蟾(240,-110)
- BOSS间：坐标(0,-640)，主石碑(240,-520)，顾飞白(120,-450)
- 门坐标：
  - 大厅→左厢：(80,60)，左厢→大厅：(-520,280)
  - 大厅→右厢：(380,60)，右厢→大厅：(680,280)
  - 大厅→内殿：(240,60)，内殿→大厅：(240,-20)
  - 内殿→BOSS间：(240,-250)，BOSS间→内殿：(240,-340)
- 玩家落点：
  - 进inner：y=-50，进boss：y=-370
  - KEY_5调试落点：y=-51

### 道心系统（新增）
GameData新增变量：
- dao_heart_stubborn：倔强/逆天倾向
- dao_heart_warm：温暖/在乎倾向

触发点：
1. test场景二选一：选"我不信"→stubborn+1，
   选"没什么大不了的"→warm+1
2. 回家悬筷子那一刻：根据道心显示不同内心旁白
3. 废庙激活灵根：
   stubborn高→activation_monologue_stubborn
   warm高→activation_monologue_warm
4. 战斗前旁白：根据道心显示不同文字

### 铜钱分支（新增）
GameData.got_coin：算命先生铜钱是否获得
BattleManager战斗结束后检查got_coin：
- false→start_scene("after_battle")
- true→start_scene("after_battle_coin")

### 章末路径（新增）
GameData.chapter_end_path：
- "a"：一起走路径
- "b"：回去看爹路径
- ""：未到章末

---

# 防Bug完整清单

```
【碰撞类】
✓ 碰撞体厚度≥8px
✓ 转角rx=4px圆角
✓ 只用move_and_slide()移动
✓ Layer0地面Layer1碰撞严格分离

【NPC交互类】
✓ 射线检测，只触发最近NPC
✓ 对话冷却0.5秒
✓ 对话进行中锁定所有交互
✓ 每个剧情节点is_triggered保护

【场景切换类】
✓ 每个场景有SpawnPoint
✓ 切换后读取SpawnPoint，禁止(0,0)
✓ 切换冷却1秒
✓ 使用SceneTransition，有过渡效果

【剧情逻辑类】
✓ story_phase只通过advance_phase()推进
✓ 禁止直接赋值story_phase
✓ 所有持久数据存GameData，不存场景节点

【UI类】
✓ 对话框单行≤20中文字符自动换行
✓ 对话时摇杆自动隐藏
✓ 所有UI锚点布局
✓ Godot拉伸模式开启

【性能类】
✓ 地图生成在_ready()一次性完成
✓ 禁止_process()里操作地图
✓ 场景切换前queue_free()动态节点
```

### 信号作用域问题
DialogueManager的event_triggered信号
只在当前场景树中的节点有效。
TownScene不在场景树时，
收不到任何DialogueManager信号。
确认每个event在正确的场景里处理，
不要依赖跨场景的信号传递。

### ShopScene三种状态
ShopScene._ready()根据story_phase走不同流程：
- phase 0：morning流程
- phase 3：回家流程（猫咪门口等待）
- phase 5：看信流程
其他phase默认走morning流程。

---

# 待完善内容（后续阶段处理）

```
1. 废庙内部探索地形设计
2. 战斗系统与混沌灵根激活的对接
3. 虚拟摇杆实现
4. 美术资源替换（素材包待定）
5. 背景音乐和音效
6. Android导出适配
7. 存档系统完善
```

---

# UIManager使用规范

## 公开接口
```gdscript
UIManager.refresh_hp()          ## 刷新HP条（战斗回合后调用）
UIManager.refresh_all_data()    ## 全量同步UI（读档后调用）
UIManager.add_item(item_id)     ## 添加旧物（叙事道具专用）
UIManager.on_battle_start()     ## 进入战斗时隐藏常驻UI
UIManager.on_battle_end()       ## 战斗结束时恢复常驻UI
```

## 调用规范
- BattleUI._ready()：调用on_battle_start()
- BattleUI结束切场景前：调用on_battle_end()
- BattleUI._refresh_all_hp()：调用refresh_hp()
- TownScene._ready()末尾：调用refresh_all_data()
- 获得叙事道具时：调用add_item()
- 全屏画面场景（ChapterEndScene等）的_ready()：调用on_battle_start()隐藏常驻UI
```gdscript
UIManager.on_battle_start()  ## 隐藏常驻UI（章末画面等全屏场景调用）
UIManager.on_battle_end()    ## 恢复常驻UI
```

## 旧物背包物品ID
- "sword_tassel"：旧剑穗
- "cinnamon"：桂皮
- "coin"：铜钱

## 技术债记录
当前UIManager.refresh_all_data()在TownScene._ready()里手动调用。
未来加主菜单时，改为：
1. GameData.gd加 signal data_loaded
2. load_from_file()末尾加 data_loaded.emit()
3. UIManager._ready()加 GameData.data_loaded.connect(refresh_all_data)

---

### _detect_current_room() 判断边界
- py < -320 → boss间
- py < -50  → inner内殿
- px < -300 → left左厢房
- px > 300  → right右厢房
- 其他      → main大厅

---

## UIManager扩展接口（第九版新增）

### 功法栏接口
```gdscript
## 以下由UIManager内部管理，无需外部调用：
## _toggle_skill_panel()  ## ESC或"悟"按钮触发
## _rebuild_skill_panel() ## 解锁状态变化时内部调用
```

### 存档系统规范（重构后）
存档槽位：

```
"auto"      → save_auto.json      自动存档
"manual_1"  → save_manual_1.json  手动槽1
"manual_2"  → save_manual_2.json  手动槽2
"crossroad" → save_crossroad.json 章末路口存档
```

调用规范：
```gdscript
GameData.save_to_file("auto")       ## 自动存档
GameData.save_to_file("crossroad")  ## 章末路口
GameData.load_from_file("auto")     ## 读自动存档
GameData.has_save("manual_1")       ## 查询是否有存档
GameData.get_save_preview("manual_1") ## 读取预览信息
```

禁止：
- 场景内直接调用load_from_file()（读档职能归MainMenuScene）
- 战斗中调用save_to_file()（战斗中不存档）


### 主菜单规范（待实装）
主场景：MainMenuScene.tscn

读档后进入场景判断：
```
last_scene == "shop"   → ShopScene.tscn
last_scene == "tea"    → TeaScene.tscn
last_scene == "temple" → TempleScene.tscn
其他（含""）           → TownScene.tscn
```

### ESC系统菜单规范（待实装）
触发条件：ui_cancel（ESC键），由UIManager监听

禁用存档的状态：
- GameData._in_battle == true（战斗中不存档）
- DialogueManager.is_active == true（对话中不存档）

面板按钮：继续 / 存入槽1 / 存入槽2 / 返回主菜单
