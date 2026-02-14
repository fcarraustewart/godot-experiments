shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.6, 0.0, 1.0);
uniform float border_width : hint_range(0.0, 16.0) = 8.0;
uniform float glow_intensity : hint_range(0.0, 10.0) = 5.0;

void fragment() {
    float size_x = border_width / float(textureSize(TEXTURE, 0).x);
    float size_y = border_width / float(textureSize(TEXTURE, 0).y);
    vec4 sprite_color = texture(TEXTURE, UV);
    
    float alpha = 0.0;
    // Multi-sampled outline for thick borders
    for (float x = -1.0; x <= 1.0; x += 0.5) {
        for (float y = -1.0; y <= 1.0; y += 0.5) {
            if (x == 0.0 && y == 0.0) continue;
            alpha = max(alpha, texture(TEXTURE, UV + vec2(x * size_x, y * size_y)).a);
        }
    }
    
    vec4 final_color = border_color;
    final_color.rgb *= glow_intensity;
    
    // Pulse effect
    float pulse = (sin(TIME * 6.0) * 0.5 + 0.5) * 0.4 + 0.6;
    final_color.a = clamp(alpha - sprite_color.a, 0.0, 1.0) * pulse;
    
    // Smooth transition
    COLOR = mix(final_color, sprite_color, sprite_color.a);
}
