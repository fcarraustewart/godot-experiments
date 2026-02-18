extends Node

class_name CastingComponent

signal cast_started(spell_id: String, duration: float)
signal cast_done
signal cast_success(spell_id: String)
signal cast_failed(reason: String)

var parent: BaseEntity
var active_skill_ctrl = null
var casting_direction = Vector2.ZERO
var casting_time: float = 1.0
var state_timer: float = 0.0
var last_cast_success: bool = true
var from_above: bool = false

func _init(p: BaseEntity):
	parent = p

func try_start_cast(ctrl, spell_id: String, global_charge: float) -> bool:
	if parent.current_state == BaseEntity.State.CASTING: return false
	if not ctrl: return false
	
	var data = DataManager.get_spell(spell_id)
	var cost = data.get("charge_cost", 0)
	
	if global_charge < cost:
		CombatManager._create_floating_text(parent.position, "NOT ENOUGH CHARGE!", Color.ORANGE)
		return false

	if ctrl.has_method("can_cast") and not ctrl.can_cast():
		return false
		
	var target_pos = Vector2.ZERO
	if ctrl.has_method("try_cast"): 
		target_pos = ctrl.try_cast(parent.position)
	
	if ctrl.is_casting:
		state_timer = 0.0
		active_skill_ctrl = ctrl
		casting_time = data.get("cast_time", 1.0)
		casting_direction = target_pos
		
		emit_signal("cast_started", spell_id, casting_time)
		return true
	
	return false

func update(delta: float):
	if parent.current_state != BaseEntity.State.CASTING:
		return

	state_timer += delta

	if active_skill_ctrl:
		from_above = !from_above
		active_skill_ctrl.cast(state_timer, from_above)

	if state_timer >= casting_time and (not active_skill_ctrl or not active_skill_ctrl.is_casting):
		if last_cast_success:
			var spell_id = ""
			if active_skill_ctrl:
				spell_id = active_skill_ctrl.get_spell_id() if active_skill_ctrl.has_method("get_spell_id") else ""
			emit_signal("cast_success", spell_id)
		else:
			emit_signal("cast_failed", BaseEntity.Reason.FAILED)

func interrupt():
	if active_skill_ctrl and active_skill_ctrl.is_casting:
		active_skill_ctrl.interrupt_charging()
	active_skill_ctrl = null
	emit_signal("cast_failed", BaseEntity.Reason.FAILED)

func handle_success_animation(delta: float) -> bool:
	state_timer -= delta
	if state_timer <= 0:
		emit_signal("cast_done")
		return true
	return false
