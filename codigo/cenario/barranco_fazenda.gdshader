shader_type canvas_item;
uniform sampler2D barranco : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 folha_tamanho;
uniform bool faixa = false;
uniform float pe = 80.0;
varying vec4 tom;
varying vec2 mundo;
void vertex() { tom=COLOR; mundo=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	float y=mundo.y-(pe-64.0);
	vec3 verde=texture(grama,mundo/128.0).rgb;
	// A faixa de vegetação pintada na fonte fica fora do recorte: a borda
	// pertence inteiramente à grama sazonal compartilhada com o chão.
	vec3 rocha=texture(barranco,vec2(mundo.x/192.0,0.12+y/64.0*0.88)).rgb;
	// O topo e o pé amostram o mesmo campo mundial do chão, inclusive na neve.
	// A irregularidade fica na borda da rocha; a fase da grama nunca reinicia por tile.
	float recorte=4.5+sin(mundo.x*0.47)*0.65+sin(mundo.x*1.17)*0.25;
	float topo=smoothstep(recorte-0.35,recorte+0.35,y);
	float base=1.0-smoothstep(55.0+sin(mundo.x*.39),60.0,y);
	vec3 cor=mix(verde,rocha,topo*base);
	if (y>recorte && y<recorte+1.0) cor*=0.92;
	COLOR=vec4(cor,texture(TEXTURE,UV).a)*tom;
}
