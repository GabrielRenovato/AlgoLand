shader_type canvas_item;

uniform sampler2D contorno : filter_nearest, repeat_disable;
uniform sampler2D terra : source_color, filter_nearest, repeat_enable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform vec2 corrente = vec2(1.5,0.4);
uniform float inverno = 0.0;
uniform float tempo_revisao = -1.0;
varying vec2 mundo;
varying vec4 tom;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float ruido(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float agua(vec2 p) {
	vec2 uv=(p-origem)/tamanho;
	if(any(lessThan(uv,vec2(0))) || any(greaterThanEqual(uv,vec2(1)))) return 0.0;
	return texture(contorno,uv).r;
}
float interior(vec2 p,float r) {
	return min(min(agua(p+vec2(r,0)),agua(p-vec2(r,0))),min(agua(p+vec2(0,r)),agua(p-vec2(0,r))));
}
void vertex() {
	mundo=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	tom=COLOR;
}
void fragment() {
	vec4 base=texture(TEXTURE,UV);
	vec2 p=floor(mundo)+vec2(0.5);
	float mascara=agua(p);
	float t=floor((tempo_revisao<0.0?TIME:tempo_revisao)*12.0)/12.0;
	float distancia=texture(contorno,(p-origem)/tamanho).g*48.0;
	float fundo=smoothstep(2.0,34.0,distancia);
	fundo=floor(fundo*8.0+ruido(p/13.0)*0.3)/8.0;
	vec2 deriva=p-corrente*t;
	float manchas=ruido(deriva/vec2(43,29))*0.65+ruido((deriva+vec2(81,37))/19.0)*0.35;
	float volume=floor(manchas*5.0)/5.0;
	vec3 rasa=vec3(0.24,0.59,0.57);
	vec3 profunda=vec3(0.075,0.26,0.36);
	vec3 cor=mix(rasa,profunda,clamp(fundo*0.85+volume*0.23,0.0,1.0));
	// Ondas largas e descontínuas: posição no mundo, sem repetição por tile.
	float onda=sin(deriva.y*0.20+sin(deriva.x*0.075+t*0.33)*1.7+t*0.62);
	float quebra=ruido((deriva+vec2(0,t*2.0))/vec2(28,13));
	float crista=step(0.88,onda)*step(0.44,quebra);
	cor=mix(cor,vec3(0.43,0.74,0.69),crista*0.24);
	// Luz refratada suave sobre o fundo raso; grupos de pixels em vez de ruído.
	float luz=sin(deriva.x*0.22+sin(deriva.y*0.13+t*0.45)*1.8)+sin(deriva.y*0.29-t*0.7);
	float caustica=step(1.73,luz)*(1.0-fundo*0.75);
	cor=mix(cor,vec3(0.57,0.77,0.61),caustica*0.22);
	float borda=1.0-interior(p,1.0);
	float areia=1.0-smoothstep(1.0,5.0,distancia);
	vec3 solo=texture(terra,p/128.0).rgb;
	cor=mix(cor,mix(solo,vec3(0.31,0.48,0.35),0.43),areia*0.55);
	cor=mix(cor,solo*vec3(0.72,0.85,0.78),borda*0.72);
	float norte=1.0-agua(p-vec2(0,4));
	cor*=1.0-norte*0.14;
	// Uma lâmina móvel encosta na margem, sem alterar a máscara/colisão.
	float espuma=(1.0-interior(p,4.0))*(1.0-borda);
	espuma*=step(0.35,sin(t*1.4+ruido(p/18.0)*6.28));
	cor=mix(cor,vec3(0.62,0.82,0.73),espuma*0.34);
	vec2 cel=floor(p/vec2(43,31));
	float s=hash(cel);
	vec2 q=mod(p,vec2(43,31))-vec2(5.0+s*28.0,5.0+hash(cel+9.0)*20.0);
	float estrela=step(abs(q.y),0.55)*step(abs(q.x),2.0)+step(abs(q.x),0.55)*step(abs(q.y),1.0);
	float pulso=pow(max(0.0,sin(t*1.8+s*28.0)),18.0)*step(0.58,s);
	cor=mix(cor,vec3(0.83,0.94,0.87),clamp(estrela,0.0,1.0)*pulso*0.75*interior(p,7.0));
	// Gelo nas margens externas; o centro continua legível e com movimento lento.
	float gelo=inverno*step(0.27+fundo*0.48,ruido(p/23.0))*(1.0-fundo*0.65);
	vec3 gelada=mix(vec3(0.48,0.72,0.79),vec3(0.78,0.89,0.88),floor(manchas*4.0)/4.0);
	cor=mix(cor,gelada,gelo*0.90);
	cor=floor(cor*31.0+0.5)/31.0;
	COLOR=vec4(mix(base.rgb,cor,mascara),base.a)*tom;
}
