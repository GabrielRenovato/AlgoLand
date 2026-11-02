shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;
#include "res://codigo/campanha/detalhe_solo.gdshaderinc"
uniform sampler2D mascaras : filter_linear, repeat_disable;
uniform sampler2D terra : filter_linear_mipmap, repeat_enable;
uniform sampler2D pedra : filter_linear_mipmap, repeat_enable;
uniform float ajuste_vegetacao = .65;
uniform vec3 tom_terra = vec3(.95,.98,1.02);
uniform int estacao = 0;
// Materiais novos criados a partir do acabamento do moinho.
// As coordenadas globais mantêm a continuidade entre todas as malhas de solo.
vec3 superficie_nitida(sampler2D mapa, vec2 ponto) {
	vec2 p = fract(ponto);
	vec2 w = smoothstep(vec2(.44),vec2(.56),p);
	vec2 q = p*.5;
	vec2 dx = dFdx(ponto)*.5;
	vec2 dy = dFdy(ponto)*.5;
	vec3 superior = mix(textureGrad(mapa,q+vec2(.5,.5),dx,dy).rgb,textureGrad(mapa,q+vec2(0.,.5),dx,dy).rgb,w.x);
	vec3 inferior = mix(textureGrad(mapa,q+vec2(.5,0.),dx,dy).rgb,textureGrad(mapa,q,dx,dy).rgb,w.x);
	return mix(superior,inferior,w.y);
}
void fragment() {
	vec3 controle = texture(mascaras,UV).rgb;
	vec4 pesos = vec4(controle,max(0.,1.-controle.r-controle.g-controle.b));
	pesos = desfiar_borda(pesos,UV2);
	// Solo sob as lâminas: a grama vem da geometria instanciada, sem imagem de vegetação.
	vec3 vegetacao = vec3(.22,.29,.10)*(.88+fbm(UV2/21.)*.20);
	vec3 caminho = superficie_nitida(terra,UV2/128.);
	// Corrigir o amarelo apenas nas folhas, preservando flores e folhas secas.
	float folha = smoothstep(-.02,.08,vegetacao.g-vegetacao.r);
	vegetacao = mix(vegetacao,vegetacao*vec3(.86,1.,1.035),folha*ajuste_vegetacao);
	float valor_terra = dot(caminho,vec3(.299,.587,.114));
	caminho = mix(caminho,vec3(valor_terra),.09)*tom_terra;
	vec3 patio = superficie_nitida(pedra,UV2/96.);
	if (estacao == 1) {
		vegetacao *= vec3(.91,.96,.94);
		caminho *= vec3(1.035,1.02,.98);
	} else if (estacao == 2) {
		float seco = smoothstep(.25,.75,fbm(UV2/22.));
		float luz = dot(vegetacao,vec3(.3,.5,.2));
		vegetacao = mix(vegetacao,luz*vec3(1.35,1.02,.59),seco*.72);
	} else if (estacao == 3) {
		float neve = smoothstep(.30,.59,fbm(UV2/37.));
		vec3 branco = vec3(.81,.86,.85)*( .94+ruido(UV2/4.)*.09 );
		vegetacao = mix(vegetacao*vec3(.74,.81,.77),branco,neve);
		caminho = mix(caminho,branco,neve*.16);
	}
	vec3 material = (vegetacao*pesos.r+caminho*pesos.g+patio*pesos.b)/max(.001,1.-pesos.a);
	ALBEDO = material;
	// Preenchimento artístico conserva a paleta; luz direcional e sombras vêm da cena 3D.
	EMISSION = material*.58;
	ROUGHNESS = .95;
	ALPHA = 1.-smoothstep(.02,.98,pesos.a);
}
void light() {
	DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*max(dot(NORMAL,LIGHT),0.0)*(.65/PI);
}
