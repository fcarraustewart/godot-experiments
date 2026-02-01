extends Node

# PhysicsManager Singleton (Autoload)
# Purpose: Simulates custom forces, Verlet integrations, and movement logic.
# Separates the 'Mathematical Truth' of the world from the 'Visual Representation'.

var gravity_player = Vector2(0, 800) # Increased for snappy platforming
var gravity_chains = Vector2(0, 20) # Increased for snappy platforming
var simulated_objects = []
var floor_y = 450.0 # Default, will be updated by game_node

# --- REGISTRATION ---

func register_character(char_node: Node2D):
	if char_node not in simulated_objects:
		simulated_objects.append(char_node)

func unregister_character(char_node: Node2D):
	simulated_objects.erase(char_node)

func register_soft_body(id: String, points: Array, constraint_dist: float):
	var body = {
		"id": id,
		"type": "SOFT_BODY",
		"points": points,
		"prev_points": points.duplicate(),
		"constraint_dist": constraint_dist,
		"forces": Vector2.ZERO,
		"anchors": {} # Dictionary of point_index: target_position
	}
	simulated_objects.append(body)
	return body

# --- SIMULATION LOOP ---

func _physics_process(delta):
	for body in simulated_objects:
		if body is Node2D:
			_simulate_character_physics(body, delta)
		elif body is Dictionary:
			match body.type:
				"SOFT_BODY":
					_simulate_soft_body(body, delta)
				"SECOND_ORDER":
					_simulate_second_order(body, delta)

func register_second_order(id: String, initial_pos: Vector2, f: float, zeta: float, r: float):
	var k1 = zeta / (PI * f)
	var k2 = 1.0 / (pow(2.0 * PI * f, 2))
	var k3 = r * zeta / (2.0 * PI * f)
	
	var sim = {
		"id": id,
		"type": "SECOND_ORDER",
		"xp": initial_pos,    # Current state position
		"xd": Vector2.ZERO,   # Current state velocity
		"y": initial_pos,     # Target position
		"y_prev": initial_pos,# Previous target (for velocity estimation)
		"k1": k1, "k2": k2, "k3": k3,
		"target_node": null   # Optional node to follow automatically
	}
	simulated_objects.append(sim)
	return sim

func _simulate_second_order(sim, delta):
	# Calculate target velocity
	var target_pos = sim.y
	if is_instance_valid(sim.target_node):
		target_pos = sim.target_node.position
		
	var y_dot = (target_pos - sim.y_prev) / delta
	sim.y_prev = target_pos
	
	# Integration (Semi-Implicit Euler for stability)
	# Using the constants k1, k2, k3 derived from f, zeta, r
	var iterations = 4 # Sub-stepping for high-frequency stability
	var step = delta / iterations
	
	for i in range(iterations):
		sim.xp = sim.xp + step * sim.xd
		sim.xd = sim.xd + step * (target_pos + sim.k3 * y_dot - sim.xp - sim.k1 * sim.xd) / sim.k2

func _simulate_character_physics(char_node, delta):
	if not char_node.has_method("apply_physics"):
		return
		
	var gravity = gravity_player
	var feet_offset = 70.0 # Standard half-height of the player hurtbox
	
	# Current State
	var velocity = char_node.get("velocity") if "velocity" in char_node else Vector2.ZERO
	
	# 1. Floor Detection (Check if feet hit floor)
	var on_floor = char_node.position.y + feet_offset >= floor_y
	
	if on_floor:
		if velocity.y > 0:
			velocity.y = 0
		char_node.position.y = floor_y - feet_offset # Snap feet to top of floor
	else:
		# 2. Apply Gravity if in the air
		velocity += gravity * delta
	
	# 3. Integration (Move the node)
	char_node.position += velocity * delta
	
	# 4. Sync State back to node
	char_node.set("velocity", velocity)
	char_node.set("is_on_floor_physics", on_floor)


func _simulate_soft_body(body, delta):
	var points = body.points
	var prev_points = body.prev_points
	var gravity = gravity_chains
	
	# 1. Integration (Movement per frame)
	for i in range(points.size()):
		if body.anchors.has(i):
			points[i] = body.anchors[i]
			continue
			
		var velocity = (points[i] - prev_points[i]) * 0.95 # Damping
		prev_points[i] = points[i]
		points[i] += velocity + (gravity + body.forces) * delta

	# 2. Constraints (Keeping lengths consistent)
	for _iter in range(12): # Relaxation
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			var diff = p2 - p1
			var d = diff.length()
			if d == 0: continue
			var error = (d - body.constraint_dist) / d
			
			# Logic: Anchored points dont move, they pull others
			var m1 = 0.5 if not body.anchors.has(i) else 0.0
			var m2 = 0.5 if not body.anchors.has(i+1) else 0.0
			
			if m1 + m2 > 0:
				points[i] += diff * error * (m1 / (m1 + m2))
				points[i+1] -= diff * error * (m2 / (m1 + m2))

# --- UTILS ---

func apply_force(id: String, force: Vector2):
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			if body.get("type") == "SOFT_BODY":
				body.forces += force

func get_body_data(id: String) -> Array:
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			return body.points
	return []

func unregister_soft_body(id: String):
	for i in range(simulated_objects.size() - 1, -1, -1):
		var body = simulated_objects[i]
		if body is Dictionary and body.get("id") == id:
			simulated_objects.remove_at(i)

func unregister_object(body):
	simulated_objects.erase(body)

func get_second_order_pos(id: String) -> Vector2:
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			return body.xp
	return Vector2.ZERO

func set_second_order_target(id: String, new_y: Vector2):
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			body.y = new_y

func update_dynamics_for_sim(sim_dict: Dictionary, f: float, zeta: float, r: float):
	sim_dict.k1 = zeta / (PI * f)
	sim_dict.k2 = 1.0 / (pow(2.0 * PI * f, 2))
	sim_dict.k3 = r * zeta / (2.0 * PI * f)
