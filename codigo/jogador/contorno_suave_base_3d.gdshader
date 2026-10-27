shader_type canvas_item;
// Contorno escuro em volta da silhueta do personagem 3D (render suave em alta resolução).
// `raio` em texels: com NITIDEZ 8, 8 texels = 1 pixel do mundo. Borda suavizada pelo próprio alfa.
uniform vec4 cor_contorno : source_color = vec4(0.13, 0.09, 0.12, 1.0);
uniform float raio = 9.0;

void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	float vizinho = 0.0;
	for (int i = 0; i < 12; i++) {
		float angulo = float(i) * 0.5235988;
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2(cos(angulo), sin(angulo)) * raio * TEXTURE_PIXEL_SIZE).a);
	}
	vec4 borda = vec4(cor_contorno.rgb, vizinho * cor_contorno.a);
	COLOR = mix(borda, vec4(cor.rgb / max(cor.a, 0.001), 1.0), cor.a);
	COLOR.a = max(cor.a, borda.a);
}
