shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float brilho = max(tex.r, max(tex.g, tex.b));
	vec3 verde = mix(vec3(0.04, 0.18, 0.10), vec3(0.40, 1.0, 0.55), brilho);
	COLOR = vec4(verde, tex.a) * COLOR;
}
