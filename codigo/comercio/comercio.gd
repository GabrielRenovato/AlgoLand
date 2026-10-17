extends Node

## Rota curta: cada casa leva uma unidade; pedidos e cotas são compartilhados pelos dois jogadores.
signal alterado
const Plantas := preload("res://codigo/dados/plantas.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
const EVENTOS := {
	"bandidos": ["BANDIDOS NA ESTRADA", "Gremlins saqueadores bloquearam a passagem.", ["LUTAR", "PAGAR 6 MOEDAS CADA", "FUGIR (PERDE 1 CARGA)"]],
	"roda": ["RODA SOLTA", "Um pino escapou da roda. O conserto atrasa a chegada.", ["CONSERTAR (+2 HORAS)", "COMPRAR PINO (4 CADA)"]],
	"mercador": ["MERCADOR AMBULANTE", "Ele troca uma unidade da carga por uma semente rara.", ["TROCAR 1 CARGA", "SEGUIR VIAGEM"]],
	"viajante": ["VIAJANTE A PE", "Uma viajante pede carona. Ela conhece o pombo da vila.", ["DAR CARONA (+1 HORA)", "SEGUIR VIAGEM"]],
	"chuva": ["ESTRADA ATOLADA", "A chuva transformou a passagem em lama.", ["EMPURRAR (+2 HORAS)", "DESVIAR (+3 HORAS)"]],
	"monstros": ["MONSTROS NA ESTRADA", "Criaturas da arena se aproximam da carga.", ["LUTAR", "DESVIAR (+2 HORAS)"]],
}
## Carroça escondida por enquanto (pedido de 2026-10-16): a fazenda não monta a carroça e nenhuma viagem é retomada.
## O sistema e os saves continuam intactos; os testes da carroça ligam isto. Para liberar no jogo, trocar para true.
var liberado := false
var caminho_save := "user://comercio.json"
var nivel := 0
## Aparência compartilhada da montaria: preto, marrom ou branco.
var pelagem := 1
var semana := -1
var atendidos: Dictionary = {}
## Carga em preparação é uma reserva da bolsa da fazenda; só sai da bolsa ao partir.
var carga: Array[Dictionary] = []
var prontos: Dictionary = {}
var votos: Dictionary = {}
var eventos: Array[String] = []
var etapa := -1 # -1 preparação; 0..N estrada; N mercado; N+1 resumo
var em_viagem := false
var em_combate := false
var atraso := 0
var receita := [0, 0]
var aviso := ""
var carona := false
var ultimo_dia := 0
var carta_estrada := ""
var _inimigos: Array[Node] = []
var _jogadores: Array[Node2D] = []
var _posicoes: Array[Vector2] = []
var _modos: Array[bool] = []

func _ready() -> void:
	carregar()
	Cidade.carta_lida.connect(_ao_carta_lida)

func definir_pelagem(indice: int) -> void:
	if em_viagem or indice < 0 or indice > 2:
		return
	pelagem = indice
	salvar()
	alterado.emit()

func capacidade() -> int:
	return 8 + nivel * 2

func atualizar_semana() -> void:
	var atual := floori((Calendario.dia - 1) / 7.0)
	if atual != semana:
		semana = atual
		atendidos.clear()

func pedidos() -> Dictionary:
	atualizar_semana()
	# Inverno pede conservas da última colheita de outono.
	var estacao := mini(Calendario.estacao(), 2)
	var plantas := Plantas.plantas_da_estacao(estacao)
	var id := plantas[posmod(semana, plantas.size())]
	var pocao := Pocoes.ORDEM[estacao * 2 + posmod(semana, 2)]
	return {"colheita:" + id: 4, "pocao:" + pocao: 2}

static func nome_produto(chave: String) -> String:
	var p := chave.split(":")
	return String(Plantas.PLANTAS[p[1]]["nome"]) if p[0] == "colheita" else String(Pocoes.POCOES[p[1]]["nome"])

static func preco_local(chave: String) -> int:
	# Valores pequenos em relação às recompensas da arena; poções custam três ingredientes.
	return 2 if chave.begins_with("colheita:") else 6

func preco(chave: String) -> int:
	var cotas := pedidos()
	return preco_local(chave) * 2 if int(atendidos.get(chave, 0)) < int(cotas.get(chave, 0)) else preco_local(chave) + 1

func disponivel(chave: String) -> int:
	var p := chave.split(":")
	var bolsa: Dictionary = Fazenda.colheita if p[0] == "colheita" else Fazenda.pocoes
	return int(bolsa.get(p[1], 0)) - carga.filter(func(c): return c.chave == chave).size() if not em_viagem else 0

func reservar(chave: String, lado: int) -> bool:
	if em_viagem or carga.size() >= capacidade() or disponivel(chave) <= 0 or lado < 1 or lado > 2:
		return false
	carga.append({"chave": chave, "lado": lado})
	prontos.clear()
	alterado.emit()
	return true

func retirar(indice: int, lado: int) -> bool:
	if em_viagem or indice < 0 or indice >= carga.size() or carga[indice].lado != lado:
		return false
	carga.remove_at(indice)
	prontos.clear()
	alterado.emit()
	return true

func melhorar(quem: Node) -> bool:
	if em_viagem or nivel >= 2 or not DadosJogo.gastar_de(quem, 120 + nivel * 120):
		return false
	nivel += 1
	prontos.clear()
	salvar()
	alterado.emit()
	return true

func motivo_partida() -> String:
	if Introducao.ativa():
		return "TERMINE O PRIMEIRO DIA DA INTRODUCAO."
	if Transicao.ocupada:
		return "AGUARDE A TRANSICAO."
	if carga.is_empty():
		return "COLOQUE PRODUTOS NA CARROCA."
	var luz := get_tree().get_first_node_in_group("iluminacao")
	if luz != null and (float(luz.hora) < 6.0 or float(luz.hora) >= 10.0):
		return "PARTIDAS DAS 6H AS 10H; VOLTA NO FIM DO DIA."
	for jogador in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
		if jogador == null:
			continue
		var cena := Cooperativo.cena_de(jogador)
		if cena == null or cena.scene_file_path != "res://cenas/fazenda.tscn" or jogador.global_position.distance_to(Vector2(528, 288)) > 100:
			return "OS VIAJANTES PRECISAM ESTAR JUNTO DA CARROCA."
	return ""

func confirmar(lado: int) -> void:
	if em_viagem:
		return
	aviso = motivo_partida()
	if aviso != "":
		alterado.emit()
		return
	prontos[lado] = true
	if prontos.size() < (2 if Cooperativo.com_dois() else 1):
		aviso = "AGUARDANDO O PARCEIRO CONFIRMAR NA METADE DELE."
		EventosJogo.abrir_tela_para(Cooperativo.parceiro_de(_jogador(lado)), "comercio")
		alterado.emit()
		return
	iniciar()

func iniciar(semente: int = -1) -> bool:
	if em_viagem:
		return false
	# Confere a reserva inteira antes de debitar qualquer produto.
	var total: Dictionary = {}
	for c in carga:
		total[c.chave] = int(total.get(c.chave, 0)) + 1
	for chave: String in total:
		var p := chave.split(":")
		var bolsa: Dictionary = Fazenda.colheita if p[0] == "colheita" else Fazenda.pocoes
		if int(bolsa.get(p[1], 0)) < int(total[chave]):
			aviso = "A BOLSA MUDOU. RETIRE A CARGA INDISPONIVEL."
			prontos.clear()
			alterado.emit()
			return false
	if carga.is_empty():
		return false
	for chave: String in total:
		var p := chave.split(":")
		var bolsa: Dictionary = Fazenda.colheita if p[0] == "colheita" else Fazenda.pocoes
		bolsa[p[1]] = int(bolsa[p[1]]) - int(total[chave])
	Fazenda.bolsas_alteradas.emit()
	Fazenda.salvar()
	atualizar_semana()
	var rng := RandomNumberGenerator.new()
	if semente >= 0:
		rng.seed = semente
	else:
		rng.randomize()
	var opcoes: Array = ["bandidos", "roda", "mercador", "viajante", "monstros"]
	if Fazenda.clima_hoje in [2, 3, 4]:
		opcoes.append("chuva")
	eventos.clear()
	for i in rng.randi_range(2, 3):
		var indice := rng.randi_range(0, opcoes.size() - 1)
		eventos.append(opcoes.pop_at(indice))
	em_viagem = true
	etapa = 0
	atraso = 0
	receita = [0, 0]
	carona = false
	votos.clear()
	aviso = ""
	ultimo_dia = Calendario.dia
	salvar()
	alterado.emit()
	return true

func escolher(indice: int, lado: int) -> void:
	if not em_viagem or em_combate or etapa >= eventos.size() or votos.has(lado):
		return
	var id := eventos[etapa]
	if indice < 0 or indice >= EVENTOS[id][2].size():
		return
	votos[lado] = indice
	if votos.size() < (2 if Cooperativo.com_dois() else 1):
		aviso = "AGUARDANDO A ESCOLHA DO PARCEIRO."
		alterado.emit()
		return
	if votos.has(2) and votos[1] != votos[2]:
		votos.clear()
		aviso = "ESCOLHAS DIFERENTES. COMBINEM UMA OPCAO PARA A CARROCA."
		alterado.emit()
		return
	votos.clear()
	aviso = ""
	if (id == "bandidos" or id == "monstros") and indice == 0:
		iniciar_combate()
		return
	var custo := 6 if id == "bandidos" and indice == 1 else (4 if id == "roda" and indice == 1 else 0)
	for l in range(1, 3 if Cooperativo.com_dois() else 2):
		if DadosJogo.moedas_de(_jogador(l)) < custo:
			aviso = "FALTAM MOEDAS PARA UM DOS VIAJANTES. ESCOLHAM OUTRA OPCAO."
			alterado.emit()
			return
	if custo > 0:
		for l in range(1, 3 if Cooperativo.com_dois() else 2):
			DadosJogo.gastar_de(_jogador(l), custo)
	if id == "bandidos" and indice == 2:
		_perder_carga()
	elif id == "roda" and indice == 0:
		atraso += 2
	elif id == "chuva":
		atraso += 2 + indice
	elif id == "monstros":
		atraso += 2
	elif id == "mercador" and indice == 0:
		var viajante := int(carga[0].lado) if not carga.is_empty() else 1
		var inv := InventarioJogador2 if viajante == 2 else InventarioJogador
		if carga.is_empty() or not inv.adicionar_sementes("melancia", 1):
			aviso = "PRECISA DE CARGA E ESPACO NA MOCHILA."
			alterado.emit()
			return
		_perder_carga()
		inv.salvar()
	elif id == "viajante" and indice == 0:
		carona = true
		atraso += 1
	avancar()

func _perder_carga() -> void:
	if not carga.is_empty():
		carga.pop_front()

func avancar() -> void:
	etapa += 1
	votos.clear()
	salvar()
	alterado.emit()

func vender(indice: int, lado: int) -> int:
	if not em_viagem or etapa != eventos.size() or indice < 0 or indice >= carga.size() or carga[indice].lado != lado:
		return 0
	var chave: String = carga[indice].chave
	var valor := preco(chave)
	atendidos[chave] = int(atendidos.get(chave, 0)) + 1
	carga.remove_at(indice)
	receita[lado - 1] += valor
	# O ouro é recebido na volta, uma única vez, por quem carregou a unidade.
	salvar()
	alterado.emit()
	return valor

func pedir_retorno(lado: int) -> void:
	if not em_viagem or etapa != eventos.size():
		return
	votos[lado] = true
	if votos.size() >= (2 if Cooperativo.com_dois() else 1):
		aviso = ""
		avancar()
	else:
		aviso = "AGUARDANDO O PARCEIRO TERMINAR O MERCADO."
		alterado.emit()

func voltar() -> void:
	if not em_viagem or etapa != eventos.size() + 1:
		return
	for c in carga:
		var p: PackedStringArray = String(c.chave).split(":")
		var bolsa: Dictionary = Fazenda.colheita if p[0] == "colheita" else Fazenda.pocoes
		bolsa[p[1]] = int(bolsa.get(p[1], 0)) + 1
	for lado in range(1, 3):
		if receita[lado - 1] > 0:
			DadosJogo.adicionar_de(_jogador(lado), receita[lado - 1])
	if carona:
		carta_estrada = Cidade.proxima_carta_misteriosa()
		Cidade.marcar_carta_pendente()
		# O pombo existente entrega a próxima carta ao sair da casa.
		AgendaVila.esperando_sair = true
	carga.clear()
	em_viagem = false
	etapa = -1
	prontos.clear()
	votos.clear()
	Fazenda.salvar()
	Fazenda.bolsas_alteradas.emit()
	salvar()
	for interface in get_tree().get_nodes_in_group("interface"):
		interface._fechar_tela("comercio")
	# Ida e volta gastam o dia; os atrasos ficam registrados no resumo.
	Transicao.dormir("carroca", null, true)
	alterado.emit()

func cancelar_preparo(lado: int) -> void:
	prontos.erase(lado)
	alterado.emit()

func _jogador(lado: int) -> Node2D:
	return Cooperativo.jogador2() if lado == 2 else Cooperativo._jogador1()

func iniciar_combate() -> void:
	em_combate = true
	_jogadores.clear()
	_posicoes.clear()
	_modos.clear()
	for lado in range(1, 3 if Cooperativo.com_dois() else 2):
		var jogador := _jogador(lado)
		if jogador == null:
			continue
		_jogadores.append(jogador)
		_posicoes.append(jogador.global_position)
		_modos.append(jogador.modo_fazenda)
		_fechar_para_luta(jogador)
		jogador.modo_fazenda = false
		_modo_barra(jogador, false)
		jogador.global_position = Vector2(480 + lado * 24, 296)
		if jogador.inventario.equipados.arma == null:
			var arma = jogador.inventario.buscar_por_tipo("espada_basica")
			if arma != null:
				jogador.inventario.equipar(arma)
	_inimigos.clear()
	for i in (3 if Cooperativo.com_dois() else 2):
		var cena: PackedScene = preload("res://cenas/inimigos/gremlin.tscn") if eventos[etapa] == "bandidos" else preload("res://cenas/inimigos/slime.tscn")
		var inimigo := cena.instantiate()
		inimigo.position = Vector2(640 + i * 26, 296)
		inimigo.vida = 22
		inimigo.inimigo_morreu.connect(_ao_inimigo_morto.bind(inimigo))
		_jogadores[0].get_parent().add_child(inimigo)
		_inimigos.append(inimigo)
	get_tree().call_group("hud", "anunciar", "PROTEJA A CARROCA", "LUTE OU RECUE INTERAGINDO COM A CARROCA", 3.0)
	alterado.emit()

func _modo_barra(jogador: Node, fazenda: bool) -> void:
	for hud in get_tree().get_nodes_in_group("hud_p2" if bool(jogador.get("eh_p2")) else "hud_p1"):
		if hud.barra_armas != null:
			hud.barra_armas.modo_fazenda = fazenda
			hud.barra_armas._atualizar()

func _fechar_para_luta(jogador: Node) -> void:
	EventosJogo.fechar_tela_de(jogador, "comercio")

func _ao_inimigo_morto(inimigo: Node) -> void:
	_inimigos.erase(inimigo)
	if _inimigos.is_empty() and em_combate:
		terminar_combate(true)

func terminar_combate(vitoria: bool) -> void:
	if not em_combate:
		return
	em_combate = false
	for inimigo in _inimigos:
		if is_instance_valid(inimigo):
			inimigo.queue_free()
	_inimigos.clear()
	for i in _jogadores.size():
		var jogador := _jogadores[i]
		if is_instance_valid(jogador):
			jogador.modo_fazenda = _modos[i]
			_modo_barra(jogador, _modos[i])
			jogador.global_position = _posicoes[i]
			jogador.desabilitar_todas_acoes(true)
	if not vitoria:
		_perder_carga()
		atraso += 2
	aviso = "PASSAGEM LIVRE." if vitoria else "RECUO: UMA CARGA PERDIDA E DUAS HORAS DE ATRASO."
	avancar()
	for jogador in _jogadores:
		if is_instance_valid(jogador):
			EventosJogo.abrir_tela_para(jogador, "comercio")

func salvar() -> bool:
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify({"nivel": nivel, "pelagem": pelagem, "semana": semana, "atendidos": atendidos,
		"viagem": em_viagem, "carga": carga if em_viagem else [], "eventos": eventos, "etapa": etapa,
		"atraso": atraso, "receita": receita, "carona": carona, "ultimo_dia": ultimo_dia, "carta_estrada": carta_estrada}))
	return true

