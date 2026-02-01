extends Node

# with_physics_manager_fire_chains_controller.gd
# Specialized version that uses PhysicsManager for simulation logic.
# All math (Verlet, constraints, convergence) is delegated.

# --- SETTINGS ---
var COOLDOWN_MAX = 0.50
var cooldown = 0.0
var RANGE = 400.0
var DURATION = 0.8
var CAST_TIME = 0.0

var game_node: Node2D
var is_casting = false
var cast_timer = 0.0
var current_target: Node2D = null
var charge_effect_node: Node2D = null

func _ready():
	var data = DataManager.get_spell("fire_chains")
	if data:
		COOLDOWN_MAX = data.cooldown
		RANGE = data.range
		CAST_TIME = data.cast_time

func get_spell_id():
	return "fire_chains"

# List of visual links and their associated physics bodies
var active_visual_chains = []

func _exit_tree():
	# CRITICAL: Clean up physics manager to avoid memory leaks
	stop_all_chains()

func stop_all_chains():
	for c in active_visual_chains:
		if c.has("physics_body"):
			PhysicsManager.unregister_object(c.physics_body)
		if is_instance_valid(c.line):
			c.line.queue_free()
	active_visual_chains.clear()

func _process(delta):
	# 1. Cooldown logic
	if cooldown > 0 and not is_casting:
		cooldown -= delta
	if cooldown > 0 and is_casting:
		cooldown = 0
		
	# 2. Update Visuals based on PhysicsManager data
	_update_visual_representation(delta)

func try_cast(start_pos: Vector2):
	if cooldown <= 0 and not is_casting:
		# Use Global CombatManager for targeting, exclude player (parent)
		var target = CombatManager.get_nearest_target(start_pos, RANGE, get_parent())
		if target:
			start_charging(target, start_pos)
			return target.global_position
	return Vector2.ZERO

func cast(casting_elapsed_time: float, from_above: bool = false):
	if is_casting:
		cast_timer = casting_elapsed_time
		if charge_effect_node and game_node:
			charge_effect_node.position = game_node.player.position
			
		if cast_timer >= CAST_TIME:
			is_casting = false
			cast_timer = 0.0
			
			# FINAL VALIDATION: Check if target is still in range at end of cast
			var success = CombatManager.request_interaction(get_parent(), current_target, "damage", {"amount": 0, "range": RANGE})
			
			if success:
				fire_fire_chains(from_above)
			else:
				# Notify player script that cast failed due to range
				if get_parent().has_method("_on_cast_interrupted"):
					get_parent()._on_cast_interrupted(18) # 18 is not standard, let's use OTHER or add RANGE_FAIL
			
			if charge_effect_node:
				charge_effect_node.queue_free()
				charge_effect_node = null
	else:
		cast_timer = 0.0
		interrupt_charging()

func start_charging(target, start_pos: Vector2):
	is_casting = true
	cast_timer = 0.0
	current_target = target
	
	# Spiral effect (Visual only)
	var ring = Line2D.new()
	ring.width = 250.0
	ring.default_color = Color(1.6, 0.4, 0.0, 0.5)
	var points = PackedVector2Array()
	for i in range(4):
		var angle = i * TAU / 32.0
		points.append((target.global_position - start_pos).normalized() + Vector2(cos(angle), sin(angle)) * 50.0)
	ring.points = points
	game_node.player.add_child(ring)
	
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2.ZERO, 1.5)
	tween.tween_callback(ring.queue_free)

func fire_fire_chains(from_above: bool):
	if not game_node or not current_target: return
	cooldown = COOLDOWN_MAX
	
	# Spawn the 5 chains with different initial paths
	var offsets = [0.0, 30.0, 20.0, 100.0, 40.0]
	for offset in offsets:
		_spawn_physics_chain(game_node.player.position, current_target, offset, from_above)

	create_encircle_effect(current_target)

