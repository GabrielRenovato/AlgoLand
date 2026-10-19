extends Node

## Clima da arena: nublado, chuva leve/forte, tempestade e neve leve/forte, tudo em sprites (pacote "Weather Effects 2.0").
## Fica como filho do nó Estacoes (que o cria em _ready), então existe no cenário e na tela de título.
##
## - Chuva e neve: as animações 32x128 (8 quadros) ladrilhadas na tela inteira, presas à câmera; a forte fica atrás da
##   leve (ver "using these effects.txt"). Entram e saem com fade.
## - Respingos (chuva) e flocos (neve): animações 16x16 sorteadas em células visíveis do chão, nunca na água, no
##   penhasco nem sob árvores.
## - Nublado: sombras de nuvem (autotile "cloud cover") que atravessam o mapa devagar.
## - O clima escurece a tela pelo Iluminacao.tom_clima (por cima do ciclo, da estação e do evento) e a chuva toca em loop.
## - TEMPESTADE é um evento de onda (Gerenciador-de-ondas EVENTOS): chuva forte + raios (ver codigo/efeitos/raio.gd).
##
## Fazenda e cidade seguem o clima do MUNDO, guardado em Fazenda.clima_hoje (salvo com a fazenda); dormir sorteia o do
## novo dia. A arena tem tempo próprio (pedido de 2026-10-15): começa no clima do mundo, o início de cada onda sorteia o
## dela (ver sortear_clima) e nada disso, nem a TEMPESTADE do evento, passa para a fazenda. Morrer ou parar as ondas
## volta ao padrão da estação. O inverno nunca fica sem neve e
## a tela de título (que não segue o calendário) é só NEVE_LEVE.

signal clima_mudou(estado: int)
## Um raio acabou de ser criado (começa o aviso no chão); usado por testes e depuração
signal raio_criado(raio: Node2D)

const Estado = preload("res://codigo/dados/estados_clima.gd").Estado

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const RaioScript := preload("res://codigo/efeitos/raio.gd")

const PASTA := "res://assets/cenario/Weather Effects/"
const FOLHA_CHUVA_LEVE := preload("res://assets/cenario/Weather Effects/weather effects, rain light anim 32x128.png")
const FOLHA_CHUVA_FORTE := preload("res://assets/cenario/Weather Effects/weather effects, rain heavy anim 32x128.png")
const FOLHA_NEVE_LEVE := preload("res://assets/cenario/Weather Effects/weather effects, snow light anim 32x128.png")
const FOLHA_NEVE_FORTE := preload("res://assets/cenario/Weather Effects/weather effects, snow heavy anim 32x128.png")
const FOLHA_RESPINGO := preload("res://assets/cenario/Weather Effects/weather effects, rain impact anim 16x16.png")
const FOLHA_FLOCO := preload("res://assets/cenario/Weather Effects/weather effects, snow impact anim 16x16.png")
const FOLHA_NUVEM := preload("res://assets/cenario/Weather Effects/weather effects, cloud cover autotile 16x16.png")
const SOM_CHUVA := preload("res://assets/audio/chuva.wav")

const QUADROS := 8
const LARGURA_QUEDA := 32
const ALTURA_QUEDA := 128
const LADO_IMPACTO := 16
## Segundos por quadro de cada animação (os valores do readme do pacote)
const TEMPO_CHUVA_LEVE := 0.05
const TEMPO_CHUVA_FORTE := 0.1
const TEMPO_NEVE_LEVE := 0.175
const TEMPO_NEVE_FORTE := 0.1
const TEMPO_RESPINGO := 0.075
const TEMPO_FLOCO := 0.15
const DURACAO_FADE := 1.4
const DURACAO_TOM := 1.5

## Sorteio por estação (0 primavera, 1 verão, 2 outono, 3 inverno): pares [estado, peso em %]
const SORTEIO_POR_ESTACAO: Array = [
	[[Estado.LIMPO, 60], [Estado.CHUVA_LEVE, 40]],
	[[Estado.LIMPO, 75], [Estado.NUBLADO, 25]],
	[[Estado.NUBLADO, 30], [Estado.CHUVA_LEVE, 40], [Estado.CHUVA_FORTE, 30]],
	[[Estado.NEVE_LEVE, 60], [Estado.NEVE_FORTE, 40]],
]
const ESTACAO_INVERNO := 3
## Clima de quando não há sorteio (início, troca de estação, ondas paradas)
const CLIMA_PADRAO: Array = [Estado.LIMPO, Estado.LIMPO, Estado.NUBLADO, Estado.NEVE_LEVE]

