class_name FlockParams
extends Resource

@export_group("Visuals")
@export var unit_count: int = 10
@export var spawn_radius: float = 50.0

@export_group("Boid Rules")
@export_range(-5, 5) var separation_weight: float = 1.5
@export_range(-5, 5) var alignment_weight: float = 1.0
@export_range(-5, 5) var cohesion_weight: float = 1.0
@export_range(-5, 5) var target_attraction_weight: float = 2.0
@export var perception_radius: float = 150.0

@export_group("Dynamics")
@export var frequency: float = 2.0
@export var damping: float = 0.6
@export var response: float = 0.0
