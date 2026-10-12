extends Node

## Efeitos sonoros 8-bit (gerados por ferramentas/sons/gerar_sons.py). Sem música.
## A chuva em loop (sons/chuva.wav) não passa por aqui: quem a toca é o clima (Codigos/Design/clima.gd), com player próprio.
## Um pool de AudioStreamPlayers toca os sons; o volume geral é o do bus Master (opcoes_jogo.gd).
## Uso: Sons.tocar("moeda") ou Sons.tocar("acerto", 0.15, -3.0)

const TAMANHO_POOL := 8
## Quantas vezes o mesmo som pode começar no mesmo quadro (muitas moedas/acertos juntos viram um só)
const MAX_POR_QUADRO := 1
## Intervalo mínimo (s) entre duas repetições do mesmo som; o que não estiver aqui usa o padrão
const INTERVALO_PADRAO := 0.0
const INTERVALOS := {
	"moeda": 0.045,
	"acerto": 0.03,
	"menu_mover": 0.03,
	"inimigo_morre": 0.04,
	"golpe_espada": 0.05,
	"golpe_lanca": 0.05,
	"pegar_semente": 0.05,
}

const STREAMS := {
	"golpe_espada": preload("res://sons/golpe_espada.wav"),
	"golpe_lanca": preload("res://sons/golpe_lanca.wav"),
	"flecha": preload("res://sons/flecha.wav"),
	"acerto": preload("res://sons/acerto.wav"),
	"inimigo_morre": preload("res://sons/inimigo_morre.wav"),
	"jogador_dano": preload("res://sons/jogador_dano.wav"),
	"jogador_morre": preload("res://sons/jogador_morre.wav"),
	"dash": preload("res://sons/dash.wav"),
	"reviver": preload("res://sons/reviver.wav"),
	"moeda": preload("res://sons/moeda.wav"),
	"compra": preload("res://sons/compra.wav"),
	"melhoria": preload("res://sons/melhoria.wav"),
	"erro": preload("res://sons/erro.wav"),
	"onda_inicio": preload("res://sons/onda_inicio.wav"),
	"onda_fim": preload("res://sons/onda_fim.wav"),
	"chefe_aparece": preload("res://sons/chefe_aparece.wav"),
	"chefe_morre": preload("res://sons/chefe_morre.wav"),
	"estacao": preload("res://sons/estacao.wav"),
	"trovao": preload("res://sons/trovao.wav"),
	"menu_mover": preload("res://sons/menu_mover.wav"),
	"menu_confirmar": preload("res://sons/menu_confirmar.wav"),
	"enxada": preload("res://sons/enxada.wav"),
	"regar": preload("res://sons/regar.wav"),
	"plantar": preload("res://sons/plantar.wav"),
	"colher": preload("res://sons/colher.wav"),
	"caldeirao": preload("res://sons/caldeirao.wav"),
	"beber": preload("res://sons/beber.wav"),
	"pegar_semente": preload("res://sons/pegar_semente.wav"),
}

## Botões marcados com esta meta têm som próprio (compra, melhoria...) e não tocam o "menu_confirmar" padrão
const META_SOM_PROPRIO := "som_proprio"
const META_SOM_LIGADO := "som_ligado"

var _jogadores: Array[AudioStreamPlayer] = []
var _proximo := 0
var _quadro_contado := -1
var _contagem_quadro: Dictionary = {}
var _ultimo_uso: Dictionary = {}

func _ready() -> void:
	# Os sons dos menus continuam tocando com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in TAMANHO_POOL:
		var jogador := AudioStreamPlayer.new()
		jogador.name = "Jogador%d" % i
		add_child(jogador)
		_jogadores.append(jogador)

func existe(nome: String) -> bool:
	return STREAMS.has(nome)

## Toca o efeito `nome`. variacao_pitch: sorteia o tom entre 1 ± variação (0 = sempre igual).
## Devolve false se o nome não existe ou se a repetição foi barrada pelo limite (por quadro / intervalo mínimo)
func tocar(nome: String, variacao_pitch := 0.1, volume_db := 0.0) -> bool:
	if not STREAMS.has(nome):
		push_warning("Som inexistente: %s" % nome)
		return false
	if not _liberar_repeticao(nome):
		return false
	var jogador := _obter_jogador()
	if jogador == null:
		return false
	jogador.stream = STREAMS[nome]
	jogador.volume_db = volume_db
	jogador.pitch_scale = 1.0 + randf_range(-variacao_pitch, variacao_pitch) if variacao_pitch > 0.0 else 1.0
	jogador.play()
	return true

# Limite de repetições do mesmo som no mesmo quadro, mais um intervalo mínimo por som
func _liberar_repeticao(nome: String) -> bool:
	var quadro := Engine.get_process_frames()
	if quadro != _quadro_contado:
		_quadro_contado = quadro
		_contagem_quadro.clear()
	var usos: int = _contagem_quadro.get(nome, 0)
	if usos >= MAX_POR_QUADRO:
		return false
	var agora := Time.get_ticks_msec() / 1000.0
	var intervalo: float = INTERVALOS.get(nome, INTERVALO_PADRAO)
	if intervalo > 0.0 and agora - float(_ultimo_uso.get(nome, -100.0)) < intervalo:
		return false
	_contagem_quadro[nome] = usos + 1
	_ultimo_uso[nome] = agora
	return true

# Um player livre; sem nenhum livre, reaproveita o que está tocando há mais tempo (rodízio)
func _obter_jogador() -> AudioStreamPlayer:
	if _jogadores.is_empty():
		return null
	for jogador in _jogadores:
		if not jogador.playing:
			return jogador
	var jogador := _jogadores[_proximo]
	_proximo = (_proximo + 1) % _jogadores.size()
	return jogador

## Liga os sons de menu a todos os botões sob `raiz`: foco (teclado/controle) toca "menu_mover" e o clique
## toca "menu_confirmar". Seguro chamar de novo na mesma árvore; botões com a meta META_SOM_PROPRIO
## só ganham o som de foco
func ligar_botoes(raiz: Node) -> void:
	for no in raiz.find_children("*", "BaseButton", true, false):
		ligar_botao(no as BaseButton)

func ligar_botao(botao: BaseButton) -> void:
	if botao.has_meta(META_SOM_LIGADO):
		return
	botao.set_meta(META_SOM_LIGADO, true)
	botao.focus_entered.connect(_ao_botao_focado.bind(botao))
	botao.pressed.connect(_ao_botao_pressionado.bind(botao))

func _ao_botao_focado(botao: BaseButton) -> void:
	# Só botões visíveis; a abertura de uma tela que já foca o botão também soa (é o feedback de abrir)
	if botao.is_visible_in_tree():
		tocar("menu_mover", 0.0, -2.0)

func _ao_botao_pressionado(botao: BaseButton) -> void:
	if not botao.has_meta(META_SOM_PROPRIO):
		tocar("menu_confirmar", 0.0)
