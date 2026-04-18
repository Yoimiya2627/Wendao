# Chapter 1 内容审查 v1：分支植入清单

> **目的**：将 chapter1.json 从"线性 VN+战斗"升级为"narrative RPG"。Sonnet 拿这份文档可以直接照着实现选择节点。
> **审查范围**：Top 10 长场景 + 战斗关键节点 + 性格塑造场景，共 ~30 个。
> **跳过**：1-2 节点的纯氛围/微交互场景（保留线性，作为节奏间隔）。

---

## 一、设计原则

1. **不动现有散文** — 章一文本是高质量文学叙事。所有改动 **追加** 选择节点和分支文本，不修改现有节点。
2. **选择必须有"可见的回响"** — 每个 flag 至少在 1 处后续内容里被读取（NPC 反应、独白回想、结局变化）。无回响的"装饰性选择"一律不做。
3. **苏云晚的人格留白** — 现在文本中她沉默而坚韧、对父亲含蓄、对朋友（年年大鱼）柔软。**选择不应背离基调**，而是在她"沉默"与"开口"之间、"克制"与"流露"之间做微小幅度的人格雕刻。
4. **选项数量上限：每场景最多 1 个真选择** — 多重选择爆炸式增长会拖死 Sonnet 实施和测试。
5. **保留可关闭** — 所有新分支默认是"额外内容"，不破坏现有线性主路径。

---

## 二、基础设施依赖（实施前需评估）

当前 `DialogueManager.gd` 不支持的能力，但本审查会用到：

| 需要 | 现状 | 推荐实现 |
|---|---|---|
| 在 dialogue 节点上设置 flag（`set_flag`） | 仅能通过 `event` 字段间接触发 | 在 `_go_to_node` 中读 `set_flag` 字段，直接写 `GameData.narrative_flags[key] = value` |
| 节点条件跳转（`if_flag` → 不同 next） | 不支持 | 读 `if_flag` 字典 `{flag_key: next_id}`，命中则跳，否则走默认 `next` |
| 选择项条件可见（`requires` 字段） | 不支持 | 在 choice 数组项加 `requires_flag`，渲染时过滤 |

**新增字段：`GameData.narrative_flags: Dictionary`**

```gdscript
## 玩家选择记录的剧情标签（独立于 triggered_events，专门承载 RPG 选择）
var narrative_flags: Dictionary = {}
```

> 这三件事是 P0，**必须先做**。否则下面 90% 的清单实施不了。

---

## 三、Flag 命名规范

格式：`{域}_{主体}_{动作或状态}`

| 域 | 含义 | 示例 |
|---|---|---|
| `father_*` | 涉及苏明 / 父女关系 | `father_morning_warm` (清晨主动回应父亲) |
| `mother_*` | 涉及隐藏的母亲线（围裙/针线篓/旧物） | `mother_bowl_lingered` (在针线篓前停留) |
| `pets_*` | 涉及年年/大鱼 | `pets_morning_farewell` (清晨与宠物郑重告别) |
| `town_*` | 涉及镇上 NPC | `town_aunts_confronted` (回应大婶背后议论) |
| `lore_*` | 涉及隐藏前人 / 母亲过往 | `lore_pages_collected` (累计计数) |
| `self_*` | 关于苏云晚自我认知 | `self_test_calm` (测试无灵根时不慌) |
| `gu_*` | 涉及顾飞白 | `gu_coin_revealed` (主动告知铜钱来源) |
| `path_*` | 章末路线 / 大分支 | `path_ending = "follow"` 或 `"return"` |

**值约定：** bool / string / int 都可以，但同一 flag 终生只用一种类型。

---

## 四、Choice 类型分类

| 代号 | 类型 | 用途 | 设计要点 |
|---|---|---|---|
| **A** | 身份/态度 | 雕刻苏云晚人格 | 没有对错，只关乎"她是哪种人" |
| **B** | 情感表达 | 对父亲/朋友/陌生人 | 表达 vs 沉默；亲近 vs 克制 |
| **C** | 探索投入 | 是否深入挖掘/停留 | 多探索 → 解锁碑文/残页/lore flag |
| **D** | 资源策略 | 灵石/物品/时间使用 | 当下收益 vs 长远收益 |
| **E** | 章末路线 | 主线分支 | 已存在的 `ab_choice`，保留 |

