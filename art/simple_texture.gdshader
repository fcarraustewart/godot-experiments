shader_type canvas_item;

uniform sampler2D main_texture;

void fragment() {
    COLOR = texture(main_texture, UV) * COLOR;
}
