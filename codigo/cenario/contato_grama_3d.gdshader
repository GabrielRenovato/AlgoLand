shader_type canvas_item;
uniform float base_y;
varying vec4 tom;
varying float altura_mapa;
void vertex() {
	tom = COLOR;
	altura_mapa = (MODEL_MATRIX*vec4(VERTEX,0.,1.)).y;
}
void fragment() {
	// REGION_RECT mantém UVs da textura compartilhada: usar a posição real do fragmento.
	vec4 cor = texture(TEXTURE,UV);
	float d = altura_mapa-base_y;
	cor.a *= smoothstep(-8.,-5.,d)*(1.-smoothstep(3.,7.,d));
	COLOR = cor*tom;
}
