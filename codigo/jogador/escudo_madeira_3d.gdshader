shader_type spatial;
render_mode diffuse_burley;
// Modo pixel (definido pelo herói): luz em faixas sem estourar e detalhes com pelo menos 1 pixel.
uniform bool luz_em_blocos = false;
varying vec2 tabua;
void vertex() { tabua=VERTEX.xz; }
void fragment() {
    float indice=floor((tabua.x+0.30)/0.12);
    float faixa=fract((tabua.x+0.30)/0.12);
    float veia=sin(tabua.y*35.0+sin(tabua.y*10.0+indice)*1.5+indice*3.0);
    // No modo pixel as tábuas alternam claro/escuro com contraste suficiente para sobreviver
    // às rampas de cor mesmo na sombra.
    float alterna=luz_em_blocos ? (mod(indice,2.0)<1.0 ? 0.25 : 0.75) : 0.4+0.17*sin(indice*2.0);
    vec3 madeira=mix(vec3(0.55,0.35,0.235),vec3(0.75,0.54,0.31),alterna);
    if (!luz_em_blocos) madeira*=1.0-0.11*smoothstep(0.75,1.0,veia);
    float distancia=min(faixa,1.0-faixa);
    float junta=1.0-smoothstep(0.015,0.055,distancia);
    // Junta com ~1 pixel de largura (fina demais some na grade). Visto de lado a tábua fica
    // mais estreita que um pixel: aí só a alternância de tons aparece, sem junta cobrindo tudo.
    if (luz_em_blocos) {
        float largura=fwidth(faixa);
        junta=largura>0.4 ? 0.0 : step(distancia,clamp(largura*0.9,0.05,0.2));
    }
    ALBEDO=mix(madeira,vec3(0.38,0.25,0.23)*(luz_em_blocos ? 0.75 : 1.0),junta*(luz_em_blocos ? 1.0 : 0.8));
    ROUGHNESS=1.0;
    SPECULAR=0.0;
    if (luz_em_blocos) {
        AO=0.75;
        AO_LIGHT_AFFECT=0.0;
    }
}
void light() {
    float n=dot(NORMAL,LIGHT)*ATTENUATION;
    // Pixel: duas faixas como o corpo, mas sombra menos escura para a madeira não virar um tom só.
    float f=luz_em_blocos ? (n<0.12 ? 0.65 : 1.0)*0.75 : max(n,0.0);
    DIFFUSE_LIGHT+=LIGHT_COLOR*f/PI;
}
