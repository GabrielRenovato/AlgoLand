shader_type canvas_item;

// Variação de um móvel repetido (interior_casa.gd, opção "variante" do layout): recolore só a madeira (marrons e
// alaranjados) e, à parte, os tecidos e pinturas saturados (cobertas, almofadas, estofados). Contorno, metal, vidro e
// pedra (pouca saturação) e os verdes (folhas das plantas) ficam como estão. Os valores vêm dos presets VARIANTES de interior_casa.gd.
uniform float madeira_matiz = 0.0;
uniform float madeira_saturacao = 1.0;
uniform float madeira_brilho = 1.0;
uniform float tecido_matiz = 0.0;

vec3 para_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 para_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	vec3 hsv = para_hsv(cor.rgb);
	bool madeira = hsv.x > 0.02 && hsv.x < 0.15 && hsv.y > 0.22 && hsv.z > 0.12;
	if (madeira) {
		hsv.x = fract(hsv.x + madeira_matiz);
		hsv.y = clamp(hsv.y * madeira_saturacao, 0.0, 1.0);
		hsv.z = clamp(hsv.z * madeira_brilho, 0.0, 1.0);
	} else if (hsv.y > 0.35 && hsv.z > 0.2 && (hsv.x < 0.17 || hsv.x > 0.5)) {
		hsv.x = fract(hsv.x + tecido_matiz);
	}
	COLOR = vec4(para_rgb(hsv), cor.a) * COLOR;
}
