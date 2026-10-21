shader_type canvas_item;
// Mesmo material da cidade (grama e campo de terra512×512 por período de 128 px),
// com a terra vinda da cobertura real dos tiles da fazenda. R = grama, B = terra (0..1, linear).
uniform sampler2D distribuicao : filter_linear, repeat_disable;
uniform sampler2D grama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terra : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 origem;
uniform vec2 tamanho;
varying vec2 mundo;
varying vec4 tom;
float solo(vec2 p) { return texture(distribuicao,(p-origem)/tamanho).b; }
void vertex() {
	mundo=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	tom=COLOR;
}
void fragment() {
	// A cobertura em pixels nativos vira contorno liso ao ser interpolada e cortada em 0,5.
	float t=smoothstep(0.47,0.53,solo(mundo));
	vec3 verde=texture(grama,mundo/128.0).rgb;
	vec3 solo_cor=texture(terra,mundo/128.0).rgb;
	// Beirada da terra: sombra fina junto da grama e leve realce do lado de dentro.
	float perto=min(min(solo(mundo+vec2(1.3,0.0)),solo(mundo-vec2(1.3,0.0))),min(solo(mundo+vec2(0.0,1.3)),solo(mundo-vec2(0.0,1.3))));
	float margem=clamp(t-smoothstep(0.47,0.53,perto),0.0,1.0);
	solo_cor*=1.0-margem*0.16;
	float contato=max(max(solo(mundo+vec2(1.6,0.0)),solo(mundo-vec2(1.6,0.0))),max(solo(mundo+vec2(0.0,1.6)),solo(mundo-vec2(0.0,1.6))));
	verde*=1.0-clamp(smoothstep(0.47,0.53,contato)-t,0.0,1.0)*0.10;
	COLOR=vec4(mix(verde,solo_cor,t),1.0)*tom;
}
