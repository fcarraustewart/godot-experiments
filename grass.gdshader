shader_type canvas_item;

uniform vec4 dark_color : source_color = vec4(0.02, 0.05, 0.02, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.1, 0.2, 0.1, 1.0);
uniform float wind_speed = 1.0;
uniform float density = 50.0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    
    // Create many thin vertical lines for grass blades
    float noise = rand(vec2(floor(uv.x * 1000.0), 0.0));
    
    // Swaying effect
    float sway = sin(TIME * wind_speed + uv.x * 10.0) * 0.01 * (1.0 - uv.y);
    uv.x += sway;
    
    // Blade mask
    float x_grid = uv.x * density * 10.0;
    float blade = step(0.7, fract(x_grid + noise));
    
    // Blade height variation
    float h_var = rand(vec2(floor(x_grid), 0.0)) * 0.5 + 0.5;
    blade *= step(uv.y, h_var);
    
    // Color gradient
    vec4 grass_col = mix(dark_color, highlight_color, 1.0 - uv.y);
    
    // Pulse glow
    float pulse = sin(TIME * 2.0 + uv.x * 5.0) * 0.5 + 0.5;
    
    // Add some "eerie" purple/blue tint based on noise and pulse
    float eerie_tint = rand(vec2(floor(x_grid), 1.0));
    grass_col.rb += eerie_tint * 0.1 * pulse;
    grass_col.g -= eerie_tint * 0.05; // Less green where there is tint
    
    // Glow at the tips
    float tip_glow = pow(1.0 - uv.y, 4.0) * pulse * 0.2;
    grass_col.rgb += vec3(0.1, 0.0, 0.2) * tip_glow;
    
    COLOR = vec4(grass_col.rgb, blade * grass_col.a);
}

