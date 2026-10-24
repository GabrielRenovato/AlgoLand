shader_type canvas_item;
render_mode unshaded;

varying vec2 ponto_mapa;
void vertex() {
	ponto_mapa = VERTEX;
}
void fragment() {
	// A área perigosa já fica inteira delimitada enquanto a marca é formada.
	vec2 p = floor(ponto_mapa) + vec2(0.5);
	float d = length(p);
	float borda = (1.0 - step(1.0, abs(d - 178.0)));
	float setor = step(0.22, fract(atan(p.y, p.x) / TAU * 40.0));
	vec2 celula = mod(p + vec2(6.0), 16.0);
	float grao = (1.0 - step(1.0, celula.x)) * (1.0 - step(2.0, celula.y));
	COLOR = vec4(vec3(0.35, 0.64, 0.40), max(borda * setor * 0.8, 0.045 + grao * 0.18)) * COLOR;
}