## Multiplicador de cor da tela em cada clima (via Iluminacao.definir_tom_clima)
const TONS: Dictionary = {
	Estado.LIMPO: Color(1, 1, 1),
	Estado.NUBLADO: Color(0.9, 0.92, 0.96),
	Estado.CHUVA_LEVE: Color(0.86, 0.89, 0.95),
	Estado.CHUVA_FORTE: Color(0.76, 0.8, 0.9),
	Estado.TEMPESTADE: Color(0.62, 0.67, 0.8),
	Estado.NEVE_LEVE: Color(1, 1, 1),
	Estado.NEVE_FORTE: Color(0.93, 0.95, 1.0),
}
## Volume (dB) da chuva em loop em cada clima; o que não está aqui fica em silêncio
const VOLUME_CHUVA: Dictionary = {
	Estado.CHUVA_LEVE: -27.0,
	Estado.CHUVA_FORTE: -21.0,
	Estado.TEMPESTADE: -18.0,
}
const VOLUME_SILENCIO := -60.0

## Respingos/flocos: segundos entre um e outro (média) e quantos podem existir ao mesmo tempo
const INTERVALO_IMPACTO: Dictionary = {
	Estado.CHUVA_LEVE: 0.3,
	Estado.CHUVA_FORTE: 0.16,
	Estado.TEMPESTADE: 0.12,
	Estado.NEVE_LEVE: 0.55,
	Estado.NEVE_FORTE: 0.3,
}
const MAX_IMPACTOS := 14
## No chão de neve o floco quase some; só uma fração cai fora da terra batida (o readme do pacote pede isso)
const CHANCE_FLOCO_NA_NEVE := 0.2
## Alturas de sprite a partir das quais um objeto do terreno cobre o chão (copas, caverna)
const ALTURA_MINIMA_COBERTURA := 28.0

## Raios da tempestade: intervalo entre eles (s) e tempo do aviso no chão
const INTERVALO_RAIO_MIN := 2.5
const INTERVALO_RAIO_MAX := 4.0
const AVISO_RAIO := 1.0

## Opacidade das sombras de nuvem em cada clima (o que não está aqui = sem nuvens)
const ALFA_NUVENS: Dictionary = {Estado.NUBLADO: 1.0, Estado.CHUVA_FORTE: 0.6, Estado.TEMPESTADE: 0.85}
## Cobertura de nuvens como no gif do pacote: a sombra cobre a maior parte do mapa e as aberturas de sol
## atravessam o chão com o vento. Um ruído sem emendas (em células de 16 px) diz onde tem nuvem e o autotile
## da folha desenha as bordas; a textura repete e anda presa ao mundo
const NUVENS_VENTO := Vector2(14.0, 5.0)
const NUVENS_COLUNAS := 48
const NUVENS_LINHAS := 32
const NUVENS_COBERTURA := 0.62
const NUVENS_FREQUENCIA := 0.07
const NUVENS_SEMENTE := 7
const LADO_TILE_NUVEM := 16
# Peças da folha (coluna, linha) em tiles de 16 px: mancha 3x3 de cima (cantos, bordas, centro) e o bloco 2x2
# de cantos internos (o buraco no meio dele é a ponta de céu aberto que entra na diagonal)
const PECA_NUVEM_CENTRO := Vector2i(1, 1)
const PECAS_NUVEM_BORDA := {
	"n": Vector2i(1, 0), "s": Vector2i(1, 2), "o": Vector2i(0, 1), "l": Vector2i(2, 1),
	"no": Vector2i(0, 0), "nl": Vector2i(2, 0), "so": Vector2i(0, 2), "sl": Vector2i(2, 2),
}
const PECAS_NUVEM_CANTO_INTERNO := {
	"sl": Vector2i(0, 6), "so": Vector2i(1, 6), "nl": Vector2i(0, 7), "no": Vector2i(1, 7),
}

class Camada extends RefCounted:
	var no: CanvasItem
	var quadros: Array[Texture2D] = []
	var duracao := 0.1
	var tempo := 0.0
	var indice := 0
	var alfa := 0.0
	## estado -> alfa quando esse clima está ativo (o que não está aqui = camada apagada)
	var alvos: Dictionary = {}

class Impacto extends RefCounted:
	var sprite: Sprite2D
	var quadros: Array[Texture2D] = []
	var duracao := 0.1
	var tempo := 0.0

var clima_atual: int = Estado.LIMPO
## O clima que vale sem o evento TEMPESTADE (volta para ele quando o evento termina)
var clima_base: int = Estado.LIMPO
var estacao_atual := -1
var tempestade_ativa := false
## Quantos raios já foram criados nesta partida de cena (testes e depuração)
var raios_criados := 0

