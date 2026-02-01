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
	body_shape.color = Color(0.1, 0.1, 0.1, 1.0) # Dark Black/Grey
	add_child(body_shape)
	
	# Add a shadow/trail
	trail = Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(0.0, 0.0, 0.0, 0.5)
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
				
			var dir = (target_enemy.position - global_position).normalized()
			global_position += dir * ATTACK_SPEED * delta
			look_at(target_enemy.position)
			
			# Hit check
			if global_position.distance_to(target_enemy.position) < 20.0:
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

func process_orbit(delta):
	if not is_instance_valid(host): return
	
	orbit_angle += ORBIT_SPEED * delta
	# Elliptical orbit simulating the "First Circle" modulation
	var x_off = cos(orbit_angle) * ORBIT_RADIUS
	var y_off = sin(orbit_angle) * (ORBIT_RADIUS * 0.5) + sin(orbit_angle * 2.0) * 20.0 # Bobbing
	
	var desired_pos = host.position + Vector2(x_off, y_off - 60) # Fly above head
	
	# Smoothly float there
	global_position = global_position.lerp(desired_pos, 5.0 * delta)
	rotation = lerp_angle(rotation, 0.0, 5.0 * delta) # Level out
	
	# Face direction of movement (tangent)
	# rotation = orbit_angle + PI/2

func find_target():
	# Access global enemies list from parent? 
	# Assuming parent (show_spectrum) has 'enemies' array.
	var main_node = get_parent()
	if "enemies" in main_node:
		var candidates = []
		for e in main_node.enemies:
			if e.position.distance_to(host.position) < 600: # Aggro range
				candidates.append(e)
		
		if candidates.size() > 0:
			return candidates.pick_random()
	return null

func start_attack(enemy):
	target_enemy = enemy
	current_state = State.ATTACK_DIVE
	# Shriek sound or visual cue here
	
func hit_enemy(enemy):
	enemy.modulate = Color(3.0, 0.5, 0.5) # Dark Red Flash
	print("Crow struck enemy!")
