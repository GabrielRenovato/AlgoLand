shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D pintura : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D pintura_baixo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D pintura_cima : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 centro_baixo;
uniform vec2 centro_cima;
uniform float flexao=0.0;
uniform vec2 olhar_base;
uniform vec2 olhar_baixo;
uniform vec2 olhar_cima;
uniform vec2 centro;
uniform float inclinacao=0.0;
void vertex() {
    // Mantém a perspectiva e a escala do desenho mesmo no primeiro quadro
    // depois de uma troca de direção ou atualização do esqueleto.
    float c=cos(inclinacao);
    float s=sin(inclinacao);
    VERTEX.xy=mat2(vec2(c,s),vec2(-s,c))*VERTEX.xy;
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
        vec4(INV_VIEW_MATRIX[0].xyz,0.0),
        vec4(INV_VIEW_MATRIX[1].xyz,0.0),
        vec4(INV_VIEW_MATRIX[2].xyz,0.0),
        MODEL_MATRIX[3]);
}
uniform float queixo=320.0;
uniform vec2 pescoco;
uniform int direcao=0;
uniform bool olhos_fechados=false;
uniform vec4 olho_a;
uniform vec4 olho_b;
uniform vec4 tom_pele : source_color = vec4(.9294,.7020,.5765,1.0);
// Penteados que não são o da pintura (raspado, cacheado, longo...): o cabelo pintado sai e vira pele,
// e a malha do penteado escolhido cobre o crânio.
uniform bool sem_cabelo=false;
uniform bool cabelo_volumetrico=false;
uniform bool cabelo_raspado=false;
uniform bool tingir_cabelo=false;
uniform vec4 tinta_cabelo : source_color = vec4(1.0);
uniform bool tingir_olhos=false;
uniform vec4 tinta_olhos : source_color = vec4(1.0);
// Exclusivo dos NPCs: pigmento na própria pintura, sem geometria sobre o rosto.
uniform int pelos_faciais_npc=0;
uniform vec4 cor_pelos_faciais_npc : source_color = vec4(.20,.11,.065,1.0);
float pelos_na_pose(vec2 pixel,vec2 origem,vec2 olhar,float maxilar) {
    if (pelos_faciais_npc==0 || (direcao>=3 && direcao<=5)) return 0.0;
    float altura=max(maxilar-origem.y-olhar.y,1.0);
    vec2 rosto=(pixel-origem-olhar)/altura;
    float u=rosto.x*(direcao>=6 ? -1.0 : 1.0);
    float v=rosto.y;
    float topo=0.70-0.38*min(abs(u),1.20);
    float limite=1.35-abs(u);
    float bigode=0.0;
    if (direcao==0) {
        vec2 metade=vec2((abs(u)-.20)/.32,(v-(.52+.06*abs(u)))/.11);
        bigode=1.0-smoothstep(.82,1.0,length(metade));
    } else {
        topo=.67+.20*u;
        limite=min(u+1.45,.62-u);
        float centro_u=direcao==2 || direcao==6 ? .12 : .25;
        float largura=direcao==2 || direcao==6 ? .13 : .30;
        vec2 metade=vec2((u-centro_u)/largura,(v-.47)/.095);
        bigode=1.0-smoothstep(.82,1.0,length(metade));
    }
    bigode*=1.0-smoothstep(.61,.64,v);
    float barba=smoothstep(topo,topo+.025,v)*(1.0-smoothstep(.98,1.02,v))*smoothstep(0.0,.035,limite);
    return pelos_faciais_npc==1 ? max(barba,bigode) : bigode;
}
vec3 fechar_olho(vec2 p,vec3 cor,vec4 area) {
    if (p.x>area.x && p.x<area.z && p.y>area.y && p.y<area.w) {
        vec2 meio=(area.xy+area.zw)*.5;
        vec3 pele=texture(pintura,vec2(meio.x,area.w+4.0)/vec2(textureSize(pintura,0))).rgb;
        float x=(p.x-meio.x)/((area.z-area.x)*.5);
        float linha=meio.y+3.0+3.0*(1.0-x*x);
        float tinta=(1.0-smoothstep(1.0,2.0,abs(p.y-linha)))*(1.0-smoothstep(.8,1.0,abs(x)));
        return mix(pele,vec3(.21,.12,.085),tinta);
    }
    return cor;
}
bool valido(vec2 pixel,vec3 cor,vec2 origem) {
    // Fundo verde da pintura; reduzida (mipmap) a borda vira mistura oliva, que também sai.
    if (cor.g>cor.r*.84 && cor.g>cor.b*1.12) return false;
    float y=pixel.y-origem.y+centro.y;
    if (y>queixo+mix(12.0,2.0,abs(flexao))) return false;
    float inicio_pescoco=queixo-(direcao==7 ? 8.0 : 0.0);
    if (y>inicio_pescoco && (pixel.x<pescoco.x || pixel.x>pescoco.y)) return false;
    return true;
}
// Mesclar desenhos sem duplicar olhos: todos os marcos convergem para a
// mesma posição intermediária. Nos extremos a amostragem é a arte original.
vec2 coordenada_pose(vec2 p,vec2 olhar,vec2 alvo,float nuca) {
    vec2 resultado=p;
    if (p.y<alvo.y) {
        resultado.y=mix(-170.0,olhar.y,(p.y+170.0)/(alvo.y+170.0));
    } else {
        resultado.y=mix(olhar.y,nuca,(p.y-alvo.y)/max(nuca-alvo.y,1.0));
    }
    float face=clamp(p.y<alvo.y ? (p.y+170.0)/(alvo.y+170.0) : (nuca-p.y)/max(nuca-alvo.y,1.0),0.0,1.0);
    resultado.x+=(olhar.x-alvo.x)*face;
    return resultado;
}
void fragment() {
    float peso=abs(flexao);
    vec2 olhar_outro=flexao>=0.0 ? olhar_baixo : olhar_cima;
    vec2 olhar_alvo=mix(olhar_base,olhar_outro,peso);
    vec2 p=(UV-.5)*370.0;
    float nuca=queixo+12.0-centro.y;
    vec2 pixel=centro+coordenada_pose(p,olhar_base,olhar_alvo,nuca);
    vec2 dimensao=vec2(textureSize(pintura,0));
    // Mipmap um nível mais nítido: reduz sem embaralhar e sem misturar o fundo da pintura.
    vec3 cor=texture(pintura,pixel/dimensao,-1.0).rgb;
    vec2 outro_pixel=(flexao>=0.0 ? centro_baixo : centro_cima)+coordenada_pose(p,olhar_outro,olhar_alvo,nuca);
    vec3 outra=flexao>=0.0 ? texture(pintura_baixo,outro_pixel/dimensao,-1.0).rgb : texture(pintura_cima,outro_pixel/dimensao,-1.0).rgb;
    bool a=valido(pixel,cor,centro);
    bool b=valido(outro_pixel,outra,flexao>=0.0 ? centro_baixo : centro_cima);
    if (mix(a ? 1.0 : 0.0,b ? 1.0 : 0.0,peso)<.5) discard;
    if (!a) cor=outra;
    if (!b) outra=cor;
    cor=mix(cor,outra,peso);
    if (olhos_fechados) {
        cor=fechar_olho(pixel,cor,olho_a);
        cor=fechar_olho(pixel,cor,olho_b);
    }
    vec3 paleta=cor;
    bool iris=paleta.b>paleta.r*1.15 && paleta.b>paleta.g*.95 && paleta.b>.25;
    bool pele=paleta.r>.50 && paleta.g>paleta.r*.58 && paleta.b>paleta.r*.42 && paleta.r>paleta.g*1.08;
    bool cabelo_pintado=!iris && !pele && paleta.r>paleta.g*1.05 && paleta.r>paleta.b*1.10;
    bool vista_nuca=direcao>=3 && direcao<=5;
    bool acima_testa=(pixel.y-centro.y)<olhar_alvo.y-90.0;
    if (sem_cabelo && ((cabelo_pintado && ((pixel.y-centro.y)<olhar_alvo.y-6.0 || vista_nuca)) || acima_testa)) {
        if (cabelo_volumetrico) discard;
        if (cabelo_raspado) {
            // Aparar a silhueta antiga e pintar fios curtos, sem transformar cabelo em pele.
            if (length((pixel-centro)/vec2(138.0,128.0))>1.0) discard;
            vec3 tinta=tingir_cabelo ? tinta_cabelo.rgb : vec3(.20,.10,.06);
            float fios=.72+.13*sin(pixel.x*2.4)*sin(pixel.y*2.1);
            cor=mix(tom_pele.rgb*.65,tinta,fios);
        } else {
            cor=tom_pele.rgb*.80;
        }
    } else if (iris && direcao>=3 && direcao<=5) {
        cor=tom_pele.rgb*.65;
    } else if (iris && tingir_olhos) {
        // A referência vem da própria textura, no espaço de cor do renderer.
        // Dividir por .12 estourava a íris no Compatibility, apagando seus detalhes.
        vec3 iris_fonte=texture(pintura,vec2(220.0,250.0)/dimensao).rgb;
        vec3 luminancia=vec3(.2126,.7152,.0722);
        float valor=dot(cor,luminancia)/max(dot(iris_fonte,luminancia),.01);
        cor=tinta_olhos.rgb*valor;
    } else if (pele) {
        cor*=tom_pele.rgb/vec3(.9294,.7020,.5765);
    } else if (tingir_cabelo && !iris && paleta.r>paleta.g*1.05 && paleta.r>paleta.b*1.10) {
        cor=tinta_cabelo.rgb*clamp(dot(cor,vec3(.2126,.7152,.0722))/.28,.35,1.25);
    }
    if (pelos_faciais_npc>0 && !vista_nuca && !iris) {
        // Mesma interpolação e os mesmos marcos do rosto: não desliza ao acenar.
        float base=pelos_na_pose(pixel,centro,olhar_base,queixo);
        vec2 outro_centro=flexao>=0.0 ? centro_baixo : centro_cima;
        float outra_pose=pelos_na_pose(outro_pixel,outro_centro,olhar_outro,queixo+outro_centro.y-centro.y);
        float mascara=mix(base,outra_pose,peso);
        bool pele_facial=paleta.r>.35 && paleta.g>paleta.r*.52 && paleta.b>paleta.r*.32;
        if (pele_facial) {
            float volume=clamp(dot(paleta,vec3(.2126,.7152,.0722))/.67,.60,1.10);
            cor=mix(cor,cor_pelos_faciais_npc.rgb*volume,mascara);
        }
    }
    ALBEDO=clamp(cor,vec3(0.0),vec3(1.0));
}
