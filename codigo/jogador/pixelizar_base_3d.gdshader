shader_type canvas_item;
render_mode unshaded;
// Recebe a renderização 3D pequena. A textura permanece na grade nativa.
// Paleta autoral registrada em arte/fontes/personagens/base_3d/paleta_pixel_art.json.
const vec3 PALETA[28] = {
    vec3(41.0,38.0,55.0)/255.0,
    vec3(152.0,85.0,99.0)/255.0,
    vec3(194.0,123.0,112.0)/255.0,
    vec3(230.0,160.0,126.0)/255.0,
    vec3(246.0,199.0,153.0)/255.0,
    vec3(255.0,229.0,185.0)/255.0,
    vec3(38.0,54.0,83.0)/255.0,
    vec3(53.0,79.0,115.0)/255.0,
    vec3(75.0,118.0,150.0)/255.0,
    vec3(113.0,162.0,178.0)/255.0,
    vec3(166.0,198.0,192.0)/255.0,
    vec3(61.0,41.0,54.0)/255.0,
    vec3(97.0,65.0,59.0)/255.0,
    vec3(140.0,90.0,60.0)/255.0,
    vec3(191.0,137.0,80.0)/255.0,
    vec3(68.0,54.0,66.0)/255.0,
    vec3(110.0,80.0,72.0)/255.0,
    vec3(149.0,113.0,78.0)/255.0,
    vec3(192.0,156.0,103.0)/255.0,
    vec3(51.0,41.0,54.0)/255.0,
    vec3(82.0,49.0,61.0)/255.0,
    vec3(125.0,73.0,75.0)/255.0,
    vec3(230.0,213.0,184.0)/255.0,
    vec3(255.0,240.0,203.0)/255.0,
    vec3(60.0,75.0,63.0)/255.0,
    vec3(92.0,113.0,78.0)/255.0,
    vec3(135.0,150.0,106.0)/255.0,
    vec3(176.0,184.0,130.0)/255.0
};
varying vec4 modulacao;
void vertex() {
    modulacao = COLOR;
}
void fragment() {
    vec4 pixel = texture(TEXTURE,UV);
    float alfa = step(0.5,pixel.a);
    // Escolhe uma cor da paleta inteira, sem criar tons intermediários.
    vec3 cor_pixel = PALETA[0];
    float menor_distancia = 10.0;
    for (int i=0;i<28;i++) {
        vec3 diferenca = pixel.rgb-PALETA[i];
        float distancia = dot(diferenca*diferenca,vec3(0.30,0.59,0.11));
        if (distancia<menor_distancia) {
            menor_distancia=distancia;
            cor_pixel=PALETA[i];
        }
    }
    // Um texel da renderização equivale a meio pixel de mundo: borda fina,
    // só por fora da silhueta, sem escurecer os detalhes internos do rosto.
    float vizinho = max(max(texture(TEXTURE,UV+vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a,
                            texture(TEXTURE,UV-vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a),
                        max(texture(TEXTURE,UV+vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a,
                            texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a));
    if (alfa<0.5 && vizinho>=0.5) {
        cor_pixel=PALETA[0];
        alfa=1.0;
    }
    COLOR = vec4(cor_pixel,alfa)*modulacao;
}
