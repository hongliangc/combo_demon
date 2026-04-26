# Core/Status/LegalAction.gd
class_name LegalAction

const NONE     := 0
const ATTACK   := 1
const MOVE     := 2
const DEFEND   := 4    # 闪避/格挡 AI 行为
const CAST     := 8    # 远程/特殊技能
const HURTABLE := 16   # 可被伤害（关闭 = i-frames）
const ALL      := 31

# 复合状态（按位或组合）
const STUN    := ATTACK | MOVE | DEFEND | CAST   # 全锁，仍 HURTABLE
const ROOT    := MOVE
const DISARM  := ATTACK
const SILENCE := CAST
const SLEEP   := ATTACK | MOVE | CAST
