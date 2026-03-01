很好 👍 下面我给你一套**完整可落地的 Player 动画架构方案**，包含：

* ✅ 分层 AnimationTree 结构
* ✅ 主状态机 + 子状态机
* ✅ 跳跃系统
* ✅ 连击系统
* ✅ 空中攻击
* ✅ 受击打断
* ✅ 优先级系统
* ✅ 可直接用的控制脚本结构

基于 **Godot 4.x**


---

# 🧠 二、AnimationTree 结构（最终版）

## Root 结构

```
AnimationTree
└── BlendTree (Root)
    ├── StateMachine (MainSM)
    └── UpperBodyAttackBlend (可选叠加层)
```

---

# 🥇 三、MainSM（主状态机）

```
MainSM
├── locomotion_sm
├── air_sm
├── attack_sm
└── hit_sm
```

👉 主状态机只负责“大模块调度”。

---

# 🥇 四、Locomotion 子状态机

```
locomotion_sm
├── idle
├── run (BlendSpace1D)
└── turn (可选)
```

### 运行控制：

```gdscript
func update_locomotion():
    if abs(velocity.x) < 5:
        locomotion.travel("idle")
    else:
        locomotion.travel("run")
```

---

# 🥇 五、Air 子状态机

```
air_sm
├── jump_up
├── apex (可选)
├── fall
├── land
├── air_attack (空中攻击)
```

### 控制逻辑：

```gdscript
func update_air():
    if velocity.y < -10:
        air.travel("jump_up")
    elif abs(velocity.y) < 10:
        air.travel("apex")
    else:
        air.travel("fall")
```

落地：

```gdscript
if is_on_floor() and main.get_current_node() == "air_sm":
    main.travel("locomotion_sm")
```

---

# 🥇 六、Attack 子状态机（连击系统）

```
attack_sm
├── attack_1
├── attack_2
├── attack_3
└── combo_end
```

### 动画设置

* attack_1 → attack_2（有过渡）
* attack_2 → attack_3
* attack_3 → combo_end
* combo_end → locomotion_sm

---

### 连击输入缓冲

```gdscript
var combo_step = 0
var combo_requested = false
```

攻击输入：

```gdscript
func request_attack():
    if main.get_current_node() == "locomotion_sm":
        combo_step = 1
        main.travel("attack_sm")
    elif main.get_current_node() == "attack_sm":
        combo_requested = true
```

动画结束信号：

```gdscript
func _on_attack_animation_finished(anim):
    if combo_requested and combo_step < 3:
        combo_step += 1
        attack.travel("attack_" + str(combo_step))
        combo_requested = false
    else:
        combo_step = 0
        main.travel("locomotion_sm")
```

---

# 🥇 七、空中攻击

在 air_sm 内添加：

```
air_attack
```

输入判断：

```gdscript
if !is_on_floor() and Input.is_action_just_pressed("attack"):
    air.travel("air_attack")
```

动画结束：

```gdscript
air.travel("fall")
```

---

# 🥇 八、Hit 子状态机（受击系统）

```
hit_sm
├── light_hit
├── heavy_hit
├── knockback
└── launch
```

主状态机添加：

```
ANY → hit_sm
```

---

# 🧠 九、优先级系统（核心）

优先级顺序：

```
hit > attack > air > locomotion
```

实现方式：

```gdscript
func can_interrupt(current, target):
    var priority = {
        "hit_sm": 4,
        "attack_sm": 3,
        "air_sm": 2,
        "locomotion_sm": 1
    }
    return priority[target] >= priority[current]
```

切换：

```gdscript
func travel_to(target):
    var current = main.get_current_node()
    if can_interrupt(current, target):
        main.travel(target)
```

---

# 🥇 十、完整控制主逻辑（核心框架）

```gdscript
func _physics_process(delta):
    apply_gravity(delta)
    handle_input()
    update_state()
```

---

### update_state()

```gdscript
func update_state():
    if is_dead:
        return

    if is_hit:
        travel_to("hit_sm")
        return

    if !is_on_floor():
        travel_to("air_sm")
        update_air()
        return

    if main.get_current_node() == "attack_sm":
        return

    travel_to("locomotion_sm")
    update_locomotion()
```

---

# 🥇 十一、防止状态爆炸的关键原则

### ✅ 主状态机只管模块

### ✅ 子状态机只管动画细节

### ✅ 不允许子状态机直接跳另一个子状态机

### ✅ 使用优先级统一控制打断

---

# 🥇 十二、AnimationTree 配置步骤总结

1️⃣ 新建 AnimationTree
2️⃣ Root = BlendTree
3️⃣ 添加 StateMachine (MainSM)
4️⃣ 添加四个子状态机
5️⃣ 配置过渡
6️⃣ 设置 Auto 或 Immediate
7️⃣ 获取 playback 控制

---
