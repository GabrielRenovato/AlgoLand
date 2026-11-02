shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 c=texture(TEXTURE,UV);
	// Fecha o alfa residual da exportação dentro das superfícies sólidas.
	if (c.a>=0.97) c.a=1.0;
	COLOR=c;
}
