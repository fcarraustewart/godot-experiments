class_name BaseFlockSwarm
extends Node2D

# --- CONFIGURATION ---
@export_group("Flock Settings")
@export var unit_scene: PackedScene
@export var unit_count: int = 10
@export var spawn_radius: float = 100.0

@export_group("Boid Rules")
@export_range(0, 5) var separation_weight: float = 1.5
@export_range(0, 5) var alignment_weight: float = 1.0
@export_range(0, 5) var cohesion_weight: float = 1.0
@export_range(0, 5) var target_attraction_weight: float = 2.0
@export var perception_radius: float = 150.0

@export_group("Dynamics")
@export var frequency: float = 2.0
@export var damping: float = 0.6
@export var response: float = 0.0

# --- STATE ---
var members: Array = []
var target_node: Node2D = null

func _ready():
	global_position = position
	spawn_flock()

func spawn_flock():
	if not unit_scene:
		push_warning("[Flock] No Unit Scene assigned!")
		return
		
	for i in range(unit_count):
		var unit = unit_scene.instantiate()
		var rand_pos = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, spawn_radius)
		unit.position = rand_pos
		add_child(unit)
		members.append(unit)
		
		# Initialize Unit
		if unit.has_method("initialize_flock_unit"):
			unit.initialize_flock_unit(self, i)

func set_target(new_target: Node2D):
	target_node = new_target

func _physics_process(delta):
	# Optimization: We could calculate center of mass here once per frame
	# instead of every unit doing it.
	pass
