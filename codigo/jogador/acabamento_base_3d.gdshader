shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 cor : source_color = vec4(1.0);
uniform bool usar_cor_do_vertice = false;
uniform bool tingir_roupa = false;
uniform int acabamento_roupa = 0;
uniform int modelo_roupa = 0;
uniform float altura_botas = 0.30;
uniform bool usar_textura_cabelo = false;
uniform sampler2D textura_cabelo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 pele_sombra : source_color;
uniform vec4 pele_meio : source_color;
uniform vec4 pele_base : source_color;
uniform vec4 pele_luz : source_color;
uniform vec4 short_sombra : source_color;
uniform vec4 short_base : source_color;
uniform vec4 short_luz : source_color;
uniform vec4 cor_rosto : source_color;
uniform vec4 branco_olho : source_color;
uniform bool esconder_camisa = false;
// Personalização: cor do cabelo (branco = cor pintada original), olhos.
uniform vec4 cor_cabelo : source_color = vec4(1.0);
uniform vec4 cor_olhos : source_color = vec4(0.29, 0.22, 0.20, 1.0);
// Penteado raspado: cabelo curtinho pintado no couro cabeludo, acima da linha do cabelo.
uniform bool raspado = false;
uniform vec4 cor_raspado : source_color = vec4(0.36, 0.24, 0.16, 1.0);
uniform bool esconder_calca = false;
uniform bool esconder_botas = false;
// Acabamento toon: luz em três faixas e brilho de borda. `inflar` engorda a malha
// (corpo e roupa juntos, sem o cabelo) para membros mais roliços de chibi.
uniform float inflar = 0.0; // >0 abre frestas nas juntas do manequim (peças separadas); deixar 0.
uniform float sombra_minima = 0.42;
uniform vec4 cor_borda : source_color = vec4(1.0, 0.93, 0.82, 1.0);
uniform float forca_borda = 0.22;

void vertex() {
    if (!usar_textura_cabelo) VERTEX += NORMAL * inflar;
}