**避免类型 F：道德选择。** 现在剧本不是道德困境的调性，强加会突兀。

---

## 五、场景分支清单

### 5.1 章首：清晨与父亲

#### `morning` ⭐ Tier 1（11节点）

**插入点**：在 `m_05c`（捡起剑穗）和 `m_07`（爹叫她）之间，加一个对宠物的告别选择。

```jsonc
"m_05d": {
  "type": "choice",
  "text": "她要出门了。",
  "choices": [
    {
      "text": "蹲下来，认真摸了摸年年和大鱼的头",
      "set_flag": {"pets_morning_farewell": true},
      "next": "m_05d_warm"
    },
    {
      "text": "随手揉了一下年年，转身出门",
      "next": "m_07"
    }
  ]
},
"m_05d_warm": {
  "type": "narration",
  "text": "年年用脑袋顶了顶她的手心。大鱼罕见地没乱跑，安静地坐着。",
  "next": "m_07"
}
```

**插入点 2**：在 `m_08`（爹叮嘱）和 `m_09`（鼻子一酸）之间，加对父亲的回应选择。

```jsonc
"m_08b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「嗯。爹你也吃。」（轻声）",
      "set_flag": {"father_morning_warm": true},
      "next": "m_09"
    },
    {
      "text": "（沉默地点了点头）",
      "set_flag": {"father_morning_silent": true},
      "next": "m_09"
    }
  ]
}
```

**Why**: 这是全章唯一的早晨场景，是定调玩家与父亲关系的起点。两个 flag 在 `letter`、`return_home`、`boss_awakening`、章末独白都会被读取。

**回调位置**：见 §6 跨场景回调表。

---

#### `suming` Tier 3（3节点 / 只在某些路径触发）

**结论**：**不审**。这个场景是 `morning` 中已包含的浓缩版，存在是冗余。建议后续清理（不影响本次审查）。

---

### 5.2 集市段

#### `market` ⭐ Tier 1（8节点）

**插入点**：在 `mk_07`（婆婆"不要钱"）和 `mk_08`（婆婆消失）之间，加对赠予的回应。

```jsonc
"mk_07b": {
  "type": "choice",
  "text": "苏云晚握着那张符。",
  "choices": [
    {
      "text": "「婆婆，我不能白拿。」（从口袋里摸出几枚灵石）",
      "set_flag": {"self_market_proud": true, "town_paid_old_lady": true},
      "next": "mk_07c_paid"
    },
    {
      "text": "「……谢谢您。」",
      "set_flag": {"self_market_grateful": true},
      "next": "mk_08"
    }
  ]
},
"mk_07c_paid": {
  "type": "narration",
  "text": "灵石放下时，老婆婆笑了笑，没有推辞，也没有收。当她抬起头，老婆婆和那几枚灵石都不见了——连人带篮子，像是从未站在那里。",
  "next": "_end"
}
```

**Why**: 给玩家一个"自尊 vs 接受"的微小拉扯。`self_market_proud` 在结局独白中可呼应（"她从来不肯白拿别人的"）。`town_paid_old_lady` 是一个未来章节可能用到的 lore 钩子（老婆婆是谁？她为什么知道？）。

---

#### `vendor_b`（香料摊）Tier 2（4节点）

**插入点**：在 `vb_01`（摊贩招呼）和 `vb_02`（来一包桂皮）之间，加是否买的选择。

```jsonc
"vb_01b": {
  "type": "choice",
  "text": "她想起爹早上说桂皮快用完了。",
  "choices": [
    {
      "text": "「来一包桂皮。」",
      "next": "vb_02"
    },
    {
      "text": "「回来再买。」（先去测灵根）",
      "set_flag": {"father_cinnamon_forgot": true},
      "next": "vb_skip"
    }
  ]
},
"vb_skip": {
  "type": "narration",
  "text": "她想着先把测试做完。摊贩点了点头。"
}
```

**回调**：`return_home` 中加分支：如果 `father_cinnamon_forgot=true`，叙述加一段"灶台上没有桂皮的味道。她忽然想起来——早上忘了买"。

