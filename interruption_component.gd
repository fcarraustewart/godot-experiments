extends Node

class_name InterruptionComponent

signal interrupted(reason: BaseEntity.Reason)

var parent: BaseEntity
var hit_count: int = 0
var diminishing_return: float = 0.0

func _on_cast_started(spell_id: String, duration: float):
	# Reset hit count and diminishing return when a new cast starts
	clear_hit_count()

func _init(p: BaseEntity):
	parent = p
	p.casting_component.connect("cast_started", _on_cast_started)

func handle_hit(current_state: BaseEntity.State, state_timer: float, casting_time: float) -> float:
	if current_state == BaseEntity.State.CASTING:
		# Calculate delay/interruption logic
		return calculate_hit_interruption(state_timer, casting_time)
	return 0.0

func interrupt(reason: BaseEntity.Reason):
	print("[InterruptionComponent] Interrupting with reason: ", BaseEntity.Reason.keys()[reason])

	if reason != BaseEntity.Reason.HIT and \
		reason != BaseEntity.Reason.PARRIED and \
		parent.casting_component:
		parent.casting_component.interrupt()
		clear_hit_count()
	
	emit_signal("interrupted", reason)

func calculate_hit_interruption(state_timer: float, casting_time: float) -> float:
	if state_timer < casting_time - 0.3:
		# diminishing_return is incremented in handle_hit
		if diminishing_return < 3.0:
			print("[InterruptionComponent] Calculating hit delay. DR = ", diminishing_return)
			return -0.01 * diminishing_return
	return 0.0

func clear_hit_count():
	diminishing_return = 0.0
	hit_count = 0
