extends Sprite2D

# Simple Enemy script to support the new Mediator architecture

func _ready():
	add_to_group("Enemy")
	if CombatManager:
		CombatManager.register_entity(self)

func _exit_tree():
	if CombatManager:
		CombatManager.unregister_entity(self)

func is_enemy():
	return true

func get_hurtbox() -> Rect2:
	# Define sizes consistent with show_spectrum.gd
	var BODY_HURTBOX_SIZE = Vector2(120, 140)
	var top_left = global_position - (BODY_HURTBOX_SIZE / 2.0)
	return Rect2(top_left, BODY_HURTBOX_SIZE)

func get_sword_hitbox() -> Rect2:
	# Using the logic from show_spectrum.gd
	var SWORD_HITBOX_SIZE = Vector2(180, 40)
	var SWORD_HITBOX_OFFSET = Vector2(240, 60)
	
	var x_dist = SWORD_HITBOX_OFFSET.x
	var y_dist = -SWORD_HITBOX_OFFSET.y
	
	var x_offset = -x_dist + 270 if !flip_h else x_dist - 80
	var y_offset = y_dist + 60 if !flip_h else y_dist + 50
	
	var box_center = global_position + Vector2(x_offset, y_offset)
	var top_left = box_center - SWORD_HITBOX_SIZE
	return Rect2(top_left, SWORD_HITBOX_SIZE)

func apply_hit(amount: float, source: Node2D):
	modulate = Color(5, 0, 0) # Flash Bright Red
	print("Enemy hit by ", source.name, " for ", amount)
	# Logic to reset modulation can be handled here or via timer
	await get_tree().create_timer(0.2).timeout
	modulate = Color(1, 1, 1)
