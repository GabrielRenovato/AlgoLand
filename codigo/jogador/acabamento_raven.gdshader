shader_type canvas_item;
// Rampas Raven e articulação da pose sentada na grade inteira de pixels.
uniform vec4 cores_origem[64];
uniform vec4 cores_destino[64];
uniform int quantidade_cores = 0;
uniform bool tingir_cabelo = false;
uniform bool sentado = false;
uniform int direcao_sentado = 0;
uniform bool sem_rastro_pesca = false;
varying vec4 tinta;

void vertex() { tinta = COLOR; }

void fragment() {
	vec2 amostra = UV;
	if (sentado) {
		vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
		vec2 local = mod(pixel, vec2(80.0));
		vec2 deslocamento = vec2(0.0);
		// Quadril apoiado e tronco dois pixels abaixo; joelhos se projetam
		// nos perfis, sem escalar rosto, roupa ou cabelo.
		if (local.y < 43.0) deslocamento.y = -2.0;
		else if (direcao_sentado == 1 || direcao_sentado == 3) {
			float joelho = local.y < 44.0 ? 3.0 : 6.0;
			deslocamento.x = direcao_sentado == 1 ? -joelho : joelho;
		}
		amostra = (pixel + deslocamento + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	}
	vec4 original = texture(TEXTURE, amostra);
	// O terceiro quadro da ferramenta mistura a haste e um efeito de arco.
	// Mantém os pixels originais de madeira; não altera a boia da preparação.
	if (sem_rastro_pesca && mod(floor(UV.x / TEXTURE_PIXEL_SIZE.x / 80.0), 4.0) == 2.0) {
		if (any(greaterThan(abs(original.rgb - vec3(116.0,92.0,66.0)/255.0),vec3(0.001)))) {
			original.a = 0.0;
		}
	}
	vec3 cor = original.rgb;
	for (int i = 0; i < quantidade_cores; i++) {
		if (all(lessThan(abs(original.rgb - cores_origem[i].rgb), vec3(0.001)))) {
			cor = cores_destino[i].rgb;
			break;
		}
	}
	if (tingir_cabelo && distance(tinta.rgb, vec3(1.0)) >= 0.005) {
		float luz = clamp(dot(cor, vec3(0.299, 0.587, 0.114)) * 1.5, 0.0, 1.0);
		cor = vec3(luz) * tinta.rgb;
	} else {
		cor *= tinta.rgb;
	}
	COLOR = vec4(cor, original.a * tinta.a);
}
