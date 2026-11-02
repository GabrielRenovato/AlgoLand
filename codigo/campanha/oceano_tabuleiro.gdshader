shader_type canvas_item;
render_mode unshaded;

uniform vec2 resolucao = vec2(576.0,324.0);
uniform sampler2D pintura : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D ilha : filter_linear, repeat_disable;
uniform vec2 origem_ilha;
uniform vec2 tamanho_ilha = vec2(576.0,384.0);
uniform float instante_forcado = -1.0;

float ruido(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	float a=fract(sin(dot(i,vec2(127.1,311.7)))*43758.5453);
	float b=fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7)))*43758.5453);
	float c=fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7)))*43758.5453);
	float d=fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7)))*43758.5453);
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
float terra(vec2 p) {
	vec2 uv=(p-origem_ilha)/tamanho_ilha;
	if(uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0) return 0.0;
	return texture(ilha,uv).a;
}
void fragment() {
	float t=instante_forcado>=0.0 ? instante_forcado : TIME;
	vec2 p=UV*resolucao;
	float n=ruido(p/28.0+vec2(t*0.11,-t*0.07));
	vec3 fundo=mix(vec3(0.025,0.19,0.23),vec3(0.065,0.37,0.39),n);
	// A faixa superior da pintura contém somente mar. A amostragem contínua
	// dessa paleta evita um retângulo estático ao redor da ilha em telas altas.
	float u=0.5+0.46*sin(p.x/83.0+sin(p.y/61.0)*0.5+t*0.05);
	vec3 pincel=texture(pintura,vec2(u,0.008+n*0.014)).rgb;
	vec3 agua=mix(fundo,pincel,0.45);
	float ondas=sin(p.y*0.22+p.x*0.08+n*7.0-t*0.9);
	agua+=vec3(0.025,0.065,0.055)*smoothstep(0.8,0.98,ondas)*(0.25+0.75*n);
	// Espuma acompanha a silhueta e respira sem mover o tabuleiro.
	float perto=max(max(terra(p+vec2(3.0,0)),terra(p-vec2(3.0,0))),max(terra(p+vec2(0,3.0)),terra(p-vec2(0,3.0))));
	float espuma=perto*(1.0-terra(p))*(0.28+0.12*sin(p.x*0.12+p.y*0.1-t*1.8));
	agua=mix(agua,vec3(0.56,0.82,0.72),espuma);
	COLOR=vec4(agua,1.0);
}
