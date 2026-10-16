shader_type canvas_item;
varying vec4 tom;

void vertex() {
	tom = COLOR;
}

// Acabamento claro de madeira exposta ao sol, preservando os pixels do atlas Mana Seed.
void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	cor.rgb = clamp(cor.rgb * vec3(1.30, 1.20, 1.12) + vec3(0.13, 0.10, 0.065), vec3(0.0), vec3(1.0));
	COLOR = cor * tom;
}
