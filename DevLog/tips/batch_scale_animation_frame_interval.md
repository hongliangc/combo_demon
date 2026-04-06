# 批量调整 AnimationPlayer 动画帧间隔 - 2026-03-13

## 场景

AnimationPlayer 中的动画关键帧间隔为 0.125s（8 FPS），需要批量改为 0.1s（10 FPS）。

## 帧数与时间的关系

- 第一帧在时间 **0** 的位置
- 动画总长度 = `(帧数 - 1) × 间隔`，如 10 帧 × 0.125s → `9 × 0.125 = 1.125s`
- 关键帧数量 = `总长度 / 间隔 + 1`

### 常用换算表

| 帧数 | 间隔 0.125s (8FPS) | 间隔 0.1s (10FPS) |
| ---- | ------------------ | ----------------- |
| 4    | 0.375s             | 0.3s              |
| 6    | 0.625s             | 0.5s              |
| 8    | 0.875s             | 0.7s              |
| 10   | 1.125s             | 0.9s              |
| 12   | 1.375s             | 1.1s              |

### 示例：10 帧动画

```
间隔 0.125s:  0.0  0.125  0.25  0.375  0.5  0.625  0.75  0.875  1.0  1.125
间隔 0.1s:    0.0  0.1    0.2   0.3    0.4  0.5    0.6   0.7    0.8  0.9
帧编号:        1    2      3     4      5    6      7     8      9    10
```

### 缩放因子

- 缩放因子 = `新间隔 / 旧间隔` = 0.1 / 0.125 = **0.8**
- 所有关键帧时间和动画总长度都乘以该因子即可

## 方法一：编辑器内置 Scale（逐个动画）

1. 选中动画，`Ctrl+A` 全选所有关键帧
2. **Animation > Scale**，输入 **0.8**
3. 手动将动画 Length 也乘以 0.8

## 方法二：EditorScript 批量处理（推荐）

新建 EditorScript，`Ctrl+Shift+X` 运行：

```gdscript
@tool
extends EditorScript

func _run():
    # 改成你的 AnimationPlayer 路径
    var anim_player: AnimationPlayer = get_editor_interface() \
        .get_edited_scene_root().get_node("AnimationPlayer")

    var scale_factor := 0.1 / 0.125  # = 0.8

    for anim_name in anim_player.get_animation_list():
        var anim: Animation = anim_player.get_animation(anim_name)
        anim.length *= scale_factor

        for track_idx in anim.get_track_count():
            for key_idx in range(anim.track_get_key_count(track_idx) - 1, -1, -1):
                var old_time := anim.track_get_key_time(track_idx, key_idx)
                var value = anim.track_get_key_value(track_idx, key_idx)
                var transition := anim.track_get_key_transition(track_idx, key_idx)
                anim.track_remove_key(track_idx, key_idx)
                anim.track_insert_key(track_idx, old_time * scale_factor, value, transition)

    print("Done! All animations scaled by ", scale_factor)
```

核心逻辑：所有关键帧时间 × 0.8，动画总长度也 × 0.8。遍历 key 时从后往前（倒序）避免索引偏移。

可以这么做，但我先直接说结论：
👉 **“帧数 = FPS，时长固定 1 秒”是可行的，但不推荐作为通用方案。**

我们拆开讲清楚 👇

---

# 1、AnimationPlayer/AnimateSprite2D 如何设置动画的fps和时长

根据公式：

`动画时长 = 帧数 / FPS`

## ✅ 方案1：固定 FPS（最常用）

```text
FPS = 12（像素风推荐）
```

结果：

| 帧数 | 时长 |
| ---- | ---- |
| 6帧  | 0.5s |
| 12帧 | 1s   |
| 18帧 | 1.5s |

👉 优点：

* 节奏统一
* 动画自然

---

## ✅ 方案2：固定“动作时长”（最专业 ⭐）

例如：

```text
attack = 0.4秒
run循环 = 0.6秒
jump = 0.5秒
```

然后：

```text
FPS = 帧数 / 时长
```

👉 这是动作游戏标准做法

---

## ✅ 方案3：固定每帧时间（我最推荐你用）

```text
每帧 = 0.08秒（≈12.5 FPS）
```

👉 自动得到：

* 帧多 → 更细腻
* 帧少 → 更快（但仍自然）

---

# 2、总结一句话

## ✅ 核心关系

如果你设定：

```text
每帧时间 = 0.08 秒（≈ 12.5 FPS）
```

那么动画总时长就是：

```text
动画时长 = 帧数 N × 0.08
          = N / 12.5
```

👉 所以答案是：
✔ **播放时长 = N / 12.5（秒）**

---

## ✅ 举几个例子

| 帧数（PNG数量） | 时长计算  | 实际时长 |
| --------------- | --------- | -------- |
| 6帧             | 6 / 12.5  | 0.48s    |
| 8帧             | 8 / 12.5  | 0.64s    |
| 12帧            | 12 / 12.5 | 0.96s    |
| 18帧            | 18 / 12.5 | 1.44s    |

---

## ✅ 在 Godot Engine 里的对应实现

如果你用的是：

### 🎯 AnimationPlayer

你其实就是在做：

```text
每一帧 key 的时间间隔 = 0.08
```

---

### 🎯 AnimatedSprite2D

直接设置：

```text
FPS = 12.5（或 12 / 13）
```

---

## ⚠️ 一个关键提醒（很多人忽略）

👉 **帧数多 = 动画更慢**

因为：

```text
帧数 ↑ → 时长 ↑
```

比如：

* 6帧 attack → 0.48s（很干脆 ✅）
* 18帧 attack → 1.44s（变慢 ❗）

---

## 🧠 实战建议（很重要）

### 👉 你现在这套方案的含义是：

* 美术决定帧数
* 程序不控制节奏

👉 这在很多情况下是 OK 的，但：

### ❗如果是动作游戏（你做平台跳跃）

建议加一层控制：

```text
如果动画太长 → 提高 FPS（加速播放）
```

例如：

```text
目标 attack = 0.5秒
实际帧数 = 18

FPS = 18 / 0.5 = 36 FPS
```

---

## ✅ 最终总结

✔ 你的公式完全正确：

```text
动画时长 = N / 12.5
```

✔ 本质是：

```text
固定每帧时间 → 自动得到动画长度
```