var _terreno: Node2D
var _chao: TileMapLayer
var _terra: TileMapLayer
var _agua: TileMapLayer
var _penhasco: TileMapLayer
var _gerenciador: Node
var _jogador: Node
var _rng := RandomNumberGenerator.new()
var _mundo: Node2D
var _camada_nuvens: Node2D
var _camada_impactos: Node2D
var _camada_raios: Node2D
var _camadas: Array[Camada] = []
## Uma só camada (TextureRect em ladrilho) com a cobertura inteira; array para o fade tratar igual às outras
var _nuvens: Array[TextureRect] = []
var _tamanho_nuvens := Vector2.ONE
var _deslocamento_nuvens := Vector2.ZERO
var _impactos: Array[Impacto] = []
var _quadros_respingo: Array[Texture2D] = []
var _quadros_floco: Array[Texture2D] = []
var _cronometro_impacto := 0.5
var _cronometro_raio := 2.0
var _coberturas: Array[Rect2] = []
var _cobertura_nos: Array[Sprite2D] = []
var _coberturas_prontas := false
var _som_chuva: AudioStreamPlayer
var _tween_som: Tween
var _flash_camada: CanvasLayer
var _flash: ColorRect
var _tween_flash: Tween

## Sorteio puro (sem estado, para poder ser testado): clima de uma onda numa estação (0..3)
static func sortear_clima(estacao: int, rng: RandomNumberGenerator) -> int:
	var tabela: Array = SORTEIO_POR_ESTACAO[clampi(estacao, 0, SORTEIO_POR_ESTACAO.size() - 1)]
	var total := 0
	for par in tabela:
		total += int(par[1])
	var ponto := rng.randf() * total
	var acumulado := 0.0
	for par in tabela:
		acumulado += float(par[1])
		if ponto < acumulado:
			return int(par[0])
	return int(tabela[tabela.size() - 1][0])

static func clima_padrao(estacao: int) -> int:
	return int(CLIMA_PADRAO[clampi(estacao, 0, CLIMA_PADRAO.size() - 1)])

static func eh_chuva(estado: int) -> bool:
	return estado == Estado.CHUVA_LEVE or estado == Estado.CHUVA_FORTE or estado == Estado.TEMPESTADE

static func eh_neve(estado: int) -> bool:
	return estado == Estado.NEVE_LEVE or estado == Estado.NEVE_FORTE

## Neve só no inverno e o inverno só com neve; o resto vale em qualquer estação
static func vale_na_estacao(estado: int, estacao: int) -> bool:
	return eh_neve(estado) == (estacao == ESTACAO_INVERNO)

## Clima do mundo que vale na estação `estacao`; um estado que não combina com ela (o painel de debug troca só o
## visual da estação) cai no padrão
static func clima_do_mundo(estacao: int) -> int:
	var estado: int = Fazenda.clima_hoje
	if estado >= 0 and vale_na_estacao(estado, estacao):
		return estado
	return clima_padrao(estacao)

func _ready() -> void:
	add_to_group("clima")
	_rng.randomize()
	_terreno = get_parent().get_parent() as Node2D
	_chao = _terreno.get_node_or_null("Chao") as TileMapLayer
	_terra = _terreno.get_node_or_null("Terra") as TileMapLayer
	_agua = _terreno.get_node_or_null("Agua") as TileMapLayer
	_penhasco = _terreno.get_node_or_null("Penhasco") as TileMapLayer
	_criar_visuais()
	_criar_flash()
	_criar_som()
	_conectar_gerenciador()
	# O Estacoes só decide se segue o calendário depois de criar este nó
	_ligar_clima_do_mundo.call_deferred()

## A fazenda (e a cidade) seguem o clima do mundo. A arena tem tempo próprio: sorteia o clima a cada onda e nada dele
## (nem a tempestade) passa para o mundo. A tela de título também não segue
func segue_mundo() -> bool:
	return get_parent() != null and bool(get_parent().get("_calendario_ligado")) and _gerenciador == null

func _ligar_clima_do_mundo() -> void:
	if segue_mundo() and not Fazenda.clima_do_dia_mudou.is_connected(_ao_clima_do_mundo_mudou):
		Fazenda.clima_do_dia_mudou.connect(_ao_clima_do_mundo_mudou)
		_ao_clima_do_mundo_mudou(Fazenda.clima_hoje)

## O tempo mudou em outro lugar (dormir, onda): durante a tempestade da arena ela continua por cima
func _ao_clima_do_mundo_mudou(_estado: int) -> void:
	if estacao_atual < 0:
		return
	clima_base = clima_do_mundo(estacao_atual)
	if not tempestade_ativa:
		definir_clima(clima_base)

func _conectar_gerenciador() -> void:
	# O Estacoes já achou o gerenciador pelo caminho; aqui o grupo cobre o mesmo nó (na tela de título não existe)
	_gerenciador = get_tree().get_first_node_in_group("gerenciador_ondas")
	if _gerenciador == null:
		_gerenciador = _terreno.get_node_or_null("../enemySpawner/GerenciadorOndas")
	_jogador = _terreno.get_node_or_null("../Jogador")
	if _gerenciador == null:
		return
	_gerenciador.onda_iniciada.connect(_ao_onda_iniciada)
	_gerenciador.sinal_ondas_paradas.connect(_ao_ondas_paradas)
	_gerenciador.evento_alterado.connect(_ao_evento_alterado)

