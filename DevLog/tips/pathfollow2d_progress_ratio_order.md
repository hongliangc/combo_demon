# PathFollow2D progress_ratio 设置顺序 - 2026-03-15

## 问题

用代码动态创建 PathFollow2D 并设置 `progress_ratio` 后，所有子节点都堆在原点 (0,0)，无法沿曲线分布。

## 原因

`progress_ratio` 的 setter 需要访问父节点 Path2D 的 `curve` 来计算位置。如果在 `add_child()` 之前设置，PathFollow2D 还没有父节点，无法获取曲线数据，位置计算失败。

## 解决

**先 `add_child()`，再设置 `progress_ratio`**：

```gdscript
# 错误 - progress_ratio 无法访问曲线
var follower := PathFollow2D.new()
follower.progress_ratio = ratio    # 此时无父节点，位置不生效
path2d.add_child(follower)

# 正确 - 先挂到 Path2D 下再设置
var follower := PathFollow2D.new()
path2d.add_child(follower)         # 先成为 Path2D 子节点
follower.progress_ratio = ratio    # 现在可以访问曲线计算位置
```

## 适用场景

- 运行时动态生成沿路径分布的节点（金币、敌人、装饰物等）
- 任何通过代码创建 PathFollow2D 的场景
