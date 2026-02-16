shader_type canvas_item;

uniform float energy = 1.0;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform vec2 light_dir = vec2(0.3, 0.5);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    // Calculate shadow/highlight based on simple light direction
    vec2 local_uv = UV - 0.5;
    float dot_l = dot(normalize(local_uv), normalize(light_dir));
    
    // Add a rim-light effect on the light_dir side (Highlight)
    float rim = pow(max(0.0, dot_l), 3.0) * 0.4;
    
    // Shadow side (opposite of light_dir)
    float shadow = pow(max(0.0, -dot_l), 2.0) * 0.3;
    
    vec4 final = tex;
    final.rgb += highlight_color.rgb * rim * energy;
    final.rgb *= (1.0 - shadow * 0.5); // Apply shadow
    
    // Add moonlight "rays" tint
    final.rgb = mix(final.rgb, highlight_color.rgb, rim * 0.2);
    
    COLOR = final;
}
