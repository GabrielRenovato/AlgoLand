shader_type canvas_item;
render_mode unshaded;
// Acabamento da grade nativa: preserva as cores pintadas, sem paleta global.
// Contorno de um texel somente nas laterais e na borda inferior da silhueta.
varying vec4 modulacao;
void vertex() {modulacao=COLOR;}
void fragment() {
    vec4 pixel=texture(TEXTURE,UV);
    vec4 esquerda=texture(TEXTURE,UV-vec2(TEXTURE_PIXEL_SIZE.x,0.0));
    vec4 direita=texture(TEXTURE,UV+vec2(TEXTURE_PIXEL_SIZE.x,0.0));
    vec4 acima=texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y));
    if (pixel.a<0.01) {
        vec3 soma=vec3(0.0);
        float quantidade=0.0;
        if (esquerda.a>0.95) {soma+=esquerda.rgb;quantidade+=1.0;}
        if (direita.a>0.95) {soma+=direita.rgb;quantidade+=1.0;}
        if (acima.a>0.95) {soma+=acima.rgb;quantidade+=1.0;}
        if (quantidade>0.0) {
            vec3 vizinho=soma/quantidade;
            pixel=vec4(mix(vizinho*0.58,vec3(0.15,0.12,0.17),0.28),1.0);
        }
    }
    COLOR=pixel*modulacao;
}
