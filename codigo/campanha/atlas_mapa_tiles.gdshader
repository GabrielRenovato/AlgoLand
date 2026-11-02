shader_type canvas_item;
render_mode unshaded;
uniform sampler2D solo : source_color, repeat_enable, filter_linear;
uniform float inverno = 0.0;
void fragment() {
	vec2 pixel=UV*vec2(512,640);
	ivec2 cel=ivec2(floor(pixel/64.0));
	vec2 q=fract(pixel/64.0);
	int indice=cel.x+(cel.y%2)*8;
	float a=float((indice>>3)&1), b=float((indice>>2)&1);
	float c=float((indice>>1)&1), d=float(indice&1);
	float m=mix(mix(a,b,q.x),mix(c,d,q.x),q.y);
	float peso=smoothstep(0.44,0.56,m);
	if(cel.y<2) { COLOR=vec4(peso,0,1.0-peso,1); }
	else if(cel.y<4) { COLOR=vec4(0,0,1,peso); }
	else if(cel.y<6) { COLOR=vec4(0,peso,1.0-peso,1); }
	else if(cel.y==6) {
		COLOR=vec4(0);
	} else if(cel.y==7) {
		float t=float(cel.x)*6.283185/8.0;
		float onda=sin(q.y*6.283185+t+sin(q.x*6.283185)*0.45)*0.5+0.5;
		float recorte=sin(q.x*12.56637-t)*0.5+0.5;
		vec3 agua=mix(vec3(0.025,0.39,0.48),vec3(0.07,0.57,0.62),onda*0.55);
		agua=mix(agua,vec3(0.55,0.84,0.82),pow(onda,15.0)*recorte*0.18);
		COLOR=vec4(mix(agua,vec3(0.35,0.57,0.64),inverno*0.2),1);
	} else {
		bool vertical=cel.x>=2;
		vec2 uv=vertical?q.yx:q;
		float fresta=smoothstep(0.93,0.98,fract(uv.x*4.0));
		vec3 madeira=mix(vec3(0.38,0.22,0.1),vec3(0.65,0.42,0.2),0.55+sin(uv.y*44.0)*0.06);
		madeira*=1.0-fresta*0.5;
		float raio=step(uv.y,0.08)+step(0.92,uv.y);
		madeira=mix(madeira,vec3(0.28,0.16,0.07),clamp(raio,0.0,1.0)*0.65);
		COLOR=vec4(madeira,1);
	}
}
