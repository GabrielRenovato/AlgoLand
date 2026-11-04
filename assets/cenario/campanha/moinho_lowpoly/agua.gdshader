shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D fundo : hint_screen_texture, filter_linear_mipmap;
uniform float tempo = 0.0;
uniform float fluxo : hint_range(0.0, 2.0) = 1.0;
uniform bool queda = false;
uniform bool inverno = false;
uniform bool sobre_mapa = false;
varying vec3 mundo;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	if (!queda) {
		VERTEX.y += sin(VERTEX.x * 13.0 + tempo * 1.7) * cos(VERTEX.z * 9.0 - tempo * 2.5) * 0.009;
	}
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float onda = sin(mundo.x * 13.0 + mundo.z * 7.0 - tempo * 2.2);
	vec2 desvio = vec2(onda, cos(mundo.z * 17.0 - tempo * 3.1)) * 0.003;
	vec3 refracao = textureLod(fundo, SCREEN_UV + desvio, 0.0).rgb;
	if (sobre_mapa) {
		refracao = vec3(0.12, 0.37, 0.43);
	}
	vec3 cor_agua = inverno ? vec3(0.10, 0.30, 0.39) : vec3(0.08, 0.39, 0.42);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	if (queda) {
		vec2 uv_movimento = vec2(UV.x * 23.0, UV.y * 9.0 - tempo * (4.0 + fluxo));
		float variacao = ruido(uv_movimento) * 0.65 + ruido(uv_movimento * 2.1) * 0.35;
		float fios = pow(max(0.0, sin(UV.x * 80.0 + variacao * 2.6)), 11.0);
		float borda = smoothstep(0.0, 0.09, UV.x) * smoothstep(0.0, 0.09, 1.0 - UV.x);
		float espuma = smoothstep(0.61, 0.86, variacao) * (0.25 + UV.y * 0.4);
		ALBEDO = mix(mix(refracao, cor_agua, 0.38), vec3(0.72, 0.91, 0.94), clamp(fios * 0.5 + espuma + fresnel * 0.22, 0.0, 0.9));
		EMISSION = vec3(0.03, 0.12, 0.14) * (0.3 + fios * 0.8);
		ALPHA = borda * (0.60 + fios * 0.23 + espuma * 0.14) * min(fluxo * 2.0, 1.0);
	} else {
		float reflexo = pow(max(0.0, onda), 15.0) * 0.17;
		ALBEDO = mix(refracao, cor_agua, 0.40) + vec3(0.62, 0.84, 0.88) * (reflexo + fresnel * 0.25);
		ALPHA = 0.88;
		vec3 normal_mundo = normalize(vec3(-cos(mundo.x * 13.0 + tempo * 1.7) * 0.12, 1.0, sin(mundo.z * 17.0 - tempo * 3.1) * 0.1));
		NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);
	}
	ROUGHNESS = 0.10;
	SPECULAR = 0.9;
	METALLIC = 0.0;
}
