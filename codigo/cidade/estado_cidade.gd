extends Node

## Progresso social separado do combate e da fazenda. Pedidos sobrevivem a morte e a troca de mapas.
signal alterado
signal conversa_pedida(id: String)
## O jogador fechou a carta que o pombo-correio trouxe (o pombo vai embora)
signal carta_lida(id: String)
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const CAMINHO_SAVE := "user://cidade.json"
var caminho_save := CAMINHO_SAVE
var missoes: Dictionary = {}
var conversas: Dictionary = {}
var visitas: Dictionary = {}
var amizade: Dictionary = {}
var ultimo_presente: Dictionary = {}
var ultimo_dialogo: Dictionary = {}
var ondas_vencidas := 0
## O que cada morador já disse e o que já sabia do jogador (conversa_moradores.gd)
var memoria: Dictionary = {}
## Cartas de pedido que o pombo-correio já entregou: {id da missão: dia em que foi lida}
var cartas: Dictionary = {}
## Dormiu e ainda não recebeu a carta do dia: o pombo entrega quando o jogador sair de casa (agenda_vila.gd)
var carta_pendente := false
## Pedido da carta aberta na caixa de conversa (vazio = conversa normal)
var carta_aberta := ""
var interlocutor := ""
## Conversa aberta como "mesa da taverna" (jogador sentado): cardápio e os vizinhos de mesa, sem interlocutor
var mesa_aberta := false
var mesa_vizinhos: Array = []
var trajetos_moradores: Dictionary = {}
var tempo_moradores := 0.0

func _process(delta: float) -> void:
	tempo_moradores += delta


func _ready() -> void:
	carregar()

func visitar(local: String) -> void:
	if visitas.has(local):
		return
	visitas[local] = true
	_gravar()

## `quem`: o jogador que puxou conversa (no cooperativo a tela abre na metade dele); null = o jogador 1
func conversar(id: String, quem: Node = null) -> void:
	if not Dados.MORADORES.has(id):
		return
	if quem == null: quem = Cooperativo._jogador1()
	interlocutor = id
	if quem != null:
		quem.set_meta("atendimento_dialogo", "")
		quem.set_meta("interlocutor_dialogo",id)
		quem.set_meta("carta_dialogo","")
		quem.set_meta("mesa_dialogo",false)
	mesa_aberta = false
	conversas[id] = true
	if int(ultimo_dialogo.get(id, -1)) != Calendario.dia:
		amizade[id] = mini(int(amizade.get(id, 0)) + 1, 10)
		ultimo_dialogo[id] = Calendario.dia
	_gravar()
	conversa_pedida.emit(id)
	EventosJogo.abrir_tela_para(quem, "conversa_cidade")

## Abrir um serviço não registra conversa nem concede amizade.
func atender(id: String, modo: String, quem: Node) -> void:
	if not Dados.MORADORES.has(id) or quem == null: return
	interlocutor = id
	mesa_aberta = false
	quem.set_meta("interlocutor_dialogo",id)
	quem.set_meta("atendimento_dialogo",modo)
	quem.set_meta("carta_dialogo","")
	quem.set_meta("mesa_dialogo",false)
	conversa_pedida.emit(id)
	EventosJogo.abrir_tela_para(quem,"conversa_cidade")

## Sentado à mesa: abre a caixa de conversa no modo mesa (cardápio e quem está sentado junto). `vizinhos`: ids
func abrir_mesa(quem: Node, vizinhos: Array) -> void:
	interlocutor = ""
	mesa_aberta = true
	if quem != null:
		quem.set_meta("mesa_dialogo",true)
		quem.set_meta("carta_dialogo","")
		quem.set_meta("atendimento_dialogo","")
	mesa_vizinhos = vizinhos
	conversa_pedida.emit("")
	EventosJogo.abrir_tela_para(quem, "conversa_cidade")

## A carta do pombo abre na caixa de conversa de quem a pegou, com o pedido e o botão ACEITAR
func abrir_carta(quem: Node, id: String) -> void:
	if not Dados.MISSOES.has(id) and carta_misteriosa(id).is_empty():
		return
	interlocutor = ""
	mesa_aberta = false
	carta_aberta = id
	if quem != null:
		quem.set_meta("carta_dialogo",id)
		quem.set_meta("atendimento_dialogo","")
		quem.set_meta("mesa_dialogo",false)
	conversa_pedida.emit("")
	EventosJogo.abrir_tela_para(quem, "conversa_cidade")

