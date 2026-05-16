class_name AIEvents

const EV_DAMAGED         := &"damaged"
const EV_DIED            := &"died"
const EV_PHASE_CHANGED   := &"phase_changed"
const EV_ATTACK_FINISHED := &"attack_finished"
const EV_HIT_RECOVERED   := &"hit_recovered"
const EV_STUN_RECOVERED  := &"stun_recovered"
const EV_REACTION_DONE   := &"reaction_finished"
const EV_INTERRUPTED     := &"interrupted"
const EV_RECOVERED       := &"recovered"

# 平台移动事件 (Player states 派发)
const EV_LANDED          := &"landed"
const EV_LEFT_GROUND     := &"left_ground"

# 玩家输入事件 (InputController 派发)
const EV_INPUT_ATTACK    := &"input_attack"
const EV_INPUT_JUMP      := &"input_jump"
const EV_INPUT_DASH      := &"input_dash"
const EV_INPUT_SPECIAL   := &"input_special"
