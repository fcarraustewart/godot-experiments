extends BasePetEntity

# --- SETTINGS ---
var offset = Vector2(40, -10)

# Dynamics settings for different states
const IDLE_F = 2.0
const IDLE_Z = 0.6
const IDLE_R = 1.2

const ATTACK_F = 5.0
const ATTACK_Z = 0.4
const ATTACK_R = 3.0

var is_procedural_attacking = false
var attack_angle = 0.0

func _ready():
	_create_axe_visuals()
	super._ready()

func _create_axe_visuals():
	# Handle
	var handle = ColorRect.new()
	handle.size = Vector2(60, 4)
	handle.position = Vector2(-50, -2)
	handle.color = Color(0.4, 0.2, 0.1) # Brown Wood
	add_child(handle)
	
	# Axe Head (Double bit)
	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(0, -20), 
		Vector2(15, -15), 
		Vector2(20, 0), 
		Vector2(15, 15), 
		Vector2(0, 20),
		Vector2(5, 0)
	])
	head.position = Vector2(5, 0)
	head.color = Color(0.7, 0.7, 0.8) # Steel Blue/Grey
	add_child(head)
	
	# Sharpened Edge
	var edge = Line2D.new()
	edge.points = PackedVector2Array([Vector2(15, -15), Vector2(20, 0), Vector2(15, 15)])
	edge.width = 2.0
	edge.default_color = Color(0.9, 0.9, 1.0)
	head.add_child(edge)

func _setup_dynamics():
	if PhysicsManager:
		dynamics_sim = PhysicsManager.register_second_order(
			"Weapon_" + str(get_instance_id()),
			global_position,
			IDLE_F, IDLE_Z, IDLE_R
		)

func _process(delta):
	if not is_instance_valid(host): return
	
	var target_pos = host.global_position
	var host_facing_right = host.get("facing_right") if "facing_right" in host else true
	
	# Adjust offset based on facing
	var current_offset = offset
	if not host_facing_right:
		current_offset.x = -offset.x
		scale.x = -1
	else:
		scale.x = 1
		
	# Attack Logic (Visual only for now)
	if is_procedural_attacking:
		attack_angle += 15.0 * delta
		current_offset += Vector2(cos(attack_angle), sin(attack_angle)) * 40.0
		if attack_angle > PI:
			stop_attack()
	
	if dynamics_sim:
		dynamics_sim.y = target_pos + current_offset
		global_position = dynamics_sim.xp
		
		# Organic Rotation based on Velocity/Movement
		var vel = dynamics_sim.xd
		var target_rot = vel.x * 0.001
		if is_procedural_attacking:
			target_rot += attack_angle
			
		rotation = lerp_angle(rotation, target_rot, 10.0 * delta)

func start_attack(target: Node2D = null):
	# Note: target is optional for weapon swing
	is_procedural_attacking = true
	attack_angle = -PI/2
	if PhysicsManager and dynamics_sim:
		PhysicsManager.update_dynamics_for_sim(dynamics_sim, ATTACK_F, ATTACK_Z, ATTACK_R)

func stop_attack():
	is_procedural_attacking = false
	if PhysicsManager and dynamics_sim:
		PhysicsManager.update_dynamics_for_sim(dynamics_sim, IDLE_F, IDLE_Z, IDLE_R)
