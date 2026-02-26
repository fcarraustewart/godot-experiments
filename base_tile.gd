extends Sprite2D

class_name BaseTile

signal stepped_on_tile(tile)

enum TileType {DEFAULT, SIDE_END, WITH_GRASS}
enum TileState {IDLE, STEPPED_ON}

var type: TileType = TileType.DEFAULT
var state: TileState = TileState.IDLE
var is_flipped: bool = false
var anim_timer: float = 0.0
var frame_count: int = 1

# Textures
const TEX_DEFAULT_STEPPED = preload("res://art/environment/tileset/TileSet-Default-NoGrass-SteppedOn.png")
const TEX_SIDE_STEPPED = preload("res://art/environment/tileset/TileSet-SideEnd-SteppedOn.png")
const TEX_SIDE_DEFAULT = preload("res://art/environment/tileset/TileSet-SideEnd-NoGrass.png")
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
			texture = TEX_SIDE_DEFAULT if state == TileState.IDLE else TEX_SIDE_STEPPED
			hframes = 1
			vframes = 1
			frame = 0
			frame_count = 1
			flip_h = is_flipped
		TileType.WITH_GRASS:
			texture = TEX_GRASS_IDLE
			hframes = 5
			vframes = 1
			frame = 0
			frame_count = 5
	_align_to_base()
	
	# --- SETUP COLLISION ---
	var static_body = StaticBody2D.new()
	add_child(static_body)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 28)
	col.shape = shape
	static_body.add_child(col)

	# --- SETUP DETECTION AREA (Replacement for _process polling) ---
	var area = Area2D.new()
	area.name = "DetectionArea"
	# Collision logic: only detect entities
	area.collision_mask = 1 # Layer 1 usually entities
	add_child(area)
	
	var area_col = CollisionShape2D.new()
	var area_shape = RectangleShape2D.new()
	area_shape.size = Vector2(28, 12) # detection box at the TOP surface
	area_col.shape = area_shape
	# Position detection box slightly ABOVE the top
	area_col.position = Vector2(0, -18)
	area.add_child(area_col)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

var _stepped_bodies = []

func _on_body_entered(body):
	if body is StaticBody2D: return # Ignore self/other tiles
	if not body in _stepped_bodies:
		_stepped_bodies.append(body)
		_update_step_state()

func _on_body_exited(body):
	if body in _stepped_bodies:
		_stepped_bodies.erase(body)
		_update_step_state()

func _update_step_state():
	var was_stepped_on = (state == TileState.STEPPED_ON)
	var currently_stepped_on = _stepped_bodies.size() > 0
	
	if currently_stepped_on:
		if not was_stepped_on:
			state = TileState.STEPPED_ON
			_update_visuals()
			emit_signal("stepped_on_tile", self )
	else:
		if was_stepped_on:
			state = TileState.IDLE
			_update_visuals()

func _process(delta):
	# 3. Animation for Grass (Keep only the light visual loop)
	if type == TileType.WITH_GRASS:
		anim_timer += delta * 12.0
		frame = int(anim_timer) % frame_count

func _update_visuals():
	match type:
		TileType.DEFAULT:
			frame = 1 if state == TileState.STEPPED_ON else 0
		TileType.SIDE_END:
			# There are two side_end textures: one for idle and one for stepped. We switch the whole texture based on state.
			texture = TEX_SIDE_STEPPED if state == TileState.STEPPED_ON else TEX_SIDE_DEFAULT
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
