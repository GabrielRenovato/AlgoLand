extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_fazenda.gd
# Carrega a cena de jogo e confere as animações de fazenda do jogador (fazenda_jogador.gd): quadros por direção,
# ferramenta certa, impacto uma vez por ação, jogador travado durante a ação e camadas de volta no fim.
# Não grava inventário; o Progresso usa um arquivo de teste, apagado no final.

const Objetos := preload("res://codigo/dados/objetos_refinados.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const FazendaJogador := preload("res://codigo/jogador/fazenda_jogador.gd")
const CAMINHO_PROGRESSO := "user://teste_fazenda_progresso.json"
const DIRECOES := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]

var _falhas: int = 0
var _cena: Node
var _jogador: Node
var _fazenda: Node
var _impactos: Array = []
var _concluidas: Array = []

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _duracao(acao: String) -> float:
	var total := 0.0
	for q in FazendaJogador.ACOES[acao]["quadros"]:
		total += float(q[1])
	return total

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	var progresso = root.get_node("Progresso")
	progresso.caminho_save = CAMINHO_PROGRESSO
	# O clima do mundo fica no autoload Fazenda (as ondas o mudam): arquivo de teste, sem o save real
	var fazenda_isolada = root.get_node("Fazenda")
	fazenda_isolada.caminho_save = "user://teste_fazenda_fazenda.json"
	fazenda_isolada.apagar()
	progresso.apagar()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	_jogador = _cena.get_node("Jogador")
	_jogador.invulneravel = true
	_jogador.temporizador_invul = 9999.0
	_fazenda = _jogador.no_fazenda
	_jogador.acao_fazenda_impacto.connect(func(acao, ponto): _impactos.append([acao, ponto]))
	_jogador.acao_fazenda_concluida.connect(func(acao): _concluidas.append(acao))
	var base: Node2D = _jogador.get_node("CompositeSprites/BaseSprites")
	var armaduras: Node2D = _jogador.get_node("CompositeSprites/Armaduras")

	_verificar("no de fazenda criado e escondido", _fazenda != null and not _fazenda.visible, "")
	# As armaduras ficam escondidas de propósito (só aparecem como ícone no inventário)
	_verificar("armaduras escondidas no boneco", not armaduras.visible, "")
	_verificar("acao inexistente e recusada", not _jogador.acao_fazenda("dancar"), "")

	# --- Cada ação inteira, olhando para baixo: ferramenta, quadros, impacto único e fim
	for acao in FazendaJogador.ACOES:
		_impactos.clear()
		_concluidas.clear()
		_jogador._direcao_ataque = Vector2.DOWN
		var comecou: bool = _jogador.acao_fazenda(acao)
		var dados: Dictionary = FazendaJogador.ACOES[acao]
		var linha_esperada: int = dados["linha_base"]
		var quadro_inicial: int = linha_esperada * 8 + int(dados["quadros"][0][0])
		_verificar("%s: comeca" % acao, comecou and _fazenda.visible and _jogador.esta_em_acao_fazenda, "")
		_verificar("%s: primeiro quadro (linha %d)" % [acao, linha_esperada], _fazenda._corpo.frame == quadro_inicial and _fazenda._ferramenta.frame == quadro_inicial, "frame=%d" % _fazenda._corpo.frame)
		_verificar("%s: ferramenta %s" % [acao, dados["ferramenta"]], _fazenda._ferramenta.texture == Objetos.textura(load("res://assets/personagens/Fazenda/ferramenta_%s.png" % dados["ferramenta"])), _fazenda._ferramenta.texture.resource_path)
		_verificar("%s: esconde o boneco normal" % acao, not base.visible and not armaduras.visible, "")
		_verificar("%s: nao comeca outra por cima" % acao, not _jogador.acao_fazenda("enxada"), "")
		await create_timer(_duracao(acao) + 0.15).timeout
		_verificar("%s: impacto uma vez" % acao, _impactos.size() == 1 and _impactos[0][0] == acao, str(_impactos))
		_verificar("%s: concluida uma vez" % acao, _concluidas == [acao], str(_concluidas))
		_verificar("%s: volta ao normal" % acao, not _fazenda.visible and not _jogador.esta_em_acao_fazenda and base.visible and not armaduras.visible, "")

	# --- Direções: linha certa dentro do bloco (baixo, cima, direita, esquerda)
	for i in DIRECOES.size():
		for acao in ["enxada", "regar"]:
			_jogador._direcao_ataque = DIRECOES[i]
			_jogador.acao_fazenda(acao)
			var linha_base: int = FazendaJogador.ACOES[acao]["linha_base"]
			var linha: int = _fazenda._corpo.frame / 8
			_verificar("%s direcao %s: linha %d" % [acao, DIRECOES[i], linha_base + i], linha == linha_base + i, "linha=%d" % linha)
			_jogador.cancelar_acao_fazenda()

	# --- Ponto da ação à frente dos pés
	var pes: Vector2 = _jogador.global_position + Vector2(0, 11)
	_jogador._direcao_ataque = Vector2.RIGHT
	_verificar("ponto da acao a direita", _jogador.ponto_acao_fazenda().x > pes.x + 8.0, str(_jogador.ponto_acao_fazenda()))
	_jogador._direcao_ataque = Vector2.UP
	_verificar("ponto da acao acima", _jogador.ponto_acao_fazenda().y < pes.y - 8.0, str(_jogador.ponto_acao_fazenda()))

	# --- Jogador travado durante a ação (não anda mesmo segurando a direção)
	_jogador._direcao_ataque = Vector2.DOWN
	var posicao: Vector2 = _jogador.global_position
	_jogador.acao_fazenda("machado")
	Input.action_press("move_right")
	await create_timer(0.3).timeout
	Input.action_release("move_right")
	_verificar("parado durante a acao", _jogador.global_position.distance_to(posicao) < 0.5, "d=%f" % _jogador.global_position.distance_to(posicao))
	await create_timer(_duracao("machado")).timeout

	# --- Dano interrompe a ação
	_jogador.invulneravel = false
	_jogador.acao_fazenda("picareta")
	_jogador.receber_dano(1)
	_verificar("dano interrompe a acao", not _jogador.esta_em_acao_fazenda and not _fazenda.visible, "acao=%s visivel=%s base=%s reacao=%s" % [_jogador.esta_em_acao_fazenda, _fazenda.visible, base.visible, _jogador.no_reacao.visible])
	# depois da pose de "ferido" o boneco normal volta
	await create_timer(0.6).timeout
	_verificar("boneco normal volta depois do dano", base.visible and not armaduras.visible, "base=%s reacao=%s" % [base.visible, _jogador.no_reacao.visible])
	_jogador.invulneravel = true
	_jogador.temporizador_invul = 9999.0

	# --- Com menu aberto (movimento desabilitado) não começa
	_jogador.desabilitar_todas_acoes(true)
	_verificar("menu aberto: nao comeca", not _jogador.acao_fazenda("enxada"), "")
	_jogador.desabilitar_todas_acoes(false)

	# --- Aparência: roupa, cabelo e cor do cabelo escolhidos na customização
	_jogador.roupa_atual = 5
	_jogador.cabelo_atual = 1
	_jogador.cor_cabelo = Color(0.8, 0.3, 0.2)
	_jogador.acao_fazenda("plantar")
	await _quadros(2)
	_verificar("roupa da customizacao (roupa_6)", _fazenda._roupa.texture == Aparencia.roupa_refinada(5,"fazenda",_jogador.pecas_cavaleiro,_jogador.raizes_armadura), _fazenda._roupa.texture.resource_path)
	_verificar("cabelo da customizacao (cabelo_2) com a cor", _fazenda._cabelo.texture == Aparencia.cabelo_refinado(1,"fazenda",5,_jogador.pecas_cavaleiro,_jogador.raizes_armadura) and _fazenda._cabelo.modulate == Color(0.8, 0.3, 0.2), "")
	_jogador.cancelar_acao_fazenda()

	if FileAccess.file_exists(CAMINHO_PROGRESSO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_PROGRESSO))
	print("FALHAS: ", _falhas)
	if FileAccess.file_exists("user://teste_fazenda_fazenda.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_fazenda_fazenda.json"))
	quit(_falhas)
