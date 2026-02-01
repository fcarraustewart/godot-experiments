extends Node2D

var host: Node2D
var dynamics_sim = null

# Languid settings: Low frequency, High damping
const F = 0.5
const Z = 1.2
const R = 0.0

func _ready():
	# Create a soft cloud shape
	var cloud = Polygon2D.new()
	var pts = []
	for i in range(8):
		var ang = i * PI / 4.0
		var r = randf_range(5, 15)
		pts.append(Vector2(cos(ang)*r, sin(ang)*r))
	cloud.polygon = PackedVector2Array(pts)
	cloud.color = Color(0.8, 0.8, 0.7, 0.4) # Dust color
	add_child(cloud)
	
	if PhysicsManager:
		dynamics_sim = PhysicsManager.register_second_order(
			"Dust_" + str(get_instance_id()),
			global_position,
			F, Z, R
		)

func _exit_tree():
	if PhysicsManager and dynamics_sim:
		PhysicsManager.unregister_object(dynamics_sim)

func _process(delta):
	if not is_instance_valid(host): return
	
	# Target is the bottom of the host (feet)
	var target = host.global_position + Vector2(0, 70)
	
	if dynamics_sim:
		dynamics_sim.y = target
		global_position = dynamics_sim.xp
		
		# Drift effect: slowly fade if host is not moving much
		var host_vel = host.get("velocity") if "velocity" in host else Vector2.ZERO
		if host_vel.length() < 10:
			modulate.a = lerp(modulate.a, 0.0, 2.0 * delta)
		else:
			modulate.a = lerp(modulate.a, 0.4, 2.0 * delta)
		
		# Scale based on speed
		var s = clamp(host_vel.length() / 500.0, 0.5, 2.0)
		scale = scale.lerp(Vector2(s, s), 2.0 * delta)
