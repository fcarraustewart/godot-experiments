shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.1, 0.3, 0.5, 0.6);
uniform float ripple_speed = 2.0;
uniform float ripple_strength = 0.02;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Pseudo-random function
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    
    // Wave distortion
    float time = TIME * ripple_speed;
    float wave = sin(uv.x * 20.0 + time) * cos(uv.y * 15.0 + time * 0.5);
    
    vec2 disturb = vec2(wave) * ripple_strength;
    
    // Rain ripple effect
    for (int i = 0; i < 5; i++) {
        float i_f = float(i);
        vec2 r_pos = vec2(rand(vec2(i_f, 123.0)), rand(vec2(456.0, i_f)));
        float r_time = fract(TIME * 0.5 + i_f * 0.2);
        
        float dist = distance(uv, r_pos);
        float ring = step(r_time * 0.5, dist) * step(dist, r_time * 0.5 + 0.02);
        float ripple_mask = ring * (1.0 - r_time);
        
        disturb += (uv - r_pos) * ripple_mask * 0.1;
    }

    // Base color with some "depth" variation
    vec4 final_color = water_color;
    final_color.rgb += wave * 0.05;
    
    // Add specular/glitter
    float spec = pow(max(0.0, wave), 10.0) * 0.3;
    final_color.rgb += spec;
    
    COLOR = final_color;
}

