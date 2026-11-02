extends Node2D
## Espuma segue a água verdadeira do mapa; nunca é pintada sobre as margens.
var terreno: Node2D
var manchas: Array[Dictionary] = []
var _acumulo := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 41736
	z_as_relative = false
	z_index = preload("res://codigo/globais/profundidade.gd").Z_CHAO + 2

func adicionar(ponto: Vector2, intensidade: float) -> void:
	_acumulo += intensidade
	if _acumulo < 0.7 or manchas.size() >= 64:
		return
	_acumulo = 0.0
	if not is_instance_valid(terreno) or terreno.peso_agua(ponto) < 0.35:
		return
	manchas.append({"p": ponto, "idade": 0.0, "vida": _rng.randf_range(2.5, 5.0), "raio": _rng.randf_range(1.5, 4.5), "fase": _rng.randf_range(0.0, TAU)})

func _process(delta: float) -> void:
	for i in range(manchas.size() - 1, -1, -1):
		var mancha: Dictionary = manchas[i]
		mancha.idade += delta
		if mancha.idade >= mancha.vida:
			manchas.remove_at(i)
			continue
		var p: Vector2 = mancha.p
		var direcao: Vector2 = terreno.corrente_em(p)*15.0*terreno.velocidade_corrente(p)
		var proximo := p + direcao * delta
		if terreno.peso_agua(proximo) >= 0.35:
			mancha.p = proximo
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(terreno):
		return
	for mancha in manchas:
		var t: float = mancha.idade / mancha.vida
		var opacidade := (1.0 - t) * 0.75
		var centro: Vector2 = mancha.p
		var raio: float = mancha.raio * (1.0 + t * 1.3)
		# Pequenos arcos com pontos alinhados à grade preservam o filtro pixel art.
		for i in 9:
			var a: float = mancha.fase + i * TAU / 12.0
			var ponto := (centro + Vector2(cos(a) * raio, sin(a) * raio * 0.45)).round()
			if terreno.peso_agua(ponto) < 0.35:
				continue
			draw_rect(Rect2(to_local(ponto), Vector2(2, 1)), Color(0.80, 0.94, 0.95, opacidade))
