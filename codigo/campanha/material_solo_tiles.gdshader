shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grama : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D terra : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D pedra : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 local;
void vertex() { local=VERTEX; }
void fragment() {
	vec4 pesos=texture(TEXTURE,UV);
	vec3 g=texture(grama,local/512.0).rgb;
	vec3 t=texture(terra,local/512.0).rgb;
	vec3 p=texture(pedra,local/512.0).rgb;
	vec3 cor=t*pesos.r+p*pesos.g+g*pesos.b;
	float arremate=1.0-smoothstep(0.03,0.24,abs(pesos.r-0.5));
	cor*=1.0-arremate*0.065;
	COLOR=vec4(cor,pesos.a);
}
