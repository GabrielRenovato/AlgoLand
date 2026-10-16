shader_type canvas_item;
void fragment() {
	COLOR = vec4(vec3(0.19, 0.17, 0.12), texture(TEXTURE, UV).a * 0.20);
}
