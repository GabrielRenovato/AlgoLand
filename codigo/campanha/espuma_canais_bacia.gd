extends Node2D
## Espuma de margem e encontros dos canais, sobre a mesma água modular do terreno.
var terreno: Node2D
var _fontes: Array[Vector2] = []
var _particulas: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_as_relative = false
	z_index = preload("res://codigo/globais/profundidade.gd").Z_CHAO + 1
	_rng.seed = 41752
	for i in terreno.CANAIS.size():
		var pontos: Array = terreno.CANAIS[i]
		for j in pontos.size() - 1:
			var a: Vector2 = pontos[j]
			var b: Vector2 = pontos[j + 1]
			var lateral := (b - a).normalized().orthogonal()
			for k in range(1, int(a.distance_to(b) / 24.0)):
				var centro := a.move_toward(b, k * 24.0)
				for lado in [-1.0, 1.0]:
					var p: Vector2 = centro + lateral * terreno.LARGURAS_CANAIS[i] * 0.65 * lado
					if terreno.limites.has_point(p) and terreno.peso_agua(p) > 0.4:
						_fontes.append(p)
	if _fontes.is_empty():
		return
	for i in 90:
		var registro := {}
		_reiniciar(registro)
		registro.idade = _rng.randf_range(0.0, registro.vida)
		_particulas.append(registro)

func _reiniciar(p: Dictionary) -> void:
	p.p = _fontes[_rng.randi_range(0, _fontes.size() - 1)]
	p.idade = 0.0
	p.vida = _rng.randf_range(3.0, 6.0)
	p.tamanho = _rng.randf_range(1.0, 2.8)

func _process(delta: float) -> void:
	for p in _particulas:
		p.idade += delta
		var ponto: Vector2 = p.p
		var proximo: Vector2 = ponto + terreno.corrente_em(ponto) * delta * 12.0 * terreno.velocidade_corrente(ponto)
		if p.idade > p.vida or terreno.peso_agua(proximo) < 0.4:
			_reiniciar(p)
		else:
			p.p = proximo
	queue_redraw()

func _draw() -> void:
	for p in _particulas:
		var t: float = p.idade / p.vida
		var ponto: Vector2 = p.p
		var opacidade := sin(t * PI) * 0.38
		var direcao: Vector2 = terreno.corrente_em(ponto)
		for i in 3:
			var local := (ponto + direcao * i * 2.0).round()
			if terreno.peso_agua(local) < 0.45:
				continue
			draw_rect(Rect2(local, Vector2(float(p.tamanho), 1).round()), Color(0.78, 0.92, 0.95, opacidade))
