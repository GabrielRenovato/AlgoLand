shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 cor_base : source_color = vec4(1.0,0.65,0.15,1.0);
uniform float tempo = 0.0;
varying float fase;
void vertex() {
	fase = VERTEX.x*13.0+VERTEX.z*5.0;
	float ponta = clamp((VERTEX.y-0.36)/0.44,0.0,1.0);
	// A base continua sobre o carvão; só o corpo e as pontas das chamas oscilam.
	VERTEX.x += sin(tempo*3.14159265+fase)*0.055*ponta;
	VERTEX.y += sin(tempo*6.28318530+fase*0.6)*0.065*ponta;
	VERTEX.z += sin(tempo*9.42477796+fase)*0.012*ponta;
}
void fragment() {
	float brilho = 0.91+0.09*sin(tempo*6.28318530+fase);
	ALBEDO = cor_base.rgb*brilho;
	EMISSION = cor_base.rgb*(0.12+0.06*brilho);
	ROUGHNESS = 1.0;
}
