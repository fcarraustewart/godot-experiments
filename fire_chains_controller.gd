extends Node

# --- FIRE CHAINS SETTINGS ---
const COOLDOWN_MAX = 0.50
var cooldown = 0.0
const RANGE = 400.0
const DURATION = 1.0

var game_node: Node2D

# --- CASTING VARIABLES ---
var is_casting = false
var cast_timer = 0.0
const CAST_TIME = 1.0 # 3.5 seconds charge time

var current_target: Sprite2D = null
var charge_effect_node: Node2D = null

func interrupt_charging():
	is_casting = false
	cast_timer = 0.0
	current_target = null
	
	if charge_effect_node:
		charge_effect_node.queue_free()
		charge_effect_node = null

	print("Interrupted Casting Fire ...")

func _process(delta):
	if cooldown > 0 and not is_casting:
		cooldown -= delta
	if cooldown > 0 and is_casting:
		cooldown = 0


func try_cast(start_pos: Vector2):
	if cooldown <= 0 and not is_casting:
		# Find target
		var target = get_nearest_enemy(start_pos)
		if target:
			start_charging(target)
			return target.position
		else:
			print("No targets in range!")
			return Vector2.ZERO
			
func cast(casting_elapsed_time: float, from_above: bool = false):
	# Casting Logic
	if is_casting:
		cast_timer = casting_elapsed_time
		
		# Update Charge Effect position if target moved or player moved (optional, for now on player)
		if charge_effect_node and game_node:
			charge_effect_node.position = game_node.player.position
			
		if cast_timer >= CAST_TIME:
			is_casting = false
			cast_timer = 0.0
			# Fire the skill
			print("Firing Fire Chains!")
			fire_fire_chains(from_above)
			if charge_effect_node:
				charge_effect_node.queue_free()
				charge_effect_node = null
	else:
		cast_timer = 0.0
		interrupt_charging()

func start_charging(target):
	is_casting = true
	cast_timer = 0.0
	current_target = target
	# Visual Charge Effect (Red/Orange gathering energy)
	charge_effect_node = Node2D.new()
	var charge_circle = Line2D.new()
	charge_circle.width = 0
	charge_circle.default_color = Color(1.0, 0.4, 0.0, 0.9)
	charge_circle.add_point(game_node.player.position)
	charge_effect_node.add_child(charge_circle)


	game_node.add_child(charge_effect_node)	
	# Spiral particles or lines
	var ring = Line2D.new()
	ring.width = 20.0
	ring.default_color = Color(1.6, 0.4, 0.0, 0.5)
	ring.closed = false
	
	# Create circle points
	var points = PackedVector2Array()
	var radius = 50.0
	for i in range(4):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
		points.append(Vector2(cos(-angle), sin(angle)) * radius)
	ring.points = points
	
	game_node.player.add_child(ring) # visual moves with enemy
	
	# Spin and squeeze
	var tween = create_tween()
	tween.tween_property(ring, "rotation", TAU * 1.5, 0.1)
	tween.parallel().tween_property(ring, "scale", Vector2(0.1, 0.1), 0.5)
	tween.parallel().tween_property(ring, "modulate:a", 0.2, 0.5)
	tween.tween_callback(ring.queue_free)

func fire_fire_chains(from_above: bool = false):
	if not game_node or not current_target: return
	
	cooldown = COOLDOWN_MAX
	start_fire_chains(game_node.player.position, current_target, from_above)

func get_nearest_enemy(from_pos: Vector2) -> Sprite2D:
	if not game_node or "enemies" not in game_node: return null
	var nearest = null
	var min_dist = RANGE
	for enemy in game_node.enemies:
		var d = from_pos.distance_to(enemy.position)
		if d < min_dist:
			min_dist = d
			nearest = enemy
	return nearest

func start_fire_chains(start_pos: Vector2, target: Sprite2D, from_above: bool = false):
	# Spawn Chains in an Arc
	# Offsets define maximum spread at the center of the path
	create_chain_link(start_pos, target, 0.0, from_above)   # Center
	create_chain_link(start_pos, target, 30.0, from_above)   # Center
	create_chain_link(start_pos, target, 20.0, from_above)   # Center

	create_chain_link(start_pos, target, 10.0, from_above) # Right Arc
	create_chain_link(start_pos, target, 40.0, from_above) # Left Arc
	
	# 2. Spawn Encircle Effect at target (The "Bind")
	create_encircle_effect(target)
	
	# 3. Hit
	target.modulate = Color(0.6, 0.10, 0.10) # Fire Flash
	# await to_signal(get_tree().create_timer(0.1), "timeout")
	await get_tree().create_timer(0.4).timeout
	target.modulate = Color(4.0, 1.0, 0.0) # Reset

