shader_type canvas_item;
render_mode unshaded;
uniform float raio = 180.0;
uniform float invocacao = 0.0;
uniform float impacto = -1.0;
uniform float relogio = 0.0;
float linha(float d, float centro, float largura) {
 return 1.0 - step(largura, abs(d - centro));
}
void fragment() {
 // Cada pixel do desenho corresponde a um pixel do mapa.
 vec2 p = floor((UV - vec2(0.5)) * 384.0) + vec2(0.5);
 float d = length(p);
 float a = atan(p.y, p.x);
 float r = max(5.0, raio * invocacao);
 float limite = 1.0 - step(r + 2.0, d);
 float anel = linha(d, r, 1.3);
 float borda = linha(d, r - 5.0, 0.7);
 float trama = linha(d, r - 16.0 + sin(a * 12.0 + relogio * 2.0) * 3.0, 0.9);
 float trama2 = linha(d, r - 16.0 - sin(a * 12.0 + relogio * 2.0) * 3.0, 0.7);
 float setor = fract(a / TAU * 16.0 + 0.5) - 0.5;
 float radial = d - (r - 29.0);
 float runas = max(linha(abs(setor) * 25.0 + abs(radial), 4.0, 0.8), (1.0 - step(0.028, abs(setor))) * (1.0 - step(6.0, abs(radial))));
 runas *= step(45.0, r) * step(r - 36.0, d) * (1.0 - step(r - 22.0, d));
 vec2 olho = p / max(10.0, r * 0.27);
 float palpebra = linha(abs(olho.y) + olho.x * olho.x * 0.43, 0.43, 0.035) * (1.0 - step(1.0, abs(olho.x)));
 float iris = linha(length(olho * vec2(1.0, 1.1)), 0.29, 0.035);
 float pupila = (1.0 - step(0.035, abs(olho.x))) * (1.0 - step(0.23, abs(olho.y)));
 float simbolo = max(palpebra, max(iris, pupila));
 float desenho = max(max(anel, borda * 0.6), max(max(trama, trama2) * 0.7, max(runas, simbolo)));
 float alpha = max(desenho * (0.78 + 0.12 * sin(relogio * 6.0)), linha(d, r - 1.0, 3.0) * 0.13) * limite;
 vec3 cor = mix(vec3(0.12, 0.44, 0.35), vec3(0.65, 0.96, 0.61), max(anel, simbolo));
 cor = mix(cor, vec3(0.86, 0.76, 0.39), runas * 0.8);
 if (impacto >= 0.0) {
  // Onda sincronizada com a janela de dano, aos 30% do impacto.
  float onda = linha(d, raio * min(1.0, impacto / 0.30), 4.0);
  float setor_fenda = fract(a / TAU * 11.0 + sin(d * 0.065) * 0.12 + 0.5) - 0.5;
  float fendas = (1.0 - step(0.017, abs(setor_fenda))) * step(14.0, d) * limite;
  float fragmentos = step(0.72, sin(floor(p.x / 4.0) * 41.7 + floor(p.y / 4.0) * 19.1));
  fragmentos *= linha(d, raio * impacto, 13.0) * limite;
  alpha = max(desenho * 0.7, max(onda, max(fendas * 0.85, fragmentos * 0.55))) * (1.0 - impacto);
  cor = mix(vec3(0.22, 0.58, 0.40), vec3(0.90, 1.0, 0.72), max(onda, fragmentos));
 }
 COLOR = vec4(cor, alpha);
}
