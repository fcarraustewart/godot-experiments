extends Node

# CombatManager Singleton (Autoload)
# Purpose: The "Overseer" (Mediator) that validates and routes all combat interactions.
# Prevents Entities from needing to know about each other's internals.

# Signals to notify other managers (UI, Animations, HP)
signal interaction_validated(interaction_result: Dictionary)
signal effect_applied(target: Node, effect_type: String, duration: float)

# Reference to the current game world (to access entities)
var current_game_node: Node2D

var registered_entities = [] # List of combat-capable nodes (Player, Enemies)

# --- REGISTRATION ---

func register_entity(entity: Node2D):
	if not registered_entities.has(entity):
		registered_entities.append(entity)

func unregister_entity(entity: Node2D):
	registered_entities.erase(entity)

# --- TARGETING LOGIC ---

func get_nearest_target(from_pos: Vector2, max_range: float, exclude: Node2D = null) -> Node2D:
	var nearest: Node2D = null
	var min_dist = max_range
	
	for entity in registered_entities:
		if not is_instance_valid(entity): continue
		if entity == exclude: continue
		
		# TARGETING FILTER: Must be an enemy
		var is_valid_enemy = false
		if entity.is_in_group("Enemy"):
			is_valid_enemy = true
		elif entity.has_method("is_enemy") and entity.is_enemy():
			is_valid_enemy = true
			
		if is_valid_enemy:
			var d = from_pos.distance_to(entity.global_position)
			if d < min_dist:
				min_dist = d
				nearest = entity
	return nearest

# --- HITBOX LOGIC ---

func find_targets_in_hitbox(hitbox: Rect2, exclude: Node2D = null) -> Array:
	var hits = []
	for entity in registered_entities:
		if entity == exclude: continue
		
		# Check if entity has a hurtbox
		if entity.has_method("get_hurtbox"):
			var hurtbox = entity.get_hurtbox()
			if hitbox.intersects(hurtbox):
				hits.append(entity)
	return hits

func _physics_process(delta):
	# 1. Simulate Soft Bodies (PhysicsManager logic or delegate)
	# ... (delegated to PhysicsManager)

	# 2. Check Hitbox/Hurtbox Intersections (The Mediator's Job)
	_process_combat_collisions()

func _process_combat_collisions():
	# This replaces the check_collisions logic from show_spectrum.gd
	for source in registered_entities:
		# Does this entity have an active attack hitbox?
		# For Player, it's during State.ATTACKING
		# For Enemies, it's during frame == 1 (as seen in user code)
		
		# PLAYER ATTACKING
		if source is PlayerController and source.current_state == source.State.ATTACKING:
			var spell_data = DataManager.get_spell("sword_attack")
			var damage = spell_data.get("damage", 10.0)
			var max_range = spell_data.get("range", 200.0)
			
			var sword_hitbox = source.get_sword_hitbox()
			var targets = find_targets_in_hitbox(sword_hitbox, source)
			for target in targets:
				if target.is_enemy():
					print("Player hit enemy: ", target.name)
					var success = request_interaction(source, target, "damage", {"amount": damage, "range": max_range})
					if success and spell_data.has("charge_gen"):
						source.add_charge(spell_data.charge_gen)
		
		# ENEMY ATTACKING
		elif source.has_method("is_enemy") and source.is_enemy() and source.frame == 1:
			var enemy_hitbox = source.get_sword_hitbox()
			var targets = find_targets_in_hitbox(enemy_hitbox, source)
			for target in targets:
				if target is PlayerController:
					print("Enemy hit player: ", target.name)
					target.hit()
					request_interaction(source, target, "cc", {"cc_type": "slow", "duration": 1.0, "amount": 0.5})
					request_interaction(source, target, "damage", {"amount": 5.0})

# Called by Source (e.g., Player) when they want to interact with a Target
func request_interaction(source: Node2D, target: Node2D, type: String, data: Dictionary) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(source):
		_notify_fail(source, "INVALID_PARTICIPANTS")
		return false

	# 1. RANGE RE-VALIDATION (Crucial for finishing casts)
	var distance = source.global_position.distance_to(target.global_position)
	var max_range = data.get("range", 9999.0)
	var proc = data.get("proc", false)

	if distance > max_range:
		_create_floating_text(source.global_position, "OUT OF RANGE!", Color.YELLOW)
		_notify_fail(source, "OUT_OF_RANGE")
		return false

	# 2. STATE VALIDATION (Is source stunned? Is target invulnerable?)
	if source.has_method("is_incapacitated") and source.is_incapacitated():
		_notify_fail(source, "SOURCE_CCED")
		return false

	if proc: 
		var type_of_proc = data.get("type_of_proc", "generic")
		print("Proc flag!!: ", type_of_proc)
		_create_floating_text(target.global_position, type_of_proc.to_upper() + "!", Color.YELLOW)

	# 3. INTERACTION LOGIC
	match type:
		"damage":
			_handle_damage(source, target, data)
		"cc": # Slow, Root, Stun
			_handle_crowd_control(source, target, data)
		"interrupt":
			_handle_interrupt(source, target, data)
	
	return true

func _handle_damage(source, target, data):
	var amount = data.get("amount", 0)
	
	if target.has_method("apply_hit"):
		target.apply_hit(amount, source)
		_create_floating_text(target.global_position, "HIT!", Color.RED)
		_notify_success(source, "HIT_SUCCESS", {"amount": amount, "target": target})
	else:
		_notify_fail(source, "TARGET_INVALID")

func _handle_crowd_control(source, target, data):
	var cc_type = data.get("cc_type", "slow")
	var duration = data.get("duration", 1.0)
	
	if target.has_method("apply_" + cc_type):
		target.call("apply_" + cc_type, duration, data.get("amount", 1.0))
		_create_floating_text(target.global_position, cc_type + "ed!", Color.CYAN)
		emit_signal("effect_applied", target, cc_type, duration)
		_notify_success(source, "CC_SUCCESS", {"type": cc_type})

func _handle_interrupt(source, target, data):
	if target.has_method("kicked"):
		target.kicked()
		_create_floating_text(target.global_position, "INTERRUPTED!", Color.ORANGE)
		_notify_success(source, "INTERRUPTED", {"target": target})

# --- VISUAL HELPERS ---

func _create_floating_text(pos: Vector2, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set("theme_override_colors/font_color", color)
	label.set("theme_override_font_sizes/font_size", 24)
	label.global_position = pos + Vector2(-50, -100) # Offset above head
	
	# Add to main scene (current_game_node)
	if current_game_node:
		current_game_node.add_child(label)
	elif get_tree().current_scene:
		get_tree().current_scene.add_child(label)
		
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.6).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

# --- ACKNOWLEDGEMENT HELPERS ---

func _notify_success(source, msg: String, meta: Dictionary):
	if source.has_method("on_interaction_success"):
		source.on_interaction_success(msg, meta)
	emit_signal("interaction_validated", {"status": "SUCCESS", "msg": msg, "meta": meta})

func _notify_fail(source, reason: String):
	if source.has_method("on_interaction_fail"):
		source.on_interaction_fail(reason)
	emit_signal("interaction_validated", {"status": "FAILED", "reason": reason})
