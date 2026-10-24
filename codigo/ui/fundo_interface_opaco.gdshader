shader_type canvas_item;

// COLOR já contém a textura e a modulação do CanvasItem.
// Reforça apenas o alfa da madeira, preservando os cantos transparentes.
void fragment() {
	COLOR.a = min(1.0, COLOR.a * 1.1);
}
