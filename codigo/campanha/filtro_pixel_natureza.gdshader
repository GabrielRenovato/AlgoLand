shader_type canvas_item;
// Pós-processo do render 3D: grade de 2px do mundo, igual à ampliação do moinho.
// A origem global mantém os pixels alinhados entre blocos e objetos independentes.
uniform vec2 origem;
uniform vec2 tamanho_logico;
uniform float passo = 2.0;
uniform float suavizacao = .22;
uniform bool recortar_pes = false;
uniform vec2 pes;
varying vec4 tom;
void vertex() {
	tom = COLOR;
}
void fragment() {
	vec2 mundo = origem+UV*tamanho_logico;
	vec2 centro = (floor(mundo/passo)+.5)*passo;
	vec2 amostra = clamp((centro-origem)/tamanho_logico,vec2(0.),vec2(1.));
	// Filtrar dentro da célula antes de reduzir evita ruído nas lâminas finas.
	vec2 raio = vec2(passo*suavizacao)/tamanho_logico;
	vec4 a = texture(TEXTURE,clamp(amostra+raio,vec2(0.),vec2(1.)));
	vec4 b = texture(TEXTURE,clamp(amostra-raio,vec2(0.),vec2(1.)));
	vec4 c = texture(TEXTURE,clamp(amostra+vec2(raio.x,-raio.y),vec2(0.),vec2(1.)));
	vec4 d = texture(TEXTURE,clamp(amostra+vec2(-raio.x,raio.y),vec2(0.),vec2(1.)));
	float alfa = a.a+b.a+c.a+d.a;
	vec4 cor = vec4((a.rgb*a.a+b.rgb*b.a+c.rgb*c.a+d.rgb*d.a)/max(alfa,.001),alfa*.25);
	cor.rgb = floor(cor.rgb*31.+.5)/31.;
	if (recortar_pes) {
		vec2 d_pes = centro-pes;
		cor.a *= smoothstep(-8.,-5.,d_pes.y)*(1.-smoothstep(3.,7.,d_pes.y))*(1.-smoothstep(7.,12.,abs(d_pes.x)));
	}
	COLOR = cor*tom;
}
