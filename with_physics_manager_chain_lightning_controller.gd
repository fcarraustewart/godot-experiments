extends Node

# with_physics_manager_chain_lightning_controller.gd
# Uses PhysicsManager to create high-tension electric arcs.
# Separates the 'Targeting Logic' from the 'Visual Arcing'.

# --- SETTINGS ---
var chain_cooldown = 0.0
var CHAIN_COOLDOWN_MAX = 3.0 
var CHAIN_RANGE = 500.0
var CHAIN_JUMPS = 3
var CHAIN_DMG_DECAY = 0.8
var OVERLOAD_CHANCE = 0.33
var CAST_TIME = 1.5

var is_casting = false
var cast_timer = 0.0
var current_target: Node2D = null
var charge_effect_node: Node2D = null
var game_node: Node2D

func _ready():
	var data = DataManager.get_spell("chain_lightning")
	if data:
		CHAIN_COOLDOWN_MAX = data.cooldown
		CHAIN_RANGE = data.range
		CHAIN_JUMPS = data.jumps
		CHAIN_DMG_DECAY = data.damage_decay
		OVERLOAD_CHANCE = data.proc_chance
		CAST_TIME = data.cast_time

func get_spell_id():
	return "chain_lightning"

# List to track active beams for visual updates and cleanup
var active_beams = []

func _exit_tree():
	stop_all_lightning()

func stop_all_lightning():
	for b in active_beams:
		if b.has("physics_body"):
			PhysicsManager.unregister_object(b.physics_body)
		if is_instance_valid(b.line):
			b.line.queue_free()
	active_beams.clear()

func _process(delta):
	if chain_cooldown > 0 and not is_casting:
		chain_cooldown -= delta
	if chain_cooldown > 0 and is_casting:
		chain_cooldown = 0
		
	_update_visual_beams(delta)

# --- CASTING ---

func cast(casting_elapsed_time: float, _from_above: bool = false):
	if is_casting:
		cast_timer = casting_elapsed_time
		if cast_timer >= CAST_TIME:
			is_casting = false
			cast_timer = 0.0
			
			# FINAL VALIDATION
			var success = CombatManager.request_interaction(get_parent(), current_target, "damage", {"amount": 0, "range": CHAIN_RANGE})
			
			if success:
				fire_chain_lightning(game_node.player.position)
			else:
				# Trigger range-fail interrupt on player
				if get_parent().has_method("_on_cast_interrupted"):
					get_parent()._on_cast_interrupted(18)
					
			if charge_effect_node:
				charge_effect_node.queue_free()
				charge_effect_node = null
	else:
		cast_timer = 0.0
		interrupt_charging()

func try_cast(source: Vector2):
	if chain_cooldown <= 0 and not is_casting:
		# Use Global CombatManager for targeting, exclude player (parent)
		var target = CombatManager.get_nearest_target(source, CHAIN_RANGE, get_parent())
		if target:
			start_charging(source, target)
			return target.position
	return Vector2.ZERO

func start_charging(source: Vector2, target):
	is_casting = true
	cast_timer = 0.0
	current_target = target
	
	charge_effect_node = Node2D.new()
	var charge_circle = Polygon2D.new() 
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * 30.0)
	charge_circle.polygon = points
	charge_circle.color = Color(0.6, 0.9, 1.0, 0.6)
	charge_circle.position = Vector2.ZERO # Centered on player parent
	charge_effect_node.add_child(charge_circle)
	game_node.player.add_child(charge_effect_node)
	
	var tween = create_tween()
	tween.parallel().tween_property(charge_circle, "modulate:a", 1.5, CAST_TIME)
	tween.parallel().tween_property(charge_circle, "scale", Vector2(2.5, 2.5), CAST_TIME)

func interrupt_charging():
	is_casting = false
	current_target = null
	if charge_effect_node:
		charge_effect_node.queue_free()
		charge_effect_node = null
	
	stop_all_lightning()

# --- FIRE LOGIC ---

