// Água do rio da Bacia do Moinho: leito de pedras, água semitransparente e estrias à velocidade da correnteza.
// Compartilhado pelo terreno da Bacia e pelas outras regiões que reutilizam essa água.
uniform sampler2D campo_corrente : filter_linear, repeat_disable;
uniform vec3 fase_corrente = vec3(0.0);
// Paleta da água da estação, do mais escuro ao brilho (extraída da animação antiga).
uniform vec3 agua_tons[5];
uniform float agua_velocidade = 24.0;
// Ruído de valor periódico: o deslocamento da correnteza dá a volta sem perder precisão com o tempo.
float hash21(vec2 p) {
	p = fract(p*vec2(123.34,456.21));
	p += dot(p,p+45.32);
	return fract(p.x*p.y);
}
float ruido_periodico(vec2 p, float periodo) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float a = hash21(vec2(mod(i.x,periodo),i.y));
	float b = hash21(vec2(mod(i.x+1.0,periodo),i.y));
	float c = hash21(vec2(mod(i.x,periodo),i.y+1.0));
	float d = hash21(vec2(mod(i.x+1.0,periodo),i.y+1.0));
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
// Leito do rio: pedras arredondadas (células de Voronoi) com fresta escura, luz em faixas e cascalho.
vec3 leito_pedras(vec2 p) {
	vec2 g = p/14.0;
	vec2 i = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = vec2(0.0);
	vec2 ct = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = i+vec2(float(x),float(y));
			vec2 pt = c+vec2(hash21(c+3.1),hash21(c+17.7))*0.7+0.15;
			float d = distance(g,pt);
			if (d < d1) { d2 = d1; d1 = d; id = c; ct = pt; }
			else if (d < d2) { d2 = d; }
		}
	}
	float sorte = hash21(id+9.3);
	vec3 base = sorte < 0.22 ? vec3(0.40,0.37,0.31) : (sorte < 0.44 ? vec3(0.30,0.30,0.28) : (sorte < 0.66 ? vec3(0.46,0.42,0.33) : (sorte < 0.88 ? vec3(0.27,0.31,0.29) : vec3(0.37,0.32,0.22))));
	float luz = clamp(dot(g-ct,vec2(-0.6,-0.8))*2.4,-1.0,1.0);
	luz = floor(luz*1.5+0.5)/1.5;
	vec3 cor = base*(1.0+luz*0.28);
	cor = mix(vec3(0.09,0.11,0.10),cor,smoothstep(0.05,0.17,d2-d1));
	return cor*(0.94+hash21(floor(p/2.0)+11.0)*0.12);
}
// Água semitransparente sobre o leito: o fundo aparece mais na margem rasa e escurece no meio fundo.
// Retorna a cor e, no alfa, o traço usado para quebrar a espuma da margem.
vec4 agua_rio(vec2 pos_mundo, vec3 campo, float tempo_corrente, float relogio) {
	vec2 direcao = normalize(campo.rg * 2.0 - 1.0 + vec2(0.0001));
	float centro = smoothstep(0.05, 0.85, campo.b);
	// Água em pixels de 2 px. Todas as camadas andam na mesma velocidade em todo o canal: velocidades diferentes
	// por ponto entortam o padrão até virar linhas finíssimas.
	vec2 ponto = (floor(pos_mundo/2.0)+0.5)*2.0;
	float avanco = tempo_corrente*agua_velocidade;
	float sinal_h = direcao.x < 0.0 ? -1.0 : 1.0;
	float sinal_v = direcao.y < 0.0 ? -1.0 : 1.0;
	vec2 qh = vec2(ponto.x*sinal_h, ponto.y);
	vec2 qv = vec2(ponto.y*sinal_v, ponto.x);
	float mistura = smoothstep(0.30, 0.70, abs(direcao.y) / max(abs(direcao.x)+abs(direcao.y), 0.001));
	float a1 = mod(avanco, 1280.0);
	float a2 = mod(avanco*1.4, 576.0);
	float a3 = mod(avanco*1.15, 1920.0);
	float longas = mix(ruido_periodico(vec2((qh.x-a1)/20.0, qh.y/3.4), 64.0), ruido_periodico(vec2((qv.x-a1)/20.0, qv.y/3.4), 64.0), mistura);
	float curtas = mix(ruido_periodico(vec2((qh.x-a2)/9.0+7.3, qh.y/1.7+3.1), 64.0), ruido_periodico(vec2((qv.x-a2)/9.0+7.3, qv.y/1.7+3.1), 64.0), mistura);
	float fio = mix(ruido_periodico(vec2((qh.x-a3)/30.0+4.7, qh.y/1.15+5.3), 64.0), ruido_periodico(vec2((qv.x-a3)/30.0+4.7, qv.y/1.15+5.3), 64.0), mistura);
	float n = longas*0.65 + curtas*0.35;
	int faixa = n < 0.34 ? 0 : (n < 0.52 ? 1 : (n < 0.70 ? 2 : (n < 0.84 ? 3 : 4)));
	// O leito não anda; a água por cima o entorta um pouco (refração).
	vec2 desvio = (vec2(longas,curtas)-0.5)*3.0;
	vec3 fundo = leito_pedras(floor((ponto+desvio)/2.0)*2.0);
	// Luz que a água projeta no fundo: rede de linhas claras que se move devagar.
	float c1 = ruido_periodico(ponto/7.0+vec2(relogio*0.35,relogio*0.20), 64.0);
	float c2 = ruido_periodico(ponto*vec2(1.1,0.9)/7.0+vec2(4.0-relogio*0.25,relogio*0.30), 64.0);
	float rede = pow(clamp(1.0-abs(c1-c2)*3.4,0.0,1.0),6.0);
	fundo += vec3(0.20,0.28,0.26)*rede*(1.0-centro*0.5);
	fundo *= mix(1.05,0.78,centro);
	vec3 tinta = mix(agua_tons[2],agua_tons[0],centro);
	vec3 rio = mix(fundo,tinta,mix(0.26,0.55,centro));
	// Superfície: estrias e cristas finas correndo com a correnteza.
	rio += (agua_tons[faixa]-agua_tons[2])*0.55;
	float crista = smoothstep(0.70, 0.76, fio) * step(0.40, longas);
	rio = mix(rio, mix(agua_tons[4], vec3(0.70,0.88,0.90), 0.45), crista*0.45);
	float faisca = step(0.9965, hash21(floor(pos_mundo/2.0)+floor(relogio*5.0))) * step(0.5, n);
	rio = mix(rio, vec3(0.85,0.95,0.95), faisca*0.8);
	return vec4(rio, smoothstep(0.42, 0.62, curtas*0.6+longas*0.4));
}
