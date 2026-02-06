extends FlockUnit

# death_swarm_unit.gd
# Specialized flock unit for the death boss swarm.

func _ready():
	# No need to call super._ready() as FlockUnit doesn't have one,
	# initialization happens via initialize_flock_unit()
	pass

func _draw():
	var sprite = Sprite2D.new()
	sprite.texture = load("res://art/death_RH.png")
	add_child(sprite)
	pass