func create_chain_link(start_pos: Vector2, target: Node2D, spread_offset: float, from_above: bool = false):
	var line = Line2D.new()
	line.width = 50.0 
	line.texture = load("res://art/fire_chain.png")
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.modulate = Color(0.1, 0.01, 0.01, 1.0) # Fully opaque
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://fire_chain.gdshader")
	mat.set_shader_parameter("tiling", 16.0)
	line.material = mat
	game_node.add_child(line)

	# --- PHYSICS SETUP ---
	var num_points = 26 # More points = more flexibility
	var points = []
	var prev_points = []
	
	# Initial landing point far from target for the whip start
	var landing_zone_offset = 50 * Vector2(randf_range(-0.2, 0.2), (1 if from_above else -1) * randf_range(-5.1, -20.0))
	var initial_target = target.position + landing_zone_offset
	
	# Start all points at player, but head moves MUCH faster
	var burst_direction = (initial_target - start_pos).normalized()
	for j in range(num_points):
		var p = start_pos
		points.append(p)
		
		# Extreme gradient of velocity
		var t = float(j) / (num_points - 1)
		var velocity_kick = burst_direction * (100.0 + t * 1200.0) 
		prev_points.append(p - velocity_kick * 0.016)

	active_chains.append({
		"line": line,
		"target": target,
		"start_node": start_pos,
		"points": points,
		"prev_points": prev_points,
		"landing_offset": landing_zone_offset,
		"timer": 0.5,
		"total_duration": DURATION + 1.5,
		"max_spread": spread_offset

	})

var active_chains = []

func _physics_process(delta):
	for i in range(active_chains.size() - 1, -1, -1):
		var c = active_chains[i]
		c.timer -= delta
		
		if c.timer <= 0 or not is_instance_valid(c.target):
			c.line.queue_free()
			active_chains.remove_at(i)
			continue

		# --- ANIMATION LOGIC ---
		# No fade in, but we handle convergence
		
		# Convergence logic: snap to target much faster
		var converge_speed = 18.90
		c.landing_offset = c.landing_offset.lerp(Vector2.ZERO, delta * converge_speed)
		active_chains[i].landing_offset = c.landing_offset
		
		var current_target_pos = c.target.position + c.landing_offset
		var start_pos = game_node.player.position + Vector2(0, -30)
		
		# Define perpendicular vector for wave modulation
		var chain_dir = (current_target_pos - start_pos).normalized()
		var perp = Vector2(-chain_dir.y, chain_dir.x)

		# --- VERLET INTEGRATION ---
		var gravity = Vector2(0, 20) # Magical weightlessness
		var points = c.points
		var prev_points = c.prev_points
		
		for j in range(points.size()):
			if j == 0: # Lock start to player
				points[j] = start_pos
			elif j == points.size() - 1: # Head (Aggressive Anchor)
				var velocity = (points[j] - prev_points[j]) * 0.94
				prev_points[j] = points[j]
				points[j] += velocity + gravity * delta
				
				# Massive attraction for 'tight' finish
				var pull = (current_target_pos - points[j]) * 120.0
				points[j] += pull * delta
			else:
				var velocity = (points[j] - prev_points[j]) * 0.94
				prev_points[j] = points[j]
				points[j] += velocity + gravity * delta
			
			# --- TRAVELLING WAVE MODULATION ---
			# Only apply modulation to non-locked interior points
			if j > 0 and j < points.size() - 1:
				var t_norm = float(j) / (points.size() - 1)
				var wave_freq = 0.0002
				var wave_speed = 0.20
				# Amplitude scales with landing offset (convergance)
				var wave_amp = c.landing_offset.length() * 0.014
				
				# Calculate wave phase based on position along chain and time
				var phase = (t_norm * wave_freq) - (Time.get_ticks_msec() * 0.001 * wave_speed)
				var wave_offset = sin(phase) * wave_amp
				
				# Apply wave perpendicular to the chain direction
				points[j] += perp * wave_offset * delta * 60.0

		# --- CONSTRAINTS (Length maintenance) ---
		var constraint_dist = 5.0 
		for iteration in range(12): # More iterations = straighter lines
			for j in range(points.size() - 1):
				var p1 = points[j]
				var p2 = points[j+1]
				var diff = p2 - p1
				var d = diff.length()
				if d == 0: continue
				var error = (d - constraint_dist) / d
				
				if j == 0: # Start is locked
					points[j+1] -= diff * error
				elif j+1 == points.size() - 1: # Heavy Anchor point (it pulls others more than they pull it)
					points[j] += diff * error * 0.8
					points[j+1] -= diff * error * 0.2
				else:
					points[j] += diff * error * 0.5
					points[j+1] -= diff * error * 0.5

		# --- RENDER LINE ---
		c.line.clear_points()
		for j in range(points.size()):
			# Add a little noise/chaos for the fire effect
			var p = points[j]
			if j > 0 and j < points.size() - 1:
				p += Vector2(randf_range(-2, 2), randf_range(-2, 2))
			c.line.add_point(p)

func create_encircle_effect(target):
	# Spiral particles or lines
	var ring = Line2D.new()
	ring.width = 40.0
	ring.default_color = Color(1.0, 0.4, 0.0)
	ring.closed = true
	
	# Create circle points
	var points = PackedVector2Array()
	var radius = 5.0
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	
	target.add_child(ring) # visual moves with enemy
	
	# Spin and squeeze
	var tween = create_tween()
	tween.tween_property(ring, "rotation", TAU * 2, 0.5)
	tween.parallel().tween_property(ring, "scale", Vector2(0.1, 0.1), 1.5)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)
