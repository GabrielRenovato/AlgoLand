shader_type spatial;
uniform vec3 cor : source_color = vec3(.45,.29,.17);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	float curva = UV.x*18.+sin(UV.y*5.+UV.x*19.)*.19;
	float faixa = hash(vec2(floor(curva),0.));
	float sulco = smoothstep(.69,.91,fract(curva));
	float fibra = sin(curva*18.+sin(UV.y*21.)*.5)*.025;
	float grao = hash(floor(UV*vec2(94.,90.)));
	ALBEDO = cor*(1.02+faixa*.045+grao*.015-sulco*.045+fibra*.25);
	ROUGHNESS = .96;
}
