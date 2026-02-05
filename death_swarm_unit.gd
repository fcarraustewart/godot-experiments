extends FlockUnit

# death_swarm_unit.gd
# Specialized flock unit for the death boss swarm.

func _ready():
	# No need to call super._ready() as FlockUnit doesn't have one,
	# initialization happens via initialize_flock_unit()
	pass

func _draw():
	# Override base FlockUnit debug draw
	# We use the Polygon2D added in the controller instead
	pass
