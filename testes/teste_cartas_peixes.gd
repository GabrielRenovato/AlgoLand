extends SceneTree
var falhas := 0
func _initialize() -> void:
	_rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	var dados: GDScript = load("res://codigo/cidade/dados_cidade.gd")
	var peixes: GDScript = load("res://codigo/pesca/peixes.gd")
	var cidade: Node = root.get_node("Cidade")
	var calendario: Node = root.get_node("Calendario")
	var fazenda: Node = root.get_node("Fazenda")
	var progresso: Node = root.get_node("Progresso")
	cidade._limpar_estado()
	fazenda._zerar()
	cidade.cartas["boas_vindas"] = 1
	for estacao in 4:
		fazenda.peixes = {}
		root.get_node("InventarioJogador").limpar()
		calendario.dia = estacao*30+2
		var id: String = cidade.proxima_carta()
		var missao: Dictionary = dados.MISSOES[id]
		verificar("pombo escolhe peixe da estação %d" % estacao,missao["tipo"]=="peixe" and missao["estacao"]==estacao and peixes.DADOS[missao["peixe"]]["estacoes"].has(estacao))
		verificar("carta informa espécie, quantidade e época",missao["texto"].contains(peixes.nome(missao["peixe"])) and missao["texto"].contains(calendario.NOMES[estacao]))
		calendario.dia = ((estacao+1)%4)*30+2
		verificar("não aceita pedido de outra estação",not cidade.aceitar(id))
		calendario.dia = estacao*30+2
		verificar("aceita carta e só uma vez",cidade.aceitar(id) and not cidade.aceitar(id))
		verificar("não entrega sem peixe",not cidade.concluir(id,missao["dono"]))
		for i in int(missao["quantidade"])+1: fazenda.pescar(missao["peixe"])
		var historico: Dictionary = fazenda.peixes_pescados.duplicate()
		verificar("não entrega ao morador errado",not cidade.concluir(id,"nilo"))
		var antes: int = progresso.brasas
		verificar("entrega consome quantidade e paga exato",cidade.concluir(id,missao["dono"]) and fazenda.quantidade_peixes(missao["peixe"])==1 and progresso.brasas==antes+int(missao["brasas"]))
		verificar("não paga duas vezes e preserva coleção",not cidade.concluir(id,missao["dono"]) and fazenda.peixes_pescados==historico)
		cidade.salvar()
		cidade.carregar()
		verificar("missão entregue persiste",cidade.missoes[id]["estado"]=="concluida")
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
