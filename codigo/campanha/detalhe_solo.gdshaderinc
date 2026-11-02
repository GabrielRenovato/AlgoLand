// Detalhe procedural do chão dos estágios 1 e 2: quebra a repetição, desfia a borda entre grama e terra
// e espalha pedrinhas e flores em pixels do mundo (1 unidade = 1 pixel de jogo), no mesmo passo da arte.
// Tudo passa por `melhorias`: com 0.0 o chão volta a ser exatamente o anterior.
uniform float melhorias : hint_range(0.0, 1.0) = 1.0;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return ruido(p) * 0.6 + ruido(p * 2.1 + 7.3) * 0.3 + ruido(p * 4.3 + 1.7) * 0.1;
}

// Borda grama/terra irregular: mexe só onde os dois se misturam (nunca em calçada nem água).
vec4 desfiar_borda(vec4 pesos, vec2 mundo) {
	float rg = pesos.r + pesos.g;
	if (melhorias <= 0.0 || rg < 0.001 || pesos.b > 0.5 || pesos.a > 0.2) return pesos;
	float t = pesos.r / rg;
	float irregular = (fbm(mundo / 5.0) - 0.5) * 0.45 + (h21(floor(mundo)) - 0.5) * 0.12;
	float t2 = smoothstep(0.40, 0.60, t + irregular);
	t2 = mix(t, t2, melhorias);
	return vec4(rg * t2, rg * (1.0 - t2), pesos.b, pesos.a);
}

vec3 detalhar_solo(vec3 cor, vec4 pesos, vec2 mundo) {
	if (melhorias <= 0.0) return cor;
	vec2 pixel = floor(mundo);
	float macro = fbm(mundo / 95.0);
	// Manchas largas de tom: o chão deixa de parecer a mesma imagem repetida.
	vec3 variado = cor * (0.92 + 0.16 * macro) + (macro - 0.5) * vec3(0.035, 0.022, -0.018);
	// Mais uma escala, menor, para quebrar o padrão do mosaico.
	variado *= 0.97 + 0.06 * fbm(mundo / 23.0 + 11.0);
	float sorte = h21(pixel);
	float sorte2 = h21(pixel + 19.7);
	// Terra: pedrinhas escuras e claras, e pontos de umidade.
	float na_terra = smoothstep(0.55, 0.95, pesos.g);
	if (sorte < 0.016) variado *= mix(1.0, 0.78, na_terra);
	else if (sorte > 0.9925) variado = mix(variado, vec3(0.80, 0.72, 0.60), 0.55 * na_terra);
	// Grama: tufos mais escuros e pouquíssimas flores claras.
	float na_grama = smoothstep(0.55, 0.95, pesos.r);
	if (sorte2 < 0.02) variado *= mix(1.0, 0.86, na_grama);
	else if (sorte2 > 0.9972) {
		float cor_flor = h21(pixel + 3.3);
		vec3 flor = cor_flor < 0.5 ? vec3(0.95, 0.93, 0.80) : vec3(0.97, 0.82, 0.30);
		variado = mix(variado, flor, 0.9 * na_grama);
	}
	// Terra à beira da grama: levemente mais escura, como solo úmido.
	float beira = pesos.r * pesos.g * 4.0;
	variado *= 1.0 - 0.07 * beira * step(0.5, pesos.g);
	return mix(cor, variado, melhorias);
}