# --- Estado -----------------------------------------------------------------------------------------------

## Chamado pelo Estacoes sempre que a estação é aplicada. Só uma estação NOVA zera o clima para o padrão dela
## (o sorteio da onda pode ter chegado antes e já ter alinhado a estação)
func definir_estacao(indice: int, imediato := false) -> void:
	if indice == estacao_atual:
		return
	estacao_atual = indice
	tempestade_ativa = false
	clima_base = clima_do_mundo(indice) if segue_mundo() else clima_padrao(indice)
	definir_clima(clima_base, imediato)

## Muda o clima com fade (ou na hora). Sair da TEMPESTADE apaga os raios
func definir_clima(estado: int, imediato := false) -> void:
	if get_parent().get("ambiente_interno") == true: estado = Estado.LIMPO
	var anterior := clima_atual
	clima_atual = estado
	if anterior == Estado.TEMPESTADE and estado != Estado.TEMPESTADE:
		limpar_raios()
	if estado == Estado.TEMPESTADE and anterior != Estado.TEMPESTADE:
		_cronometro_raio = _rng.randf_range(1.5, INTERVALO_RAIO_MAX)
	if imediato:
		for c in _camadas:
			c.alfa = float(c.alvos.get(estado, 0.0))
		for nuvem in _nuvens:
			nuvem.modulate.a = float(ALFA_NUVENS.get(estado, 0.0))
	_aplicar_tom(imediato)
	_ajustar_som(imediato)
	if anterior != estado:
		clima_mudou.emit(estado)

func _ao_onda_iniciada(onda: int) -> void:
	# A estação da onda (o Estacoes só a alinha depois, se a onda começou antes da troca agendada)
	var estacao: int = get_parent().estacao_atual
	if estacao != estacao_atual:
		estacao_atual = estacao
	clima_base = sortear_clima(estacao, _rng)
	# Durante a tempestade o mundo fica na chuva forte; o sorteio vale quando ela passar
	if tempestade_ativa:
		return
	if segue_mundo():
		Fazenda.definir_clima_hoje(clima_base)
	definir_clima(clima_base)

## Morrer ou parar as ondas não muda o tempo do mundo; só acaba a tempestade da arena
func _ao_ondas_paradas() -> void:
	tempestade_ativa = false
	clima_base = clima_do_mundo(estacao_atual) if segue_mundo() else clima_padrao(estacao_atual)
	definir_clima(clima_base)
	limpar_raios()

# O evento TEMPESTADE chega antes do onda_iniciada (o gerenciador o define ao montar a onda)
func _ao_evento_alterado(evento: Dictionary) -> void:
	if String(evento.get("id", "")) == "tempestade":
		tempestade_ativa = true
		definir_clima(Estado.TEMPESTADE)
		# Para o resto do mundo (a fazenda) a tempestade é chuva forte: rega, mas sem raios
		if segue_mundo():
			Fazenda.definir_clima_hoje(Estado.CHUVA_FORTE)
	elif tempestade_ativa:
		tempestade_ativa = false
		if segue_mundo():
			Fazenda.definir_clima_hoje(clima_base)
		definir_clima(clima_base)
		limpar_raios()

func _aplicar_tom(imediato: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().call_group("iluminacao", "definir_tom_clima", TONS.get(clima_atual, Color.WHITE), 0.0 if imediato else DURACAO_TOM)

# --- Visuais -----------------------------------------------------------------------------------------------

func _criar_visuais() -> void:
	# Em coordenadas do mundo (acima de tudo menos dos CanvasLayers: o HUD fica por cima) e tingido pela noite
	_mundo = Node2D.new()
	_mundo.name = "Mundo"
	_mundo.top_level = true
	_mundo.z_index = Profundidade.Z_TOPO
	_mundo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mundo)

	_camada_impactos = Node2D.new()
	_camada_impactos.name = "Impactos"
	_camada_impactos.z_as_relative = false
	_camada_impactos.z_index = Profundidade.Z_CHAO + 5  # no chão, abaixo de personagens e árvores
	_mundo.add_child(_camada_impactos)

	_camada_nuvens = Node2D.new()
	_camada_nuvens.name = "Nuvens"
	_camada_nuvens.z_as_relative = false
	_camada_nuvens.z_index = Profundidade.Z_TOPO - 1  # sobre tudo, só abaixo do tempo (chuva/neve/raios)
	_mundo.add_child(_camada_nuvens)

	# Forte antes da leve (fica atrás); as cores de alfa deixam o céu visível por entre as gotas
	_nova_camada_queda(FOLHA_CHUVA_FORTE, TEMPO_CHUVA_FORTE,
			{Estado.CHUVA_FORTE: 0.9, Estado.TEMPESTADE: 1.0})
	_nova_camada_queda(FOLHA_CHUVA_LEVE, TEMPO_CHUVA_LEVE,
			{Estado.CHUVA_LEVE: 0.9, Estado.CHUVA_FORTE: 0.85, Estado.TEMPESTADE: 0.9})
	_nova_camada_queda(FOLHA_NEVE_FORTE, TEMPO_NEVE_FORTE, {Estado.NEVE_FORTE: 1.0})
	_nova_camada_queda(FOLHA_NEVE_LEVE, TEMPO_NEVE_LEVE, {Estado.NEVE_LEVE: 1.0, Estado.NEVE_FORTE: 0.9})

	_camada_raios = Node2D.new()
	_camada_raios.name = "Raios"
	_camada_raios.z_as_relative = false
	_camada_raios.z_index = Profundidade.Z_TOPO + 1
	_mundo.add_child(_camada_raios)

	_quadros_respingo = _fatiar(FOLHA_RESPINGO, LADO_IMPACTO, LADO_IMPACTO)
	_quadros_floco = _fatiar(FOLHA_FLOCO, LADO_IMPACTO, LADO_IMPACTO)
	_criar_nuvens()