**Why**: 把"忘记给父亲带桂皮"的小遗憾放进章末归家戏，呼应"桌上摆着两副碗筷"的伤感。这种小细节是 RPG 感的重要组成。

---

### 5.3 测灵根

#### `test_stone` ⭐ Tier 1（7节点）

**插入点**：在 `ts_05b`（"今天可以早点回家吃饭了"）和 `ts_06`（"回家"）之间，加对测试结果的态度选择。

```jsonc
"ts_05c": {
  "type": "choice",
  "text": "她站在台下。台上的人和台下的人都没有再看她。",
  "choices": [
    {
      "text": "（她没有低头，把口袋里的剑穗握紧了）",
      "set_flag": {"self_test_calm": true},
      "next": "ts_06"
    },
    {
      "text": "（她快步走开，希望谁都别看她）",
      "set_flag": {"self_test_hurt": true},
      "next": "ts_06"
    }
  ]
}
```

**Why**: 这是苏云晚最重要的人格定调时刻——"无灵根"被宣告。她怎么承受？两个 flag 都是合理的、不同侧面的"她"。
**回调**：`aunts_return`（被大婶背后议论时反应不同）、`disciple_b`（弟子安慰时反应不同）、`boss_awakening`（觉醒回想片段差异）。

---

### 5.4 NPC 互动段（去程/回程）

#### `aunts_return` ⭐ Tier 2（7节点）

**插入点**：在 `ar_07`（最后那句"她听见了"）后，加是否回应的选择。

```jsonc
"ar_08": {
  "type": "choice",
  "text": "她经过她们身边。",
  "choices": [
    {
      "text": "（停下来，回头看了她们一眼）",
      "set_flag": {"town_aunts_confronted": true},
      "next": "ar_09_confront"
    },
    {
      "text": "（什么都没说，继续走）",
      "set_flag": {"town_aunts_silent": true},
      "next": "_end"
    }
  ]
},
"ar_09_confront": {
  "type": "narration",
  "text": "两个大婶笑得有点僵。苏云晚没有说话，只是看着。三秒之后，她转身走了。背后的笑声没有再响起。"
}
```

**Why**: 给"被议论"一个不同的处理方式。`town_aunts_confronted` 是个小小的"反抗" flag——这种小反抗会在很多地方累积影响声誉/性格走向。

**回调**：未来章节回碎玉镇时大婶反应不同。短期回调可放在 `notice_board_after`。

---

#### `old_wanderer` ⭐ Tier 1（11节点）

**插入点**：在 `ow_10`（"我就是说个事实"）和 `ow_11`（重新端起酒盅）之间。

```jsonc
"ow_10b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「老人家见过那种『起步慢的』，最后都走到哪儿了？」",
      "set_flag": {"lore_wanderer_asked": true},
      "next": "ow_10c_lore"
    },
    {
      "text": "（点了点头，没有再问）",
      "next": "ow_11"
    }
  ]
},
"ow_10c_lore": {
  "speaker": "老江湖",
  "text": "走得最远的那个？……早些年的事了。她最后一次出现，是在城南的传音阵旁边。",
  "next": "ow_10d"
},
"ow_10d": {
  "speaker": "老江湖",
  "text": "再之后，没人见过她。",
  "next": "ow_11"
}
```

**Why**: 主动暴露"母亲伏笔"线索。**`lore_wanderer_asked` 是触发 `tally_marks` 第二段独白的前置条件**——划痕和传音阵的关联会变得更明确。

---

#### `teahouse_before` ⭐ Tier 1（9节点）

**插入点**：在 `tb_05`（"上个月有个外乡少年……金灵根五品"）和 `tb_06`（"那他家里人呢"）之间。

```jsonc
"tb_05b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「他想去吗？」",
      "set_flag": {"self_teahouse_curious": true},
      "next": "tb_05c_yes"
    },
    {
      "text": "「那他家里人呢？」",
      "next": "tb_06"
    }
  ]
},
"tb_05c_yes": {
  "speaker": "茶馆掌柜",
  "text": "想不想要紧吗？灵根这种事，由不得人挑。",
  "next": "tb_05d"
},
"tb_05d": {
  "speaker": "苏云晚",
  "text": "……那他家里人呢？",
  "next": "tb_06"
}
```

