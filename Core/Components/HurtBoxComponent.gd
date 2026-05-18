extends Area2D
class_name HurtBoxComponent

############################################################
# HurtBoxComponent — 受击碰撞标记区域。
# 攻击方 HitBoxComponent 通过 `target is HurtBoxComponent` 识别可命中目标，
# 伤害经受击者的 DamagePipeline 结算（见 HitBoxComponent / DamagePipeline）。
# v1 的 take_damage() / damaged 信号路径已在 sub-spec-6 移除。
############################################################
