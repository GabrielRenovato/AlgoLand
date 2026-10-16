shader_type canvas_item;

// Paleta curta no desenho do corpo: bordas e sombras com tons definidos.
// Conserva a textura e a geometria; cabelos, roupas e armas não recebem o efeito.
varying vec4 cor_vertices;

void vertex() {
	cor_vertices = COLOR;
}

void comparar(vec3 entrada, vec3 candidata, inout vec3 melhor, inout float distancia) {
	vec3 diferenca = entrada - candidata;
	float atual = dot(diferenca * vec3(1.0, 1.3, 1.0), diferenca);
	if (atual < distancia) {
		distancia = atual;
		melhor = candidata;
	}
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 cor = vec3(16.0, 19.0, 22.0) / 255.0;
	float distancia = 100.0;
	comparar(pixel.rgb, vec3(16.0, 19.0, 22.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(33.0, 20.0, 14.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(48.0, 54.0, 58.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(76.0, 40.0, 27.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(121.0, 64.0, 43.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(162.0, 87.0, 55.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(200.0, 121.0, 76.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(223.0, 153.0, 97.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(239.0, 180.0, 122.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(255.0, 205.0, 152.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(255.0, 226.0, 181.0) / 255.0, cor, distancia);
	comparar(pixel.rgb, vec3(255.0, 242.0, 217.0) / 255.0, cor, distancia);
	COLOR = vec4(cor, step(0.5, pixel.a)) * cor_vertices;
}
