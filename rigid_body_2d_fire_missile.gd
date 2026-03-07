extends RigidBody2D


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Missile launched!")
	self.connect("body_entered", Callable(self, "_on_body_entered"))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_body_entered(body):
	if body:
		print("Missile hit!")
		# queue_free() # Destroy the target
