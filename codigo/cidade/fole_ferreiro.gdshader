shader_type canvas_item;
uniform float pressao : hint_range(0.0,1.0) = 1.0;
varying vec4 tinta;
void vertex() { tinta = COLOR; }
void fragment() {
	vec2 ponto = UV * vec2(48.0,29.0);
	float deslocamento = (4.0 + pressao * 7.0) * clamp(1.0-ponto.x/35.0,0.0,1.0);
	float topo = 4.0 + min(ponto.x,35.0)*0.37;
	float topo_atual = topo + deslocamento;
	vec2 origem = ponto;
	// Alavanca gira na dobradiça; sanfona comprime; placa inferior e pés ficam apoiados.
	if (ponto.y < topo_atual) origem.y -= deslocamento;
	else if (ponto.y < 23.0) origem.y = topo + (ponto.y-topo_atual)*(23.0-topo)/max(1.0,23.0-topo_atual);
	COLOR = origem.y < 0.0 ? vec4(0.0) : texture(TEXTURE,origem/vec2(48.0,29.0))*tinta;
}