**Why**: 让玩家选择苏云晚是先关心"他怎么想"还是"家里人"——两种性格切片。`self_teahouse_curious` 在 `boss_awakening` 觉醒回想时可以加一句不同的回想。

---

#### `disciple_b` ⭐ Tier 2（6节点）

**插入点**：`db_b06`（"这话比骂她还难受"）后，加回应。

```jsonc
"db_b07": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「碎玉镇确实挺好的。」（淡淡地）",
      "requires_flag": {"self_test_calm": true},
      "set_flag": {"town_disciple_calm_reply": true},
      "next": "db_b08_calm"
    },
    {
      "text": "（没有说话，端起茶杯）",
      "set_flag": {"town_disciple_silent": true},
      "next": "_end"
    }
  ]
},
"db_b08_calm": {
  "type": "narration",
  "text": "弟子愣了一下，似乎没料到她会接话。他点了点头，把脸转开了。"
}
```

**Why**: 这是 `requires_flag` 的好用例——只有在 `test_stone` 选了 calm 路线的玩家，这条选项才出现。性格连贯性。

---

#### `fortune_teller` ⭐ Tier 1（7节点）

**插入点**：`ft_06`（"什么东西？"）和 `ft_07`（摇头不再说话）之间。

```jsonc
"ft_06b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「先生既然看出来了，能不能说得明白些？」（追问）",
      "set_flag": {"lore_fortune_pressed": true},
      "next": "ft_06c_press"
    },
    {
      "text": "（沉默地等他说下去）",
      "next": "ft_07"
    }
  ]
},
"ft_06c_press": {
  "speaker": "算命先生",
  "text": "明白了反而走不出来。姑娘，今天就到这里。",
  "next": "ft_06d"
},
"ft_06d": {
  "type": "narration",
  "text": "他低下头，开始整理桌上的卦象，再没有抬起来看她。"
}
```

**Why**: `lore_fortune_pressed` 是触发 `fortune_teller_coin`（送铜钱）变体的前置——**追问过的玩家，铜钱后会多一句"算了，这枚拿去。"**。这是把"主动好奇"和"被动接受"区分开。

---

#### `fortune_teller_coin` ⭐ Tier 2（6节点）

**插入点**：`ftc_05`（推钱、收袋、起身）之前，加一个根据 flag 触发的额外台词。

不需要选择，但加一个 `if_flag` 判断：

```jsonc
"ftc_04b": {
  "if_flag": {"lore_fortune_pressed": "ftc_04c_extra"},
  "next": "ftc_05"
},
"ftc_04c_extra": {
  "speaker": "算命先生",
  "text": "你早上问我那句话——我不答，是因为这枚钱比答案有用。",
  "next": "ftc_05"
}
```

**Why**: 让追问过的玩家拿到额外的一句话。**这是回响机制最直接的演示**。

---

### 5.5 废庙·初战

#### `temple` ⭐ Tier 1（8节点）

**插入点**：`tp_07`（"不行。不能死在这里"）和 `tp_08`（trigger_battle）之间，加战前姿态选择。

```jsonc
"tp_07b": {
  "type": "choice",
  "text": "她握住口袋里的剑穗。",
  "choices": [
    {
      "text": "（深吸一口气，挡在路前）",
      "set_flag": {"self_temple_brave": true},
      "next": "tp_08"
    },
    {
      "text": "（抖着，但没有退）",
      "set_flag": {"self_temple_scared": true},
      "next": "tp_08"
    }
  ]
}
```

**Why**: 两个 flag 都是 OK 的——勇敢与"虽然怕但不退"是不同的英雄主义。在 `boss_awakening` 觉醒回想时可以呼应到。

---

#### `tutorial_first_battle` Tier 3（5节点）

**结论**：**不插选择**。教学场景需要纯线性，加选择会打断节奏。保持原样。

---

### 5.6 章末·归家与离开

#### `after_battle` / `after_battle_coin` ⭐ Tier 1（已有 ab_choice）

**结论**：**已有的 `ab_choice` 是全章最重要的分支节点，保留**。但建议对其做以下增强：