func _spawn_physics_chain(start_pos: Vector2, target: Node2D, spread: float, from_above: bool):
	# 1. VISUAL SETUP
	var line = Line2D.new()
	line.width = 40.0 
	line.texture = load("res://art/fire_chain.png")
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.modulate = Color(0.1, 0.01, 0.01, 1.0)
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://fire_chain.gdshader")
	mat.set_shader_parameter("tiling", 16.0)
	line.material = mat
	game_node.add_child(line)

	# 2. PHYSICS INITIALIZATION
	var num_points = 60 # Increased resolution for user's requested segments
	var points = []
	var start_anchor = start_pos + Vector2(0, -30)
	
	# Landing logic
	var landing_offset = 50 * Vector2(randf_range(-0.2, 0.2), (1 if from_above else -1) * randf_range(-5.1, -20.0))
	var initial_target_pos = target.position + landing_offset
	
	for j in range(num_points):
		points.append(start_anchor)

	# Register with the separate Manager
	var body = PhysicsManager.register_soft_body("fire_chain_" + str(line.get_instance_id()), points, 5.0)
	
	# Apply the initial "Whip Blast"
	var burst_dir = (initial_target_pos - start_anchor).normalized()
	for j in range(num_points):
		var t_fac = float(j) / (num_points - 1)
		var kick = burst_dir * (100.0 + t_fac * 1200.0)
		body.prev_points[j] = points[j] - kick * 0.016

	# Store the data required for visual updates
	active_visual_chains.append({
		"line": line,
		"target": target,
		"physics_body": body,
		"landing_offset": landing_offset,
		"timer": DURATION,
		"max_spread": spread # Determining the arc height
	})

func _update_visual_representation(delta):
	for i in range(active_visual_chains.size() - 1, -1, -1):
		var c = active_visual_chains[i]
		var body = c.physics_body
		c.timer -= delta
		
		if c.timer <= 0 or not is_instance_valid(c.target):
			PhysicsManager.unregister_object(body)
			c.line.queue_free()
			active_visual_chains.remove_at(i)
			continue

		# 1. Update Anchors in PhysicsManager
		var converge_speed = 6.90
		c.landing_offset = c.landing_offset.lerp(Vector2.ZERO, delta * converge_speed)
		
		var player_hand = game_node.player.position + Vector2(0, -30)
		var target_anchor = c.target.position + c.landing_offset
		
		body.anchors[0] = player_hand
		body.anchors[body.points.size() - 1] = target_anchor
		
		# --- WAVE CALCULATIONS ---
		var chain_dir = (target_anchor - player_hand).normalized()
		var perp = Vector2(-chain_dir.y, chain_dir.x)
		var mid_point = (player_hand + target_anchor) / 2.0
		var control_point = mid_point + (perp * c.max_spread)
		var link = mid_point

		# 2. Map Physics Points to Line2D Points with Cardioid and Chaos
		c.line.clear_points()
		for j in range(body.points.size()):
			var t = float(j) / (body.points.size() - 1)
			var p = body.points[j]
			
			# --- USER CARDIOID LOGIC ---
			# Iteratively shift the 'link' point per frame to maintain the shape
			link = (link + target_anchor + perp * (1.0 / (t + 1.0)) * 150.0 * randf()) / 2.0
			var c_p = link + (perp * c.max_spread)
			
			# Calculate displacement: how much the cardioid bends vs a straight line
			var straight_p = player_hand.lerp(target_anchor, t)
			var cardioid_ideal = player_hand.lerp(c_p, t).lerp(c_p.lerp(target_anchor, t), t)
			var displacement = (cardioid_ideal - straight_p) * (c.landing_offset.length() / 20.0)
			
			# Apply displacement to physical point
			p += displacement
			
			# --- TRAVELLING WAVE ---
			var wave_freq = 0.0002
			var wave_speed = 0.20
			var wave_amp = c.landing_offset.length() * 0.0014
			var phase = (t * wave_freq) - (Time.get_ticks_msec() * 0.001 * wave_speed)
			p += perp * sin(phase) * wave_amp

			# --- USER CHAOS SPIKES ---
			if j > 0 and j < body.points.size() - 1:
				var spike_scale = sin(t * PI) * 5.0
				var jitter = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * spike_scale * randf()
				p += jitter
			
			c.line.add_point(p)

# --- REUSED HELPERS ---

func interrupt_charging():
	is_casting = false
	cast_timer = 0.0
	current_target = null
	if charge_effect_node:
		charge_effect_node.queue_free()
		charge_effect_node = null
	
	# If an interrupt should also kill existing active chains:
	stop_all_chains()

func create_encircle_effect(target):
	var ring = Line2D.new()
	ring.width = 40.0
	ring.default_color = Color(1.0, 0.4, 0.0)
	ring.closed = true
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * 5.0)
	ring.points = points
	target.add_child(ring)
	var tween = create_tween()
	tween.tween_property(ring, "rotation", TAU * 2, 0.5)
	tween.parallel().tween_property(ring, "scale", Vector2(0.1, 0.1), 1.5)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)
