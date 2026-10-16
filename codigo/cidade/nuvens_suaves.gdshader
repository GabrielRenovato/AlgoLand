shader_type canvas_item;

varying vec4 tom;
void vertex() {
	tom = COLOR;
}
void fragment() {
	vec2 passo = TEXTURE_PIXEL_SIZE * 6.0;
	float alfa = texture(TEXTURE, UV).a * 4.0;
	alfa += texture(TEXTURE, UV + vec2(passo.x, 0.0)).a;
	alfa += texture(TEXTURE, UV - vec2(passo.x, 0.0)).a;
	alfa += texture(TEXTURE, UV + vec2(0.0, passo.y)).a;
	alfa += texture(TEXTURE, UV - vec2(0.0, passo.y)).a;
	alfa += texture(TEXTURE, UV + passo).a;
	alfa += texture(TEXTURE, UV - passo).a;
	alfa += texture(TEXTURE, UV + vec2(passo.x, -passo.y)).a;
	alfa += texture(TEXTURE, UV + vec2(-passo.x, passo.y)).a;
	// Nuvens altas filtram a luz com pouca força; a borda não parece outro terreno.
	COLOR = vec4(0.20, 0.23, 0.28, alfa / 12.0 * 0.24 * tom.a);
}
