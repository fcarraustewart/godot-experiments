class_name FlockDustUnit
extends FlockUnit

func _ready():
	# Visuals from DustPuff (soft cloud shape)
	var cloud = Polygon2D.new()
	var pts = []
	for i in range(8):
		var ang = i * PI / 4.0
		var r = randf_range(2.5, 3.5)
		pts.append(Vector2(cos(ang)*r, sin(ang)*r))
	cloud.polygon = PackedVector2Array(pts)
	cloud.color = Color(0.8, 0.8, 0.7, 0.2) # Slightly more opaque for swarm
	add_child(cloud)

func _draw():
	pass # Override FlockUnit's debug draw to avoid the cyan circle

# Note: We do NOT implement _process or _physics_process here.
# We inherit _physics_process from FlockUnit, allowing it to move using Boids logic.
# The PhysicsManager registration happens in FlockUnit.initialize_flock_unit.
