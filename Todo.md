1. 参考：res://AI敌人状态机.md 的，然后梳理下Dinosaur AI的状态机和动画实现
2. 修改补充当前项目AI 状态机和AnimationTree不足的地方，简化、删除多余的逻辑， 不用向后兼容。
3. 给AI 敌人的场景中 添加 AnimationTree 选择AnimationNodeBlendTree类型，添加StateMachine 结合OneShot ， BlendSpace2D ，timescale等高级功能优化
4. 不要再代码中创建节点对象，都在编辑器中配置完成，特别是AnimationTree 中的状态切换。
5. 给出优化架构文档




---

1. AnimationTree中 选择AnimationNodeBlendTree类型，然后并使用添加StateMachine，在结合OneShot ，blend，timescale等高级功能优化
2. 不用向后兼容
3. 可以实施列出的4个改进步骤，可以而外新增需要的步骤



2026.02.26 角色场景模板化改造
1. 继续改造，把当前的player和boss等charator 都改造成使用模板场景，简化代码， 抽出公共的功能模块，直接放到模板场景中或者使用组合模式放到模板场景中。方便后续新建boss或者player角色时直接继承模板场景就可以了
2. 修改后可以需要进行验证
3. 如果有更好的修改建议可以提出来让我抉择


2026.04.20 编码优化
阅读：docs\superpowers\specs\2026-04-12-ai-v3-agent-base-design.md，查看 _setup_transitions 。优化BladeKeeper 场景脚本实现_setup_transitions。并记录下，用于后续场景迁移或者新建使用AgentAI优化


2026.04.21 状态机可以加上重入效果
触发重入后，可以设置播放动画，animationPlayer.seek 设置为第一帧


2026.04.25 
1. DS2 被攻击不掉血修复