1. **加一个前置的"问出真相"选择**，在 `ab_07`（顾飞白说"有人动了手脚"）之后：

```jsonc
"ab_07b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「谁动了手脚？」",
      "set_flag": {"gu_pressed_who": true},
      "next": "ab_07c_press"
    },
    {
      "text": "「这条路通向什么？」",
      "set_flag": {"gu_pressed_where": true},
      "next": "ab_07d_where"
    },
    {
      "text": "（沉默地等他说完）",
      "next": "ab_08"
    }
  ]
},
"ab_07c_press": {
  "speaker": "顾飞白",
  "text": "现在告诉你，你也未必信。等你在槐树林见到我，我再说。",
  "next": "ab_08"
},
"ab_07d_where": {
  "speaker": "顾飞白",
  "text": "通向一个能给你答案的地方。也通向更多的麻烦。",
  "next": "ab_08"
}
```

**Why**: 顾飞白现在像个工具人——给玩家一个表达"她想知道什么"的机会。`gu_pressed_*` 在第二章顾飞白再出现时会被读取。

2. **修改章末两个分支的事件名差异化**——目前 `start_chapter_end_a` 是"跟走"，`return_home_final` 是"回家"。建议：在 `ab_together_02` 和 `ab_return_03` 之前加一个 `set_flag: {"path_ending": "follow"}` / `"return"`。

---

#### `letter` ⭐ Tier 1（13节点）

**插入点**：`lt_11`（"活着，比赢了更要紧"）和 `lt_12`（"知道了，爹"）之间。

```jsonc
"lt_11b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "「知道了，爹。」（轻声）",
      "next": "lt_end"
    },
    {
      "text": "「……我会回来的。」",
      "set_flag": {"father_letter_promise_return": true},
      "next": "lt_11c_promise"
    }
  ]
},
"lt_11c_promise": {
  "type": "narration",
  "text": "她对着空房子说了这句话。窗外风吹过，灯芯抖了一下，没有灭。",
  "next": "lt_end"
}
```

**Why**: 让"回家路线"的玩家自己决定 — 是接受父亲的话，还是反过来许诺。`father_letter_promise_return` 是第二章/第三章重要的回响 flag。

---

#### `return_home` ⭐ Tier 1（11节点）

**改动**：加 `if_flag` 检查 `father_cinnamon_forgot`，在 `rh_05`（旧围裙）之前插入：

```jsonc
"rh_04b": {
  "if_flag": {"father_cinnamon_forgot": "rh_04c_cinnamon"},
  "next": "rh_05"
},
"rh_04c_cinnamon": {
  "type": "narration",
  "text": "灶台上没有桂皮的味道。她忽然想起来——早上忘了买。",
  "next": "rh_05"
}
```

**Why**: 桂皮回响。**这是"小选择产生小回响"的典型示范**——玩家会记住自己忘了买。

---

### 5.7 BOSS 段

#### `boss_room_enter` Tier 2（8节点）

**结论**：**不插选择**。这段独白节奏紧凑，加选择会破坏氛围。但可以加一个 `if_flag` 的细节支线：

```jsonc
"bre_05c": {
  "if_flag": {"lore_pages_collected_3plus": "bre_05d_recall"},
  "next": "bre_06"
},
"bre_05d_recall": {
  "type": "narration",
  "text": "那几张残页上写过的字，忽然在她脑子里浮起来——「尘埃也能迷了它的眼。」",
  "next": "bre_06"
}
```

**Why**: 探索奖励的顶级回报——读了 3 张以上残页的玩家，在 BOSS 室门口会得到一段"知道为什么自己能赢"的额外独白。

> 需要新加 `lore_pages_collected_3plus` 的累计逻辑（在每张残页 set 一个 counter）。

---

#### `boss_awakening` ⭐ Tier 1（9节点）

**改动**：这是全章高潮。**不加新选择**，但需要根据玩家累积的 flag，在觉醒回想（`ba_04` ~ `ba_06b`）中**条件性插入额外回想**。

具体方案：在 `ba_06`（爹的背影）和 `ba_06b`（"别怕"）之间，根据 flag 加 0-3 段回想：

