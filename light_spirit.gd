extends Node2D

class_name LightSpirit

# -- CONFIG --
@export var color: Color = Color(1.0, 0.8, 0.4, 0.6) # Warm cozy orange/yellow
@export var radius: float = 120.0
@export var intensity: float = 1.0
@export var pulse_speed: float = 2.0
@export var pulse_magnitude: float = 0.1 # Variation in scale

# -- STATE --
var sprite: Sprite2D
var base_scale: Vector2
var time: float = 0.0
var target_intensity: float = 1.0

func _ready():
	# Create a radial gradient texture procedurally
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.7, 1.0]
	gradient.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)]
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	
	sprite = Sprite2D.new()
	sprite.texture = tex
	# sprite.material = CanvasItemMaterial.new()
	# sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	
	add_child(sprite)
	
	setup_visuals()
	
	# Default Z index to be below characters but above floor
	z_index = -3

func setup_visuals():
	sprite.modulate = color
	var s = radius / 64.0 # Texture is 128px wide
	base_scale = Vector2(s, s)
	sprite.scale = base_scale
	sprite.modulate.a = color.a * intensity

func _process(delta):
	time += delta
	
	# Pulse effect
	var pulse = 1.0 + sin(time * pulse_speed) * pulse_magnitude
	sprite.scale = base_scale * pulse
	
	# Smoothly interpolate intensity (for transitions)
	intensity = lerp(intensity, target_intensity, delta * 5.0)
	sprite.modulate.a = color.a * intensity

func set_glow(p_intensity: float, p_radius: float = -1.0):
	target_intensity = p_intensity
	if p_radius > 0:
		radius = p_radius
		base_scale = Vector2(radius / 64.0, radius / 64.0)

func burst(p_intensity: float, duration: float = 0.5):
	var prev_target = target_intensity
	target_intensity = p_intensity
	await get_tree().create_timer(duration).timeout
	target_intensity = prev_target
