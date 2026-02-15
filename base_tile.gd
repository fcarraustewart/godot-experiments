extends Sprite2D

class_name BaseTile

enum TileType { DEFAULT, SIDE_END, WITH_GRASS }
enum TileState { IDLE, STEPPED_ON }

var type: TileType = TileType.DEFAULT
var state: TileState = TileState.IDLE
var is_flipped: bool = false
var anim_timer: float = 0.0
var frame_count: int = 1

# Textures
const TEX_DEFAULT_STEPPED = preload("res://art/environment/tileset/TileSet-Default-NoGrass-SteppedOn.png")
const TEX_SIDE_STEPPED = preload("res://art/environment/tileset/TileSet-SideEnd-SteppedOn.png")
const TEX_GRASS_IDLE = preload("res://art/environment/tileset/TileSet-WithGrass-Idle.png")
const TEX_GRASS_STEPPED = preload("res://art/environment/tileset/TileSet-WithGrass-SteppedOn.png")

func _ready():
	centered = true
	# Initialize visuals based on type
	match type:
		TileType.DEFAULT:
			texture = TEX_DEFAULT_STEPPED
			hframes = 2
			frame = 0 # SteppedOn frame 1 as default state
			frame_count = 2
		TileType.SIDE_END:
			texture = TEX_SIDE_STEPPED
			hframes = 2
			frame = 0 # SteppedOn frame 1 as default state
			frame_count = 2
			flip_h = is_flipped
		TileType.WITH_GRASS:
			texture = TEX_GRASS_IDLE
			hframes = 5
			frame = 0
			frame_count = 5

func _process(delta):
	# 1. Detection: Check if any entity is on top of this tile
	var was_stepped_on = (state == TileState.STEPPED_ON)
	var currently_stepped_on = false
	
	if PhysicsManager:
		# Tile bounds: 32x32 centered
		var tile_rect = Rect2(global_position - Vector2(16, 16), Vector2(32, 32))
		# Check slightly above the tile for feet
		var detection_rect = Rect2(global_position - Vector2(16, 20), Vector2(32, 10))
		
		for obj in PhysicsManager.simulated_objects:
			if obj is Node2D:
				# Use a simple point check for feet
				# feet_offset in PhysicsManager is 70, but here we just check if position.y is near tile top
				var feet_pos = obj.global_position + Vector2(0, 70) 
				if abs(feet_pos.x - global_position.x) < 16 and abs(feet_pos.y - (global_position.y - 16)) < 5:
					currently_stepped_on = true
					break
	
	# 2. State Transition
	if currently_stepped_on:
		if state != TileState.STEPPED_ON:
			state = TileState.STEPPED_ON
			_update_visuals()
	else:
		if state != TileState.IDLE:
			state = TileState.IDLE
			_update_visuals()
	
	# 3. Animation for Grass
	if type == TileType.WITH_GRASS:
		anim_timer += delta * 12.0 # Animation speed
		frame = int(anim_timer) % frame_count

func _update_visuals():
	match type:
		TileType.DEFAULT:
			frame = 1 if state == TileState.STEPPED_ON else 0
		TileType.SIDE_END:
			frame = 1 if state == TileState.STEPPED_ON else 0
		TileType.WITH_GRASS:
			texture = TEX_GRASS_STEPPED if state == TileState.STEPPED_ON else TEX_GRASS_IDLE
			# Reset timer if needed? User says "run animations 7 frames", usually implies looped
