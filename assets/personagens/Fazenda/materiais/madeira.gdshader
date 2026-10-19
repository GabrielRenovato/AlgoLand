shader_type canvas_item;

// Paleta de madeira sobre a silhueta nativa; água e rastros brancos permanecem intactos.
uniform float pixels_por_unidade = 1.0;
uniform float nivel = 1.0;
varying vec4 tom_instancia;
void vertex() {
	tom_instancia = COLOR;
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float luz = max(base.r,max(base.g,base.b));
	bool efeito_branco = min(base.r,min(base.g,base.b)) > 0.94;
	bool agua = base.g > base.r + 0.10 && base.b > base.r + 0.10;
	vec3 madeira;
	if (luz < 0.16) madeira = vec3(0.16,0.09,0.045);
	else if (luz < 0.30) madeira = vec3(0.29,0.17,0.08);
	else if (luz < 0.47) madeira = vec3(0.43,0.27,0.13);
	else if (luz < 0.65) madeira = vec3(0.59,0.38,0.19);
	else if (luz < 0.82) madeira = vec3(0.74,0.51,0.29);
	else madeira = vec3(0.85,0.67,0.42);
	// Veios discretos, no mesmo tamanho lógico nos ícones e nas animações refinadas.
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE / pixels_por_unidade);
	if (luz > 0.30 && luz < 0.94 && mod(pixel.x + floor(pixel.y/4.0),4.0) == 1.0) {
		madeira *= 0.91;
	}
	if (nivel>1.5 && base.b>=base.r*.90 && !efeito_branco && !agua) {
		madeira = nivel>2.5 ? mix(vec3(.20,.25,.32),vec3(.78,.88,.89),floor(luz*5.0)/5.0) : mix(vec3(.29,.25,.22),vec3(.76,.68,.48),floor(luz*5.0)/5.0);
	}
	COLOR = vec4((efeito_branco || agua) ? base.rgb : madeira,base.a) * tom_instancia;
}
