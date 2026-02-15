extends Node2D

class_name BaseEntity

# --- SHARED STATE ---
enum State { IDLE, STATIONARY, RUNNING, ATTACKING, ATTACKING_2, ATTACKING_3, CASTING, CASTING_COMPLETE, JUMPING, DASHING, STUNNED, INTERRUPTED, HURT }
var current_state: State = State.IDLE
var state_timer: float = 0.0

# --- SHARED DATA ---
var velocity: Vector2 = Vector2.ZERO
var facing_right: bool = true
var is_on_floor_physics: bool = false
var external_lighting_modulate: Color = Color.WHITE
var target_glow_active: bool = false

# --- CONFIG ---
const BODY_HURTBOX_SIZE = Vector2(64, 64)
var feet_offset: float = 32.0 # Default center-to-feet distance

func _ready():
	global_position = position
	_register_with_managers()

func _exit_tree():
	_unregister_from_managers()

func _register_with_managers():
	if PhysicsManager:
		PhysicsManager.register_character(self)
	if CombatManager:
		CombatManager.register_entity(self)

func _unregister_from_managers():
	if PhysicsManager:
		PhysicsManager.unregister_character(self)
	if CombatManager:
		CombatManager.unregister_entity(self)

func apply_physics():
	# Marker for PhysicsManager
	pass

func get_feet_offset() -> float:
	return feet_offset

func is_enemy() -> bool:
	return false

func get_hurtbox() -> Rect2:
	var top_left = position - (BODY_HURTBOX_SIZE / 2.0)
	return Rect2(top_left, BODY_HURTBOX_SIZE)

func apply_hit(amount: float, source: Node2D):
	state_timer = 0.2
	change_state(State.HURT)
	# Flash effect
	modulate = Color(5, 5, 5, 1) # Bright flash
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1, 1)

func change_state(new_state: State):
	if current_state == new_state: return
	current_state = new_state

func get_active_sprite() -> Sprite2D:
	return null # Overridden by children