```jsonc
"ba_06_callbacks": {
  "if_flag_chain": [
    {"flag": "father_morning_warm", "node": "ba_cb_warm"},
    {"flag": "pets_morning_farewell", "node": "ba_cb_pets"},
    {"flag": "self_test_calm", "node": "ba_cb_calm"},
    {"flag": "self_temple_brave", "node": "ba_cb_brave"}
  ],
  "next": "ba_06b"
},
"ba_cb_warm": {
  "type": "narration",
  "text": "她对爹说过——「你也吃。」",
  "next": "ba_06_callbacks_continue"
},
// ... etc
```

> `if_flag_chain` 是一个新机制：按顺序检查 flags，命中的依次播放，最后回到 next。这需要 DialogueManager 支持。

**Why**: **这是全章最重要的"回响支付"时刻**。玩家做的所有小选择，在这一刻全部回到她脑海里——觉醒不是机械事件，是她活过的所有片段在那一瞬被点燃。

**这一节如果只能做一件事，就做这个。**

---

### 5.8 lore / 探索段

#### `bowl_interact` ⭐ Tier 2（6节点）

**插入点**：`bi_06`（"没有问是谁"）后，加是否记得这件事的选择。

```jsonc
"bi_07": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "（在心里默默把"她"这个字记住了）",
      "set_flag": {"mother_bowl_lingered": true},
      "next": "_end"
    },
    {
      "text": "（转身走开，没有再想）",
      "next": "_end"
    }
  ]
}
```

**Why**: `mother_bowl_lingered` 是母亲伏笔线的入口 flag。在 `tally_marks`、`transmission_array`、`old_wanderer` 都会读取。

---

#### `tally_marks` ⭐ Tier 2（8节点）

**改动**：加 `if_flag` 在 `tm_07`（想起传音阵）之前：

```jsonc
"tm_06b": {
  "if_flag": {"mother_bowl_lingered": "tm_06c_link"},
  "next": "tm_07"
},
"tm_06c_link": {
  "type": "narration",
  "text": "她忽然想起书架角落那只针线篓，那块缝了一半的布。「等她回来自己补。」——爹是这么说的。",
  "next": "tm_07"
}
```

**Why**: 把 `mother_bowl_lingered` flag 转化为"恍然大悟"——划痕的人、传音阵的人、针线篓的"她"，是同一个人。这种"玩家自己拼起线索"的瞬间是 RPG 感的核心。

---

#### `remnant_page_*` Tier 3（每张 3-5 节点）

**改动**：每张残页末尾加 `set_flag` 自增计数：

```jsonc
"rp1_03b": {
  "set_flag": {"lore_pages_count": "+1"},
  "next": "_end"
}
```

> 需要 DialogueManager 支持 `+1` 这种累加语法，或者在 GameData 加 helper。

**Why**: 累计 3 张以上触发 `boss_room_enter` 的额外独白。

---

#### `temple_stone_*` Tier 3

**结论**：**不动**。碑文已经有 `stones_read` 数组追踪，无需新加。但可以考虑：四块全读完后，在 `temple_stone_4` 加一句额外独白。当前 `ts4_03` 已经隐含这个意思，可以保留。

---

#### `transmission_array` ⭐ Tier 2（5节点）

**改动**：`ta_05`（"只有一道"）后加一个 if_flag 分支：

```jsonc
"ta_06": {
  "if_flag": {"mother_bowl_lingered": "ta_06b_link"},
  "next": "_end"
},
"ta_06b_link": {
  "type": "narration",
  "text": "和爹书架角落那只针线篓的线头，都是只剩一头。等谁回来。"
}
```

**Why**: 又一个母亲伏笔的连接点。

---

#### `monster_approach` Tier 3（7节点）

**结论**：**不插选择**。和 `temple` 几乎重复（不同路径触发），加选择会和 `temple` 的选择冗余。保持线性。

---

#### `activation_monologue` Tier 3（9节点）

**结论**：**不插选择**。这段是觉醒前内省，应保留连贯。

---

#### `celebration_boy` Tier 2（7节点）

**插入点**：`cb_06`（少年移开眼神）和 `cb_07`（云晚也移开）之间。

