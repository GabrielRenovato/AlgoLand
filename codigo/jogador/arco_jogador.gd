extends Node2D

# Camadas visuais do jogador com arco (folhas pBOW2 e pBOW3 do pacote Bow Combat).
# Parado ou andando: o corpo é o de sempre (BaseSprites, mesma corrida das outras armas), com o arco
# e a aljava como sprites soltos nos nós da espada e do escudo (ver atualizar_texturas_arco); este nó não desenha nada.
# Disparando: desenha corpo, roupa, cabelo, arco e aljava da folha pBOW3.
# Cada folha tem 8x8 quadros: linhas 0-3 = baixo, cima, direita, esquerda; a metade de baixo
# (linhas 4-7) repete as mesmas direções. Sem AnimationPlayer: os quadros avançam por tempo.

signal disparo_liberado(direcao: Vector2)
signal disparo_terminado

enum Estado { CARREGANDO, DISPARANDO }

const RAIZ := "res://assets/personagens/Arco/"
const QUADROS_POR_LINHA := 8
# Durações em segundos, sugeridas pelo autor do pacote
const DURACAO_DISPARO: Array[float] = [0.18, 0.1, 0.1, 0.1, 0.4, 0.05, 0.05, 0.1]
const QUADRO_SOLTAR := 5
const LINHA_DISPARO_RETO := 4
const ObjetosRefinados := preload("res://codigo/dados/objetos_refinados.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
# Camadas relativas ao corpo (z = 3 em BaseSprites)
const Z_ATRAS := 2
const Z_CORPO := 3
const Z_ROUPA := 4
const Z_CABELO := 5
const Z_FRENTE := 6

var jogador = null

var _estado: Estado = Estado.CARREGANDO
var _linha: int = 0
var _indice: int = 0
var _tempo: float = 0.0
var _escala_tempo: float = 1.0
var _direcao_disparo: Vector2 = Vector2.DOWN
var _pagina: int = 2
var _textura_arco_p2: Texture2D = null
var _textura_arco_p3: Texture2D = null
var _cabelo_aplicado: int = -1
var _roupa_aplicada: int = -1
var _pecas_aplicadas: int = -1
var _raizes_aplicadas: Dictionary = {}

var _corpo: Sprite2D
var _roupa: Sprite2D
var _cabelo: Sprite2D
var _arco: Sprite2D
var _aljava: Sprite2D

func _ready() -> void:
	_corpo = _criar_camada(Z_CORPO)
	_roupa = _criar_camada(Z_ROUPA)
	_cabelo = _criar_camada(Z_CABELO)
	_arco = _criar_camada(Z_FRENTE)
	_aljava = _criar_camada(Z_ATRAS)
	_aplicar_texturas()
	_aplicar_quadro()

func _criar_camada(z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = QUADROS_POR_LINHA
	sprite.vframes = QUADROS_POR_LINHA
	sprite.z_index = z
	add_child(sprite)
	return sprite

func configurar(textura_arco_p2: Texture2D, textura_arco_p3: Texture2D) -> void:
	_textura_arco_p2 = textura_arco_p2
	_textura_arco_p3 = textura_arco_p3
	if is_node_ready():
		_aplicar_texturas()

func esta_disparando() -> bool:
	return _estado == Estado.DISPARANDO

# Linha da folha para a direção; eixo dominante vence e empate fica na vertical
static func linha_da_direcao(direcao: Vector2) -> int:
	if absf(direcao.x) > absf(direcao.y):
		return 2 if direcao.x > 0.0 else 3
	return 0 if direcao.y > 0.0 else 1

# escala_tempo multiplica a duração de cada quadro (menor = disparo mais rápido)
func disparar(direcao: Vector2, escala_tempo: float) -> void:
	_direcao_disparo = direcao.normalized()
	_escala_tempo = escala_tempo
	_linha = linha_da_direcao(_direcao_disparo)
	_estado = Estado.DISPARANDO
	_indice = 0
	_tempo = 0.0
	_pagina = 3
	_aplicar_texturas()
	_aplicar_quadro()

# Interrompe sem emitir disparo_terminado (usado ao desequipar ou abrir uma tela)
func parar_disparo() -> void:
	if _estado != Estado.DISPARANDO:
		return
	_estado = Estado.CARREGANDO
	_indice = 0
	_tempo = 0.0
	_pagina = 2
	_aplicar_texturas()
	_aplicar_quadro()

func _process(delta: float) -> void:
	if not visible:
		return
	if _estado == Estado.DISPARANDO:
		_sincronizar_aparencia()
		_tempo += delta
		_avancar(DURACAO_DISPARO, _escala_tempo)
	elif jogador != null:
		# Segue a direção do corpo desenhado em BaseSprites (linha = quadro / 8)
		_linha = clampi(int(jogador.sprite_corpo.frame / QUADROS_POR_LINHA), 0, 3)
	_aplicar_quadro()

func _avancar(duracoes: Array[float], escala: float) -> void:
	while _tempo >= duracoes[_indice] * escala:
		_tempo -= duracoes[_indice] * escala
		_indice += 1
		if _indice >= duracoes.size():
			_estado = Estado.CARREGANDO
			_pagina = 2
			_indice = 0
			_tempo = 0.0
			_aplicar_texturas()
			disparo_terminado.emit()
			return
		elif _estado == Estado.DISPARANDO and _indice == QUADRO_SOLTAR:
			disparo_liberado.emit(_direcao_disparo)

# Quadro na folha de acordo com o estado
func _coluna() -> int:
	return _indice if _estado == Estado.DISPARANDO else 0

func _linha_na_folha() -> int:
	return _linha + (LINHA_DISPARO_RETO if _estado == Estado.DISPARANDO else 0)

func _aplicar_quadro() -> void:
	if _corpo == null:
		return
	var disparando := _estado == Estado.DISPARANDO
	# Andando, o arco e a aljava são sprites soltos em BaseSprites; aqui só se desenha ao disparar
	for camada in [_corpo, _roupa, _cabelo, _arco, _aljava]:
		camada.visible = disparando
	var coluna := _coluna()
	var quadro := _linha_na_folha() * QUADROS_POR_LINHA + coluna
	for camada in [_corpo, _roupa, _cabelo, _arco, _aljava]:
		camada.frame = quadro
	_arco.z_index = Z_FRENTE if _arco_na_frente(coluna) else Z_ATRAS
	# A aljava fica nas costas: só aparece na frente do corpo quando o jogador olha para cima
	_aljava.z_index = Z_FRENTE if _linha == 1 else Z_ATRAS

# Ordem das camadas segundo os guias "layer order" do pacote
func _arco_na_frente(coluna: int) -> bool:
	if _pagina == 2:
		return _linha == 0
	match _linha:
		0:
			return true
		1:
			return false
	return coluna != 0

func _aplicar_texturas() -> void:
	if _corpo == null:
		return
	_corpo.texture = load(RAIZ + "corpo_p%d.png" % _pagina)
	ObjetosRefinados.aplicar(_aljava, load(RAIZ + "aljava_p%d.png" % _pagina))
	ObjetosRefinados.aplicar(_arco, _textura_arco_p3 if _pagina == 3 else _textura_arco_p2)
	_cabelo_aplicado = -1
	_roupa_aplicada = -1
	_sincronizar_aparencia()

# Cabelo e roupa escolhidos na customização do jogador
func _sincronizar_aparencia() -> void:
	if jogador == null:
		return
	var cabelo: int = Aparencia.indice_cabelo(jogador.cabelo_atual)
	var roupa: int = Aparencia.indice_roupa(jogador.roupa_atual)
	var pecas: int = jogador.pecas_cavaleiro
	var raizes_lidas = jogador.get("raizes_armadura")
	var raizes: Dictionary = raizes_lidas if raizes_lidas is Dictionary else {}
	Aparencia.aplicar_corpo(_corpo, "arco_p%d" % _pagina, roupa, pecas, raizes)
	if cabelo != _cabelo_aplicado or roupa != _roupa_aplicada or pecas != _pecas_aplicadas or raizes != _raizes_aplicadas:
		Aparencia.aplicar_cabelo(_cabelo, cabelo, "arco_p%d" % _pagina, roupa, pecas, raizes)
		_cabelo_aplicado = cabelo
	if roupa != _roupa_aplicada or pecas != _pecas_aplicadas or raizes != _raizes_aplicadas:
		Aparencia.aplicar_roupa(_roupa, roupa, "arco_p%d" % _pagina, pecas, raizes)
		_roupa_aplicada = roupa
	_pecas_aplicadas = pecas
	_raizes_aplicadas = raizes.duplicate()
	_cabelo.modulate = jogador.cor_cabelo
	Aparencia.aplicar_cartola(_cabelo, _roupa, "arco_p%d" % _pagina, roupa, pecas, raizes)
