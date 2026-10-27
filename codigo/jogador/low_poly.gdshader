shader_type spatial;
// Low poly: cada face recebe uma normal só (sombreado facetado) e a cor do vértice
// ou uma cor fixa. A luz da cena faz o resto.
render_mode diffuse_lambert, specular_disabled;
uniform vec4 cor : source_color = vec4(1.0);
uniform bool usar_cor_do_vertice = false;

void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = usar_cor_do_vertice ? COLOR.rgb : cor.rgb;
	ROUGHNESS = 1.0;
}
