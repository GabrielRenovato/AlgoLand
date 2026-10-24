extends CharacterBody2D

## Bicho da floresta (cervo, coelho, capivara, corvo) com as folhas do Tiny RPG (assets/animais/floresta/).
## Vive à toa: fica parado, pasta e vagueia perto do ponto de origem. Ao ver um jogador chegando ele PARA e encara (alerta);
## se o jogador chega mais perto, FOGE até a árvore mais conveniente (a que o afasta do jogador), passa por trás dela e some;
## o corvo levanta voo. Volta depois, em outra clareira longe de qualquer jogador. Não bloqueia ninguém (camada 0) e esbarra
## em troncos, pedras e no lago (camada 64). Todas as folhas olham para a ESQUERDA: a direita é espelhada.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const PASTA := "res://assets/animais/floresta/"
const LADO := 0
const FRENTE := 1
const COSTAS := 2
const NOMES_ESTACAO := ["primavera", "verao", "outono", "inverno"]

## Por espécie: tamanho do quadro, distância de alerta/fuga (px), velocidades (px/s), raio de passeio, sombra e as ações.
## Ação: folha (por variante), colunas, linhas (lado, frente, costas), quadros usados e quadros por segundo.
const ESPECIES := {
	"cervo": {"quadro": Vector2i(32, 32), "alerta": 170.0, "fuga": 112.0, "andar": 24.0, "correr": 98.0, "passeio": 90.0,
		"sombra": 9.0, "pes": 3.0, "parado": Vector2(2.0, 6.0),
		"variantes": [["cervo_macho"], ["cervo_femea"]],
		"acoes": {"parar": {"folha": "idle", "colunas": 2, "linhas": [0, 1, 2], "quadros": 2, "fps": 2.5},
			"andar": {"folha": "walk", "colunas": 4, "linhas": [0, 1, 2], "quadros": 4, "fps": 6.0},
			"correr": {"folha": "run", "colunas": 4, "linhas": [0, 1, 2], "quadros": 4, "fps": 12.0},
			"comer": {"folha": "eat", "colunas": 3, "linhas": [0, 0, 0], "quadros": 3, "fps": 2.5}}},
	"coelho": {"quadro": Vector2i(16, 16), "alerta": 120.0, "fuga": 78.0, "andar": 26.0, "correr": 88.0, "passeio": 70.0,
		"sombra": 0.0, "pes": 1.0, "parado": Vector2(1.5, 5.0),
		"variantes": [["coelho_marrom"], ["coelho_loiro"], ["coelho_preto"], ["coelho_branco"]],
		"acoes": {"parar": {"colunas": 4, "linhas": [0, 1, 2], "quadros": 4, "fps": 2.5},
			"andar": {"colunas": 4, "linhas": [3, 4, 5], "quadros": 4, "fps": 7.0},
			"correr": {"colunas": 4, "linhas": [3, 4, 5], "quadros": 4, "fps": 13.0},
			"comer": {"colunas": 4, "linhas": [6, 7, 8], "quadros": 4, "fps": 3.0}}},
	"capivara": {"quadro": Vector2i(32, 32), "alerta": 90.0, "fuga": 58.0, "andar": 18.0, "correr": 44.0, "passeio": 60.0,
		"sombra": 9.0, "pes": 3.0, "parado": Vector2(4.0, 10.0),
		"variantes": [["capivara_marrom"], ["capivara_clara"]],
		# A linha 5 da folha é a capivara na água (azul): de costas anda com os quadros de costas da linha 2
		"acoes": {"parar": {"colunas": 4, "linhas": [0, 1, 2], "quadros": 4, "fps": 2.0},
			"andar": {"colunas": 4, "linhas": [3, 4, 2], "quadros": 4, "fps": 5.0},
			"correr": {"colunas": 4, "linhas": [3, 4, 2], "quadros": 4, "fps": 8.0},
			"comer": {"colunas": 4, "linhas": [0, 1, 2], "quadros": 4, "fps": 2.0}}},
	"corvo": {"quadro": Vector2i(32, 32), "alerta": 130.0, "fuga": 96.0, "andar": 0.0, "correr": 0.0, "passeio": 0.0,
		"sombra": 5.0, "pes": 3.0, "parado": Vector2(2.0, 6.0), "voo": true,
		"variantes": [["corvo"]],
		"acoes": {"parar": {"colunas": 5, "linhas": [0, 0, 0], "quadros": 1, "fps": 1.0},
			"comer": {"colunas": 5, "linhas": [0, 0, 0], "quadros": 5, "fps": 2.5},
			"correr": {"colunas": 5, "linhas": [2, 2, 2], "quadros": 5, "fps": 15.0}}},
}

