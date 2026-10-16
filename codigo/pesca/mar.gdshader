shader_type canvas_item;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;

uniform float tempo = 0.0;
uniform float costa_base = 300.0;
uniform vec4 curvas_costa = vec4(16.0, 0.011, 8.0, 0.027);
varying vec2 mundo;
varying vec4 tom;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tom = COLOR;
}

vec3 amostra(vec2 origem, vec2 pixel) {
	return texture(atlas, (origem + mod(floor(pixel), 32.0) + 0.5) / vec2(128.0, 96.0)).rgb;
}

void fragment() {
	vec2 p = floor(mundo);
	float costa = costa_base + curvas_costa.x * sin(p.x * curvas_costa.y) + curvas_costa.z * sin(p.x * curvas_costa.w);
	float profundidade = p.y - costa;
	vec3 areia = amostra(vec2(0.0), p);
	areia = mix(areia, vec3(0.91, 0.75, 0.48), 0.18);
	vec3 molhada = amostra(vec2(32.0, 0.0), p);
	// Trilha discreta de areia pisada e pegadas alternadas da entrada até o píer.
	float trilha_x = 336.0 + 8.0 * sin(p.y * 0.02);
	float trilha = (1.0 - smoothstep(14.0, 30.0, abs(p.x - trilha_x))) * step(40.0, p.y) * (1.0 - step(250.0, p.y));
	areia = mix(areia, molhada, trilha * 0.14);
	float passo = floor(p.y / 13.0);
	float pe_x = trilha_x + mix(-4.0, 4.0, mod(passo, 2.0));
	vec2 pe = vec2((p.x - pe_x) / 1.5, (mod(p.y, 13.0) - 6.0) / 2.5);
	float pegada = (1.0 - step(1.0, dot(pe, pe))) * trilha;
	areia *= 1.0 - pegada * 0.14;
	float chegada = sin(tempo * 1.1) * 4.0 + sin(p.x * 0.09 + tempo * 0.65) * 0.8;
	float faixa_molhada = smoothstep(-18.0, 1.0, profundidade);
	areia = mix(areia, molhada, faixa_molhada * 0.48);
	vec2 deslocamento = vec2(sin(p.y * 0.07 + tempo * 0.7) * 1.3, tempo * 2.1 + sin(p.x * 0.04 + tempo * 0.6));
	vec3 rasa = amostra(vec2(64.0, 0.0), p + deslocamento);
	vec3 funda = amostra(vec2(96.0, 0.0), p + deslocamento * 0.7);
	rasa = mix(vec3(0.25, 0.63, 0.62), rasa, 0.23);
	funda = mix(vec3(0.10, 0.34, 0.47), funda, 0.20);
	vec3 agua = mix(rasa, funda, smoothstep(28.0, 170.0, profundidade));
	// Ondulações largas atravessam a textura; brilhos curtos se desfazem em pixels.
	float ondulacao = sin(p.y * 0.10 + sin(p.x * 0.022) * 1.8 + tempo * 1.2);
	agua *= 0.97 + ondulacao * 0.035;
	float brilho = smoothstep(0.91, 1.0, sin(p.y * 0.32 + tempo * 1.9 + sin(p.x * 0.07))) * smoothstep(0.5, 0.95, sin(p.x * 0.19 + tempo * 0.35));
	agua = mix(agua, vec3(0.65, 0.89, 0.85), brilho * 0.24);
	float frente = mod(profundidade + tempo * 7.0 + sin(p.x * 0.038) * 3.0, 57.0);
	float onda = (1.0 - smoothstep(0.6, 2.0, frente)) * smoothstep(8.0, 22.0, profundidade) * (1.0 - smoothstep(65.0, 150.0, profundidade));
	float quebra = 0.65 + 0.35 * sin(p.x * 0.21 + tempo * 0.4);
	agua = mix(agua, vec3(0.87, 0.94, 0.83), onda * quebra * 0.55);
	float nivel = profundidade - chegada;
	vec3 cor = mix(areia, agua, smoothstep(-1.0, 1.0, nivel));
	float espuma = (1.0 - smoothstep(1.0, 3.0, abs(nivel))) * (0.76 + 0.24 * sin(p.x * 0.45));
	cor = mix(cor, vec3(0.94, 0.96, 0.83), espuma * 0.88);
	COLOR = vec4(cor, 1.0) * tom;
}
