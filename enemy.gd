extends BaseEntity

# --- ENEMY CONFIG ---
const WANDER_SPEED = 150.0
const AGGRO_RANGE = 500.0

var sprite: Sprite2D
var wander_timer: float = 0.0
var wander_direction: float = 1.0

func _ready():
	super._ready()

	add_to_group("Enemy")
	feet_offset = 96.0 # Scaled to 192px height
	
	# Create sprite if not already present
	sprite = Sprite2D.new()
	sprite.texture = load("res://art/SpectrumWithSword.png")
	sprite.hframes = 3
	add_child(sprite)

	# --- COLLISION ---
	var col = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 32.0
	shape.height = 192.0 # Matches feet_offset 96
	col.shape = shape
	add_child(col)

func is_enemy():
	return true

func _process(delta):
	state_timer -= delta
	
	match current_state:
		State.IDLE, State.RUNNING:
			process_wander(delta)
		State.HURT:
			velocity.x = 0
			if state_timer <= 0:
				change_state(State.IDLE)
				
	# Animation sync (simple)
	# Animation sync (simple) & AUTO-SCALE
	if sprite and sprite.texture:
		var tex_w = sprite.texture.get_width()
		var tex_h = sprite.texture.get_height()
		var frame_w = tex_w / sprite.hframes
		var frame_h = tex_h / sprite.vframes
		
		var h_target = 192.0 # Target height/width
		var s_x = h_target / frame_w
		var s_y = h_target / frame_h
		
		# sprite.flip_h = !facing_right # Removed, using scale instead
		
		if facing_right:
			sprite.scale = Vector2(s_x, s_y)
		else:
			sprite.scale = Vector2(-s_x, s_y) # Flip via scale
			
		# --- APPLY LIGHTING ---
		sprite.modulate = external_lighting_modulate
		# ----------------------

		if velocity.x != 0:
			sprite.frame = (int(Time.get_ticks_msec() / 200.0) % 3)
		else:
			sprite.frame = 0

func process_wander(delta):
	wander_timer -= delta
	if wander_timer <= 0:
		wander_timer = randf_range(1.0, 3.0)
		if randf() > 0.3:
			wander_direction = 1.0 if randf() > 0.5 else -1.0
			change_state(State.RUNNING)
		else:
			wander_direction = 0.0
			change_state(State.IDLE)
	
	velocity.x = wander_direction * WANDER_SPEED
	if wander_direction != 0:
		facing_right = wander_direction > 0

func get_sword_hitbox() -> Rect2:
	# Keep the old hitbox logic if needed, but simplified
	var size = Vector2(33.3, 13.3)
	var offset = Vector2(20, 0)
	if not facing_right: offset.x = -offset.x
	
	var top_left = position + offset - (size / 2.0)
	return Rect2(top_left, size)

func get_active_sprite() -> Sprite2D:
	return sprite
