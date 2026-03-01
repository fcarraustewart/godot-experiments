extends Node

class_name MovementComponent

## MovementComponent
## Owns horizontal movement speed computation and applies it to the parent CharacterBody2D's velocity.x.
## The parent reads movement_component.current_speed if it needs the value directly.

# --- CONFIG ---
@export var base_speed: float = 200.0
@export var speed_while_jumping: float = 0.7
@export var speed_while_dashing: float = 4.5

# --- STATE ---
var current_speed: float = 0.0  ## Read by parent if needed
var _player

func _init(player) -> void:
	_player = player

## Called every _physics_process from PlayerController.
func update(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	if _player.is_rooted_active:
		_player.velocity.x = 0
		current_speed = 0.0
		return

	var throttle: float = _player.input_throttle

	if _player.is_incapacitated():
		print("[MovementComponent] CC'd can't move")
		throttle = 0.0

	var state = _player.current_state

	# --- Compute horizontal speed ---
	var speed = base_speed

	match state:
		_player.State.DASHING:
			speed *= speed_while_dashing
		_player.State.JUMPING, _player.State.JUMP_PEAK, _player.State.FALLING:
			speed *= speed_while_jumping

	# Slow debuff (if player has it)
	if _player.get("is_slowed_active") and _player.is_slowed_active:
		speed *= _player.get("active_slow_factor")

	current_speed = speed

	# --- Apply to velocity ---
	if state == _player.State.CASTING:
		_player.velocity.x = 0
	else:
		_player.velocity.x = throttle * current_speed

	# --- Update animation state ---
	if throttle != 0:
		_player.facing_right = throttle > 0
		if state == _player.State.IDLE or state == _player.State.STATIONARY:
			_player.change_state(_player.State.RUNNING)
	elif state == _player.State.RUNNING:
		_player.change_state(_player.State.IDLE)