## A caixa da carta fechou: registra a leitura (aceita ou não, o pombo não traz a mesma carta de novo)
func fechar_carta(identificador := "") -> void:
	var id := identificador if identificador != "" else carta_aberta
	if carta_aberta == id:
		carta_aberta = ""
	if id == "":
		return
	var presente := int(carta_misteriosa(id).get("brasas", 0))
	if presente > 0 and not cartas.has(id):
		Progresso.brasas += presente
		Progresso.salvar()
		Progresso.brasas_alteradas.emit(Progresso.brasas)
	cartas[id] = Calendario.dia
	carta_pendente = false
	_gravar()
	carta_lida.emit(id)

## Próximo pedido que o pombo traz: o primeiro que o jogador ainda não aceitou nem leu por carta
func proxima_carta() -> String:
	var disponiveis: Array = Dados.MISSOES.keys().filter(func(id):
		return not missoes.has(id) and not cartas.has(id) and Dados.missao_na_estacao(id,Calendario.estacao())
	)
	if disponiveis.has("boas_vindas"):
		return "boas_vindas"
	if Calendario.dia % 2 == 0:
		for id in disponiveis:
			if Dados.MISSOES[id]["tipo"] == "peixe": return id
	return "" if disponiveis.is_empty() else String(disponiveis[0])

## A próxima carta sem remetente ainda não lida (Dados.CARTAS_MISTERIOSAS), ou vazio
func proxima_carta_misteriosa() -> String:
	for carta in Dados.CARTAS_MISTERIOSAS:
		if not cartas.has(carta["id"]):
			return carta["id"]
	return ""

## O que o pombo traz hoje: no domingo (ou sem pedidos a entregar) uma carta sem remetente; nos outros dias, o pedido
func carta_do_dia() -> String:
	var pedido := proxima_carta()
	var misterio := proxima_carta_misteriosa()
	if misterio != "" and (pedido == "" or Calendario.dia_da_semana() == 6):
		return misterio
	return pedido

static func carta_misteriosa(id: String) -> Dictionary:
	for carta in Dados.CARTAS_MISTERIOSAS:
		if carta["id"] == id:
			return carta
	return {}

func marcar_carta_pendente() -> void:
	carta_pendente = carta_do_dia() != ""
	salvar()

## O pombo vem no máximo uma vez por dia
func carta_entregue_hoje() -> bool:
	return cartas.values().any(func(dia): return int(dia) == Calendario.dia)

func aceitar(id: String) -> bool:
	if not Dados.MISSOES.has(id) or missoes.has(id) or not Dados.missao_na_estacao(id,Calendario.estacao()):
		return false
	missoes[id] = {"estado": "aceita", "ondas_inicio": ondas_vencidas, "estacao": Calendario.estacao()}
	_gravar()
	return true

func registrar_onda(_onda: int) -> void:
	ondas_vencidas += 1
	_gravar()

func colheitas_aceitas(id: String) -> Array:
	var lista: Array = Fazenda.PLANTAS.keys()
	if id in ["horta", "limiar_raizes"]:
		var estacao := int(missoes.get(id, {}).get("estacao", Calendario.estacao()))
		if estacao != 3:
			lista = Fazenda.plantas_da_estacao(estacao)
	return lista

func progresso_missao(id: String, quem: Node = null) -> Vector2i:
	var dados: Dictionary = Dados.MISSOES[id]
	match dados["tipo"]:
		"conversas", "visitas":
			var tabela := conversas if dados["tipo"] == "conversas" else visitas
			var total := 0
			for alvo in dados["alvos"]:
				total += 1 if tabela.has(alvo) else 0
			return Vector2i(total, dados["alvos"].size())
		"peixe":
			return Vector2i(mini(Fazenda.quantidade_peixes(dados["peixe"],quem),int(dados["quantidade"])),dados["quantidade"])
		"colheita":
			var total := 0
			for planta in colheitas_aceitas(id):
				total += Fazenda.quantidade_colhida(planta,quem)
			return Vector2i(mini(total, int(dados["quantidade"])), dados["quantidade"])
		"ondas":
			var inicio := int(missoes.get(id, {}).get("ondas_inicio", ondas_vencidas))
			return Vector2i(mini(ondas_vencidas - inicio, int(dados["quantidade"])), dados["quantidade"])
		"chefe":
			return Vector2i(mini(Progresso.checkpoint_max, int(dados["quantidade"])), dados["quantidade"])
	return Vector2i.ZERO

