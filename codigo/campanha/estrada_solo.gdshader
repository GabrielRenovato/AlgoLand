shader_type canvas_item;
#include "res://codigo/campanha/detalhe_solo.gdshaderinc"
uniform sampler2D grama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D raizes : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pedra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D agua : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mapa_raizes : filter_linear, repeat_disable;
uniform sampler2D marcas_estrada : filter_linear, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
varying vec2 mundo;
varying vec4 tom;
// Cruza metades opostas nas emendas, preservando orientação e sem espelhar raízes.
vec3 superficie_continua(sampler2D mapa, vec2 ponto) {
	vec2 p = fract(ponto);
	vec2 w = smoothstep(vec2(0.0),vec2(1.0),p);
	vec2 q = p*0.5;
	vec3 superior = mix(texture(mapa,q+vec2(0.5,0.5)).rgb,texture(mapa,q+vec2(0.0,0.5)).rgb,w.x);
	vec3 inferior = mix(texture(mapa,q+vec2(0.5,0.0)).rgb,texture(mapa,q).rgb,w.x);
	return mix(superior,inferior,w.y);
}
// Densidade original: metades de 64px lógicos, sem misturar quatro imagens
// por toda a superfície. A transição fica restrita à junção das metades.
vec3 vegetacao_nitida(vec2 ponto) {
	vec2 repeticao = ponto/64.0;
	vec2 p = fract(repeticao);
	vec2 w = smoothstep(vec2(0.44),vec2(0.56),p);
	vec2 q = p*0.5;
	// Derivar a coordenada contínua evita mipmaps borrados nas quebras de fract.
	vec2 dx = dFdx(repeticao)*0.5;
	vec2 dy = dFdy(repeticao)*0.5;
	vec3 superior = mix(textureGrad(grama,q+vec2(0.5,0.5),dx,dy).rgb,textureGrad(grama,q+vec2(0.0,0.5),dx,dy).rgb,w.x);
	vec3 inferior = mix(textureGrad(grama,q+vec2(0.5,0.0),dx,dy).rgb,textureGrad(grama,q,dx,dy).rgb,w.x);
	return mix(superior,inferior,w.y);
}
void vertex() {
	mundo = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	tom = COLOR;
}
void fragment() {
	vec3 controle = texture(TEXTURE,UV).rgb;
	vec4 pesos = vec4(controle, max(0.0,1.0-controle.r-controle.g-controle.b));
	pesos /= max(dot(pesos,vec4(1.0)),0.001);
	pesos = desfiar_borda(pesos,mundo);
	vec2 uv = mundo/128.0;
	vec3 floresta = vegetacao_nitida(mundo);
	vec3 solo = texture(terra,uv).rgb;
	vec2 dentro = abs(fract(uv)-0.5);
	float borda_repeticao = 1.0-smoothstep(0.35,0.49,max(dentro.x,dentro.y));
	float r = texture(mapa_raizes,(mundo-origem)/tamanho).r*borda_repeticao;
	solo = mix(solo,texture(raizes,uv).rgb,r*0.85);
	vec3 estrada = superficie_continua(pedra,mundo/96.0);
	vec2 corrente = uv+vec2(sin(mundo.y*0.04+TIME*0.7)*0.005,TIME*0.008);
	vec3 rio = superficie_continua(agua,corrente);
	float espuma = pesos.a*(1.0-pesos.a)*0.35;
	rio = mix(rio,vec3(0.72,0.89,0.84),espuma);
	vec3 cor = floresta*pesos.r+solo*pesos.g+estrada*pesos.b+rio*pesos.a;
	cor = detalhar_solo(cor,pesos,mundo);
	float sulco = texture(marcas_estrada,(mundo-origem)/tamanho).r;
	cor *= 1.0-sulco*0.24;
	COLOR = vec4(cor,1.0)*tom;
}