void light() {
    float n = dot(NORMAL, LIGHT) * ATTENUATION;
    float faixa = mix(sombra_minima, 0.78, smoothstep(0.0, 0.06, n));
    faixa = mix(faixa, 1.0, smoothstep(0.55, 0.62, n));
    DIFFUSE_LIGHT += LIGHT_COLOR * faixa / PI;
}
// Desenho vetorial no espaço da cabeça: curvas contínuas, sem grade de pixels.
float elipse(vec2 p, vec2 raios) {
    float d = length(p/raios);
    float aa = max(fwidth(d),0.005);
    return 1.0-smoothstep(1.0-aa,1.0+aa,d);
}
float traco(float distancia, float largura) {
    float aa = max(fwidth(distancia),0.0001);
    return 1.0-smoothstep(largura-aa,largura+aa,abs(distancia));
}
void fragment() {
    ROUGHNESS = 0.82;
    SPECULAR = 0.25;
    // UV2 guarda apenas a cobertura da roupa no corpo em repouso.
    if (usar_cor_do_vertice) {
        if (esconder_camisa && UV2.x > 0.0) discard;
        if (esconder_calca && UV2.y > 0.24 && UV2.y < 1.025) discard;
        if (esconder_botas && UV2.y < altura_botas) discard;
        ALBEDO = mix(pele_base.rgb,short_base.rgb,step(0.75,COLOR.r));
    } else {
        ALBEDO = cor.rgb*(tingir_roupa ? COLOR.rgb : vec3(1.0));
    }
    if (usar_textura_cabelo) {
        ALBEDO = texture(textura_cabelo,UV).rgb;
        // Tinge pela luminância da pintura, mantendo mechas e brilhos; branco não altera.
        if (any(lessThan(cor_cabelo.rgb, vec3(0.99)))) {
            float luz = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
            ALBEDO = clamp(cor_cabelo.rgb * luz * 2.1, 0.0, 1.0);
        }
        ROUGHNESS = 1.0;
        SPECULAR = 0.0;
    }
    // Coordenadas de costura em repouso: os detalhes acompanham o tecido no rig.
    if (acabamento_roupa>0) {
        vec3 tecido = vec3(UV.x,UV.y,UV2.x);
        float frente_tecido = smoothstep(0.04,0.10,tecido.z);
        if (acabamento_roupa==1) {
            float barra = 1.0-smoothstep(0.977,0.987,tecido.y);
            float punho = smoothstep(0.400,0.410,abs(tecido.x));
            float gola = smoothstep(1.492,1.505,tecido.y);
            ALBEDO *= 1.0-0.22*max(barra,max(punho,gola));
            float carcela = (1.0-smoothstep(0.009,0.014,abs(tecido.x)))*step(1.335,tecido.y)*(1.0-step(1.494,tecido.y))*frente_tecido;
            ALBEDO *= 1.0-0.25*carcela;
            float botao = max(elipse(vec2(tecido.x,tecido.y-1.445),vec2(0.009,0.009)),elipse(vec2(tecido.x,tecido.y-1.385),vec2(0.009,0.009)))*frente_tecido;
            ALBEDO = mix(ALBEDO,vec3(0.73,0.57,0.34),botao);
            // Duas dobras curtas na barra; evita relevo de músculos do manequim.
            float vinco = traco(abs(tecido.x)-(0.175+(tecido.y-1.03)*0.22),0.007);
            vinco *= smoothstep(0.99,1.02,tecido.y)*(1.0-smoothstep(1.09,1.16,tecido.y));
            ALBEDO *= 1.0-0.16*vinco;
            if (modelo_roupa==1) {
                float bolso_peito = step(-0.16,tecido.x)*(1.0-step(-0.055,tecido.x))*step(1.24,tecido.y)*(1.0-step(1.34,tecido.y))*frente_tecido;
                ALBEDO *= 1.0-0.18*bolso_peito;
                float costura = traco(tecido.y-1.34,0.005)*step(-0.16,tecido.x)*(1.0-step(-0.055,tecido.x))*frente_tecido;
                ALBEDO *= 1.0-0.20*costura;
            } else if (modelo_roupa==2) {
                float cinto=step(1.055,tecido.y)*(1.0-step(1.095,tecido.y));
                ALBEDO=mix(ALBEDO,vec3(.24,.17,.15),cinto);
                float fivela=(1.0-smoothstep(.017,.025,abs(tecido.x)))*cinto*frente_tecido;
                ALBEDO=mix(ALBEDO,vec3(.75,.56,.31),fivela);
            } else if (modelo_roupa==3) {
                float abertura=(1.0-smoothstep(.014,.024,abs(tecido.x)))*frente_tecido;
                ALBEDO*=1.0-.50*abertura;
                float bolso=step(.09,abs(tecido.x))*(1.0-step(.19,abs(tecido.x)))*step(1.05,tecido.y)*(1.0-step(1.17,tecido.y))*frente_tecido;
                ALBEDO*=1.0-.20*bolso;
            }
            if (modelo_roupa==4) {
                float fita=step(1.075,tecido.y)*(1.0-step(1.11,tecido.y));
                ALBEDO=mix(ALBEDO,vec3(.75,.56,.31),fita*.8);
                float laco=elipse(vec2(abs(tecido.x)-.022,tecido.y-1.43),vec2(.025,.018))*frente_tecido;
                ALBEDO=mix(ALBEDO,vec3(.90,.80,.62),laco);
            } else if (modelo_roupa==5) {
                float abertura=(1.0-smoothstep(.014,.024,abs(tecido.x)))*frente_tecido;
                ALBEDO*=1.0-.35*abertura;
                float botao=elipse(vec2(tecido.x-.022,mod(tecido.y-1.13,.085)-.042),vec2(.006,.006))*frente_tecido;
                ALBEDO=mix(ALBEDO,vec3(.90,.80,.62),botao*step(1.12,tecido.y));
            }
        } else if (acabamento_roupa==2) {
            float cos_calca = smoothstep(1.005,1.020,tecido.y);
            ALBEDO *= 1.0-0.30*cos_calca;
            float bolso = traco(tecido.y-(1.00-abs(tecido.x)*0.62),0.006);
            bolso *= smoothstep(0.07,0.09,abs(tecido.x))*(1.0-smoothstep(0.16,0.19,abs(tecido.x)))*frente_tecido;
            float lateral = smoothstep(0.92,0.99,abs(tecido.x)/max(0.01,0.112+0.103));
            ALBEDO *= 1.0-0.24*bolso-0.10*lateral;
            float joelho = traco(tecido.y-(0.50+abs(tecido.x)*0.17),0.010)*frente_tecido;
            ALBEDO *= 1.0-0.12*joelho;
            if (modelo_roupa==1) {
                float bolso_cargo=step(.13,abs(tecido.x))*step(.59,tecido.y)*(1.0-step(.76,tecido.y));
                ALBEDO*=1.0-.20*bolso_cargo;
                float aba=traco(tecido.y-.755,.012)*step(.13,abs(tecido.x));
                ALBEDO*=1.0-.23*aba;
            } else if (modelo_roupa==2) {
                float dobra=1.0-smoothstep(.30,.33,tecido.y);
                ALBEDO=mix(ALBEDO,ALBEDO*1.4,dobra);
            }
            if (modelo_roupa>=3) {
                float barra_y=modelo_roupa==3 ? .71 : .64;
                float meia=1.0-smoothstep(barra_y-.02,barra_y+.005,tecido.y);
                ALBEDO=mix(ALBEDO,vec3(.24,.22,.28),meia);
                float barra=traco(tecido.y-barra_y-.025,.009)*(1.0-meia);
                ALBEDO*=1.0-.26*barra;
            }
        } else {
            float sola = 1.0-smoothstep(0.040,0.048,tecido.y);
            ALBEDO = mix(ALBEDO,vec3(0.16,0.13,0.16),sola);
            float faixa = smoothstep(0.208,0.215,tecido.y)*(1.0-smoothstep(0.243,0.250,tecido.y));
            ALBEDO *= 1.0-0.28*faixa;
            float biqueira = smoothstep(0.10,0.14,tecido.z)*(1.0-smoothstep(0.08,0.12,tecido.y));
            ALBEDO *= 1.0+0.16*biqueira;
            float fivela = (1.0-smoothstep(0.014,0.022,abs(abs(tecido.x)-0.09)))*faixa*frente_tecido;
            ALBEDO = mix(ALBEDO,vec3(0.70,0.53,0.31),fivela);
            if (modelo_roupa>0) {
                float cadarco=step(.09,tecido.y)*(1.0-step(.19,tecido.y))*frente_tecido;
                float faixa_cadarco=1.0-smoothstep(.004,.008,abs(mod(tecido.y-.10,.03)-.015));
                ALBEDO=mix(ALBEDO,vec3(.75,.64,.46),cadarco*faixa_cadarco*.8);
            }
        }
        ROUGHNESS = 0.95;
        SPECULAR = 0.05;
    }
    // Coordenadas do rosto gravadas na pele em repouso. A animação deforma
    // a malha e estes atributos juntos: nenhuma peça fica solta na frente da cabeça.
    if (usar_cor_do_vertice && COLOR.r > 0.25 && COLOR.r < 0.75) {
        vec3 p = vec3(COLOR.g*0.30-0.15,COLOR.b*0.32-0.03,COLOR.a*0.32-0.16);
        float frente = smoothstep(0.030,0.040,p.z);
        if (raspado) {
            // Linha do cabelo: alta na testa, baixa na nuca; borda um pouco irregular.
            float linha = mix(0.085, 0.215, smoothstep(-0.06, 0.09, p.z)) + 0.004*sin(p.x*140.0);
            float cabelo = smoothstep(linha, linha+0.012, p.y);
            float fios = 0.88 + 0.12*sin(p.x*420.0 + p.z*380.0)*sin(p.y*510.0);
            ALBEDO = mix(ALBEDO, cor_raspado.rgb*fios, cabelo);
        }
        vec2 olho_p = vec2(abs(p.x)-0.040,p.y-0.138);
        vec3 tinta = vec3(0.065,0.045,0.085);
        float branco = elipse(olho_p,vec2(0.027,0.037))*frente;
        ALBEDO = mix(ALBEDO,branco_olho.rgb,branco);
        float iris = elipse(olho_p-vec2(0.0,-0.002),vec2(0.017,0.027))*branco;
        ALBEDO = mix(ALBEDO,cor_olhos.rgb,iris);
        float pupila = elipse(olho_p-vec2(0.0,-0.002),vec2(0.010,0.018))*iris;
        ALBEDO = mix(ALBEDO,tinta,pupila);
        float brilho = elipse(olho_p-vec2(-0.005,0.009),vec2(0.0055,0.006))*iris;
        ALBEDO = mix(ALBEDO,vec3(1.0),brilho);
        // Íris e pálpebra legíveis também na renderização pequena do personagem.
        float arco = 0.034*sqrt(max(0.0,1.0-pow(olho_p.x/0.027,2.0)));
        float cilio = traco(olho_p.y-arco,0.0030)*(1.0-smoothstep(0.025,0.029,abs(olho_p.x)))*frente;
        // Sobrancelha: arco curto acima do olho, mais grosso no meio.
        float sobrancelha = traco(olho_p.y-0.052-0.004*(1.0-pow(olho_p.x/0.026,2.0)),0.0035)*(1.0-smoothstep(0.020,0.026,abs(olho_p.x+0.002)))*frente;
        ALBEDO = mix(ALBEDO,vec3(0.24,0.15,0.11),sobrancelha*0.9);
        ALBEDO = mix(ALBEDO,tinta,cilio*0.90);
        // Conserva parte do contraste do desenho sob a luz do cenário.
        EMISSION = ALBEDO*branco*0.25;
        ALBEDO *= 1.0-branco*0.25;
        float boca = traco(p.y-0.096,0.00075)*(1.0-smoothstep(0.006,0.010,abs(p.x)))*frente;
        ALBEDO = mix(ALBEDO,vec3(0.52,0.31,0.30),boca*0.65);
    }
    // Brilho de borda: separa o boneco do fundo, mais forte nas costas da luz.
    RIM = forca_borda;
    RIM_TINT = 0.6;
}
