extends BasePetEntity

# --- CROW SETTINGS ---
const ORBIT_SPEED = 2.0
const ORBIT_RADIUS = 50.0
const ATTACK_SPEED = 800.0
const RETURN_SPEED = 500.0
const DAMAGE = 10.0

# --- DYNAMICS PRESETS ---
const DYNAMICS_ORBIT_F = 0.35
const DYNAMICS_ORBIT_Z = 0.5
const DYNAMICS_ORBIT_R = 2.0

const DYNAMICS_ATTACK_F = 4.0
const DYNAMICS_ATTACK_Z = 0.8
const DYNAMICS_ATTACK_R = 0.5

# Visuals
var body_shape: Polygon2D
var trail: Line2D
var orbit_angle = 0.0

func _ready():
	# Create visuals
	body_shape = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(5, 0),   # Beak/Head
		Vector2(-5, -4), # Wing Left
		Vector2(-2.5, 0),   # Body Center
		Vector2(-5, 4)   # Wing Right
	])
	body_shape.polygon = points
	body_shape.color = Color(0.4, 0.4, 0.4, 1.0)
	add_child(body_shape)
	
	# Add shadow/trail
	trail = Line2D.new()
	trail.width = 0.4
	trail.default_color = Color(1.40, 1.40, 1.40, 0.2)
	trail.points = PackedVector2Array([Vector2(-2.5, 0), Vector2(-5, 0), Vector2(-10, 0)])
	add_child(trail)

	# trail.hide() 
	
	# Initialize dynamics via base setup
	super._ready()

func _setup_dynamics():
	if PhysicsManager:
		dynamics_sim = PhysicsManager.register_second_order(
			"Crow_" + str(get_instance_id()), 
			global_position, 
			DYNAMICS_ORBIT_F, DYNAMICS_ORBIT_Z, DYNAMICS_ORBIT_R
		)

func _process(delta):
	super._process(delta)
	
	match current_pet_state:
		PetState.ORBIT:
			process_orbit(delta)
			if attack_timer <= 0:
				var target = find_target()
				if target:
					start_attack(target)
					
		PetState.ATTACK:
			process_attack_dive(delta)
				
		PetState.RETURN:
			process_return(delta)

func process_orbit(delta):
	if not is_instance_valid(host): return
	
	orbit_angle += ORBIT_SPEED * delta
	var x_off = cos(orbit_angle) * ORBIT_RADIUS
	var y_off = sin(orbit_angle) * (ORBIT_RADIUS * 0.5) + sin(orbit_angle * 2.0) * 20.0 # Bobbing
	
	var desired_pos = host.global_position + Vector2(x_off, y_off - 60)
	
	if dynamics_sim:
		PhysicsManager.set_second_order_target(dynamics_sim.id, desired_pos)
		global_position = PhysicsManager.get_second_order_pos(dynamics_sim.id)
		
		# Rotate based on velocity
		var vel = PhysicsManager.get_second_order_velocity(dynamics_sim.id)
		if vel.length() > 50:
			rotation = lerp_angle(rotation, vel.angle(), 10.0 * delta)
		else:
			rotation = lerp_angle(rotation, 0.0, 5.0 * delta)

func process_attack_dive(delta):
	if not is_instance_valid(target_entity):
		current_pet_state = PetState.RETURN
		return
		
	if dynamics_sim:
		PhysicsManager.set_second_order_target(dynamics_sim.id, target_entity.global_position)
		global_position = PhysicsManager.get_second_order_pos(dynamics_sim.id)
		look_at(target_entity.global_position)
		
		if global_position.distance_to(target_entity.global_position) < 40.0:
			hit_target(target_entity)
			current_pet_state = PetState.RETURN
			# No easy way to set velocity directly in C++ yet, so we skip the bounce for now or add a setter
			# dynamics_sim.xd = -dynamics_sim.xd * 0.5 # Bounce
	else:
		# Fallback
		var dir = (target_entity.global_position - global_position).normalized()
		global_position += dir * ATTACK_SPEED * delta
		look_at(target_entity.global_position)
		if global_position.distance_to(target_entity.global_position) < 20.0:
			hit_target(target_entity)
			current_pet_state = PetState.RETURN

func process_return(delta):
	# Return to a point near the host before resuming orbit
	if not is_instance_valid(host): return
	
	var return_pos = host.global_position + Vector2(0, -60)
	
	if dynamics_sim:
		PhysicsManager.set_second_order_target(dynamics_sim.id, return_pos)
		global_position = PhysicsManager.get_second_order_pos(dynamics_sim.id)
		
		# Rotate based on velocity
		var vel = PhysicsManager.get_second_order_velocity(dynamics_sim.id)
		if vel.length() > 50:
			rotation = lerp_angle(rotation, vel.angle(), 10.0 * delta)
		
		if global_position.distance_to(return_pos) < 50.0:
			current_pet_state = PetState.ORBIT
			attack_timer = attack_cooldown + randf()
		return

	# Fallback (Legacy movement)
	var dir = (return_pos - global_position).normalized()
	var dist = global_position.distance_to(return_pos)
	
	global_position += dir * RETURN_SPEED * delta
	look_at(return_pos)
	
	if dist < 20.0:
		current_pet_state = PetState.ORBIT
		attack_timer = attack_cooldown + randf()
		if dynamics_sim: 
			PhysicsManager.update_dynamics_for_sim(dynamics_sim, DYNAMICS_ORBIT_F, DYNAMICS_ORBIT_Z, DYNAMICS_ORBIT_R)
			dynamics_sim.xp = global_position
			dynamics_sim.y = global_position
			dynamics_sim.xd = Vector2.ZERO

func start_attack(target: Node2D):
	super.start_attack(target)
	if dynamics_sim:
		PhysicsManager.update_dynamics_for_sim(dynamics_sim, DYNAMICS_ATTACK_F, DYNAMICS_ATTACK_Z, DYNAMICS_ATTACK_R)

func hit_target(target: Node2D):
	if target.has_method("apply_hit"):
		target.apply_hit(DAMAGE, self)
	print("Crow struck target!")
