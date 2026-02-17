extends Node

class_name JumpComponent

signal falling
signal jumped
signal jump_peak

# --- CONFIG ---
var jump_impulse: float = -800.0
var jumping_gravity_mult: float = 1.0
var falling_gravity_mult: float = 2.0
var peak_threshold: float = 100.0 # Velocity range (abs) for "peak" state

const COYOTE_TIME = 0.15
const JUMP_BUFFER = 0.15

# --- STATE ---
var parent: BaseEntity
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

func _init(p: BaseEntity):
	parent = p

func update(delta: float):
	# 1. Update Buffers
	if parent.is_on_floor_physics:
		coyote_timer = COYOTE_TIME
	else:
		if coyote_timer > 0:
			coyote_timer -= delta
			
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		
	# 2. Check for Landing
	if parent.is_on_floor_physics and parent.velocity.y >= 0:
		if parent.current_state == BaseEntity.State.JUMPING or \
		   parent.current_state == BaseEntity.State.JUMP_PEAK or \
		   parent.current_state == BaseEntity.State.FALLING:
			parent.change_state(BaseEntity.State.IDLE)
			parent.set("gravity_multiplier", 1.0)
			
	# 3. State Transitions while in the air
	if not parent.is_on_floor_physics:
		var vy = parent.velocity.y
		# Ascending
		if vy < -peak_threshold:
			if parent.current_state != BaseEntity.State.JUMPING:
				parent.change_state(BaseEntity.State.JUMPING)
				parent.set("gravity_multiplier", jumping_gravity_mult)
			
		# Peak
		elif vy >= -peak_threshold and vy <= peak_threshold:
			if parent.current_state != BaseEntity.State.JUMP_PEAK:
				emit_signal('jump_peak')
				# Even lower gravity at the peak for "floatiness"? 
				parent.set("gravity_multiplier", jumping_gravity_mult * 0.5)
			
		# Descending
		elif vy > peak_threshold:
			if parent.current_state != BaseEntity.State.FALLING:
				emit_signal('falling')
				parent.set("gravity_multiplier", falling_gravity_mult)

	# 4. Handle Buffered Jump
	if parent.is_on_floor_physics and jump_buffer_timer > 0:
		perform_jump()

func handle_jump_input():
	if (parent.is_rooted_active == false) and \
		(parent.is_on_floor_physics or coyote_timer > 0.0):
		# Don't jump if already jumping or dashing (though jumping state is more granular now)
		# We allow jumping from FALLING if coyote time is active
		perform_jump()
	else:
		jump_buffer_timer = JUMP_BUFFER

func perform_jump():
	parent.velocity.y = jump_impulse
	parent.is_on_floor_physics = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	parent.set("gravity_multiplier", jumping_gravity_mult)
	if parent.has_signal("jumped"):
		parent.emit_signal("jumped")