```jsonc
"cb_06b": {
  "type": "choice",
  "text": "",
  "choices": [
    {
      "text": "（朝他点了点头，笑了一下）",
      "set_flag": {"town_celebration_smile": true},
      "next": "cb_07"
    },
    {
      "text": "（移开视线，继续走）",
      "next": "cb_07"
    }
  ]
}
```

**Why**: 这是一个"有福气和没福气的两个人对视"的瞬间。让玩家选她要怎么承接这个目光——大度还是回避。无需重大回响，但是性格雕刻的小笔触。

---

#### `storyteller` Tier 3（6节点）

**结论**：**不插选择**。说书人是世界观铺垫，被动接收即可。

---

#### `water_carrier_before` / `water_carrier_return` Tier 3

**结论**：**不审**。已经够好。

---

## 六、跨场景回调表

| Flag | 写入位置 | 读取位置 | 回响形式 |
|---|---|---|---|
| `father_morning_warm` | `morning/m_08b` | `letter/lt_06b`(可选) `boss_awakening/ba_06_callbacks` `chapter_ending` | 独白 / 回想 |
| `father_morning_silent` | `morning/m_08b` | `letter/lt_05b`(可选) `chapter_ending` | 独白差异 |
| `pets_morning_farewell` | `morning/m_05d` | `boss_awakening/ba_06_callbacks` | 觉醒回想 |
| `father_cinnamon_forgot` | `vendor_b/vb_01b` | `return_home/rh_04b` | 灶台细节 |
| `self_test_calm` | `test_stone/ts_05c` | `disciple_b/db_b07`(选项条件) `aunts_return/ar_08b`(可选) `boss_awakening` | 选项可见 / 反应差异 |
| `self_test_hurt` | `test_stone/ts_05c` | `aunts_return` `letter` | 反应差异 |
| `town_aunts_confronted` | `aunts_return/ar_08` | 第二章碎玉镇回访 | NPC 反应 |
| `town_paid_old_lady` | `market/mk_07b` | 第二章 lore | 老婆婆身份揭示 |
| `lore_wanderer_asked` | `old_wanderer/ow_10b` | `tally_marks/tm_06b` | 划痕/传音阵关联强化 |
| `lore_fortune_pressed` | `fortune_teller/ft_06b` | `fortune_teller_coin/ftc_04b` | 额外台词 |
| `mother_bowl_lingered` | `bowl_interact/bi_07` | `tally_marks/tm_06b` `transmission_array/ta_06` | 母亲线索串联 |
| `lore_pages_count` (≥3) | `remnant_page_1~4` | `boss_room_enter/bre_05c` | BOSS 室独白 |
| `self_temple_brave` | `temple/tp_07b` | `boss_awakening/ba_06_callbacks` | 觉醒回想 |
| `gu_pressed_who/where` | `after_battle/ab_07b` | 第二章顾飞白对话 | 提前透露信息 |
| `father_letter_promise_return` | `letter/lt_11b` | 第二章 / 章末独白 | 重要承诺 |
| `path_ending` ("follow"/"return") | `after_battle/ab_choice` | 第二章 | 主分支 |

---

## 七、不审场景说明

以下场景**保留原样不动**，理由：

| 场景 | 节点数 | 不动理由 |
|---|---|---|
| `niannian` `dayu` `dayu_approach` `niannian_after` `dayu_after` | 1 | 微交互，加选择反而矫情 |
| `dog_before/return` | 2-3 | 氛围细节 |
| `vendor_a` `vendor_a_return` `vendor_c` `vendor_c_return` | 1-3 | 路过细节 |
| `night_walk_tree` `night_walk_well` | 1 | 探索氛围 |
| `examiner_after` `guard` `guard_return` | 2-3 | 流程性 NPC |
| `light_still_on` `temple_entrance_night` `night_exit` | 2 | 转场 |
| `sword_tassel_hint` `sense_unlocked_hint` | 2 | 系统提示 |
| `well_heal` | 3 | 功能性（回血）|
| `night_vendor_shop` `night_vendor_return` | 已有 choice | 商店菜单已是 choice 结构 |
| `niannian_morning` `dayu_morning` `niannian_comfort` `dayu_comfort` | 4-5 | 宠物温暖小段，加选择破坏氛围 |
| `disciple_a_before` `disciple_b_before` | 3-5 | 短互动 |
| `bowl_interact_return` | 3 | 已被 `bowl_interact/bi_07` flag 影响 |
| `notice_board_*` | 3 | 阅读告示，不是社交 |
| `tutorial_first_battle` `monster_approach` `activation_monologue` | 5-9 | 战斗前后线性独白，加选择破坏节奏 |
| `boss_phase2_start` | 7 | BOSS 战中插话，节奏不允许 |
| `battle_loss_*` | 4-5 | 战败独白，必须线性 |
| `temple_stone_1~3` | 2-3 | 已有 `stones_read` 追踪 |