## Quanto o gerenciador (animais_floresta.gd) sabe: árvores de abrigo, clareiras para voltar e se o jogador está perto
var gerente: Node
var especie := "cervo"
var variante := 0
var estado := "parado"
var origem := Vector2.ZERO
var estacao := 0

var _dados: Dictionary
var _sprite: Sprite2D
var _texturas := {}
var _direcao := LADO
var _esquerda := true
var _acao := "parar"
var _tempo_anim := 0.0
var _temporizador := 1.0
var _destino := Vector2.ZERO
var _abrigo: Vector2 = Vector2.ZERO
var _tem_abrigo := false
var _tempo_fuga := 0.0
var _preso := 0.0
var _tentativas := 0
var _altura := 0.0
var _oculto := 0.0
var _jogador_perto: Node2D
var _distancia_jogador := INF

func configurar(nome_especie: String, indice_variante: int, ponto: Vector2) -> void:
	especie = nome_especie
	variante = indice_variante
	origem = ponto
	position = ponto   # o gerente fica na origem do terreno: local = global
	_dados = ESPECIES[especie]

func _ready() -> void:
	if _dados.is_empty():
		_dados = ESPECIES[especie]
	collision_layer = 0
	collision_mask = 64
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 4.0
	forma.shape = circulo
	forma.position = Vector2(0, -3)
	add_child(forma)
	_sprite = Sprite2D.new()
	_sprite.name = "Imagem"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_aplicar_textura()
	_temporizador = randf_range(0.2, 2.0)
	_atualizar_z()

# --- Aparência --------------------------------------------------------------------------------------------

func definir_estacao(indice: int) -> void:
	estacao = indice
	_aplicar_textura()

## Coelhos ficam brancos no inverno; o resto não muda de pelagem
func _variante_efetiva() -> int:
	if especie == "coelho" and estacao == 3:
		return 3
	return variante

func _caminho(acao: String) -> String:
	var base: String = _dados["variantes"][_variante_efetiva() % _dados["variantes"].size()][0]
	var folha: String = _dados["acoes"][acao].get("folha", "")
	return PASTA + base + ("_" + folha if folha != "" else "") + ".png"

func _textura(acao: String) -> Texture2D:
	var caminho := _caminho(acao)
	if not _texturas.has(caminho):
		_texturas[caminho] = load(caminho)
	return _texturas[caminho]

func _aplicar_textura() -> void:
	if _sprite == null:
		return
	var dados: Dictionary = _dados["acoes"][_acao]
	var tamanho: Vector2i = _dados["quadro"]
	var textura := _textura(_acao)
	_sprite.texture = textura
	_sprite.hframes = int(dados["colunas"])
	_sprite.vframes = maxi(1, int(textura.get_height() / tamanho.y))
	_sprite.offset = Vector2(-tamanho.x / 2.0, -tamanho.y + float(_dados["pes"]) - _altura)
	_atualizar_quadro()

func _definir_acao(acao: String) -> void:
	if acao == _acao:
		return
	_acao = acao
	_tempo_anim = 0.0
	_aplicar_textura()

func _atualizar_quadro() -> void:
	var dados: Dictionary = _dados["acoes"][_acao]
	var coluna: int = int(_tempo_anim) % int(dados["quadros"])
	var linha: int = int(dados["linhas"][_direcao])
	_sprite.frame = linha * _sprite.hframes + coluna
	# A folha olha para a esquerda; para a direita, espelha. De frente e de costas não há lado.
	_sprite.flip_h = not _esquerda if _direcao == LADO else false

func _olhar_para(vetor: Vector2) -> void:
	if vetor.length() < 0.01:
		return
	if absf(vetor.x) > absf(vetor.y) * 1.2:
		_direcao = LADO
		_esquerda = vetor.x < 0.0
	else:
		_direcao = FRENTE if vetor.y > 0.0 else COSTAS
		if vetor.x != 0.0:
			_esquerda = vetor.x < 0.0

func _atualizar_z() -> void:
	z_as_relative = false
	z_index = 900 if _altura > 4.0 else Profundidade.z_de(global_position.y)

