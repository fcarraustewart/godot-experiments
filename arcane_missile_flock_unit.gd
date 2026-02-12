extends FlockUnit

# arcane_missile_flock_unit.gd
# Visual representation of an arcane missile: Pink circle with a trail line.

func _draw():
	# Draw pink circle
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.4, 0.8, 1.0)) # Pink
	
	# Draw trailing line (visual only, based on velocity if available, or just behind)
	# Since FlockUnit doesn't always have valid velocity in _draw (it's in physics), 
	# we can use a fixed tail or try to read velocity.
	# For now, a simple trail effect can be simulated or we just draw a line.
	
	# Let's draw a trail fading out
	draw_line(Vector2(-10, 0), Vector2(0, 0), Color(1.0, 0.4, 0.8, 0.5), 3.0)
	
func _process(_delta):
	# Add some rotation to look dynamic if we want, or align to velocity
	pass
