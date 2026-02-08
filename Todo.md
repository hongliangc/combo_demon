1. 参考：res://AI敌人状态机.md 的，然后梳理下Dinosaur AI的状态机和动画实现
2. 修改补充当前项目AI 状态机和AnimationTree不足的地方，简化、删除多余的逻辑， 不用向后兼容。
3. 给AI 敌人的场景中 添加 AnimationTree 选择AnimationNodeBlendTree类型，添加StateMachine 结合OneShot ， BlendSpace2D ，timescale等高级功能优化
4. 不要再代码中创建节点对象，都在编辑器中配置完成，特别是AnimationTree 中的状态切换。
5. 给出优化架构文档




---

1. AnimationTree中 选择AnimationNodeBlendTree类型，然后并使用添加StateMachine，在结合OneShot ，blend，timescale等高级功能优化
2. 不用向后兼容
3. 可以实施列出的4个改进步骤，可以而外新增需要的步骤
