# 《问道》虚拟摇杆任务交接文档

---

## 项目基本信息

```
游戏名称：问道
引擎：Godot 4
项目路径：E:/wendao
视口：1280×720 横屏
目标平台：华为Mate 40+（横屏，有挖孔摄像头）
当前版本：第十三版
```

## AutoLoad单例

```
GameData        全局数据/存档
DialogueManager 对话管理
SceneTransition 场景切换
UIManager       全局UI（HP条/心绪/背包/功法/ESC菜单）
```

---

## 任务目标

为《问道》添加手机端虚拟摇杆和触屏交互，让玩家在华为Mate 40+横屏上正常游玩。

---

## 需要新增的控件

### 1. 虚拟摇杆（左下角）
- 功能：控制角色8方向移动
- 替代：键盘WASD/方向键
- 对接方式：通过 `Input.action_press()` 模拟 `ui_left/ui_right/ui_up/ui_down`
- Player.gd使用 `Input.get_vector("ui_left","ui_right","ui_up","ui_down")` ，不需要改

### 2. 交互按钮（右下角）
- 功能：替代键盘E键
- 用途：NPC交互、进入场景、古井回血、道具交互等
- 对接方式：模拟 `KEY_E` 按下事件

### 3. 菜单按钮（右下角，交互按钮旁）
- 功能：替代ESC键呼出系统菜单
- 对接方式：调用 `UIManager._open_esc_menu()` 或模拟 `ui_cancel`

---

## 推荐布局

```
┌─────────────────────────────────────┐
│  [HP] [灵石]         [心绪面板]  ●  │  ← ●是挖孔位置
│                                      │
│         游戏画面                     │
│                                      │
│  [摇杆]          [交互E] [菜单≡]    │
└─────────────────────────────────────┘
```

战斗时：摇杆和交互/菜单按钮自动隐藏，战斗UI按钮本身已是Control节点，手机触屏天然可用。

---

## 华为Mate 40+ 安全区域

- 挖孔在横屏右侧中间偏上
- **右侧所有UI元素需留60px安全边距**
- 心绪面板、囊/悟按钮已在右侧，实装时检查是否被挖孔遮挡

---

## 技术实现建议

### 虚拟摇杆
不推荐使用Godot内置`TouchScreenButton`，建议手写Control节点：

```gdscript
# 摇杆核心逻辑伪代码
func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            _joystick_origin = event.position
        else:
            # 松开，释放所有方向
            Input.action_release("ui_left")
            Input.action_release("ui_right")
            Input.action_release("ui_up")
            Input.action_release("ui_down")

    if event is InputEventScreenDrag:
        var dir = (event.position - _joystick_origin)
        # 死区处理
        if dir.length() > DEAD_ZONE:
            # 根据方向模拟按键
            if dir.x < -threshold: Input.action_press("ui_left")
            if dir.x > threshold:  Input.action_press("ui_right")
            if dir.y < -threshold: Input.action_press("ui_up")
            if dir.y > threshold:  Input.action_press("ui_down")
```

### 显隐控制
虚拟摇杆和交互按钮需要在以下情况隐藏：
- 战斗中（`UIManager._in_battle == true`）
- 对话进行中（`DialogueManager.is_active == true`）
- ESC菜单开启时

建议挂在UIManager下统一管理，复用现有的`on_battle_start()/on_battle_end()`接口。

---

## 现有UIManager公开接口（可复用）

```gdscript
UIManager.on_battle_start()    # 战斗开始，隐藏主HUD
UIManager.on_battle_end()      # 战斗结束，恢复主HUD
UIManager.hide_main_hud()      # 隐藏所有游戏UI
UIManager.show_main_hud()      # 显示所有游戏UI
UIManager.refresh_hp()         # 刷新HP显示
UIManager.refresh_all_data()   # 全量刷新UI
UIManager.add_item(item_id)    # 添加旧物
```

---

## 需要注意的坑

### 1. 电脑端和手机端共存
虚拟摇杆在电脑上也会显示，需要根据平台判断显隐：

```gdscript
# 电脑端隐藏虚拟摇杆
if not OS.has_feature("mobile"):
    _joystick_node.hide()
    _interact_button.hide()
    _menu_button.hide()
```

### 2. 多点触控
虚拟摇杆和交互按钮可能同时被触摸，需要用`event.index`区分不同的触摸点，防止互相干扰。

### 3. UIManager的paused状态
现有`_update_pause_state()`控制游戏暂停：
```gdscript
get_tree().paused = _esc_open or _bag_open or _skill_open
```
游戏暂停时虚拟摇杆输入也应该停止响应，注意处理。

### 4. Android导出配置
需要在Godot Project Settings里：
- 开启 `Display > Window > Handheld > Orientation = Landscape`
- 开启触屏支持
- 配置Android SDK路径

华为手机安装APK需要开启"允许安装未知来源应用"。

---

## 当前已完成内容（第十三版）

- 五条主链路全部可测 ✅
- 存档系统完整（四槽位/覆盖/串档全修复）✅
- UI系统完整（HP/灵石/心绪/背包/功法/ESC菜单）✅
- 第一轮测试12条问题全部处理完毕 ✅
- 旧剑穗获取方式修正 ✅
- 所有已知Bug清零 ✅

## 待完成（按优先级）

1. **虚拟摇杆 + Android适配**（本任务）
2. 美术资源替换（Midjourney出图后替换）
3. 背景音乐和音效

---

## 开发规则（必须遵守）

1. 每次只做一条任务
2. 改完上传文件审查，确认通过再继续
3. 提方案→确认→再给Claude Code指令
4. 不靠猜，有问题先看代码
5. story_phase只通过`advance_phase()`推进，禁止直接赋值
6. 所有NPC消失统一调用`disappear()`
7. 场景切换统一用`SceneTransition.change_scene()`
8. 对话内容全部在chapter1.json，不硬编码在脚本里
9. 存档只在玩家主动离开场景时触发，战斗中不存档
