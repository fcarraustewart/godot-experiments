extends Node

# PhysicsManager Singleton (Autoload)
# Purpose: Simulates custom forces, Verlet integrations, and movement logic.
# Separates the 'Mathematical Truth' of the world from the 'Visual Representation'.

var gravity_player = Vector2(0, 800) # Increased for snappy platforming
var gravity_chains = Vector2(0, 20) # Increased for snappy platforming
var simulated_objects = []
var floor_y = 450.0 # Default base floor
var all_platforms = [] # Array of Rect2 representing solid blocks

func clear_platforms():
	all_platforms.clear()

var native_manager = null

func _ready():
	if ClassDB.can_instantiate("NativePhysicsManager"):
		native_manager = ClassDB.instantiate("NativePhysicsManager")
		add_child(native_manager)
		print("[PhysicsManager] Native GDExtension physics enabled!")
	else:
		print("[PhysicsManager] Running in GDScript fallback mode.")

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
					if not native_manager:
						_simulate_second_order(body, delta)


func register_second_order(id: String, initial_pos: Vector2, f: float, zeta: float, r: float):
	if native_manager:
		return native_manager.register_second_order(id, initial_pos, f, zeta, r)
		
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
	
	# 1. Platform & Floor Detection
	var current_floor_y = floor_y
	
	# Only check floor/platforms if we are moving down or stationary at apex
	if velocity.y >= 0:
		# Check Platforms first
		for plat in all_platforms:
			# plat is a Rect2
			if char_node.global_position.x >= plat.position.x and char_node.global_position.x <= plat.position.x + plat.size.x:
				var plat_top = plat.position.y
				# Vertical threshold: must be within 20px of the top to land
				var feet_y = char_node.global_position.y + feet_offset
				if feet_y >= plat_top - 5 and feet_y <= plat_top + 20:
					# Land!
					current_floor_y = plat_top
					break
	
	# Determine if we hit the floor
	# FIXME: this can cause issues if the player is moving up through a platform and then down again in the same frame, but for simplicity we will allow it for now. A more robust solution would involve checking the trajectory of the player within the frame.
	var on_floor = char_node.global_position.y + feet_offset >= current_floor_y - 2.0
	var is_snapped = on_floor and velocity.y >= 0

	if is_snapped:
		velocity.y = 0
		char_node.position.y = current_floor_y - feet_offset
		if char_node.is_in_group("Player"):
			floor_y = current_floor_y # Update global floor for reflections

		if(Engine.get_process_frames() % 60 == 0):
			print("Landed on floor/platform at y =", current_floor_y)
	else:
		# 2. Apply Gravity if strictly in the air or moving upwards
		velocity += gravity * delta

		if(Engine.get_process_frames() % 30 == 0):
			print("Velocity after gravity:", velocity)
	
	# 3. Integration (Move the node)
	char_node.position += velocity * delta
	
	# 4. Sync State back to node
	char_node.set("velocity", velocity)
	char_node.set("is_on_floor_physics", is_snapped)


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
	if native_manager and body is Dictionary and body.get("type") == "SECOND_ORDER":
		native_manager.unregister_object(body)
	else:
		simulated_objects.erase(body)

func get_second_order_pos(id: String) -> Vector2:
	if native_manager:
		return native_manager.get_second_order_pos(id)
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			return body.xp
	return Vector2.ZERO

func get_second_order_velocity(id: String) -> Vector2:
	if native_manager:
		return native_manager.get_second_order_velocity(id)
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			return body.xd
	return Vector2.ZERO

func set_second_order_target(id: String, new_y: Vector2):
	if native_manager:
		native_manager.set_second_order_target(id, new_y)
		return
	for body in simulated_objects:
		if body is Dictionary and body.get("id") == id:
			body.y = new_y

func update_dynamics_for_sim(sim_dict: Dictionary, f: float, zeta: float, r: float):
	if native_manager and sim_dict.get("type") == "SECOND_ORDER":
		native_manager.update_dynamics_for_sim(sim_dict, f, zeta, r)
		return
		
	sim_dict.k1 = zeta / (PI * f)
	sim_dict.k2 = 1.0 / (pow(2.0 * PI * f, 2))
	sim_dict.k3 = r * zeta / (2.0 * PI * f)
