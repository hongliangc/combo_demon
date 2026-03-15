# AnimationTree 继承场景中的可编辑方案 - 2026-03-12

## 问题

敌人场景（ForestBoar、ForestBee、ForestSnail）继承自 `EnemyBase.tscn`。基类中定义了 `AnimationTree` 及其 `tree_root`（`AnimationNodeBlendTree`）。在子场景中，该 BlendTree **只读**，无法编辑节点和连线。

编辑器中 Inspector 显示：**"This object is read-only"**

`Tree Root` 下拉菜单中 **"Make Unique"** 和 **"Make Unique (Recursive)"** 被禁用。

### 根本原因

Godot 场景继承机制下，父场景的 `sub_resource`（内联资源）在子场景中共享引用，资源**内容**只读。子场景可以覆盖**属性引用**（tree_root 指向哪个资源），但不能编辑继承的资源内容（BlendTree 内部节点）。

## 解决方案：从 EnemyBase 导出 .tres 模板

从基类场景导出 BlendTree 为 `.tres` 文件，新敌人通过 **"Load..."** 加载该模板来覆盖继承的只读引用。

### 导出模板步骤

1. 打开 `EnemyBase.tscn`
2. 选中 `AnimationTree` 节点
3. 点击 `Tree Root` 下拉 → **"Save As..."**
4. 保存为 `.tres` 文件（如 `res://Scenes/Characters/Templates/EnemyBlendTree.tres`）

### 新建敌人使用步骤

1. 继承 `EnemyBase.tscn` 创建新敌人场景
2. 选中 `AnimationTree` 节点
3. 点击 `Tree Root` 下拉 → **"Load..."** → 选择导出的 `.tres` 文件
4. 自由编辑 BlendTree

> **注意：** 通过 "Load..." 加载后，Godot 编辑器保存场景时会将 `.tres` 的内容**内联**为 `sub_resource` 写入 `.tscn`。也就是说，`.tres` 文件仅作为初始模板使用，后续编辑器中的修改直接保存在 `.tscn` 内部。

## 当前状态

- ForestBoar: 已通过内联 sub_resource 实现
- ForestBee: 已通过 Load .tres 实现（Godot 编辑器保存后自动内联）
- ForestSnail: 已通过内联 sub_resource 实现
- 后续新敌人统一使用 Load .tres 方式