## Fatia uma folha em quadros lado a lado (cada quadro vira uma ImageTexture própria: o TextureRect em modo
## TILE repete a textura inteira, e um AtlasTexture não ladrilha direito)
func _fatiar(folha: Texture2D, largura: int, altura: int) -> Array[Texture2D]:
	var imagem := folha.get_image()
	var quadros: Array[Texture2D] = []
	@warning_ignore("integer_division")
	var quantidade := imagem.get_width() / largura
	for i in quantidade:
		quadros.append(ImageTexture.create_from_image(imagem.get_region(Rect2i(i * largura, 0, largura, altura))))
	return quadros

func _nova_camada_queda(folha: Texture2D, duracao: float, alvos: Dictionary) -> void:
	var camada := Camada.new()
	camada.quadros = _fatiar(folha, LARGURA_QUEDA, ALTURA_QUEDA)
	camada.duracao = duracao
	camada.alvos = alvos
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = camada.quadros[0]
	rect.visible = false
	camada.no = rect
	_mundo.add_child(rect)
	_camadas.append(camada)

## Gera a cobertura de nuvens: máscara por ruído sem emendas (as bordas da textura casam ao repetir) e as
## peças do autotile escolhidas pelos vizinhos de cada célula
func _criar_nuvens() -> void:
	var mascara := mascara_nuvens(NUVENS_COLUNAS, NUVENS_LINHAS, NUVENS_COBERTURA, NUVENS_SEMENTE)
	var folha := FOLHA_NUVEM.get_image()
	folha.convert(Image.FORMAT_RGBA8)
	var lado := LADO_TILE_NUVEM
	var imagem := Image.create(NUVENS_COLUNAS * lado, NUVENS_LINHAS * lado, false, Image.FORMAT_RGBA8)
	for y in NUVENS_LINHAS:
		for x in NUVENS_COLUNAS:
			var peca := peca_nuvem(mascara, x, y)
			if peca.x >= 0:
				imagem.blit_rect(folha, Rect2i(peca * lado, Vector2i(lado, lado)), Vector2i(x, y) * lado)
	_tamanho_nuvens = Vector2(imagem.get_size())
	var rect := TextureRect.new()
	rect.name = "Cobertura"
	rect.texture = ImageTexture.create_from_image(imagem)
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	rect.visible = false
	_camada_nuvens.add_child(rect)
	_nuvens.append(rect)

## Máscara de nuvem (true = sombra) com `cobertura` das células cobertas, repetível nas bordas. Depois limpa o que
## a folha não sabe desenhar: faixas de 1 célula (borda dos dois lados) e céu aberto só nas diagonais
static func mascara_nuvens(colunas: int, linhas: int, cobertura: float, semente: int) -> Array:
	var ruido := FastNoiseLite.new()
	ruido.seed = semente
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = NUVENS_FREQUENCIA
	ruido.fractal_octaves = 2
	var imagem := ruido.get_seamless_image(colunas, linhas)
	var valores: Array[float] = []
	for y in linhas:
		for x in colunas:
			valores.append(imagem.get_pixel(x, y).r)
	var ordenados := valores.duplicate()
	ordenados.sort()
	var corte: float = ordenados[clampi(int((1.0 - cobertura) * ordenados.size()), 0, ordenados.size() - 1)]
	var mascara: Array = []
	for y in linhas:
		var linha: Array[bool] = []
		for x in colunas:
			linha.append(valores[y * colunas + x] >= corte)
		mascara.append(linha)
	for _passada in 12:
		var mudou := false
		for y in linhas:
			for x in colunas:
				if not mascara[y][x]:
					continue
				var n := _celula(mascara, x, y - 1)
				var s := _celula(mascara, x, y + 1)
				var o := _celula(mascara, x - 1, y)
				var l := _celula(mascara, x + 1, y)
				if (not n and not s) or (not o and not l):
					mascara[y][x] = false
					mudou = true
				elif n and s and o and l:
					var diagonais_abertas: Array[Vector2i] = []
					for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
						if not _celula(mascara, x + d.x, y + d.y):
							diagonais_abertas.append(d)
					# a folha só tem canto interno de uma diagonal por vez: fecha as outras
					if diagonais_abertas.size() >= 2:
						for d in diagonais_abertas:
							mascara[posmod(y + d.y, linhas)][posmod(x + d.x, colunas)] = true
						mudou = true
		if not mudou:
			break
	return mascara

