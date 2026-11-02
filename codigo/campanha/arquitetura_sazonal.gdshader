shader_type canvas_item;
uniform int estacao = 0;
uniform bool telhado = false;
uniform float topo_neve = -10000.0;
varying vec2 posicao_mundo;
void vertex() { posicao_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec3 cor = texel.rgb;
	float musgo = smoothstep(0.01, 0.07, cor.g - max(cor.r, cor.b));
	if (estacao == 1) cor = mix(cor, cor * vec3(1.08, 1.00, 0.88), 0.35);
	if (estacao == 2) cor = mix(cor, vec3(cor.g * 1.15, cor.g * 0.75, cor.b * 0.65), musgo * 0.7);
	if (estacao == 3) {
		// Neve nas bordas expostas: máscara derivada do alpha acima do pixel,
		// preservando faces verticais, ferragens e vazios.
		float acima = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a;
		float topo = texel.a * (1.0 - acima);
		cor = mix(cor, vec3(0.86, 0.93, 0.96), max(max(topo, musgo * 0.7), 1.0 - smoothstep(2.0, 5.0, abs(posicao_mundo.y - topo_neve))));
		if (telhado) cor = mix(cor, vec3(0.87, 0.94, 0.97), smoothstep(0.2, 0.4, texel.r - texel.g) * 0.88);
	}
	COLOR = vec4(cor, texel.a);
}
