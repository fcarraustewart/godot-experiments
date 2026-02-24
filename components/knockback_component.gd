extends Node

class_name KnockbackComponent

## KnockbackComponent
## Generates and receives impulse vectors, decays them exponentially, and applies to parent velocity.
## Replaces raw velocity += ... knockback in PlayerController.

@export var mass: float = 1.0        ## Heavier = less knockback received
@export var decay_rate: float = 8.0  ## How fast impulse fades per second (higher = snappier)

var current_impulse: Vector2 = Vector2.ZERO

var _parent: CharacterBody2D

func _init(parent: CharacterBody2D) -> void:
	_parent = parent

## Apply an outward impulse. direction should be normalized.
func apply_impulse(direction: Vector2, force: float) -> void:
	current_impulse += direction.normalized() * (force / max(mass, 0.01))

## Call from parent _physics_process every frame.
func update(delta: float) -> void:
	if current_impulse == Vector2.ZERO:
		return
	if not is_instance_valid(_parent):
		return

	# Apply impulse to parent velocity
	_parent.velocity += current_impulse * delta

	# Exponential decay
	current_impulse = current_impulse.lerp(Vector2.ZERO, decay_rate * delta)

	# Snap to zero to avoid micro-drift
	if current_impulse.length() < 0.5:
		current_impulse = Vector2.ZERO

## Returns true if there is active knockback being applied.
func is_active() -> bool:
	return current_impulse.length() > 0.5
