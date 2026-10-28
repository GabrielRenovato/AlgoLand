shader_type canvas_item;
render_mode unshaded;
// Teste (F3 → VISUAL DA FAZENDA): aplica ao mundo as mesmas rampas de pintura do personagem.
#include "res://codigo/jogador/rampa_pixel.gdshaderinc"
uniform sampler2D tela : hint_screen_texture, filter_nearest;
void fragment() {
    COLOR=vec4(rampa(texture(tela,SCREEN_UV).rgb),1.0);
}
