# TreasureChest Display Fix - 2026-03-07

## 问题描述

宝箱资源文件包含2个状态（关闭和打开），每个16x16像素。之前的实现直接显示整个纹理，导致两个状态同时显示。

## 问题原因

- Sprite2D未设置`hframes`（水平帧数）
- 未指定`frame`（当前显示帧）
- 打开动画未切换到打开状态的帧

## 修复方案

### 1. [TreasureChest.gd](Scenes/Levels/Components/TreasureChest.gd)

**修改 `_setup_sprite()`**:
```gdscript
func _setup_sprite() -> void:
    if sprite:
        # 宝箱纹理包含2帧：0=关闭，1=打开
        sprite.hframes = 2
        sprite.frame = 0  # 初始显示关闭状态

        if chest_size == "big":
            sprite.texture = preload("res://Assets/Art/Ninja_Adventure/Items/Treasure/BigTreasureChest.png")
        else:
            sprite.texture = preload("res://Assets/Art/Ninja_Adventure/Items/Treasure/LittleTreasureChest.png")
```

**修改 `_play_open_animation()`**:
```gdscript
func _play_open_animation() -> void:
    if animation_player and animation_player.has_animation("open"):
        animation_player.play("open")
    else:
        # 切换到打开状态（第2帧）
        if sprite:
            sprite.frame = 1

        # 简单的缩放和消失动画
        var tween = create_tween()
        tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
        tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
        tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
```

### 2. [TreasureChest.tscn](Scenes/Levels/Components/TreasureChest.tscn)

**修改 Sprite2D 节点**:
```gdscript
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_sprite")
hframes = 2    # 添加：2个水平帧
frame = 0      # 添加：初始显示第1帧（关闭状态）
```

## 技术细节

### hframes 属性

`hframes` 告诉Sprite2D纹理被分割成多少个水平帧：
- 宝箱纹理是 32x16 像素（2个16x16的帧）
- `hframes = 2` 将纹理分割为2帧
- 每帧宽度 = 总宽度 / hframes = 32 / 2 = 16像素

### frame 属性

`frame` 指定当前显示的帧索引：
- `frame = 0` → 显示第1帧（关闭状态，左边16像素）
- `frame = 1` → 显示第2帧（打开状态，右边16像素）

## 工作流程

1. **初始化**:
   - `_ready()` 调用 `_setup_sprite()`
   - 设置 `hframes = 2` 和 `frame = 0`
   - 宝箱显示关闭状态

2. **玩家交互**:
   - 玩家按下 E 键
   - 调用 `open_chest()`
   - 触发 `_play_open_animation()`

3. **打开动画**:
   - 设置 `sprite.frame = 1` → 切换到打开状态
   - 播放缩放和淡出动画
   - 0.5秒后移除宝箱节点

## 适用资源

此修复适用于以下宝箱资源：
- `LittleTreasureChest.png` (32x16像素，2帧)
- `BigTreasureChest.png` (32x16像素，2帧)

## 测试结果

✅ **测试场景**: Level2.tscn
✅ **宝箱生成**: 2个big宝箱正常生成
✅ **初始显示**: 显示关闭状态（frame 0）
✅ **打开动画**: 切换到打开状态（frame 1）
✅ **无错误**: 场景运行正常

## 相关文件

- `Scenes/Levels/Components/TreasureChest.gd` - 宝箱脚本
- `Scenes/Levels/Components/TreasureChest.tscn` - 宝箱场景
- `Assets/Art/Ninja_Adventure/Items/Treasure/LittleTreasureChest.png` - 小宝箱资源
- `Assets/Art/Ninja_Adventure/Items/Treasure/BigTreasureChest.png` - 大宝箱资源

## 注意事项

1. **资源格式**: 确保宝箱纹理是水平排列的2帧（关闭|打开）
2. **帧顺序**: 第0帧必须是关闭状态，第1帧必须是打开状态
3. **hframes值**: 必须与纹理实际的帧数匹配
4. **初始frame**: 必须设置为0，否则会显示错误的状态

## 扩展建议

### 如果需要更多状态

如果宝箱有更多状态（例如：关闭、半开、打开），可以扩展：

```gdscript
# 3帧：关闭、半开、打开
sprite.hframes = 3
sprite.frame = 0  # 关闭

# 打开时播放帧序列动画
func _play_open_animation():
    var tween = create_tween()
    tween.tween_property(sprite, "frame", 1, 0.1)  # 半开
    tween.tween_property(sprite, "frame", 2, 0.1)  # 打开
```

### AnimatedSprite2D 替代方案

如果需要复杂动画，可以使用 `AnimatedSprite2D`:

```gdscript
# 将 Sprite2D 替换为 AnimatedSprite2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _setup_sprite():
    sprite.play("closed")  # 播放关闭动画

func _play_open_animation():
    sprite.play("open")    # 播放打开动画
```

---

**修复日期**: 2026-03-07
**测试状态**: ✅ 已验证
**影响范围**: Level1, Level2 所有宝箱
