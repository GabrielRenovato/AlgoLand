shader_type canvas_item;
render_mode unshaded;

uniform float raio = 180.0;
uniform float invocacao = 0.0;
uniform float impacto = -1.0;
uniform float relogio = 0.0;

void fragment() {
	// Coordenadas em pixels do mundo: bordas e runas não são uma imagem ampliada.
	vec2 p = floor((UV - vec2(0.5)) * 384.0) + vec2(0.5);
	float distancia = length(p);
	float angulo = atan(p.y, p.x);
	float r = max(6.0, raio * invocacao);
	float anel = 1.0 - step(1.4, abs(distancia-r));
	float interno = 1.0 - step(0.8, abs(distancia-(r-7.0)));
	float setor = fract(angulo / TAU * 24.0 + 0.5) - 0.5;
	float runa = (1.0-step(0.10,abs(setor))) * step(r-13.0,distancia) * (1.0-step(r-3.0,distancia));
	float w = max(4.0,r*0.18);
	float olho = (1.0-step(1.0,abs(abs(p.y)-(w-abs(p.x))*.38))) * (1.0-step(w,abs(p.x)));
	float iris = (1.0-step(1.2,abs(distancia-w*.25))) * (1.0-step(w*.32,abs(p.x)));
	float pupila = (1.0-step(1.0,abs(p.x))) * (1.0-step(w*.23,abs(p.y)));
	float desenho = max(max(anel,interno*.7),max(runa,max(olho,max(iris,pupila))));
	vec3 cor = mix(vec3(.19,.56,.34),vec3(.66,1.0,.69),max(anel,max(olho,pupila)));
	float alpha = desenho * (.78 + .12*sin(relogio*7.0));
	if (impacto >= 0.0) {
		float onda = 1.0-step(3.0,abs(distancia-raio*min(1.0,impacto*2.2)));
		float fenda = (1.0-step(.055,abs(fract(angulo/TAU*12.0 + sin(distancia*.08)*.09+.5)-.5))) * step(20.0,distancia) * (1.0-step(raio,distancia));
		alpha = max(desenho*.75,max(onda,fenda*.75)) * (1.0-impacto);
		cor = mix(vec3(.30,.76,.45),vec3(.87,1.0,.72),onda);
	}
	COLOR = vec4(cor,alpha);
}
