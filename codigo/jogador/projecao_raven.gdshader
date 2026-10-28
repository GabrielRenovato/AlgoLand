shader_type spatial;
// Projeta as quatro fotos do Raven na superfície 3D, pixel a pixel (sem filtro):
// cada ponto usa a vista para onde a superfície aponta, sem misturar cores.
render_mode cull_disabled, specular_disabled;
uniform sampler2D frente : source_color, filter_nearest;
uniform sampler2D costas : source_color, filter_nearest;
uniform sampler2D direita : source_color, filter_nearest; // Mostra o lado -X.
uniform sampler2D esquerda : source_color, filter_nearest; // Mostra o lado +X.
uniform float celula = 160.0;
uniform vec2 pivo = vec2(80.0, 94.0);
// 0 = cores exatas do sprite (sem luz); 1 = iluminado pela cena.
uniform float luz = 0.0;
varying vec3 posicao;
varying vec3 normal_modelo;

void vertex() {
	posicao = vec3(UV.x, UV.y, UV2.x);
	normal_modelo = NORMAL;
}

void fragment() {
	vec3 n = normalize(normal_modelo);
	float linha = pivo.y - posicao.y;
	vec3 cor;
	// Topo e base seguem a frente ou as costas, conforme a metade do corpo.
	if (abs(n.x) > abs(n.z) && abs(n.x) > abs(n.y) * 0.6) {
		cor = n.x < 0.0 ? texture(direita, vec2(pivo.x + posicao.z, linha) / celula).rgb
				: texture(esquerda, vec2(pivo.x - posicao.z, linha) / celula).rgb;
	} else if (n.z > 0.0 || (abs(n.z) < 0.2 && posicao.z >= 0.0)) {
		cor = texture(frente, vec2(pivo.x + posicao.x, linha) / celula).rgb;
	} else {
		cor = texture(costas, vec2(pivo.x - posicao.x, linha) / celula).rgb;
	}
	ALBEDO = cor * luz;
	EMISSION = cor * (1.0 - luz);
	ROUGHNESS = 1.0;
}