---

## 八、实施优先级（给 Sonnet 的执行顺序）

### Phase 0 — 基础设施（必做前置，不做就别碰后面）
1. `GameData.gd` 加 `narrative_flags: Dictionary`
2. `DialogueManager.gd` 支持节点字段：`set_flag`、`if_flag`、`requires_flag`（choice 项级别）
3. `DialogueManager.gd` 支持 `lore_pages_count` 这种累加 / counter（可以直接用 GameData helper 函数代替）
4. （可选高价值）支持 `if_flag_chain` 用于 `boss_awakening` 回响链

### Phase 1 — 高 ROI 选择植入（按文档 §5 顺序）
1. `morning` × 2 选择
2. `test_stone` × 1 选择
3. `temple` × 1 选择
4. `letter` × 1 选择
5. `after_battle` / `after_battle_coin` × 增强（`ab_07b` 追问 + `path_ending` flag）

### Phase 2 — 性格雕刻 / NPC 反应
1. `market` × 1
2. `vendor_b` × 1（带 `return_home` 回响）
3. `aunts_return` × 1
4. `teahouse_before` × 1
5. `disciple_b` × 1（条件可见选项）
6. `celebration_boy` × 1

### Phase 3 — Lore / 母亲线 / 探索回报
1. `bowl_interact` × 1
2. `old_wanderer` × 1
3. `fortune_teller` × 1（+ `fortune_teller_coin` if_flag）
4. `tally_marks` × if_flag
5. `transmission_array` × if_flag
6. `remnant_page_*` × set_flag counter
7. `boss_room_enter` × if_flag

### Phase 4 — 觉醒回响（最高优先级的"压轴")
1. `boss_awakening` if_flag_chain（根据所有累积 flag 动态插入回想）

> **Phase 4 是这次升级的灵魂，但它依赖 Phase 0-3 全部完成**。如果 Sonnet 时间紧，至少做 Phase 0 + Phase 1 + Phase 4 的最简实现（只读 2-3 个 flag），也比现在好 10 倍。

---

## 九、统计预期

| 指标 | 当前 | 实施 §5 全部后 |
|---|---|---|
| 选择节点数 | 4（其中 2 是商店）| ~22 |
| 真实剧情分支 | 2（其实是 1）| ~16 |
| 跨场景 flag 回调 | 0 | ~12 |
| 重复游玩差异度 | 极低 | 中（人格/路线感知）|
| 章末独白变体 | 2（A/B 路径）| 8+（路径 × flag 组合）|

预估 Sonnet 全量实施工期：**Phase 0 半天 + Phase 1-4 顺序做完约 3-5 天**。

---

## 十、风险与权衡

1. **`if_flag_chain` 是新机制，没现成实现**——如果 Sonnet 觉得做不来，可以降级为：在 `boss_awakening` 用 GDScript 在 BattleUI 中读 flag、动态拼接回想节点。但这把逻辑分散到两个层（数据+代码），后续维护差。建议直接做在 DialogueManager。

2. **flag 命名一旦写死，改名成本高** —— 严格按 §3 命名约定。

3. **测试成本** —— 22 个选择节点 × 平均 2 分支 = 44 条路径。完整测试需要重玩多次。建议加一个 debug 面板：可以快速 toggle 任意 flag 来跳测后续场景。

4. **写作工作量未计算** —— §5 中所有新文本（约 30 段，每段 1-3 句）需要写出来。我已经在示例中给了草稿，但全部需要由懂这个项目语调的人最终敲定。**建议这一步留给项目作者本人，不交给 Sonnet**。
