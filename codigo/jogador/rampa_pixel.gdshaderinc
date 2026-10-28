// Rampas de cor no estilo de pintura pixel art: degraus de luminosidade com leve
// deslocamento de matiz (sombra roxa, luz quente). Usado pelo personagem e pelo filtro do mapa.
uniform float tons = 5.0; // Degraus por rampa: 5 mantém o sombreado pintado do rosto e do cabelo.
uniform vec3 cor_sombra : source_color = vec3(0.32, 0.20, 0.36);
uniform vec3 cor_luz : source_color = vec3(1.0, 0.96, 0.90);
vec3 rampa(vec3 cor) {
    float lum=dot(cor,vec3(.299,.587,.114));
    if (lum<.001) return cor;
    vec3 croma=cor/lum;
    // Saturação levemente maior, como na pintura de pixel art de cores limpas.
    croma=mix(vec3(1.0),croma,1.15);
    float degrau=clamp(floor(lum*tons+.5)/tons,1.0/tons,1.0)*.92;
    vec3 saida=croma*degrau;
    // Sombras frias/roxas e luzes quentes: o deslocamento de matiz das rampas.
    float t=clamp((degrau-.5)*2.0,-1.0,1.0);
    // Deslocamento sutil: forte demais, a pele virava dois matizes e trocava de cor com a pose.
    saida=t<0.0 ? mix(saida,saida*cor_sombra/max(dot(cor_sombra,vec3(.333)),.01),-t*.18)
                : mix(saida,saida*cor_luz,t*.08);
    // Reduz a cor inteira em vez de cortar um canal: cortar o vermelho amarelava a pele nos tons claros.
    saida/=max(1.0,max(saida.r,max(saida.g,saida.b)));
    return clamp(saida,0.0,1.0);
}

