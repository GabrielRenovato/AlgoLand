shader_type canvas_item;

// Os tons de cinza do desenho do PixelLab controlam a densidade da borda em pixel art.
void fragment() {
	vec4 mascara = texture(TEXTURE, UV);
	float densidade = 1.0 - dot(mascara.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(COLOR.rgb, COLOR.a * mascara.a * densidade);
}
