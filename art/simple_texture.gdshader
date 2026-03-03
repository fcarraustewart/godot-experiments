shader_type canvas_item;

uniform sampler2D main_texture;

void fragment() {
    // Add glow effect by brightening the texture color and applying a radial gradient
    vec2 uv = UV * 2.0 - 1.0; // Center UV around (0,0)
    float dist = length(uv);
    float glow = smoothstep(0.4, 0.1, dist); // Glow intensity based on distance from center
    vec4 tex_color = texture(main_texture, UV);
    tex_color.rgb += glow * 0.5; // Add glow to the texture color
    COLOR = tex_color * COLOR; // Modulate by vertex color
}
