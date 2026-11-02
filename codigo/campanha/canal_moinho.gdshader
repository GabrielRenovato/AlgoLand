shader_type canvas_item;
render_mode unshaded;
uniform float instante_forcado = -1.0;
varying vec2 local;
void vertex() {local=VERTEX;}
void fragment() {
	float t=instante_forcado>=0.0?instante_forcado:TIME;
	float fluxo=sin(local.x*0.35+local.y*0.55-t*3.0)*0.5+0.5;
	vec3 agua=mix(vec3(0.07,0.46,0.56),vec3(0.24,0.69,0.72),fluxo*0.6);
	agua+=vec3(0.18,0.23,0.22)*pow(fluxo,15.0);
	COLOR=vec4(agua,1);
}
