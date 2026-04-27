# 问道 (Wendao)

> 碎玉镇少女苏云晚的测灵礼那天 —— 散文叙事 + 回合制战斗。

## 这是什么

一个**叙事优先**的修仙题材独立游戏。形式上是回合制 RPG，但核心是一段
被仔细打磨过的小镇日常 + 命运转折叙事——回合制只是壳。

- **引擎**：Godot 4.6
- **当前状态**：第一章「测灵礼」可玩切片（v40.14），从晨起到觉醒一击全链路通
- **平台**：PC（1280×720 窗口，未来或扩展手机/手柄）
- **类型**：单机 / 散文叙事 / 轻回合制

## 核心设计

游戏不是为"修仙战斗"服务的，是为**苏云晚这个人**服务的。

- **叙事优先**：所有机制（战斗、商店、测灵）都是为某段心境/某次选择服务的演出
- **数据驱动**：所有对话、选择支、flag 链路都在 `data/chapter1.json`，
  代码层 `DialogueManager.gd` 只负责解释执行
- **作者圣经**：苏云晚的性格尺子、世界观规则、禁忌（哪些不能写）全部
  锁在 [`design/narrative/sui-yu-zhen-bible.md`](design/narrative/sui-yu-zhen-bible.md)
  —— 改任何叙事内容前先对照
- **回合制是壳**：战斗系统简单（攻击/治疗/跳过 + 觉醒一击），不追求
  深度策略；它的存在是为了承担"剑穗烫了一下"那种瞬间

## 项目结构

```text
wendao/
├── project.godot               # Godot 4.6 配置
├── scenes/
│   ├── MainMenuScene.tscn      # 主菜单（入口）
│   ├── TownScene.tscn          # 碎玉镇（核心场景，白天/夜晚）
│   ├── TeaScene.tscn           # 茶馆（老江湖、说书人）
│   ├── ShopScene.tscn          # 杂货铺（婆婆、平安符）
│   ├── TempleScene.tscn        # 废庙五房间（夜晚 + 觉醒一击）
│   ├── BattleScene.tscn        # 战斗
│   └── ChapterEndScene.tscn    # 章末（路径 A/B）
├── scripts/
│   ├── 单例 (AutoLoad)
│   │   ├── GameData.gd          # 玩家数据、flag、存读档、story_phase
│   │   ├── DialogueManager.gd   # 数据驱动对话执行器（读 chapter1.json）
│   │   ├── SceneTransition.gd   # 转场（黑屏/白屏/水墨）
│   │   ├── AudioManager.gd      # BGM/SFX/响度补偿
│   │   ├── UIManager.gd         # HP / 心绪 / 旧物背包
│   │   ├── ThemeManager.gd      # 全局主题
│   │   └── CharmSpirit.gd       # 符灵系统（第一章硬编码版）
│   ├── 战斗
│   │   ├── BattleManager.gd     # 回合状态机
│   │   ├── BattleUI.gd          # 战斗 UI / BGM / 觉醒触发
│   │   ├── BattleSkillMenu.gd   # 技能菜单
│   │   ├── BattleEffects.gd     # 伤害数字、震屏
│   │   └── BattleParticles.gd   # 战斗粒子
│   ├── 场景控制器
│   │   ├── TownScene.gd / TeaScene.gd / ShopScene.gd
│   │   ├── TempleScene.gd / ChapterEndScene.gd
│   │   └── MainMenuScene.gd
│   └── 其它
│       ├── DialogueBox.gd       # 对话框 UI
│       ├── NPC.gd / Player.gd / Character.gd
│       ├── NPCSilhouettes.gd / EnemySilhouettes.gd  # 程序化剪影
│       └── VirtualJoystick.gd / ButtonAnimator.gd
├── data/
│   └── chapter1.json           # 第一章全部叙事内容（85 个 scene）
├── assets/                     # 立绘、音乐、环境素材
├── design/
│   └── narrative/sui-yu-zhen-bible.md   # ⭐ 作者圣经（必读）
├── docs/
│   ├── wendao_05_开发进度与改动记录.md   # 改动 changelog
│   └── wendao_06_有意义互动补全设计.md   # 互动设计参考
└── CLAUDE.md                   # 协作规范（给 AI 协作者用）
```

## 第一章流程

晨起 → 集市 → 测灵广场 → 回家 → 夜晚出门 → 废庙 → 觉醒一击 → 章末。

每一段都不是"任务"，都是一次心境切片。具体台词与分支结构请参阅
`data/chapter1.json` 与 bible §10 渗透清单。

> **⚠️ 剧透红线**：第一章的叙事意图（特别是"母亲"留白、符灵真实身份、
> 觉醒一击的真正含义）禁止在任何对外文案中提前揭示。详见 bible §禁忌。

## 开发上手

1. **环境**：Godot 4.6（不要用 4.5 或更早，AutoLoad 类型语法不兼容）
2. **打开**：双击 `project.godot`，主场景默认 `MainMenuScene.tscn`
3. **运行**：F5，或主菜单点"开始新的一天"
4. **跳关调试**：`GameData.story_phase` 直接改值；`GameData.narrative_flags`
   字典里塞 flag 可跳过测灵/觉醒等门槛节点
5. **改对话**：直接编辑 `data/chapter1.json`，重启场景即可生效（无需重编译）

## 文档地图

按"我现在要做什么"分类：

| 我想…… | 看这个 |
|--------|--------|
| 改任何叙事内容 / 写新台词 | `design/narrative/sui-yu-zhen-bible.md` ⭐ 必读 |
| 知道最近改过什么 | `docs/wendao_05_开发进度与改动记录.md` |
| 设计一段新互动 | `docs/wendao_06_有意义互动补全设计.md` |
| 给 AI 协作者下指令 | `CLAUDE.md` + `.claude/` 目录 |
| 看场景/scene 清单 | `docs/wendao_05` 第二节 |
| 看 GameData 字段全貌 | `docs/wendao_05` 第三节 |

## 协作约定

本项目主要由人 + Claude Code 协作开发，遵循 `CLAUDE.md` 的
"Question → Options → Decision → Draft → Approval" 协议——
任何写文件前先问、commit 前先确认、设计讨论先反思现状再扩展。

## License

本项目为个人独立开发作品，代码仅供学习参考。
