# 批量调整 AnimationPlayer 动画帧间隔 - 2026-03-13

## 场景

AnimationPlayer 中的动画关键帧间隔为 0.125s（8 FPS），需要批量改为 0.1s（10 FPS）。

## 帧数与时间的关系

- 第一帧在时间 **0** 的位置
- 动画总长度 = `(帧数 - 1) × 间隔`，如 10 帧 × 0.125s → `9 × 0.125 = 1.125s`
- 关键帧数量 = `总长度 / 间隔 + 1`

### 常用换算表

| 帧数 | 间隔 0.125s (8FPS) | 间隔 0.1s (10FPS) |
|------|--------------------|--------------------|
| 4    | 0.375s             | 0.3s               |
| 6    | 0.625s             | 0.5s               |
| 8    | 0.875s             | 0.7s               |
| 10   | 1.125s             | 0.9s               |
| 12   | 1.375s             | 1.1s               |

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
