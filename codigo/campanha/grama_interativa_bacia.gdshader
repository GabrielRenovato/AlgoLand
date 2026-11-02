shader_type spatial;
render_mode cull_disabled, world_vertex_coords, ambient_light_disabled;
uniform vec3 cor_grama = vec3(.30,.47,.12);
uniform vec4 jogadores[8]; // xy: pés no mapa; zw: direção ponderada pela velocidade.
uniform vec4 rastros[16]; // xy: centro; zw: direção da passagem.
uniform float forcas_rastros[16];
uniform int quantidade_jogadores = 0;
uniform int quantidade_rastros = 0;
uniform bool somente_frente = false;
varying vec2 raiz_mapa;
varying vec4 tom;
void vertex() {
	raiz_mapa = INSTANCE_CUSTOM.xy;
	float altura = max(VERTEX.y-INSTANCE_CUSTOM.z,0.);
	float ponta = pow(clamp(altura/.34,0.,1.),1.65);
	tom = vec4(mix(vec3(.43,.53,.34),vec3(1.),clamp(altura/.31,0.,1.)),1.);
	vec2 dobra = vec2(sin(TIME*1.6+raiz_mapa.x*.039+raiz_mapa.y*.021)*.035+sin(TIME*.77+raiz_mapa.y*.05)*.012,.009);
	float baixar = 0.;
	for (int i=0; i<8; i++) {
		if (i >= quantidade_jogadores) break;
		vec2 d = raiz_mapa-jogadores[i].xy;
		float peso = 1.-smoothstep(3.,18.,length(d));
		vec2 direcao = normalize(d+jogadores[i].zw*9.+vec2(.001));
		dobra += direcao*peso*.19;
		baixar = max(baixar,peso*.10);
	}
	for (int i=0; i<16; i++) {
		if (i >= quantidade_rastros) break;
		float peso = (1.-smoothstep(2.,15.,distance(raiz_mapa,rastros[i].xy)))*forcas_rastros[i];
		dobra += rastros[i].zw*peso*.14;
		baixar = max(baixar,peso*.07);
	}
	VERTEX.x += dobra.x*ponta;
	VERTEX.z += dobra.y*ponta/.70710678;
	VERTEX.y -= baixar*ponta;
}
void fragment() {
	if (somente_frente) {
		float visivel = 0.;
		for (int i=0; i<8; i++) {
			if (i >= quantidade_jogadores) break;
			vec2 d = raiz_mapa-jogadores[i].xy;
			if (d.y >= -.5 && d.y <= 12. && abs(d.x) <= 16.) visivel = 1.;
		}
		if (visivel < .5) discard;
	}
	ALBEDO = cor_grama.rgb*tom.rgb;
	EMISSION = ALBEDO*.50;
	ROUGHNESS = .96;
	SPECULAR = .08;
}

void light() {
	DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*(.5+.5*abs(dot(NORMAL,LIGHT)))*(.70/PI);
}
