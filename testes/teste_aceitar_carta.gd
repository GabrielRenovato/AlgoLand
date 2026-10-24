extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	var cidade := root.get_node("Cidade")
	cidade.apagar()
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(30)
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var ui: Node = root.get_node("EventosJogo").interface_p1()
	var tela: Control = ui._telas["conversa_cidade"]
	for id in ["boas_vindas","horta","carta_pesca_0_0"]:
		cidade.abrir_carta(jogador,id)
		await quadros()
		var titulo: String = tela._titulo.text
		verificar("carta abre com remetente: "+id,titulo.begins_with("CARTA DE "))
		tela._aceitar(id)
		await quadros()
		verificar("pedido aceito: "+id,cidade.missoes.get(id,{}).get("estado","")=="aceita")
		verificar("aceitar preserva id e remetente: "+id,tela._pedido==id and tela._titulo.text==titulo and tela._carta)
		verificar("confirmação não vira carta misteriosa: "+id,tela._fala.text.contains("Pedido aceito") and not tela._fala.text.contains("- ?"))
		ui._fechar_tela("conversa_cidade")
		await quadros()
		verificar("leitura registrada para a carta correta: "+id,cidade.cartas.has(id) and cidade.carta_aberta=="" and str(jogador.get_meta("carta_dialogo",""))=="")
	var brasas: int = root.get_node("Progresso").brasas
	cidade.abrir_carta(jogador,"misterio_1")
	await quadros()
	verificar("carta misteriosa legítima mantém identidade",tela._titulo.text=="CARTA SEM REMETENTE" and tela._pedido=="misterio_1")
	ui._fechar_tela("conversa_cidade")
	await quadros()
	verificar("aceitar pedidos não registra mistérios falsos",cidade.cartas.has("misterio_1") and cidade.cartas.size()==4 and root.get_node("Progresso").brasas==brasas)
	cidade.abrir_carta(jogador,"misterio_3")
	await quadros()
	ui._fechar_tela("conversa_cidade")
	await quadros()
	var presente: int = root.get_node("Progresso").brasas
	cidade.abrir_carta(jogador,"misterio_3")
	await quadros()
	ui._fechar_tela("conversa_cidade")
	await quadros()
	verificar("presente misterioso é entregue uma única vez",presente==brasas+3 and root.get_node("Progresso").brasas==presente)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Aceitar carta: %d falhas" % falhas)
	quit(1 if falhas else 0)