func fire_chain_lightning(source: Vector2):
	if not game_node or not current_target: return
	chain_cooldown = CHAIN_COOLDOWN_MAX
	_execute_chain(source, current_target, CHAIN_JUMPS, 1.0, true)

func _execute_chain(start: Vector2, target: Node2D, jumps: int, power: float, is_primary: bool):
	if not is_instance_valid(target) or jumps <= 0: return

	# 1. Spawn Physics-Driven Beam
	_spawn_lightning_beam(start, target, power)
	
	# 2. Visual Explosion at Target
	create_lightning_explosion(target.position, power)
	target.modulate = Color(4.0, 4.0, 20.0) # Flash blue
	
	# Overload logic
	if is_primary and randf() < OVERLOAD_CHANCE:
		# Overload Validation
		var success = CombatManager.request_interaction(get_parent(), target, "damage", {"amount": 0, "range": CHAIN_RANGE, "proc": true, "type_of_proc": "overload"})
		if success:
			_spawn_lightning_beam(get_parent().position + Vector2(randf()*20, randf()*20), target, power * 0.5)
		else:
			return


	# 3. Chain next
	await get_tree().create_timer(0.1).timeout
	var next_target = CombatManager.get_nearest_target(target.position, CHAIN_RANGE, target)
	if next_target:
		# Jump VALIDATION
		var success = CombatManager.request_interaction(target, next_target, "damage", {"amount": 0, "range": CHAIN_RANGE * power})
		if success:
			_execute_chain(target.position, next_target, jumps - 1, power * CHAIN_DMG_DECAY, true)
		else:
			return

func _spawn_lightning_beam(from: Vector2, target: Node2D, power: float):
	var line = Line2D.new()
	line.width = 60.0 * power 
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.material = ShaderMaterial.new()
	line.material.shader = load("res://chain_lightning.gdshader")
	
	# Set shader defaults for high energy
	line.material.set_shader_parameter("energy", 8.0)
	line.material.set_shader_parameter("outline_color", Color(0.1, 0.4, 1.5, 1.0))
	
	game_node.add_child(line)

	# PHYSICS INITIALIZATION (Snappy Tension)
	var num_points = 8 # Less points for sharp lightning
	var points = []
	for j in range(num_points):
		points.append(from.lerp(target.position, float(j)/(num_points-1)))

	# Register as high-tension beam
	var body = PhysicsManager.register_soft_body("bolt_" + str(line.get_instance_id()), points, 10.0)
	
	active_beams.append({
		"line": line,
		"target": target,
		"physics_body": body,
		"static_start": from, # Usually the hand or previous enemy
		"timer": 0.4, # Bolts disappear fast
		"power": power
	})

func _update_visual_beams(delta):
	for i in range(active_beams.size() - 1, -1, -1):
		var b = active_beams[i]
		b.timer -= delta
		
		if b.timer <= 0 or not is_instance_valid(b.target):
			PhysicsManager.unregister_object(b.physics_body)
			b.line.queue_free()
			active_beams.remove_at(i)
			continue

		# Snap physics anchors
		b.physics_body.anchors[0] = b.static_start
		b.physics_body.anchors[b.physics_body.points.size()-1] = b.target.position
		
		# Give a slight 'upward' magic gravity for arcing
		b.physics_body.forces = Vector2(0, -800) 

		# Draw with shader-flicker
		b.line.clear_points()
		for p in b.physics_body.points:
			# Random jitter per point for 'electric' feel
			var jitter = Vector2(randf_range(-5,5), randf_range(-5,5)) * b.power
			b.line.add_point(p + jitter)
		
		# Fade out bolt
		b.line.modulate.a = b.timer / 0.4

# --- HELPERS ---

func create_lightning_explosion(pos: Vector2, power: float):
	var sprite = Sprite2D.new()
	sprite.texture = load("res://art/lightning_impact.png")
	sprite.position = pos
	sprite.scale = Vector2(0.1, 0.1) * power
	sprite.modulate = Color(2.0, 4.0, 10.0, 1.0)
	game_node.add_child(sprite)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2) * power, 0.1)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	sprite.rotation = randf() * TAU
	tween.tween_callback(sprite.queue_free)
