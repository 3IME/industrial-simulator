shader_type canvas_item;

uniform float speed = 1.5;
uniform float line_height = 0.02;
uniform vec4 scanline_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);

void fragment() {
    float scanline = sin((UV.y + TIME * speed) * 120.0) * 0.5 + 0.5;
    scanline = step(1.0 - line_height, scanline);
    COLOR = vec4(scanline_color.rgb, scanline * 0.08);
}
