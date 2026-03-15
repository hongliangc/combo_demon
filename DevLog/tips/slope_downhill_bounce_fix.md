# 下坡弹跳修复 - 2026-03-13

## 问题

角色在斜坡上向上走正常，向下走时一跳一跳的（下坡弹跳）。

## 原因

1. `PlayerBase.gd` 在 `is_on_floor()` 时将 `velocity.y` 重置为 0
2. 下坡时角色只有水平速度，没有向下分量来贴合斜面
3. `move_and_slide()` 按水平方向移动后，角色脱离斜面
4. 下一帧重力生效才拉回地面，造成反复弹跳

## 解决

在 `CharacterBody2D` 节点上设置两个属性：

| 属性 | 值 | 作用 |
|------|----|------|
| `floor_snap_length` | `16.0` | 下坡时在 16px 范围内自动吸附地面 |
| `floor_constant_speed` | `true` | 斜面上保持匀速，上坡不减速、下坡不加速 |

### 编辑器设置路径

选中 `CharacterBody2D` 节点 → Inspector → **Floor** 分组：

- **Floor Constant Speed** → 勾选
- **Floor Snap Length** → 16

### 对应 tscn 属性

```
[node name="PlayerBase" type="CharacterBody2D"]
floor_constant_speed = true
floor_snap_length = 16.0
```

## 注意事项

- `floor_snap_length` 默认值为 1.0，对斜坡移动不够用
- 值太大会导致角色从高处"吸"到地面，16 是较安全的值
- 如果角色速度更快或坡度更陡，可能需要增大该值
- 该属性只在 `move_and_slide()` 时生效
