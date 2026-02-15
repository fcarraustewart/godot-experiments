extends Node

# --- WIND PARAMETERS ---
var wind_strength = 1.0
var wind_frequency = 1.0
var wind_direction = Vector2(1, 0) # Right by default
var wind_variation = 0.5 # Random fluctuation over time

# Internal timer for wind fluctuation
var _time = 0.0
var current_wind_power = 0.0

func _process(delta):
	_time += delta * wind_frequency
	
	# Periodic wind bursts using sine waves and noise-like variation
	var base_wind = sin(_time) * 0.5 + 0.5
	var variation = sin(_time * 2.3) * wind_variation
	
	current_wind_power = (base_wind + variation) * wind_strength
	current_wind_power = clamp(current_wind_power, 0.0, 2.0)

# Helper to get wind influence on a position (e.g. for swaying)
func get_wind_at(pos: Vector2) -> float:
	# Add some spatial variation so not everything sways at the exact same time
	var spatial = sin(_time + pos.x * 0.01) * 0.2
	return current_wind_power + spatial