func concluir(id: String, morador: String, quem: Node = null) -> bool:
	if not missoes.has(id) or missoes[id]["estado"] != "aceita" or Dados.MISSOES[id]["dono"] != morador:
		return false
	var progresso := progresso_missao(id,quem)
	if progresso.x < progresso.y:
		return false
	var dados: Dictionary = Dados.MISSOES[id]
	missoes[id]["estado"] = "concluida"
	if dados["tipo"] == "peixe":
		var peixe: String = dados["peixe"]
		Fazenda.gastar_peixes(peixe,int(dados["quantidade"]),quem)
		Fazenda.bolsas_alteradas.emit()
	if dados["tipo"] == "colheita":
		var faltam := int(dados["quantidade"])
		for planta in colheitas_aceitas(id):
			var retirar := mini(faltam, Fazenda.quantidade_colhida(planta,quem))
			Fazenda.gastar_coletavel("colheita",planta,retirar,quem)
			faltam -= retirar
			if faltam == 0:
				break
		Fazenda.salvar()
		Fazenda.bolsas_alteradas.emit()
	amizade[morador] = mini(int(amizade.get(morador, 0)) + 2, 10)
	if dados.has("receita"):
		Progresso.armas_liberadas[dados.receita] = true
		Progresso.armas_liberadas_alteradas.emit()
	Progresso.brasas += int(dados["brasas"])
	Progresso.salvar()
	Progresso.brasas_alteradas.emit(Progresso.brasas)
	_gravar()
	if id == "limiar_selo":
		get_tree().call_group("hud", "anunciar", "O SELO FOI RESTAURADO", "A FONTE DA PRACA AGORA RECUPERA ENERGIA", 5.0)
	return true

## Grava a memória das conversas sem avisar as telas (a fala na tela não deve mudar por isso)
func lembrar() -> void:
	salvar()

func _gravar() -> void:
	salvar()
	alterado.emit()

func salvar() -> bool:
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify({"versao": 1, "missoes": missoes, "conversas": conversas, "visitas": visitas,
		"amizade": amizade, "ultimo_presente": ultimo_presente, "ultimo_dialogo": ultimo_dialogo, "ondas_vencidas": ondas_vencidas, "memoria": memoria, "cartas": cartas, "carta_pendente": carta_pendente}, "\t"))
	return true

func carregar() -> bool:
	trajetos_moradores.clear()
	tempo_moradores = 0.0
	_limpar_estado()
	if not FileAccess.file_exists(caminho_save):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not dados is Dictionary:
		return false
	for id in Dados.MISSOES:
		var registro = dados.get("missoes", {}).get(id) if dados.get("missoes", {}) is Dictionary else null
		if registro is Dictionary and registro.get("estado") in ["aceita", "concluida"]:
			missoes[id] = {"estado": registro["estado"], "ondas_inicio": maxi(0, int(registro.get("ondas_inicio", 0))), "estacao": clampi(int(registro.get("estacao", 0)), 0, 3)}
	for campo in ["conversas", "visitas", "amizade", "ultimo_presente", "ultimo_dialogo", "memoria", "cartas"]:
		var valor = dados.get(campo, {})
		if valor is Dictionary:
			set(campo, valor.duplicate())
	ondas_vencidas = maxi(0, int(dados.get("ondas_vencidas", 0)))
	carta_pendente = bool(dados.get("carta_pendente", false))
	return true

func _limpar_estado() -> void:
	missoes = {}
	conversas = {}
	visitas = {}
	amizade = {}
	ultimo_presente = {}
	ultimo_dialogo = {}
	memoria = {}
	cartas = {}
	carta_pendente = false
	carta_aberta = ""
	ondas_vencidas = 0
	interlocutor = ""

func apagar() -> void:
	_limpar_estado()
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))

## Mantém os dois moradores parados quando P1 e P2 conversam simultaneamente.
func em_conversa(id: String) -> bool:
	for interface in get_tree().get_nodes_in_group("interface"):
		if interface._telas_abertas.has("conversa_cidade"):
			var tela: Node = interface._telas["conversa_cidade"]
			if tela._id_atual == id and not tela._mesa_aberta and not tela._carta and tela._atendimento == "":
				return true
	return false

func dialogo_aberto_no_ambiente(no: Node) -> bool:
	var cena := Cooperativo.cena_de(no)
	for interface in get_tree().get_nodes_in_group("interface"):
		if Cooperativo.cena_de(interface)==cena and interface._telas_abertas.has("conversa_cidade"):
			return true
	return false
