shader_type canvas_item;
uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_enable;
uniform bool pedra = false;
varying vec2 mundo;
varying vec4 tom;
void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
	tom = COLOR;
}
void fragment() {
	float alfa = texture(TEXTURE,UV).a;
	vec2 passo = TEXTURE_PIXEL_SIZE;
	float borda = min(min(texture(TEXTURE,UV+vec2(passo.x,0.0)).a,texture(TEXTURE,UV-vec2(passo.x,0.0)).a),
		min(texture(TEXTURE,UV+vec2(0.0,passo.y)).a,texture(TEXTURE,UV-vec2(0.0,passo.y)).a));
	vec3 cor = texture(arte,mundo/128.0).rgb;
	// Acabamento da pedra e sombra da grama seguem os cantos do atlas existente.
	cor *= mix(pedra ? 0.78 : 0.85,1.0,borda);
	COLOR = vec4(cor,alfa)*tom;
}
