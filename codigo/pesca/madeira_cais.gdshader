shader_type canvas_item;
uniform int estacao = 0;
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
 vec2 p = floor(mundo);
 float linha = floor(p.y / 8.0);
 float emenda = mod(p.x + mod(linha, 3.0) * 16.0, 48.0);
 float altura = mod(p.y, 8.0);
 float variacao = fract(sin(linha * 31.17 + floor((p.x + mod(linha, 3.0)*16.0)/48.0)*13.7)*143.7);
 vec3 base = vec3(0.56, 0.34, 0.16);
 if(estacao == 1) base = vec3(0.63, 0.40, 0.20);
 if(estacao == 2) base = vec3(0.49, 0.30, 0.17);
 if(estacao == 3) base = vec3(0.44, 0.35, 0.26);
 vec3 cor = base + (variacao - 0.5) * 0.06;
 if(altura == 0.0) cor *= 0.58;
 if(altura == 1.0) cor += vec3(0.10, 0.08, 0.045);
 if(emenda == 0.0) cor *= 0.66;
 // Veios curtos e pregos em grupos de pixels, sem ruído subpixel.
 float veio = mod(p.x + linha*7.0, 29.0);
 if(altura == 5.0 && veio<12.0) cor *= 0.86;
 if(altura == 3.0 && veio>19.0 && veio<26.0) cor += vec3(0.035,0.025,0.012);
 // Nós pequenos, espaçados e desenhados em pixels inteiros.
 if(variacao>0.73) {
  vec2 no = vec2(emenda-23.0,(altura-4.0)*1.8);
  float raio = dot(no,no);
  if(raio<13.0 && raio>5.0) cor *= 0.79;
  if(raio<2.0) cor *= 0.64;
 }
 if((emenda == 3.0 || emenda == 45.0) && (altura == 2.0 || altura == 6.0)) cor = base*0.47;
 COLOR = vec4(cor, 1.0);
}
