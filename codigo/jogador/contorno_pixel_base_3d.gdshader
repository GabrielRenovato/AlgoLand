shader_type canvas_item;
render_mode unshaded;
// Acabamento da grade nativa no estilo de pintura do Mana Seed (sem usar a arte dele):
// rampas curtas por cor (sombra puxa para o roxo, luz para o quente) e contorno escuro
// colorido de 1 texel em toda a silhueta.
uniform bool estilo_mana = true;
#include "res://codigo/jogador/rampa_pixel.gdshaderinc"
uniform vec3 cor_contorno : source_color = vec3(0.13, 0.08, 0.14);
varying vec4 modulacao;
void vertex() {modulacao=COLOR;}

void fragment() {
    vec4 pixel=texture(TEXTURE,UV);
    vec2 px=TEXTURE_PIXEL_SIZE;
    vec4 esquerda=texture(TEXTURE,UV-vec2(px.x,0.0));
    vec4 direita=texture(TEXTURE,UV+vec2(px.x,0.0));
    vec4 acima=texture(TEXTURE,UV-vec2(0.0,px.y));
    vec4 abaixo=texture(TEXTURE,UV+vec2(0.0,px.y));
    vec4 saida=pixel;
    if (!estilo_mana) {
        if (pixel.a<0.01) {
            vec3 soma=vec3(0.0);
            float quantidade=0.0;
            if (esquerda.a>0.95) {soma+=esquerda.rgb;quantidade+=1.0;}
            if (direita.a>0.95) {soma+=direita.rgb;quantidade+=1.0;}
            if (acima.a>0.95) {soma+=acima.rgb;quantidade+=1.0;}
            if (quantidade>0.0) {
                vec3 vizinho=soma/quantidade;
                saida=vec4(mix(vizinho*0.58,vec3(0.15,0.12,0.17),0.28),1.0);
            }
        }
    } else if (pixel.a<0.5) {
        // Contorno em volta de toda a silhueta, tingido pela cor vizinha.
        vec3 soma=vec3(0.0);
        float quantidade=0.0;
        if (esquerda.a>0.5) {soma+=esquerda.rgb;quantidade+=1.0;}
        if (direita.a>0.5) {soma+=direita.rgb;quantidade+=1.0;}
        if (acima.a>0.5) {soma+=acima.rgb;quantidade+=1.0;}
        if (abaixo.a>0.5) {soma+=abaixo.rgb;quantidade+=1.0;}
        saida=quantidade>0.0 ? vec4(mix(cor_contorno,soma/quantidade*.35,.35),1.0) : vec4(0.0);
    } else {
        // Pixel solto: se os 4 vizinhos concordam entre si e ele destoa, assume a cor deles.
        vec3 media=(esquerda.rgb+direita.rgb+acima.rgb+abaixo.rgb)*.25;
        float espalhamento=max(max(distance(esquerda.rgb,media),distance(direita.rgb,media)),max(distance(acima.rgb,media),distance(abaixo.rgb,media)));
        bool vizinhos_opacos=min(min(esquerda.a,direita.a),min(acima.a,abaixo.a))>.5;
        vec3 base=pixel.rgb;
        if (vizinhos_opacos && espalhamento<.09 && distance(pixel.rgb,media)>.10) base=media;
        saida=vec4(rampa(base),1.0);
    }
    COLOR=saida*modulacao;
}
