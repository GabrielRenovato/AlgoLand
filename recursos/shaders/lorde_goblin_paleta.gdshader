shader_type canvas_item;
render_mode unshaded;
// Compensa a variação de tingimento entre fontes, preservando luz e textura.
uniform vec3 ganho_couro = vec3(1.0);
uniform vec3 ganho_manto = vec3(1.0);
varying vec4 cor_modulada;
void vertex() {
	cor_modulada = COLOR;
}
void fragment() {
	vec4 amostra = texture(TEXTURE, UV);
	vec3 c = amostra.rgb;
	float couro = smoothstep(1.08, 1.25, c.r / max(c.g, 0.001));
	couro *= 1.0 - smoothstep(0.88, 1.0, c.b / max(c.g, 0.001));
	float manto = smoothstep(1.03, 1.18, c.g / max(c.r, 0.001));
	manto *= smoothstep(0.85, 0.96, c.b / max(c.g, 0.001));
	c *= mix(vec3(1.0), ganho_couro, couro);
	c *= mix(vec3(1.0), ganho_manto, manto);
	COLOR = vec4(c, amostra.a) * cor_modulada;
}