func _draw() -> void:
	var raio: float = _dados.get("sombra", 0.0) if not _dados.is_empty() else 0.0
	if raio > 0.0 and modulate.a > 0.01:
		draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, raio * (1.0 - clampf(_altura / 90.0, 0.0, 0.6)), Color(0, 0, 0, 0.22))

# --- Jogador ---------------------------------------------------------------------------------------------

func _procurar_jogador() -> void:
	_jogador_perto = null
	_distancia_jogador = INF
	for no in get_tree().get_nodes_in_group("jogadores"):
		if no is Node2D and no.get_world_2d() == get_world_2d():
			var d := global_position.distance_to(no.global_position)
			if d < _distancia_jogador:
				_distancia_jogador = d
				_jogador_perto = no

## Correr assusta de mais longe do que andar devagar
func _raio_alerta() -> float:
	var raio: float = _dados["alerta"]
	if _jogador_perto != null and "velocity" in _jogador_perto and _jogador_perto.velocity.length() > 80.0:
		raio *= 1.3
	return raio

# --- Comportamento -----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if estado == "oculto":
		_oculto -= delta
		if _oculto <= 0.0:
			_reaparecer()
		return
	_procurar_jogador()
	if _distancia_jogador > 700.0 and estado in ["parado", "comer", "andando"]:
		# Longe de todo mundo: só respira, sem gastar processamento com passeio
		_tempo_anim += delta * float(_dados["acoes"][_acao]["fps"])
		_atualizar_quadro()
		return
	match estado:
		"parado", "comer":
			_ao_parado(delta)
		"andando":
			_ao_andar(delta)
		"alerta":
			_ao_alerta(delta)
		"fugindo":
			_ao_fugir(delta)
		"sumindo":
			_ao_sumir(delta)
	_tempo_anim += delta * float(_dados["acoes"][_acao]["fps"])
	_atualizar_quadro()
	_atualizar_z()

func _ao_parado(delta: float) -> void:
	velocity = Vector2.ZERO
	if _distancia_jogador < _raio_alerta():
		_entrar_em_alerta()
		return
	_temporizador -= delta
	if _temporizador > 0.0:
		return
	var sorteio := randf()
	var parado: Vector2 = _dados["parado"]
	if sorteio < 0.5 and float(_dados["andar"]) > 0.0:
		_escolher_destino()
	elif sorteio < 0.8 and _dados["acoes"].has("comer"):
		estado = "comer"
		_definir_acao("comer")
		_temporizador = randf_range(parado.x, parado.y)
	else:
		estado = "parado"
		_definir_acao("parar")
		_temporizador = randf_range(parado.x, parado.y)

func _escolher_destino() -> void:
	var alcance: float = _dados["passeio"]
	for tentativa in 6:
		var alvo := origem + Vector2.from_angle(randf() * TAU) * randf_range(alcance * 0.3, alcance)
		if gerente == null or gerente.ponto_livre(alvo):
			_destino = alvo
			estado = "andando"
			_definir_acao("andar")
			_preso = 0.0
			return
	_temporizador = 1.5

func _ao_andar(delta: float) -> void:
	if _distancia_jogador < _raio_alerta():
		_entrar_em_alerta()
		return
	var vetor := _destino - global_position
	if vetor.length() < 4.0 or _preso > 0.8:
		velocity = Vector2.ZERO
		estado = "parado"
		_definir_acao("parar")
		_temporizador = randf_range(_dados["parado"].x, _dados["parado"].y)
		return
	_olhar_para(vetor)
	velocity = vetor.normalized() * float(_dados["andar"])
	_mover(delta)

func _entrar_em_alerta() -> void:
	estado = "alerta"
	velocity = Vector2.ZERO
	_definir_acao("parar")
	_temporizador = randf_range(0.35, 0.7)

func _ao_alerta(delta: float) -> void:
	velocity = Vector2.ZERO
	if _jogador_perto != null:
		_olhar_para(_jogador_perto.global_position - global_position)
	if _distancia_jogador > _raio_alerta() * 1.25:
		estado = "parado"
		_temporizador = randf_range(0.8, 2.0)
		return
	_temporizador -= delta
	# Ou o jogador chegou perto demais, ou o bicho se cansou de esperar e some assim mesmo
	if _distancia_jogador < float(_dados["fuga"]) or (_temporizador <= 0.0 and _distancia_jogador < _raio_alerta() * 0.8):
		_comecar_fuga()

