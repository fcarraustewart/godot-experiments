extends Sprite2D

class_name BaseTile

signal stepped_on_tile(tile)

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
			vframes = 1
			frame = 0 # SteppedOn frame 1 as default state
			frame_count = 2
		TileType.SIDE_END:
			texture = TEX_SIDE_STEPPED
			hframes = 2
			vframes = 1
			frame = 0 # SteppedOn frame 1 as default state
			frame_count = 2
			flip_h = is_flipped
		TileType.WITH_GRASS:
			texture = TEX_GRASS_IDLE
			# TEX_GRASS_IDLE has 5 frames, TEX_GRASS_STEPPED has 7
			hframes = 5
			vframes = 1
			frame = 0
			frame_count = 5
	_align_to_base()

func _process(delta):
	# 1. Detection: Check if any entity is on top of this tile
	var was_stepped_on = (state == TileState.STEPPED_ON)
	var currently_stepped_on = false
	
	if PhysicsManager:
		# Check slightly above the tile for feet
		# Standard detection: center X, top Y
		for obj in PhysicsManager.simulated_objects:
			if obj is Node2D:
				var f_offset = 32.0
				if obj.has_method("get_feet_offset"):
					f_offset = obj.get_feet_offset()
					
				var feet_pos = obj.global_position + Vector2(0, f_offset) 
				if abs(feet_pos.x - global_position.x) < 16 and abs(feet_pos.y - (global_position.y - 16)) < 8:
					currently_stepped_on = true
					break
	
	# 2. State Transition
	if currently_stepped_on:
		if state != TileState.STEPPED_ON:
			state = TileState.STEPPED_ON
			_update_visuals()
			emit_signal("stepped_on_tile", self)
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
			if state == TileState.STEPPED_ON:
				texture = TEX_GRASS_STEPPED
				hframes = 7
				frame_count = 7
			else:
				texture = TEX_GRASS_IDLE
				hframes = 5
				frame_count = 5
			_align_to_base()
			# Reset animation timer on state switch to avoid glitches
			anim_timer = 0.0

func _align_to_base():
	# If the texture is taller than 32px, we offset it upwards so the bottom 32px
	# matches the tile grid. 
	# center of sprite is 0,0. Bottom is H/2. We want bottom at +16.
	if texture:
		var frame_h = texture.get_height() / vframes
		offset.y = 16 - (frame_h / 2.0)
