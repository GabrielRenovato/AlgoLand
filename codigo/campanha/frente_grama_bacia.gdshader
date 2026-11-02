shader_type canvas_item;
uniform vec2 pes;
uniform vec2 origem;
varying vec4 tom;
void vertex() { tom = COLOR; }
void fragment() {
	vec4 cor = texture(TEXTURE,UV);
	vec2 d = origem+UV*vec2(64.,48.)-pes;
	cor.a *= smoothstep(-8.,-5.,d.y)*(1.-smoothstep(3.,7.,d.y))*(1.-smoothstep(7.,12.,abs(d.x)));
	COLOR = cor*tom;
}