static func _celula(mascara: Array, x: int, y: int) -> bool:
	var linhas := mascara.size()
	var colunas: int = mascara[0].size()
	return mascara[posmod(y, linhas)][posmod(x, colunas)]

## Peça da folha para a célula (x, y); (-1, -1) = céu aberto (nada desenhado)
static func peca_nuvem(mascara: Array, x: int, y: int) -> Vector2i:
	if not _celula(mascara, x, y):
		return Vector2i(-1, -1)
	var n := _celula(mascara, x, y - 1)
	var s := _celula(mascara, x, y + 1)
	var o := _celula(mascara, x - 1, y)
	var l := _celula(mascara, x + 1, y)
	if n and s and o and l:
		if not _celula(mascara, x + 1, y + 1):
			return PECAS_NUVEM_CANTO_INTERNO["sl"]
		if not _celula(mascara, x - 1, y + 1):
			return PECAS_NUVEM_CANTO_INTERNO["so"]
		if not _celula(mascara, x + 1, y - 1):
			return PECAS_NUVEM_CANTO_INTERNO["nl"]
		if not _celula(mascara, x - 1, y - 1):
			return PECAS_NUVEM_CANTO_INTERNO["no"]
		return PECA_NUVEM_CENTRO
	var chave := ("n" if not n else ("s" if not s else "")) + ("o" if not o else ("l" if not l else ""))
	return PECAS_NUVEM_BORDA.get(chave, PECA_NUVEM_CENTRO)

func _criar_flash() -> void:
	# Mesma camada do fade da estação e do HUD (1), antes dele na árvore: o HUD continua por cima do clarão
	_flash_camada = CanvasLayer.new()
	_flash_camada.name = "FlashRaio"
	_flash_camada.layer = 1
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_camada.add_child(_flash)
	add_child(_flash_camada)

## Clarão branco de um raio: some num quadro e desvanece devagar
func piscar_raio(intensidade := 0.85) -> void:
	if _tween_flash:
		_tween_flash.kill()
	_flash.color.a = intensidade
	_tween_flash = create_tween()
	_tween_flash.tween_interval(0.05)
	_tween_flash.tween_property(_flash, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# --- Som ---------------------------------------------------------------------------------------------------

func _criar_som() -> void:
	_som_chuva = AudioStreamPlayer.new()
	_som_chuva.name = "SomChuva"
	var fluxo: AudioStreamWAV = SOM_CHUVA
	# O .import já pede loop; isto garante o mesmo caso o arquivo seja reimportado com outras opções
	if fluxo.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		fluxo = SOM_CHUVA.duplicate()
		fluxo.loop_mode = AudioStreamWAV.LOOP_FORWARD
		fluxo.loop_begin = 0
		@warning_ignore("integer_division")
		var quadros_de_audio := fluxo.data.size() / 2
		fluxo.loop_end = quadros_de_audio
	_som_chuva.stream = fluxo
	_som_chuva.volume_db = VOLUME_SILENCIO
	add_child(_som_chuva)

func _ajustar_som(imediato: bool) -> void:
	if _som_chuva == null:
		return
	var alvo: float = VOLUME_CHUVA.get(clima_atual, VOLUME_SILENCIO)
	if _tween_som:
		_tween_som.kill()
	if alvo > VOLUME_SILENCIO and not _som_chuva.playing:
		_som_chuva.volume_db = VOLUME_SILENCIO
		_som_chuva.play()
	if imediato or not is_inside_tree():
		_som_chuva.volume_db = alvo
		if alvo <= VOLUME_SILENCIO:
			_som_chuva.stop()
		return
	_tween_som = create_tween()
	_tween_som.tween_property(_som_chuva, "volume_db", alvo, DURACAO_FADE)
	if alvo <= VOLUME_SILENCIO:
		_tween_som.tween_callback(_som_chuva.stop)

# --- Quadro a quadro ------------------------------------------------------------------------------------

## Retângulo do mundo que a câmera enxerga agora (coordenadas globais). No cooperativo junta as duas metades da
## tela que mostram este mundo: só a câmera da janela principal cobria a metade do jogador 1
func retangulo_visivel() -> Rect2:
	var retangulos := retangulos_visiveis()
	var total: Rect2 = retangulos[0]
	for r in retangulos:
		total = total.merge(r)
	return total

func retangulos_visiveis() -> Array[Rect2]:
	var retangulos: Array[Rect2] = []
	for vp in Cooperativo.vistas_do_mundo(get_viewport().find_world_2d()):
		retangulos.append(vp.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size))
	if retangulos.is_empty():
		var vp := get_viewport()
		retangulos.append(vp.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size))
	return retangulos

