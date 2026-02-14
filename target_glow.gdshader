shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float border_width : hint_range(0.0, 10.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    float size_x = border_width / float(textureSize(TEXTURE, 0).x);
    float size_y = border_width / float(textureSize(TEXTURE, 0).y);
    vec4 sprite_color = texture(TEXTURE, UV);
    
    float alpha = sprite_color.a;
    alpha += texture(TEXTURE, UV + vec2(size_x, 0.0)).a;
    alpha += texture(TEXTURE, UV + vec2(-size_x, 0.0)).a;
    alpha += texture(TEXTURE, UV + vec2(0.0, size_y)).a;
    alpha += texture(TEXTURE, UV + vec2(0.0, -size_y)).a;
    
    vec4 final_color = mix(vec4(0), border_color, clamp(alpha, 0.0, 1.0));
    final_color.rgb *= glow_intensity;
    
    // Pulse effect
    final_color.a *= (sin(TIME * 5.0) * 0.5 + 0.5) * 0.8 + 0.2;
    
    // Only show border outside the sprite or as a glow
    COLOR = mix(final_color, sprite_color, sprite_color.a);
}
