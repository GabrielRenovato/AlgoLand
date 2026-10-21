shader_type canvas_item;
uniform sampler2D distribuicao : filter_linear, repeat_disable;
uniform sampler2D grama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pedra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terra : source_color, filter_linear, repeat_enable;
uniform vec2 origem;
uniform vec2 tamanho;
varying vec2 mundo;
varying vec4 tom;
vec3 mapa(vec2 p) { return texture(distribuicao,(p-origem)/tamanho).rgb; }
void vertex() {
	mundo=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	tom=COLOR;
}
void fragment() {
	vec3 m=mapa(mundo);
	float cobertura=clamp(m.r+m.g+m.b,0.0,1.0);
	vec3 verde=texture(grama,mundo/128.0).rgb;
	vec3 pavimento=texture(pedra,mundo/128.0).rgb;
	vec3 solo=texture(terra,mundo/128.0).rgb;
	// Arremate contínuo de pedra clara: acompanha cantos, curvas e junções.
	float perto=min(min(mapa(mundo+vec2(1.1,0)).g,mapa(mundo-vec2(1.1,0)).g),min(mapa(mundo+vec2(0,1.1)).g,mapa(mundo-vec2(0,1.1)).g));
	float borda=clamp(m.g-perto,0.0,1.0);
	pavimento=mix(pavimento,vec3(0.64,0.60,0.50),borda*0.9);
	float contato=max(max(mapa(mundo+vec2(1.0,0)).g,mapa(mundo-vec2(1.0,0)).g),max(mapa(mundo+vec2(0,1.0)).g,mapa(mundo-vec2(0,1.0)).g));
	verde*=1.0-clamp(contato-m.g,0.0,1.0)*0.08;
	vec3 cor=(verde*m.r+pavimento*m.g+solo*m.b)/max(cobertura,0.001);
	COLOR=vec4(cor,cobertura)*tom;
}
