extends Node

class_name KnockbackComponent

## KnockbackComponent
## Generates and receives impulse vectors, decays them exponentially, and applies to parent velocity.
## Replaces raw velocity += ... knockback in PlayerController.

@export var mass: float = 1.0 ## Heavier = less knockback received
@export var decay_rate: float = 8.0 ## How fast velocity fades per second (higher = snappier)

var current_velocity: Vector2 = Vector2.ZERO

var _parent

func _init(parent) -> void:
	_parent = parent

## Apply an outward impulse. direction should be normalized.
func apply_impulse(direction: Vector2, force: float) -> void:
	current_velocity += direction.normalized() * (force / max(mass, 0.01))

## Call from parent _physics_process every frame.
func update(delta: float) -> void:
	if current_velocity == Vector2.ZERO:
		return
	if not is_instance_valid(_parent):
		return

	# Exponential decay of the knockback velocity itself
	current_velocity = current_velocity.lerp(Vector2.ZERO, decay_rate * delta)

	# Snap to zero to avoid micro-drift
	if current_velocity.length() < 1.0:
		current_velocity = Vector2.ZERO

## Returns true if there is active knockback being applied.
func is_active() -> bool:
	return current_velocity.length() > 1.0
