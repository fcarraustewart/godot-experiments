shader_type canvas_item;

uniform vec4 sky_color : source_color = vec4(0.02, 0.02, 0.08, 1.0); // Very dark blue/black
uniform vec4 thunder_color : source_color = vec4(0.8, 0.8, 0.9, 1.0);
uniform float lightning_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rain_speed = 0.20;

// Simple pseudo-random function
float rand(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    // Slant the UVs for rain direction
    uv.x += (rand(floor(uv)) * 0.01);
    
    float time = TIME * rain_speed;
    
    // Grid for rain drops
    // Multiply UV to create many vertical strips
    vec2 rain_uv = uv * vec2(900.0, 90.0); 
    
    // Shift Y based on time
    rain_uv.y -= time * 30.0;
    
    // Random value for this grid cell
    float cell_rand = rand(floor(rain_uv));
    
    // Draw drop if rand > threshold
    float rain_mask = step(0.99, cell_rand);
    
    // Fade trail (optional, keeps it simple pixels for now)
    
    vec4 bg = mix(sky_color, thunder_color, lightning_strength);
    vec4 rain_col = vec4(0.5, 0.6, 0.7, 0.3); // Faint blue-grey rain
    
    COLOR = mix(bg, rain_col, rain_mask * 0.5); // *0.5 for semi-transparent rain
}
