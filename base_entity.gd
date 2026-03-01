extends CharacterBody2D

class_name BaseEntity

# --- SHARED STATE ---
enum Reason {SILENCED, STUNNED, KICKED, PARRIED, HIT, OUT_OF_RANGE, FAILED, OTHER}
enum State {IDLE, STATIONARY, RUNNING, ATTACKING, ATTACKING_2, ATTACKING_3, CASTING, CASTING_COMPLETE, JUMPING, DASHING, STUNNED, INTERRUPTED, HURT, JUMP_PEAK, FALLING, LANDING, COMBAT, KNOCKDOWN}
var current_state: State = State.IDLE
var state_timer: float = 0.0
var knockback_component: KnockbackComponent

# --- SHARED DATA ---
# velocity is now built-in to CharacterBody2D
var facing_right: bool = true
# is_on_floor_physics replaced by is_on_floor()
@export var gravity_multiplier: float = 1.0
@export var is_rooted_active: bool = false
var external_lighting_modulate: Color = Color.WHITE
var target_glow_active: bool = false

# --- CONFIG ---
const BODY_HURTBOX_SIZE = Vector2(64, 64)
var feet_offset: float = 32.0 # Default center-to-feet distance

func _ready():
	global_position = position

	knockback_component = KnockbackComponent.new(self )
	knockback_component.name = "KnockbackComponent"
	add_child(knockback_component)

	_register_with_managers()

func _exit_tree():
	_unregister_from_managers()

func _register_with_managers():
	if PhysicsManager:
		PhysicsManager.register_character(self )
	if CombatManager:
		CombatManager.register_entity(self )

func _unregister_from_managers():
	if PhysicsManager:
		PhysicsManager.unregister_character(self )
	if CombatManager:
		CombatManager.unregister_entity(self )

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

func apply_flash_effect():
	# Flash effect
	modulate = Color(5, 5, 5, 1) # Bright flash
	if is_inside_tree():
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self ):
			modulate = Color(1, 1, 1, 1)

func apply_hit(amount: float, source: Node2D):
	state_timer = 0.2
	change_state(State.HURT)

	# Impulse
	if source:
		var knockback_dir = (global_position - source.global_position).normalized()
		if knockback_component:
			get_node("KnockbackComponent").apply_impulse(knockback_dir, 200.0)

func change_state(new_state: State):
	if current_state == new_state: return
	current_state = new_state

func get_active_sprite() -> Sprite2D:
	return null # Overridden by children

func is_incapacitated() -> bool:
	return (current_state == State.KNOCKDOWN or \
			current_state == State.STUNNED)

func on_interaction_success(_msg, _meta):
	print("[BaseEntity] recvd CombatManager validation")

func on_interaction_fail(reason: String):
	# If we are currently casting and we get a failure, track it
	print("[BaseEntity] recvd CombatManager fail")
	if current_state == State.CASTING or current_state == State.CASTING_COMPLETE:
		if reason == "OUT_OF_RANGE" or reason == "TARGET_INVALID":
			# if casting_component.interrupt(Reason.FAILED)
			# Force jump back to IDLE if the interaction failed mid-cast
			change_state(State.IDLE)
