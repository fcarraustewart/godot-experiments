extends Node2D

# --- CROW SETTINGS ---
const ORBIT_SPEED = 2.0
const ORBIT_RADIUS = 100.0
const ATTACK_SPEED = 800.0
const RETURN_SPEED = 500.0
const ATTACK_COOLDOWN = 2.0
const DAMAGE = 10.0

# --- STATE ---
enum State { ORBIT, ATTACK_DIVE, RETURN }
var current_state = State.ORBIT
var orbit_angle = 0.0
var target_enemy = null
var attack_timer = 0.0
var host: Node2D # The player to orbit

# --- VISUALS ---
var body_shape: Polygon2D
var trail: Line2D

# --- DYNAMICS PRESETS ---
const DYNAMICS_ORBIT_F = 0.35
const DYNAMICS_ORBIT_Z = 0.5
const DYNAMICS_ORBIT_R = 2.0

const DYNAMICS_ATTACK_F = 4.0
const DYNAMICS_ATTACK_Z = 0.8
const DYNAMICS_ATTACK_R = 0.5

var dynamics_sim = null

func _ready():
	# Create the visual bird shape (A dark sharp triangle/crow silhouette)
	body_shape = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(10, 0),   # Beak/Head
		Vector2(-10, -8), # Wing Left
		Vector2(-5, 0),   # Body Center
		Vector2(-10, 8)   # Wing Right
	])
	body_shape.polygon = points
	body_shape.color = Color(1.1, 0.1, 0.1, 1.0) # Dark Black/Grey
	add_child(body_shape)
	
	# Register with Second Order Dynamics for organic flight
	if PhysicsManager:
		dynamics_sim = PhysicsManager.register_second_order(
			"Crow_" + str(get_instance_id()), 
			global_position, 
			DYNAMICS_ORBIT_F, DYNAMICS_ORBIT_Z, DYNAMICS_ORBIT_R
		)

func _exit_tree():
	if PhysicsManager and dynamics_sim:
		PhysicsManager.unregister_object(dynamics_sim)
	
	# Add a shadow/trail
	trail = Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(1.40, 1.40, 1.40, 0.5)
	trail.hide() # Show only when moving fast
	# Note: Line2D doesn't strictly work as a trail automatically without code, 
	# but for simplicity we'll just toggle visibility or rotation.
	# Actually, let's just use the body rotation to imply speed.

func _process(delta):
	# Cooldown
	if attack_timer > 0:
		attack_timer -= delta
		
	match current_state:
		State.ORBIT:
			process_orbit(delta)
			# Look for targets
			if attack_timer <= 0:
				var enemy = find_target()
				if enemy:
					start_attack(enemy)
					
		State.ATTACK_DIVE:
			if not is_instance_valid(target_enemy):
				current_state = State.RETURN
				return
				
			# Update Dynamics for Hit Logic
			if dynamics_sim:
				dynamics_sim.y = target_enemy.global_position
				global_position = dynamics_sim.xp
				look_at(target_enemy.global_position)
				
				# Hit check
				if global_position.distance_to(target_enemy.global_position) < 40.0:
					hit_enemy(target_enemy)
					current_state = State.RETURN
					# "Bounce" back on hit
					dynamics_sim.xd = -dynamics_sim.xd * 0.5 
			else:
				# Fallback
				var dir = (target_enemy.global_position - global_position).normalized()
				global_position += dir * ATTACK_SPEED * delta
				look_at(target_enemy.global_position)
				if global_position.distance_to(target_enemy.global_position) < 20.0:
					hit_enemy(target_enemy)
					current_state = State.RETURN
				
		State.RETURN:
			if not is_instance_valid(host): return
			
			# Target orbit position (simplified: just host center)
			var dest = host.position + Vector2(0, -50) 
			var dir = (dest - global_position).normalized()
			var dist = global_position.distance_to(dest)
			
			global_position += dir * RETURN_SPEED * delta
			look_at(dest)
			
			if dist < 20.0:
				current_state = State.ORBIT
				attack_timer = ATTACK_COOLDOWN + randf() # Random delay
				# Sync sim position on return to avoid "teleporting"
				if dynamics_sim: 
					# Revert to gentle orbit dynamics
					PhysicsManager.update_dynamics_for_sim(dynamics_sim, DYNAMICS_ORBIT_F, DYNAMICS_ORBIT_Z, DYNAMICS_ORBIT_R)
					dynamics_sim.xp = global_position
					dynamics_sim.y = global_position
					dynamics_sim.xd = Vector2.ZERO

func process_orbit(delta):
	if not is_instance_valid(host): return
	
	orbit_angle += ORBIT_SPEED * delta
	# Elliptical orbit simulating the "First Circle" modulation
	var x_off = cos(orbit_angle) * ORBIT_RADIUS
	var y_off = sin(orbit_angle) * (ORBIT_RADIUS * 0.5) + sin(orbit_angle * 2.0) * 20.0 # Bobbing
	
	var desired_pos = host.position + Vector2(x_off, y_off - 60) # Fly above head
	
	# Update Second Order Simulation for organic weight
	if dynamics_sim:
		dynamics_sim.y = desired_pos # Update target
		global_position = dynamics_sim.xp # Apply simulated position
		
		# Rotate based on velocity for "leaning" effect
		var vel = dynamics_sim.xd
		if vel.length() > 50:
			rotation = lerp_angle(rotation, vel.angle(), 10.0 * delta)
		else:
			rotation = lerp_angle(rotation, 0.0, 5.0 * delta)
	else:
		# Fallback to simple lerp
		global_position = global_position.lerp(desired_pos, 5.0 * delta)
		rotation = lerp_angle(rotation, 0.0, 5.0 * delta)
	
	# Face direction of movement (tangent)
	# rotation = orbit_angle + PI/2

func find_target():
	if not CombatManager or not is_instance_valid(host): return null
	
	# 1. PRIORITY: If player is attacking something, help!
	if host.current_state == host.State.ATTACKING:
		# Use the player's sword hitbox (now in global space) to find what they are hitting
		var targets = CombatManager.find_targets_in_hitbox(host.get_sword_hitbox(), host)
		for t in targets:
			if is_instance_valid(t) and t.has_method("is_enemy") and t.is_enemy():
				print("[CrowPet] Target Found: Assisting player attack on ", t.name)
				return t
			
	# 2. SECONDARY: Nearest enemy in AGGRO range (600px)
	var nearest = CombatManager.get_nearest_target(host.global_position, 600.0, host)
	if nearest:
		print("[CrowPet] Target Found: Aggroing nearest enemy ", nearest.name)
	return nearest

func start_attack(enemy):
	target_enemy = enemy
	current_state = State.ATTACK_DIVE
	PhysicsManager.update_dynamics_for_sim(dynamics_sim,DYNAMICS_ATTACK_F, DYNAMICS_ATTACK_Z, DYNAMICS_ATTACK_R)
	# Shriek sound or visual cue here
	
func hit_enemy(enemy):
	enemy.modulate = Color(3.0, 0.5, 0.5) # Dark Red Flash
	print("Crow struck enemy!")

func assign_host(player_node: Node2D):
	host = player_node