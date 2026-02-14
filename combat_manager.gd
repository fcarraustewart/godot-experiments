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
var current_target_node: Node2D = null
var target_shader = load("res://target_glow.gdshader")

# --- REGISTRATION ---

func register_entity(entity: Node2D):
	if not registered_entities.has(entity):
		registered_entities.append(entity)
		print("[CombatManager] Registered entity: ", entity.name, " (Total: ", registered_entities.size(), ")")

func unregister_entity(entity: Node2D):
	registered_entities.erase(entity)
	print("[CombatManager] Unregistered entity: ", entity.name, " (Total: ", registered_entities.size(), ")")

# --- TARGETING LOGIC ---

enum Faction { PLAYER, ENEMY, ALL }

func get_nearest_target(from_pos: Vector2, max_range: float, exclude: Node2D = null, faction: Faction = Faction.ENEMY) -> Node2D:
	var nearest: Node2D = null
	var min_dist = max_range
	
	for entity in registered_entities:
		if not is_instance_valid(entity): continue
		if entity == exclude: continue
		
		var is_match = false
		match faction:
			Faction.PLAYER:
				is_match = not entity.is_enemy()
			Faction.ENEMY:
				is_match = entity.is_enemy()
			Faction.ALL:
				is_match = true
				
		if is_match:
			var d = from_pos.distance_to(entity.position)
			if d < min_dist:
				min_dist = d
				nearest = entity
	
	if(faction == Faction.ENEMY):
		set_visual_target(nearest)
		
	return nearest

func set_visual_target(node: Node2D):
	if current_target_node == node: return
	
	# Clear old target glow flag
	if is_instance_valid(current_target_node):
		if "target_glow_active" in current_target_node:
			print("[CombatManager] Clearing target glow on: ", current_target_node.name)
			current_target_node.target_glow_active = false
		var s = _get_sprite(current_target_node)
		if s: s.material = null
	
	current_target_node = node
	
	# Set new target glow flag
	if is_instance_valid(current_target_node):
		if "target_glow_active" in current_target_node:
			print("[CombatManager] Setting target glow on: ", current_target_node.name)
			current_target_node.target_glow_active = true

func _update_target_visuals():
	# Update ALL registered entities based on their target_glow_active flag
	for ent in registered_entities:
		if not is_instance_valid(ent): continue
		
		var s = _get_sprite(ent)
		if not s: continue
		
		if ent.get("target_glow_active") == true:
			if not s.material or s.material.shader != target_shader:
				var mat = ShaderMaterial.new()
				mat.shader = target_shader
				mat.set_shader_parameter("border_color", Color(1.0, 0.6, 0.0, 1.0))
				mat.set_shader_parameter("border_width", 8.0)
				mat.set_shader_parameter("glow_intensity", 5.0)
				s.material = mat
		else:
			if s.material and s.material.shader == target_shader:
				s.material = null

func _get_sprite(node: Node2D) -> CanvasItem:
	if "sprite" in node: return node.sprite
	if node.has_node("Sprite2D"): return node.get_node("Sprite2D")
	if node.has_node("AnimatedSprite2D"): return node.get_node("AnimatedSprite2D")
	# Search children
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

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
	# 1. Simulate Soft Bodies (PhysicsManager logic)
	
	# 2. Check Hitbox/Hurtbox Intersections
	_process_combat_collisions()
	
	# 3. Update Visual Target Glow (Every frame to handle sprite swaps)
	_update_target_visuals()


func _process_combat_collisions():
	# This replaces the check_collisions logic from show_spectrum.gd
	for source in registered_entities:
		# Does this entity have an active attack hitbox?
		# For Player, it's during State.ATTACKING
		# For Enemies, it's during frame == 1 (as seen in user code)
		
		# PLAYER ATTACKING
		if source.is_in_group("Player") and source.current_state == source.State.ATTACKING:
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
		elif source.has_method("is_enemy") and source.is_enemy():
			# Check for standard sprite-based attack frame logic
			var is_attacking = false
			if "sprite" in source and is_instance_valid(source.sprite):
				if source.sprite.frame == 1:
					is_attacking = true
					
			if is_attacking:
				var enemy_hitbox = source.get_sword_hitbox()
				var targets = find_targets_in_hitbox(enemy_hitbox, source)
				for target in targets:
					if target.is_in_group("Player"):
						print("Enemy hit player: ", target.name)
						target.apply_hit(5.0, source)
						request_interaction(source, target, "cc", {"cc_type": "slow", "duration": 1.0, "amount": 0.5})
						request_interaction(source, target, "damage", {"amount": 5.0})

# Called by Source (e.g., Player) when they want to interact with a Target
func request_interaction(source: Node2D, target: Node2D, type: String, data: Dictionary) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(source):
		return false

	# flash on hit
	if type == "damage":
		var s = _get_sprite(target)
		if s:
			var prev_mod = s.modulate
			s.modulate = Color(15, 15, 15, 1) # Super Bright flash
			get_tree().create_timer(0.05).timeout.connect(func(): if is_instance_valid(s): s.modulate = prev_mod)

	# 1. RANGE RE-VALIDATION
	var distance = source.position.distance_to(target.position)
	var max_range = data.get("range", 9999.0)
	var proc = data.get("proc", false)

	if distance > max_range:
		_create_floating_text(source.position, "OUT OF RANGE!", Color.YELLOW)
		_notify_fail(source, "OUT_OF_RANGE")
		return false

	# 2. STATE VALIDATION
	if source.has_method("is_incapacitated") and source.is_incapacitated():
		_notify_fail(source, "SOURCE_CCED")
		return false

	if proc: 
		var type_of_proc = data.get("type_of_proc", "generic")
		_create_floating_text(target.position, type_of_proc.to_upper() + "!", Color.YELLOW)

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
		_create_floating_text(target.position, "HIT!", Color.RED)
		_notify_success(source, "HIT_SUCCESS", {"amount": amount, "target": target})
	else:
		_notify_fail(source, "TARGET_INVALID")

func _handle_crowd_control(source, target, data):
	var cc_type = data.get("cc_type", "slow")
	var duration = data.get("duration", 1.0)
	
	if target.has_method("apply_" + cc_type):
		target.call("apply_" + cc_type, duration, data.get("amount", 1.0))
		_create_floating_text(target.position, cc_type + "ed!", Color.CYAN)
		emit_signal("effect_applied", target, cc_type, duration)
		_notify_success(source, "CC_SUCCESS", {"type": cc_type})

func _handle_interrupt(source, target, data):
	if target.has_method("kicked"):
		target.kicked()
		_create_floating_text(target.position, "INTERRUPTED!", Color.ORANGE)
		_notify_success(source, "INTERRUPTED", {"target": target})

# --- VISUAL HELPERS ---

func _create_floating_text(pos: Vector2, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set("theme_override_colors/font_color", color)
	label.set("theme_override_font_sizes/font_size", 24)
	label.position = pos + Vector2(-50, -100) # Offset above head
	
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
