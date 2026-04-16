
视频地址： https://www.youtube.com/watch?v=hK_kz9rBvv4&t=2565s （Metroidvania Enemy AI – A Better Enemy // Metroidvania Forge Ch 05 Ep 03 // Godot 4 Tutorial）

# 一、这个视频的本质架构（重点）

👉 **State Machine + Decision Engine 分层架构**


```
Enemy
│
├── State Machine（执行层）
│     ├── Idle
│     ├── Move
│     ├── Attack
│     └── etc...
│
└── Decision System（决策层）
      ├── Context（环境数据）
      ├── Considerations（评估）
      └── Decision（输出状态）
```

架构
```
Enemy
│
└── BlackBoard
      ├── State Machine
      ├── Sensors & Modular Nodes(RayCast2D 地形检测)
      └── Decision（输出状态）




```

---

# 二、视频里的关键思想（非常重要）

## 1️⃣ “状态不做决策”

视频强调一个核心：

> ❗ **State 只是执行行为，不决定切换**

这和很多初学者写法完全相反。

---

### ❌ 初学者写法（视频反对）

```gdscript
# AttackState.gd
if distance > 100:
    change_state("chase")
```

👉 问题：

* 状态之间耦合
* 很难扩展
* 逻辑分散

---

### ✅ 视频推荐写法

```gdscript
# AttackState 只做攻击
func update():
    attack()
```

👉 所有切换由 Decision Engine 决定

---

# 三、Decision Engine（视频重点）

视频的“灵魂”就在这里

---

## 1️⃣ Context（上下文 / 黑板）

本质就是：

```gdscript
context = {
    "distance_to_player": 32,
    "hp": 50,
    "can_see_player": true
}
```

👉 统一收集信息

类似很多 AI 系统里的：

* Blackboard（黑板系统） ([GameFromScratch.com][1])

---

## 2️⃣ Considerations（评分机制）

视频里不是简单 if，而是：

👉 **打分系统（Utility AI）**

```gdscript
attack_score = 0

if distance < 50:
    attack_score += 10

if can_see_player:
    attack_score += 5
```

---

## 3️⃣ Decision（选择）

```gdscript
best = max(scores)
```

👉 输出：

```
attack / chase / flee
```

---

# 四、State Machine（视频里的实现方式）

视频用的是：

👉 **Node-based FSM（节点式状态机）**

这也是 Godot 推荐方式之一 ([GDQuest][2])

---

## 结构类似：

```
StateMachine (Node)
├── IdleState (Node)
├── MoveState (Node)
└── AttackState (Node)
```

---

## 状态统一接口

```gdscript
func enter()
func exit()
func update(delta)
```

👉 标准 FSM 写法

---

# 五、视频里的“关键优化点”（精华）

---

## ⭐ 1. 决策有“节奏”（不是每帧）

```gdscript
if think_timer > 0.2:
    decide()
```

👉 避免：

* 状态抖动
* 频繁切换

---

## ⭐ 2. 状态是“纯行为模块”

每个 State：

* 不关心其他状态
* 不写 if 判断谁接管

👉 解耦极强

---

## ⭐ 3. AI = “感知 + 评分 + 选择”

视频其实在讲：

👉 AI ≠ if else
👉 AI = Evaluation System

这点很关键

---

# 六、和传统 FSM 的本质区别

| 方案             | 特点       |
| -------------- | -------- |
| 传统 FSM         | 状态自己决定跳转 |
| 视频架构           | 决策层统一控制  |
| 行为树            | 层级结构     |
| Utility AI（视频） | 打分选择     |

---

👉 视频其实是：

**FSM + Utility AI 混合架构**

---

# 七、为什么这个架构更高级？

因为它解决了 FSM 最大问题：

---

## ❌ FSM 痛点

* 状态爆炸
* transition 太多
* 逻辑分散

---

## ✅ 视频方案优势

### 1. 集中决策

所有“该干嘛”在一处

---

### 2. 易扩展

加一个行为只需要：

```gdscript
scores["dodge"] = ...
```

---

### 3. 更像“真实 AI”

可以：

* 犹豫（评分接近）
* 随机性（加 noise）
* 权重调节

---

# 八、在 Godot 4.6 中如何完整复现（落地）

---

## Step 1：StateMachine

```gdscript
class_name StateMachine

var current_state

func update(enemy, delta):
    current_state.update(enemy, delta)
```

---

## Step 2：DecisionEngine

```gdscript
func decide(enemy):

    var context = collect_context(enemy)

    var scores = {
        "attack": calc_attack(context),
        "chase": calc_chase(context),
        "idle": calc_idle(context)
    }

    var best = scores.max_key()

    enemy.state_machine.change_state(best)
```

---

## Step 3：主循环

```gdscript
func _physics_process(delta):
    decision_engine.update(self, delta)
    state_machine.update(self, delta)
```

---

# 九、这个视频的真正定位（总结）

👉 它不是在教 FSM
👉 它在教 **游戏 AI 架构设计**

---

# 十、一句话总结（非常重要）

👉 **State Machine = 行为执行器**
👉 **Decision Engine = 行为选择器（大脑）**

---
