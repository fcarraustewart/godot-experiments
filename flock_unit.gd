class_name FlockUnit
extends Node2D

# This class is now a "bridge" or "marker" for systems that still expect individual nodes,
# like the Chain Lightning or Death Chains which link to specific transforms.
# However, the MOVEMENT is now handled by the NativeSwarmManager if this unit is a member.

var flock_manager: NativeSwarmManager
var id: String
var velocity: Vector2 = Vector2.ZERO

func initialize_flock_unit(manager: NativeSwarmManager, index: int):
	flock_manager = manager
	# We don't register with PhysicsManager anymore; NativeSwarmManager handles its own sim.
	pass

func _physics_process(_delta):
	# If this unit is part of a NativeSwarmManager, it might want to sync its position
	# so that external things (like Line2D chains) can track it.
	# But in a true MultiMesh system, we'd avoid this.
	# For legacy compatibility with DeathChains, we'll let the Manager update these nodes
	# if they exist.
	pass