func _comecar_fuga() -> void:
	estado = "fugindo"
	_tempo_fuga = 0.0
	_tentativas = 0
	_preso = 0.0
	_escolher_abrigo()
	if _dados.get("voo", false):
		_definir_acao("correr")

## A árvore que mais afasta do jogador sem exigir uma corrida enorme: o bicho vai ATRÁS dela (ao norte da base, onde a copa o esconde)
func _escolher_abrigo() -> void:
	_tem_abrigo = false
	if _jogador_perto == null or gerente == null:
		return
	var jogador := _jogador_perto.global_position
	var melhor := -INF
	for base: Vector2 in gerente.abrigos_perto(global_position, 300.0):
		var ponto := base + Vector2(randf_range(-9.0, 9.0), -14.0)
		var fuga_d := ponto.distance_to(jogador)
		if fuga_d < _distancia_jogador + 12.0:
			continue   # não corre na direção do jogador
		var nota := fuga_d - 0.7 * global_position.distance_to(ponto)
		if nota > melhor:
			melhor = nota
			_abrigo = ponto
			_tem_abrigo = true

func _ao_fugir(delta: float) -> void:
	_tempo_fuga += delta
	var longe := Vector2.ZERO
	if _jogador_perto != null:
		longe = (global_position - _jogador_perto.global_position).normalized()
	var vetor := longe
	if _tem_abrigo:
		vetor = _abrigo - global_position
		if vetor.length() < 20.0:
			_comecar_sumico()
			return
	if _dados.get("voo", false):
		_ao_voar(delta, longe)
		return
	_definir_acao("correr")
	_olhar_para(vetor)
	velocity = vetor.normalized() * float(_dados["correr"])
	_mover(delta)
	# Travou num tronco ou sem abrigo: tenta outro caminho e, no fim, some mesmo assim
	if _preso > 0.45:
		_preso = 0.0
		_tentativas += 1
		_escolher_abrigo()
		if _tentativas >= 3:
			_comecar_sumico()
	elif not _tem_abrigo and _tempo_fuga > 2.2:
		_comecar_sumico()

func _ao_voar(delta: float, longe: Vector2) -> void:
	# O corvo abre as asas, sobe e vai embora por cima das copas
	var direcao := Vector2(longe.x if absf(longe.x) > 0.2 else (1.0 if randf() < 0.5 else -1.0), -0.35).normalized()
	_olhar_para(Vector2(direcao.x, 0.0))
	_altura += 70.0 * delta
	global_position += direcao * 95.0 * delta
	_aplicar_altura()
	if _tempo_fuga > 1.5:
		_comecar_sumico()

func _aplicar_altura() -> void:
	_sprite.offset.y = -float(_dados["quadro"].y) + float(_dados["pes"]) - _altura
	_atualizar_z()
	queue_redraw()

func _comecar_sumico() -> void:
	estado = "sumindo"
	_temporizador = 0.35

func _ao_sumir(delta: float) -> void:
	_temporizador -= delta
	modulate.a = clampf(_temporizador / 0.35, 0.0, 1.0)
	if _dados.get("voo", false):
		_altura += 60.0 * delta
		global_position += Vector2(-1.0 if _esquerda else 1.0, -0.3) * 90.0 * delta
		_aplicar_altura()
	elif _tem_abrigo:
		velocity = (_abrigo - global_position).normalized() * float(_dados["correr"]) * 0.5
		_mover(delta)
	if _temporizador <= 0.0:
		estado = "oculto"
		visible = false
		_oculto = randf_range(35.0, 80.0)
		velocity = Vector2.ZERO
		queue_redraw()

func _reaparecer() -> void:
	var ponto: Vector2 = gerente.refugio_longe_dos_jogadores(self) if gerente != null else origem
	origem = ponto
	global_position = ponto
	_altura = 0.0
	modulate.a = 1.0
	visible = true
	estado = "parado"
	_definir_acao("parar")
	_aplicar_altura()
	_temporizador = randf_range(1.0, 3.0)

func _mover(_delta: float) -> void:
	var antes := global_position
	move_and_slide()
	if (global_position - antes).length() < velocity.length() * _delta * 0.25:
		_preso += _delta
	else:
		_preso = 0.0
	_atualizar_z()
