extends FlockUnit

# cleave_swarm_unit.gd
# Specialized unit for the player's cleave swarm.

var impact_sprite: Sprite2D

func _ready():
	# We don't call super._ready() because FlockUnit doesn't have one (it uses initialize)
	
	# Add the lightning impact visual
	impact_sprite = Sprite2D.new()
	impact_sprite.texture = load("res://art/lightning_impact.png")
	
	# Assuming it might be a spritesheet (e.g. 4x4), but let's start with a single frame.
	# If it's too big, we scale it down.
	impact_sprite.scale = Vector2(0.1, 0.1) 
	add_child(impact_sprite)
	
	# Optional: Add some glow
	impact_sprite.modulate = Color(1.5, 1.5, 2.0, 1.0) 

func _draw():
	# Overriding _draw to remove the Cyan debug circles from the base FlockUnit
	# If you want to keep them, leave this empty or call super._draw()
	pass

func _physics_process(delta):
	super._physics_process(delta)
	# We let the base class handle movement, but we can animate the sprite here
	if is_instance_valid(impact_sprite):
		# rotate it slowly for effect
		impact_sprite.rotation += 5.0 * delta
