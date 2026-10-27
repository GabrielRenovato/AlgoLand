shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 cor : source_color = vec4(1.0);
uniform bool usar_cor_do_vertice = false;
uniform bool tingir_roupa = false;
uniform bool luz_em_blocos = false;
uniform int acabamento_roupa = 0;
uniform int modelo_roupa = 0;
uniform bool desenho_pixel_roupas = false;
uniform sampler2D desenho_roupa : source_color, filter_nearest, repeat_disable;
uniform float altura_botas = 0.30;
uniform bool usar_textura_cabelo = false;
uniform sampler2D textura_cabelo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool desenho_pixel_cabeca = false;
uniform sampler2D desenho_rosto : source_color, filter_nearest, repeat_disable;
uniform sampler2D desenho_cabelo : source_color, filter_nearest, repeat_enable;
// No estudo, conservar o azul e as gradações da referência anexada.
uniform bool tingir_olhos_desenho = false;
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
uniform bool casaca_mordomo = false;
uniform bool elmo_fechado = false;
uniform float altura_grevas = 0.;
uniform bool recortar_cartola = false;
// Personalização: cor do cabelo (branco = cor pintada original), olhos.
uniform vec4 cor_cabelo : source_color = vec4(1.0);
uniform bool olhos_fechados = false;
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
    if (luz_em_blocos) faixa=n<0.08 ? 0.56 : (n<0.58 ? 0.80 : 1.0);
    DIFFUSE_LIGHT += LIGHT_COLOR * faixa / PI;
}
// Desenho vetorial no espaço da cabeça: curvas contínuas, sem grade de pixels.
float elipse(vec2 p, vec2 raios) {
    float d = length(p/raios);
    if (luz_em_blocos) return step(d,1.0);
    float aa = max(fwidth(d),0.005);
    return 1.0-smoothstep(1.0-aa,1.0+aa,d);
}
float traco(float distancia, float largura) {
    if (luz_em_blocos) return step(abs(distancia),largura);
    float aa = max(fwidth(distancia),0.0001);
    return 1.0-smoothstep(largura-aa,largura+aa,abs(distancia));
}
// Atlas2x2 sem mipmaps: manter as amostras dentro de cada painel.
vec2 painel_tecido(vec2 uv, vec2 painel) {
    return (clamp(uv,vec2(0.025),vec2(0.975))+painel)*0.5;
}
vec2 uv_desenho_roupa(vec3 p) {
    vec2 painel=vec2(p.z>=0.015 ? 0.0 : 1.0,0.0);
    vec2 uv;
    if (acabamento_roupa==1) {
        uv=vec2((p.x+0.28)/0.56,(1.58-p.y)/0.62);
        if (abs(p.x)>0.27) {
            painel=vec2(0.0,1.0);
            uv=vec2((abs(p.x)-0.26)/0.46,(1.58-p.y)/0.30);
        }
    } else if (acabamento_roupa==2) {
        uv=vec2((p.x+0.27)/0.54,(1.04-p.y)/0.80);
        if (modelo_roupa>=3) {
            painel.y=1.0;
            uv=vec2((p.x+0.36)/0.72,(1.04-p.y)/(modelo_roupa==3 ? 0.35 : 0.42));
        }
    } else {
        float x_pe=p.x-sign(p.x)*0.089;
        uv=vec2(x_pe/0.20+0.5,1.0-p.y/0.35);
        if (abs(x_pe)>0.060) {
            painel=vec2(1.0,1.0);
            uv.x=(p.z+0.11)/0.29;
        } else if (p.y<0.13 && p.z>0.04) {
            painel=vec2(0.0,1.0);
            uv.y=1.0-(p.z+0.10)/0.28;
        }
    }
    return painel_tecido(uv,painel);
}
void fragment() {
    if (elmo_fechado && usar_cor_do_vertice && COLOR.r>.25 && COLOR.r<.75) discard;
    if (acabamento_roupa==2 && UV.y<altura_grevas) discard;
    if (recortar_cartola) {
        if (usar_textura_cabelo && UV2.y>.235) discard;
        if (usar_cor_do_vertice && COLOR.r>.25 && COLOR.r<.75 && COLOR.b*.32-.03>.235) discard;
    }
    // Os braços novos guardam a coordenada transversal em UV2.x e o marcador2.
    // Não usar VERTEX: ele já acompanha a deformação do esqueleto.
    if (casaca_mordomo && usar_cor_do_vertice && UV2.y>1.8 && UV2.x>-.306) discard;
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
        ALBEDO = desenho_pixel_cabeca ? texture(desenho_cabelo,UV).rgb : texture(textura_cabelo,UV).rgb;
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
        if (desenho_pixel_roupas) {
            // O atlas desenha a peça; a cor do catálogo continua independente.
            vec3 base=texture(desenho_roupa,vec2(0.40,0.20)).rgb;
            vec3 pintura=texture(desenho_roupa,uv_desenho_roupa(tecido)).rgb;
            // A variação fina do fundo neutro não é desenho de costura.
            // Preservar os grupos pintados e evitar ruído de um texel no tecido.
            vec3 diferenca=abs(pintura-base);
            if (max(diferenca.r,max(diferenca.g,diferenca.b))<0.025) pintura=base;
            ALBEDO=cor.rgb*pintura/max(base,vec3(0.01));
            if (luz_em_blocos) {
                float valor=dot(pintura/max(base,vec3(0.01)),vec3(0.333333));
                float tom=valor<0.82 ? 0.72 : (valor<0.96 ? 0.90 : (valor<1.08 ? 1.0 : 1.16));
                ALBEDO=cor.rgb*tom;
            }
            // Detalhes específicos dos modelos acompanham a grade no repouso,
            // em vez de pixelizar a imagem final ou deformar a malha.
            tecido=(floor(tecido/0.0125)+0.5)*0.0125;
        }
        float frente_tecido = smoothstep(0.04,0.10,tecido.z);
        if (luz_em_blocos) frente_tecido=step(0.04,tecido.z);
        if (acabamento_roupa==1) {
            float barra = 1.0-smoothstep(0.977,0.987,tecido.y);
            float punho = smoothstep(0.400,0.410,abs(tecido.x));
            float gola = smoothstep(1.492,1.505,tecido.y);
            ALBEDO *= 1.0-0.22*max(barra,max(punho,gola));
            float carcela = (1.0-smoothstep(0.009,0.014,abs(tecido.x)))*step(1.335,tecido.y)*(1.0-step(1.494,tecido.y))*frente_tecido;
            ALBEDO *= 1.0-0.25*carcela;
            float botao = max(elipse(vec2(tecido.x,tecido.y-1.445),vec2(0.009,0.009)),elipse(vec2(tecido.x,tecido.y-1.385),vec2(0.009,0.009)))*frente_tecido;
            if (desenho_pixel_roupas) botao=0.0; // Já pintados no painel frontal.
            ALBEDO = mix(ALBEDO,vec3(0.73,0.57,0.34),botao);
            // Duas dobras curtas na barra; evita relevo de músculos do manequim.
            float vinco = traco(abs(tecido.x)-(0.175+(tecido.y-1.03)*0.22),0.007);
            vinco *= smoothstep(0.99,1.02,tecido.y)*(1.0-smoothstep(1.09,1.16,tecido.y));
            if (desenho_pixel_roupas) vinco=0.0;
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
            if (desenho_pixel_roupas) bolso=0.0;
            ALBEDO *= 1.0-0.24*bolso-0.10*lateral;
            float joelho = traco(tecido.y-(0.50+abs(tecido.x)*0.17),0.010)*frente_tecido;
            if (desenho_pixel_roupas) joelho=0.0;
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
            if (modelo_roupa>0 && (!desenho_pixel_roupas || modelo_roupa<3)) {
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
        if (desenho_pixel_cabeca) {
            // O desenho é uma textura frontal no espaço de repouso da cabeça.
            // A máscara termina antes da nuca; não é uma camada virada para a câmera.
            vec2 uv_rosto = vec2((p.x+0.15)/0.30,(0.29-p.y)/0.32);
            vec2 uv_desenho = uv_rosto;
            float lateral_rosto = abs(uv_rosto.x-0.5);
            // Aumenta apenas a altura dos olhos; o azul e os pixels vêm da fonte.
            bool area_olhos=luz_em_blocos ? (lateral_rosto>0.045 && lateral_rosto<0.205 && uv_rosto.y>0.41 && uv_rosto.y<0.575) : (lateral_rosto>0.065 && lateral_rosto<0.19 && uv_rosto.y>0.42 && uv_rosto.y<0.565);
            if (area_olhos) {
                uv_desenho.y=0.492+(uv_rosto.y-0.492)/(luz_em_blocos ? 1.30 : 1.18);
                if (luz_em_blocos) {
                    float centro_olho=uv_rosto.x<0.5 ? 0.379 : 0.621;
                    uv_desenho.x=centro_olho+(uv_rosto.x-centro_olho)/1.30;
                }
            }
            bool sobrancelha_pintada = lateral_rosto>0.07 && lateral_rosto<0.19 && uv_rosto.y>0.37 && uv_rosto.y<0.40;
            if (sobrancelha_pintada) {
                float centro_sobrancelha = uv_rosto.x<0.5 ? 0.379 : 0.621;
                uv_desenho.x=centro_sobrancelha+(uv_rosto.x-centro_sobrancelha)/0.84;
            }
            vec3 desenho = texture(desenho_rosto,uv_desenho).rgb;
            if (sobrancelha_pintada) desenho=mix(texture(desenho_rosto,vec2(0.0)).rgb,desenho,0.60);
            // Boca da arte nativa: x30..33, linha39. Desce três texels
            // na mesma malha para aproximá-la do queixo, sem mover nariz/olhos.
            vec2 pixel_rosto = floor(uv_rosto*64.0);
            if (pixel_rosto.x>=30.0 && pixel_rosto.x<34.0) {
                if (pixel_rosto.y==39.0) desenho = texture(desenho_rosto,vec2(0.0)).rgb;
                if (pixel_rosto.y==42.0) desenho = texture(desenho_rosto,uv_rosto-vec2(0.0,3.0/64.0)).rgb;
            }
            // Pele neutra da pintura vira a pele escolhida. A íris conserva
            // a pintura original, salvo tintura explicitamente habilitada.
            bool iris_pintada = desenho.b > desenho.r*1.15 && desenho.b > desenho.g*0.95 && desenho.g > 0.09;
            bool pele_pintada = desenho.r > desenho.g*1.12 && desenho.g > desenho.b*1.12 && desenho.r > 0.35;
            // Amostrar o fundo usa o MESMO espaço de cor da textura neste renderer.
            // Não dividir por uma constante linear num render Compatibility/sRGB.
            vec3 pele_fonte = texture(desenho_rosto,vec2(0.0)).rgb;
            vec3 cor_pintada = desenho;
            if (pele_pintada) cor_pintada = pele_base.rgb * desenho / pele_fonte;
            if (luz_em_blocos && pele_pintada && length(desenho-pele_fonte)<0.06) cor_pintada=pele_base.rgb;
            // Na grade pequena a pupila ocupa um só pixel. Mesclar sua tinta
            // com o azul da própria pintura evita olhos que parecem perder a íris.
            bool pigmento_azul=desenho.b>desenho.r*1.15 && desenho.b>desenho.g*0.95;
            if (luz_em_blocos && pigmento_azul && length(desenho)<0.60) {
                vec3 iris_original=texture(desenho_rosto,vec2(0.379,0.520)).rgb;
                cor_pintada=mix(desenho,iris_original,0.60);
            }
            if (iris_pintada && tingir_olhos_desenho) cor_pintada = cor_olhos.rgb * clamp(desenho.g*3.0,0.45,1.3);
            // Dormir continua com os olhos fechados, na mesma grade do desenho.
            vec2 olho = vec2(abs(p.x)-0.036,p.y-0.133);
            if (olhos_fechados && abs(olho.x)<(luz_em_blocos ? 0.026 : 0.020) && abs(olho.y)<(luz_em_blocos ? 0.030 : 0.025)) {
                cor_pintada = pele_base.rgb;
                if (abs(olho.y)<0.004) cor_pintada = cor_rosto.rgb;
            }
            float dentro = step(0.0,uv_rosto.x)*step(uv_rosto.x,1.0)*step(0.0,uv_rosto.y)*step(uv_rosto.y,1.0);
            ALBEDO = mix(ALBEDO,cor_pintada,frente*dentro);
        } else {
        vec2 olho_p = vec2(abs(p.x)-0.040,p.y-0.138);
        vec3 tinta = vec3(0.065,0.045,0.085);
        float branco = elipse(olho_p,vec2(0.027,0.037))*frente*(olhos_fechados ? 0.0 : 1.0);
        ALBEDO = mix(ALBEDO,branco_olho.rgb,branco);
        float iris = elipse(olho_p-vec2(0.0,-0.002),vec2(0.017,0.027))*branco;
        ALBEDO = mix(ALBEDO,cor_olhos.rgb,iris);
        float pupila = elipse(olho_p-vec2(0.0,-0.002),vec2(0.010,0.018))*iris;
        ALBEDO = mix(ALBEDO,tinta,pupila);
        float brilho = elipse(olho_p-vec2(-0.005,0.009),vec2(0.0055,0.006))*iris;
        ALBEDO = mix(ALBEDO,vec3(1.0),brilho);
        // Íris e pálpebra legíveis também na renderização pequena do personagem.
        float arco = 0.034*sqrt(max(0.0,1.0-pow(olho_p.x/0.027,2.0)));
        if (olhos_fechados) { arco = -0.007 - 0.005*max(0.0,1.0-pow(olho_p.x/0.027,2.0)); }
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
    }
    // Brilho de borda: separa o boneco do fundo, mais forte nas costas da luz.
    RIM = forca_borda;
    RIM_TINT = 0.6;
    if (luz_em_blocos) {
        RIM=0.0;
        SPECULAR=0.0;
    }
}