func _process(delta: float) -> void:
	var visivel := retangulo_visivel()
	_atualizar_camadas(delta, visivel)
	_atualizar_nuvens(delta, visivel)
	# Respingos numa das metades por vez (a união de duas vistas distantes cobre muito chão que ninguém vê)
	var vistas := retangulos_visiveis()
	_atualizar_impactos(delta, vistas[_rng.randi() % vistas.size()])
	if clima_atual == Estado.TEMPESTADE:
		_atualizar_raios(delta)

func _atualizar_camadas(delta: float, visivel: Rect2) -> void:
	for c in _camadas:
		var alvo: float = c.alvos.get(clima_atual, 0.0)
		c.alfa = move_toward(c.alfa, alvo, delta / DURACAO_FADE)
		var rect := c.no as TextureRect
		rect.visible = c.alfa > 0.001
		if not rect.visible:
			continue
		c.tempo += delta
		while c.tempo >= c.duracao:
			c.tempo -= c.duracao
			c.indice = (c.indice + 1) % c.quadros.size()
			rect.texture = c.quadros[c.indice]
		rect.modulate.a = c.alfa
		# Presa ao mundo, não à tela: o retângulo começa num múltiplo do ladrilho, então o desenho da chuva
		# fica parado no mapa quando a câmera anda (só a animação cai). Um ladrilho a mais cobre a sobra
		var ladrilho := Vector2(LARGURA_QUEDA, ALTURA_QUEDA)
		rect.position = (visivel.position / ladrilho).floor() * ladrilho
		rect.size = ((visivel.end - rect.position) / ladrilho).ceil() * ladrilho + ladrilho

func _atualizar_nuvens(delta: float, visivel: Rect2) -> void:
	var alvo: float = ALFA_NUVENS.get(clima_atual, 0.0)
	# o vento continua soprando mesmo sem nuvem na tela, para não voltarem do mesmo jeito
	_deslocamento_nuvens = (_deslocamento_nuvens + NUVENS_VENTO * delta).posmodv(_tamanho_nuvens)
	for nuvem in _nuvens:
		nuvem.modulate.a = move_toward(nuvem.modulate.a, alvo, delta / DURACAO_FADE)
		nuvem.visible = nuvem.modulate.a > 0.001
		if not nuvem.visible:
			continue
		# Presa ao mundo e arrastada pelo vento: a origem do ladrilho fica numa grade do tamanho da textura,
		# deslocada pelo vento acumulado; um ladrilho a mais cobre a sobra da tela
		var origem := ((visivel.position - _deslocamento_nuvens) / _tamanho_nuvens).floor() * _tamanho_nuvens + _deslocamento_nuvens
		nuvem.position = origem.round()
		nuvem.size = ((visivel.end - nuvem.position) / _tamanho_nuvens).ceil() * _tamanho_nuvens + _tamanho_nuvens

# --- Respingos e flocos -----------------------------------------------------------------------------------

func _atualizar_impactos(delta: float, visivel: Rect2) -> void:
	for i in range(_impactos.size() - 1, -1, -1):
		var impacto := _impactos[i]
		impacto.tempo += delta
		var indice := int(impacto.tempo / impacto.duracao)
		if indice >= impacto.quadros.size():
			impacto.sprite.queue_free()
			_impactos.remove_at(i)
			continue
		impacto.sprite.texture = impacto.quadros[indice]
	if not INTERVALO_IMPACTO.has(clima_atual):
		return
	_cronometro_impacto -= delta
	if _cronometro_impacto > 0.0:
		return
	_cronometro_impacto = float(INTERVALO_IMPACTO[clima_atual]) * _rng.randf_range(0.6, 1.4)
	if _impactos.size() < MAX_IMPACTOS:
		_gerar_impacto(visivel)

func _gerar_impacto(visivel: Rect2) -> void:
	if _chao == null:
		return
	var neve := eh_neve(clima_atual)
	for tentativa in 8:
		var ponto := visivel.position + Vector2(_rng.randf(), _rng.randf()) * visivel.size
		var celula := _chao.local_to_map(_chao.to_local(ponto))
		if not celula_aceita_impacto(celula, neve):
			continue
		var centro := _chao.to_global(_chao.map_to_local(celula))
		var impacto := Impacto.new()
		impacto.quadros = _quadros_floco if neve else _quadros_respingo
		impacto.duracao = TEMPO_FLOCO if neve else TEMPO_RESPINGO
		impacto.sprite = Sprite2D.new()
		impacto.sprite.texture = impacto.quadros[0]
		impacto.sprite.global_position = centro
		impacto.sprite.modulate.a = 0.9
		_camada_impactos.add_child(impacto.sprite)
		_impactos.append(impacto)
		return

