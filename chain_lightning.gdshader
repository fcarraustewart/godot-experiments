shader_type canvas_item;

uniform float beams = 2.0; // Number of strands
uniform float energy : hint_range(0.0, 10.0) = 5.0; // Brightness
uniform float roughness : hint_range(0.0, 1.0) = 0.5; // Jitter amount
uniform float frequency = 10.0; // Frequency of the zig-zags
uniform float speed = 1.0; // Animation speed
uniform float thickness : hint_range(0.0, 1.0) = 0.05; // Core thickness
uniform float outline_thickness : hint_range(0.0, 1.0) = 0.1; // Glow region
uniform float beam_difference : hint_range(0.0, 1.0) = 0.0; // Spread between beams
uniform float glow : hint_range(0.0, 3.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.2, 0.2, 1.0, 1.0); // Blueish
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float y_offset : hint_range (-0.5, 0.5) = 0.0;
uniform vec2 fixed_edge_size = vec2(0.05, 0.05);
uniform vec2 noise_scale = vec2(1.0);

float fbm(vec2 uv, float time) {
    float h = 0.0;
    float a = 0.7; // Amplitude
    float f = frequency; // Frequency
    
    for (int i = 0; i < 4; i++) {
        // Simple sin-based pseudo-noise for speed, though texture based is better for quality
        // Using sin here to avoid needing a noise texture input for simplicity
        float n = sin(uv.x * f + time * speed * (float(i)+1.0)) * a; 
        n += cos(uv.x * f * 0.5 - time * speed * 2.0) * a * 0.5;
        h += n;
        
        a *= roughness;
        f *= 2.0;
    }
    return h;
}

// Pseudo-random
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    float time = TIME;
    vec2 uv = UV;
    
    // Distort UV based on noise
    float displacement = fbm(uv, time);
    
    // Taper displacement at ends
    float fade = smoothstep(0.0, fixed_edge_size.x, uv.x) * (1.0 - smoothstep(1.0 - fixed_edge_size.x, 1.0, uv.x));
    
    float dist = abs(uv.y - 0.5 + displacement * fade * 0.5);
    
    // Core beam
    float alpha = 1.0 - smoothstep(thickness, thickness + 0.02, dist);
    
    // Glow
    float glow_alpha = 1.0 - smoothstep(outline_thickness, outline_thickness + 0.1, dist);
    
    vec4 final_color = mix(outline_color, vec4(1.0), alpha); // White core, colored glow
    
    // Dynamic transparency (flicker)
    float flicker = 0.8 + 0.2 * sin(time * 20.0);
    
    COLOR = final_color;
    COLOR.a = glow_alpha * energy * flicker * fade;
    
    // Scroll progress (optional clipping)
    if (uv.x > progress) {
        COLOR.a = 0.0;
    }
}
