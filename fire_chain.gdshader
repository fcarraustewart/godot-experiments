shader_type canvas_item;

uniform float fire_speed = 3.0;
uniform float flicker_speed = 1.0;
uniform float tiling = 4.0;

void fragment() {
    // Tiling logic: repeat UV.x based on the tiling parameter
    vec2 tiled_uv = vec2(fract(UV.x * tiling), UV.y);
    
    // Sample the pixel art texture using tiled UVs
    vec4 tex = texture(TEXTURE, tiled_uv);
    
    // Discard nearly-black colors or low alpha to prevent "black blocks"
    if (tex.a < 0.1 || length(tex.rgb) < 0.05) {
        discard;
    }
    
    // Simple fire flicker logic
    // float flicker = 0.8 + 0.1 * sin(TIME * flicker_speed);
    
    // Add a bit of "heat" movement to the colors
    // float heat = sin(UV.x * 20.0 - TIME * fire_speed) * 0.5 + 0.5;
    // vec3 heat_tint = mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 0.8, 0.2), heat);
    
    // Apply texture and tint
    COLOR.rgb = tex.rgb /*  * heat_tint * flicker*/;
    COLOR.a = tex.a;
}
