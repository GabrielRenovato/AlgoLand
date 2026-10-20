shader_type canvas_item;

// Corpo/arma aprovados e cabeça canônica sem redimensionamento entre quadros.
uniform sampler2D acabamento : source_color, filter_nearest;
uniform sampler2D modelo : source_color, filter_nearest;
uniform sampler2D acabamento_modelo : source_color, filter_nearest;
uniform vec4 cabeca_original = vec4(35.0, 21.0, 11.0, 10.0);
uniform vec2 cabeca_destino = vec2(34.0, 21.0);
uniform float direcao = 0.0;
uniform vec4 tinta_bento : source_color = vec4(0.109804, 0.094118, 0.101961, 1.0);
uniform vec4 contorno_original_a : source_color = vec4(0.188235, 0.137255, 0.152941, 1.0);
uniform vec4 contorno_original_b : source_color = vec4(0.286275, 0.2, 0.168627, 1.0);
varying vec4 modulacao;

void vertex() {
	modulacao = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec2 ponto = mod(floor(UV / TEXTURE_PIXEL_SIZE), vec2(80.0));
	bool area_original = ponto.x >= cabeca_original.x - 1.0 && ponto.x < cabeca_original.x + cabeca_original.z + 2.0
		&& ponto.y >= cabeca_original.y && ponto.y < cabeca_original.y + 10.0;
	vec2 local = ponto - cabeca_destino;
	bool area_modelo = local.x >= 0.0 && local.x < 14.0 && local.y >= 0.0 && local.y < 10.0;
	bool metal = pixel.a > 0.5 && pixel.b > pixel.r * 1.08 && pixel.b > 0.35;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec4 vizinho = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE);
			metal = metal || (vizinho.a > 0.5 && vizinho.b > vizinho.r * 1.08 && vizinho.b > 0.35);
		}
	}
	bool cabeca = (area_original || area_modelo) && !metal;
	if (cabeca) {
		pixel = vec4(0.0);
		if (area_modelo) {
			vec2 uv_modelo = (vec2(direcao * 80.0 + 34.0, 21.0) + local + vec2(0.5)) / vec2(320.0, 80.0);
			pixel = texture(modelo, uv_modelo);
			vec4 detalhe = texture(acabamento_modelo, uv_modelo);
			if (pixel.a > 0.5 && detalhe.a > 0.5) {
				pixel.rgb = detalhe.rgb;
			}
			// A mandíbula não recebe marcas de boca/camisa trazidas da adaptação.
			if (local.y >= 8.0 && local.x >= 4.0 && local.x <= 9.0 && pixel.a > 0.5) {
				pixel.rgb = vec3(0.866667, 0.647059, 0.454902);
			}
		}
	}
	// O recorte antigo deixava partes do maxilar projetadas sobre a gola.
	bool gola = local.y >= 10.0 && local.y < 12.0 && local.x >= 3.0 && local.x <= 10.0;
	if (gola && !metal && pixel.a > 0.5) {
		bool pele = pixel.r > pixel.g * 1.12 && pixel.g > pixel.b * 1.1 && pixel.r > 0.4;
		if (pele) {
			pixel.rgb = (local.x >= 6.0 && local.x <= 8.0 && local.y == 10.0)
				? vec3(0.866667, 0.647059, 0.454902) : vec3(0.937255, 0.905882, 0.807843);
		}
	}
	if (pixel.a > 0.5) {
		vec4 retoque = texture(acabamento, UV);
		if (retoque.a > 0.5 && !cabeca) {
			pixel.rgb = retoque.rgb;
		}
		bool contorno = distance(pixel.rgb, contorno_original_a.rgb) < 0.012
			|| distance(pixel.rgb, contorno_original_b.rgb) < 0.012;
		bool borda = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a < 0.5
			|| texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a < 0.5
			|| texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a < 0.5
			|| texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a < 0.5;
		if (contorno && (cabeca || (borda && retoque.a < 0.5))) {
			pixel.rgb = tinta_bento.rgb;
		}
	}
	COLOR = pixel * modulacao;
}
