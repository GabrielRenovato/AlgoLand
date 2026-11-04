shader_type spatial;
uniform vec3 cor : source_color = vec3(.45,.29,.17);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	float faixa = hash(vec2(floor(UV.x*21.),0.));
	float risco = step(.88,fract(UV.x*21.+sin(UV.y*17.)*.09));
	float grao = hash(floor(UV*vec2(63.,47.)));
	ALBEDO = cor*(.85+faixa*.27+grao*.10-risco*.23);
	ROUGHNESS = .96;
}
