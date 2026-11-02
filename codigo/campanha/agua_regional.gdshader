shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terreno : filter_linear, repeat_disable;
uniform float instante_forcado = -1.0;
uniform vec2 extensao;
uniform vec2 origem;
uniform vec2 tamanho_terreno;

float terra(vec2 uv) {
	if (uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0) return 0.0;
	return texture(terreno,uv).a;
}

float ruido(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void fragment() {
	float t=instante_forcado>=0.0?instante_forcado:TIME;
	vec2 uv=(UV*extensao-origem)/tamanho_terreno;
	vec2 p=uv*vec2(1536,1024);
	vec2 corrente=p/31.0+vec2(-t*0.17,t*0.1);
	float n=ruido(corrente)*0.65+ruido(corrente*2.4+vec2(t*0.11,0))*0.35;
	vec3 fundo=mix(vec3(0.025,0.36,0.46),vec3(0.055,0.64,0.69),n);
	float onda=sin(p.y*0.15+p.x*0.035+n*4.5-t*1.4);
	float reflexo=smoothstep(0.88,0.99,onda)*smoothstep(0.32,0.7,ruido(p/14.0+vec2(t*0.12,0)));
	fundo=mix(fundo,vec3(0.52,0.88,0.84),reflexo*0.45);
	vec2 d=vec2(2.2/1536.0,2.2/1024.0);
	float margem=max(max(terra(uv+vec2(d.x,0)),terra(uv-vec2(d.x,0))),max(terra(uv+vec2(0,d.y)),terra(uv-vec2(0,d.y))));
	float costa=margem*(1.0-terra(uv));
	float espuma=costa*(0.45+0.25*sin(p.x*0.17+p.y*0.11-t*1.9));
	fundo=mix(fundo,vec3(0.84,0.98,0.91),espuma);
	COLOR=vec4(fundo,1.0);
}
