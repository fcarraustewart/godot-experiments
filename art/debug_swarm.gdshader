shader_type canvas_item;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    
    // Outer ring for high visibility
    float outer_ring = smoothstep(1.0, 0.9, dist) * smoothstep(0.7, 0.8, dist);
    
    // Inner thin ring
    float inner_ring = smoothstep(0.4, 0.35, dist) * smoothstep(0.2, 0.25, dist);
    
    // Direction line pointing right (transformed by instance rotation)
    float line = 0.0;
    if (abs(uv.y) < 0.05 && uv.x > 0.0) {
        line = smoothstep(1.0, 0.8, dist);
    }
    
    float alpha = max(outer_ring * 0.8, max(inner_ring * 0.5, line));
    if (alpha < 0.1) discard;
    
    // CYAN debug color
    COLOR = vec4(0.0, 1.0, 1.0, alpha) * COLOR;
}
