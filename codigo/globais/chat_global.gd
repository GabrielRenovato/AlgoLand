extends Node
## Mantém as sessões por jogador durante viagens, sem pertencer a nenhum mapa.
const Sessao := preload("res://codigo/cidade/sessao_lobby.gd")
var sessoes := {}
var _ausentes := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Saves.mundo_trocado.connect(func(_mundo: String) -> void: limpar())

func sessao_de(jogador: Node2D) -> Node:
	if not is_instance_valid(jogador) or not jogador.is_inside_tree(): return null
	var cena := Cooperativo.cena_de(jogador)
	if cena == null: return null
	var lado := 2 if jogador.eh_p2 else 1
	if not sessoes.has(lado):
		var sessao := Sessao.new()
		sessao.jogador = jogador
		sessao.cidade = cena
		sessoes[lado] = sessao
		add_child(sessao)
	var atual: Node = sessoes[lado]
	var mudou: bool = atual.jogador != jogador or atual.cidade != cena
	atual.jogador = jogador
	atual.cidade = cena
	_ausentes[lado] = 0.0
	if mudou:
		atual.participantes.clear()
		atual._ultimo_visual = ""
		atual._tempo = minf(atual._tempo, 0.55)
	return atual

func _process(delta: float) -> void:
	var presentes := {}
	for jogador in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
		if is_instance_valid(jogador) and jogador.is_inside_tree():
			var sessao := sessao_de(jogador)
			if sessao != null: presentes[2 if jogador.eh_p2 else 1] = true
	for lado in sessoes.keys():
		if presentes.has(lado): continue
		# A troca de cena pode ficar alguns quadros sem o novo personagem.
		_ausentes[lado] = float(_ausentes.get(lado, 0)) + delta
		if _ausentes[lado] > 3.0: _encerrar(lado)

func _encerrar(lado: int) -> void:
	var sessao: Node = sessoes[lado]
	sessoes.erase(lado)
	_ausentes.erase(lado)
	sessao.definir_online(false, false)
	remove_child(sessao)
	sessao.queue_free()

func limpar() -> void:
	for lado in sessoes.keys(): _encerrar(lado)

func alvo_da_fala(id: String, mundo: World2D) -> Node2D:
	for sessao in sessoes.values():
		if sessao.eu == id and is_instance_valid(sessao.jogador) and sessao.jogador.get_world_2d() == mundo:
			return sessao.jogador
	for lobby in get_tree().get_nodes_in_group("lobby_cidade"):
		if lobby.get_world_2d() == mundo and lobby.remotos.has(id): return lobby.remotos[id]
	return null
