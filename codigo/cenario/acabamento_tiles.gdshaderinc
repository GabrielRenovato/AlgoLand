// A transformação depende só da cor: pixels iguais nas bordas continuam iguais.
vec4 acabamento_tile(vec4 amostra, float intensidade) {
	float luminancia = dot(amostra.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 cor = mix(vec3(luminancia), amostra.rgb, 1.045);
	cor = clamp((cor - vec3(0.42)) * 1.085 + vec3(0.42), vec3(0.0), vec3(1.0));
	if (luminancia < 0.14) {
		cor = amostra.rgb * 0.88;
	}
	// Neve, reflexos e brilhos permanecem claros.
	if (min(amostra.r, min(amostra.g, amostra.b)) > 0.94) {
		cor = amostra.rgb;
	}
	return vec4(mix(amostra.rgb, cor, intensidade), amostra.a);
}
