shader_type canvas_item;
uniform vec2 grade = vec2(96.0);
varying vec4 tom;
void vertex() {
	tom = COLOR;
}
void fragment() {
	vec2 uv_pixel = (floor(UV * grade) + vec2(0.5)) / grade;
	COLOR = texture(TEXTURE, uv_pixel) * tom;
}
