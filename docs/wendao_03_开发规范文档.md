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

## 新增scenes列表

```json
需要新增以下scene_id：
- "niannian_morning"：年年早晨互动
- "dayu_morning"：大鱼早晨互动
- "bowl_interact"：破碗互动
- "return_home"：回家盛饭
- "niannian_comfort"：年年回家安慰
- "dayu_comfort"：大鱼回家安慰
- "fortune_teller"：算命先生去程
- "aunts_before"：两个大婶去程
- "water_carrier_before"：打水人去程
- "dog_before"：老狗去程（旁白）
- "notice_board"：公告栏
- "guard"：守卫
- "teahouse_before"：茶馆掌柜去程
- "teahouse_after"：茶馆掌柜回程
- "celebration_boy"：庆祝的少年（旁白）
- "temple_stone_1/2/3/4"：四块碑文
- "activation_monologue"：激活混沌灵根独白
- "monster_approach"：妖兽出现过渡旁白
```

## 回程旁白scenes

```json
需要新增以下回程旁白（强制触发，不需要按E）：
- "fortune_teller_return"：算命先生收摊
- "aunts_return"：大婶窃窃私语
- "water_carrier_return"：打水人低头
- "dog_return"：老狗继续睡
- "grandma_return"：老婆婆消失
```

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
