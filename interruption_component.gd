extends Node

class_name InterruptionComponent

signal interrupted(reason: BaseEntity.Reason)

var parent: BaseEntity
var hit_count: int = 0
var diminishing_return: float = 0.0

func _init(p: BaseEntity):
	parent = p

func handle_hit(current_state: BaseEntity.State, state_timer: float, casting_time: float) -> float:
	# This logic follows the user's recent modifications in PlayerController
	if current_state != BaseEntity.State.DASHING:
		hit_count += 1
		parent.emit_signal("struck")
		
		if current_state == BaseEntity.State.CASTING:
			# Calculate delay/interruption logic
			print("Player hit during cast. Adding time 0.01!. DR = ", diminishing_return)
			if state_timer < casting_time - 0.3:
				diminishing_return += 1.0
				if diminishing_return < 3.0:
					return -0.01 * diminishing_return
	return 0.0

func interrupt(reason: BaseEntity.Reason):
	print("[InterruptionComponent] Interrupting with reason: ", BaseEntity.Reason.keys()[reason])
	emit_signal("interrupted", reason)

func calculate_hit_interruption(state_timer: float, casting_time: float) -> float:
	if state_timer < casting_time - 0.3:
		# diminishing_return is incremented in handle_hit
		if diminishing_return < 3.0:
			print("[InterruptionComponent] Calculating hit delay. DR = ", diminishing_return)
			return -0.01 * diminishing_return
	return 0.0

func clear_hit_count():
	hit_count = 0
