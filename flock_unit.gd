class_name FlockUnit
extends Node2D

var flock_manager: BaseFlockSwarm
var id: String
var velocity: Vector2 = Vector2.ZERO
var dynamics_sim: Dictionary = {}

func initialize_flock_unit(manager: BaseFlockSwarm, index: int):
	flock_manager = manager
	id = "flock_" + str(get_instance_id()) + "_" + str(index)
	
	# Register with Native Physics Manager (Second Order Dynamics)
	# Register with Native Physics Manager (Second Order Dynamics)
	# This gives the unit its "weight" and organic movement
	# IMPORTANT: PhysicsManager works in GLOBAL SPACE.
	dynamics_sim = PhysicsManager.register_second_order(
		id, 
		global_position, 
		flock_manager.frequency, 
		flock_manager.damping, 
		flock_manager.response
	)

func _exit_tree():
	if dynamics_sim:
		PhysicsManager.unregister_object(dynamics_sim)

func _draw():
	# Simple debug visual: A circle with a direction line
	draw_circle(Vector2.ZERO, 5.0, Color.CYAN)
	draw_line(Vector2.ZERO, Vector2(10, 0), Color.WHITE, 2.0)

func _physics_process(delta):
	if not flock_manager: return
	
	queue_redraw()
	if not flock_manager: return
	
	var neighbors = _get_neighbors()
	var swarm_force = _calculate_flock_behaviors(neighbors)
	var target_force = _calculate_target_attraction()
	
	# The flocking algorithm desires a VELOCITY/DIRECTION
	var desired_velocity = (swarm_force + target_force).limit_length(300.0) # Max Speed
	
	if desired_velocity == Vector2.ZERO:
		desired_velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0
	
	# --- INTEGRATION WITH SECOND ORDER DYNAMICS ---
	# Instead of setting velocity directly, we set the 'Target Position' ahead of us.
	# This makes the unit try to reach that point 'organically'.
	var target_pos = global_position + desired_velocity
	
	if dynamics_sim:
		# 1. Update Parameters (in case Manager changed them in Inspector)
		# Optimization: Only do this when they actually change
		# PhysicsManager.update_dynamics_for_sim(dynamics_sim, flock_manager.frequency, flock_manager.damping, flock_manager.response)
		
		# 2. Set Target
		PhysicsManager.set_second_order_target(id, target_pos)
		
		# 3. Apply Result
		global_position = PhysicsManager.get_second_order_pos(id)
		
		# 4. Rotate properly
		var real_velocity = PhysicsManager.get_second_order_velocity(id)
		if real_velocity.length_squared() > 100:
			rotation = lerp_angle(rotation, real_velocity.angle(), 10.0 * delta)

func _get_neighbors() -> Array:
	# Naive O(N) neighbor check.
	# For large flocks (>100), this should be optimized with a Spatial SpatialHash or QuadTree in C++
	var neighbors = []
	for member in flock_manager.members:
		if member == self: continue
		if global_position.distance_to(member.global_position) < flock_manager.perception_radius:
			neighbors.append(member)
	return neighbors

func _calculate_flock_behaviors(neighbors: Array) -> Vector2:
	var separation = Vector2.ZERO
	var alignment = Vector2.ZERO
	var cohesion = Vector2.ZERO
	
	if neighbors.is_empty():
		return Vector2.ZERO
		
	var center_of_mass = Vector2.ZERO
	var avg_velocity = Vector2.ZERO
	
	for n in neighbors:
		# Separation: Move away from nearby neighbors
		var push = global_position - n.global_position
		var dist = push.length()
		if dist > 0:
			separation += (push.normalized() / dist) * 100.0 # Weight by inverse distance
		
		# Accumulate for Cohesion/Alignment
		center_of_mass += n.global_position
		
		# Approximate velocity from their rotation/movement direction?
		# Since we don't have explicit velocity stored on peers easily without casting,
		# we assume their forward vector is their velocity direction.
		avg_velocity += Vector2.RIGHT.rotated(n.rotation) * 100.0 
		
	center_of_mass /= neighbors.size()
	avg_velocity /= neighbors.size()
	
	# Cohesion: Steer towards center of mass
	cohesion = (center_of_mass - global_position)
	
	# Alignment: Steer towards average heading
	alignment = avg_velocity
	
	return (separation * flock_manager.separation_weight) + \
		   (alignment * flock_manager.alignment_weight) + \
		   (cohesion * flock_manager.cohesion_weight)

func _calculate_target_attraction() -> Vector2:
	if is_instance_valid(flock_manager.target_node):
		var to_target = flock_manager.target_node.global_position - global_position
		return to_target * flock_manager.target_attraction_weight
	elif is_instance_valid(flock_manager):
		# Fallback: Stay near the flock manager origin if no target
		var to_home = flock_manager.global_position - global_position
		return to_home * 0.5
	return Vector2.ZERO