## Uma célula do chão aceita respingo/floco se há chão, não é água nem penhasco, nenhuma copa a cobre
## e (neve) está na terra batida ou, com pouca chance, na neve do chão
func celula_aceita_impacto(celula: Vector2i, neve := false) -> bool:
	# a terra batida do acampamento substitui o chão (não há tile de grama/neve embaixo dela)
	var na_terra := _terra != null and _terra.get_cell_source_id(celula) != -1
	if _chao == null or (_chao.get_cell_source_id(celula) == -1 and not na_terra):
		return false
	if _agua != null and _agua.get_cell_source_id(celula) != -1:
		return false
	if _penhasco != null and _penhasco.get_cell_source_id(celula) != -1:
		return false
	var centro := _chao.to_global(_chao.map_to_local(celula))
	if _coberto(centro):
		return false
	if neve and not na_terra and _rng.randf() >= CHANCE_FLOCO_NA_NEVE:
		return false
	return true

# Retângulos (globais) dos sprites altos do terreno (árvores, caverna): a chuva cai sobre eles, não no chão
func _coberto(ponto: Vector2) -> bool:
	if not _coberturas_prontas:
		_coberturas_prontas = true
		_coletar_coberturas(_terreno)
	for i in _coberturas.size():
		# as árvores de outra estação etc. ficam escondidas e não cobrem nada
		if _coberturas[i].has_point(ponto) and _cobertura_nos[i].is_visible_in_tree():
			return true
	return false

func _coletar_coberturas(no: Node) -> void:
	for filho in no.get_children():
		var sprite := filho as Sprite2D
		if sprite != null and sprite.texture != null:
			var local := sprite.get_rect()
			if local.size.y >= ALTURA_MINIMA_COBERTURA:
				_coberturas.append(sprite.get_global_transform() * local)
				_cobertura_nos.append(sprite)
		if filho.get_child_count() > 0 and not (filho is TileMapLayer):
			_coletar_coberturas(filho)

# --- Raios --------------------------------------------------------------------------------------------------

func _atualizar_raios(delta: float) -> void:
	_cronometro_raio -= delta
	if _cronometro_raio > 0.0:
		return
	_cronometro_raio = _rng.randf_range(INTERVALO_RAIO_MIN, INTERVALO_RAIO_MAX)
	if _jogador == null or not is_instance_valid(_jogador) or bool(_jogador.get("estaMorto")):
		return
	criar_raio(sortear_ponto_raio(), AVISO_RAIO)

## Ponto do chão onde o próximo raio vai cair: metade das vezes perto do jogador (perto o bastante para ameaçar,
## longe o bastante para dar para fugir), a outra metade em cima de um inimigo
func sortear_ponto_raio() -> Vector2:
	var pes_jogador: Vector2 = _jogador.global_position + Vector2(0, Profundidade.PES_JOGADOR)
	var inimigos: Array[Node2D] = []
	for no in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(no) and no is Node2D and not bool(no.get("esta_morto")):
			inimigos.append(no)
	if inimigos.is_empty() or _rng.randf() < 0.5:
		return pes_jogador + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(24.0, 90.0)
	var alvo := inimigos[_rng.randi() % inimigos.size()]
	return alvo.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 14.0)

## Cria um raio em `ponto` (global): aviso no chão por `aviso` segundos e depois a queda. O dano segue a onda
func criar_raio(ponto: Vector2, aviso: float) -> Node2D:
	var raio: Node2D = RaioScript.new()
	var mult_vida := 1.0
	var mult_dano := 1.0
	if _gerenciador != null:
		mult_vida = _gerenciador.mult_vida_onda(_gerenciador.onda_atual)
		mult_dano = _gerenciador.mult_dano_onda(_gerenciador.onda_atual)
	_camada_raios.add_child(raio)
	raio.iniciar(ponto, aviso, RaioScript.dano_para_inimigo(mult_vida), RaioScript.dano_para_jogador(mult_dano), _jogador)
	raios_criados += 1
	raio_criado.emit(raio)
	return raio

func raios_ativos() -> int:
	return _camada_raios.get_child_count() if _camada_raios != null else 0

## Apaga todos os raios (e os avisos no chão deles): fim da onda, parar ondas ou saída da tempestade
func limpar_raios() -> void:
	if _camada_raios == null:
		return
	for raio in _camada_raios.get_children():
		_camada_raios.remove_child(raio)
		raio.queue_free()
