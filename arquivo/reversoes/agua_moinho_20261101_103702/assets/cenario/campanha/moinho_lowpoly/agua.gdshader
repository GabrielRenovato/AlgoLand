shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D fundo : hint_screen_texture, filter_linear_mipmap;
uniform float tempo = 0.0;
uniform float fluxo : hint_range(0.0, 2.0) = 1.0;
uniform bool queda = false;
uniform bool inverno = false;
uniform bool sobre_mapa = false;
varying vec3 mundo;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	if (!queda) {
		VERTEX.y += sin(VERTEX.x * 13.0 + tempo * 1.7) * cos(VERTEX.z * 9.0 - tempo * 2.5) * 0.009;
	}
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = mundo.xz;
	float onda = sin(p.x * 13.0 + p.y * 7.0 - tempo * 2.2);
	vec2 desvio = vec2(onda, cos(p.y * 17.0 - tempo * 3.1)) * 0.003;
	vec3 refracao = textureLod(fundo, SCREEN_UV + desvio, 0.0).rgb;
	if (sobre_mapa) {
		refracao = vec3(0.18, 0.48, 0.52);
	}
	vec3 cor_agua = inverno ? vec3(0.10, 0.30, 0.36) : vec3(0.07, 0.32, 0.33);
	float impacto = exp(-dot(p - vec2(-2.78, -0.3), p - vec2(-2.78, -0.3)) * 6.0);
	float espuma = impacto * (0.25 + 0.35 * sin(p.y * 32.0 - tempo * 8.0)) * min(fluxo, 1.5);
	if (queda) {
		float linhas = pow(max(0.0, sin(UV.x * 72.0 + sin(UV.y * 17.0 - tempo * 7.0))), 12.0);
		ALBEDO = mix(refracao, vec3(0.28, 0.65, 0.67), 0.3) + linhas * 0.22;
		ALPHA = (0.46 + linhas * 0.24) * min(fluxo * 2.0, 1.0);
	} else {
		ALBEDO = mix(mix(refracao, cor_agua, 0.40), vec3(0.83, 0.94, 0.90), clamp(espuma, 0.0, 0.8));
		ALPHA = 0.88;
		vec3 normal_mundo = normalize(vec3(-cos(p.x * 13.0 + tempo * 1.7) * 0.12, 1.0, sin(p.y * 17.0 - tempo * 3.1) * 0.1));
		NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);
	}
	ROUGHNESS = 0.14;
	SPECULAR = 0.85;
	METALLIC = 0.0;
}
