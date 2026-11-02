shader_type canvas_item;
uniform vec4 cor_listras : source_color = vec4(0.25,0.54,0.35,1);
varying vec4 cor_vertice;
void vertex() { cor_vertice=COLOR; }
void fragment() {
	vec4 c=texture(TEXTURE,UV);
	// Só muda o tecido vermelho do toldo; produtos, madeira e listras claras preservados.
	if(UV.y<0.47 && c.r>c.g*1.4 && c.r>c.b*1.6) {
		float luz=clamp(c.r/0.75,0.35,1.35);
		c.rgb=cor_listras.rgb*luz;
	}
	COLOR=c*cor_vertice;
}