func carregar() -> bool:
	_limpar()
	if not FileAccess.file_exists(caminho_save):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not d is Dictionary:
		return false
	carta_estrada = String(d.get("carta_estrada", ""))
	nivel = clampi(int(d.get("nivel", 0)), 0, 2)
	pelagem = clampi(int(d.get("pelagem", 1)), 0, 2)
	semana = int(d.get("semana", -1))
	atendidos = d.get("atendidos", {})
	em_viagem = bool(d.get("viagem", false))
	if em_viagem:
		for c in d.get("carga", []):
			carga.append(c)
		for id: String in d.get("eventos", []):
			eventos.append(id)
		etapa = clampi(int(d.get("etapa", 0)), 0, eventos.size() + 1)
		atraso = int(d.get("atraso", 0))
		receita = d.get("receita", [0, 0])
		carona = bool(d.get("carona", false))
		ultimo_dia = int(d.get("ultimo_dia", Calendario.dia))
	alterado.emit()
	if not liberado:
		em_viagem = false
		em_combate = false
	return true

func _limpar() -> void:
	nivel = 0
	pelagem = 1
	semana = -1
	atendidos.clear()
	carga.clear()
	prontos.clear()
	votos.clear()
	eventos.clear()
	etapa = -1
	em_viagem = false
	em_combate = false
	atraso = 0
	receita = [0, 0]
	carona = false
	aviso = ""
	ultimo_dia = 0
	carta_estrada = ""

func _ao_carta_lida(id: String) -> void:
	if id == carta_estrada:
		carta_estrada = ""
		salvar()

func apagar() -> void:
	_limpar()
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	alterado.emit()
