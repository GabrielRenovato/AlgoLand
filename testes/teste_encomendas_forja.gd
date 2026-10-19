extends SceneTree
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var prog: Node = root.get_node("Progresso")
	var cal: Node = root.get_node("Calendario")
	var inv: Node = root.get_node("InventarioJogador")
	var inv2: Node = root.get_node("InventarioJogador2")
	var receitas: GDScript = load("res://codigo/dados/forja_armas.gd")
	prog.apagar()
	cal.apagar()
	for tipo in receitas.RECEITAS:
		verificar("prazo definido para "+tipo,receitas.DIAS_FABRICACAO.has(tipo) and receitas.dias_fabricacao(tipo) in [1,2,3])
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.adicionar_coletavel("receita","maca")
	prog.aprender_receita("maca",inv)
	prog.adicionar_materiais_forja(receitas.RECEITAS["maca"],inv)
	cal.dia = 29
	cal.salvar()
	var antes: Array = inv.fotografar_mochila()
	var caminho: String = prog.caminho_save
	prog.caminho_save = "user://pasta_inexistente_encomenda/progresso.json"
	verificar("falha ao salvar nao cobra nem registra pedido",prog.encomendar_arma("maca",inv) != "" and prog.encomenda_forja.is_empty() and inv.fotografar_mochila() == antes)
	prog.caminho_save = caminho
	verificar("encomenda cobra materiais uma vez",prog.encomendar_arma("maca",inv) == "" and inv.quantidade_tipo("material:ferro") == 0 and not prog.arma_liberada("maca"))
	verificar("prazo atravessa estacao sem antecipar",int(prog.encomenda_forja["dia_pronto"]) == 31 and prog.texto_encomenda_forja().contains("VERAO, DIA 1"))
	verificar("segundo jogador nao duplica encomenda",prog.encomendar_arma("arco_curto",inv2) == "IVO JA TEM UMA ENCOMENDA")
	verificar("nao retira antes do prazo",prog.retirar_encomenda_forja(inv) == "A ENCOMENDA AINDA NAO ESTA PRONTA" and not prog.encomenda_forja.is_empty())
	cal.dormir()
	prog.carregar()
	cal.carregar()
	verificar("salvar e carregar conserva dia e entrega de materiais",cal.dia == 30 and int(prog.encomenda_forja.get("dia_pronto",0)) == 31 and not prog.encomenda_forja_pronta() and inv.quantidade_tipo("material:ferro") == 0)
	prog.iniciar_partida()
	verificar("nova partida nao apaga encomenda",str(prog.encomenda_forja.get("tipo","")) == "maca")
	cal.dormir()
	verificar("fica pronta apos dois dias do jogo",prog.encomenda_forja_pronta() and not prog.arma_liberada("maca"))
	prog.caminho_save = "user://pasta_inexistente_encomenda/progresso.json"
	verificar("falha ao confirmar retirada conserva encomenda",prog.retirar_encomenda_forja(inv) != "" and prog.encomenda_forja_pronta() and not prog.arma_liberada("maca") and inv.buscar_por_tipo("maca") == null)
	prog.caminho_save = caminho
	verificar("retirada confirma modelo sem cobrar novamente",prog.retirar_encomenda_forja(inv) == "" and prog.arma_liberada("maca") and prog.encomenda_forja.is_empty() and inv.quantidade_tipo("material:ferro") == 0)
	var copias: int = inv.quantidade_tipo("maca")
	verificar("retirada repetida nao duplica arma",prog.retirar_encomenda_forja(inv) == "NENHUMA ENCOMENDA PARA RETIRAR" and inv.quantidade_tipo("maca") == copias)
	# Prazo mais longo, virada de ano e mochila cheia do segundo jogador.
	prog.apagar()
	inv2.limpar()
	inv2.criar_itens_iniciais()
	inv2.adicionar_coletavel("receita","arco_longo")
	prog.aprender_receita("arco_longo",inv2)
	prog.adicionar_materiais_forja(receitas.RECEITAS["arco_longo"],inv2)
	cal.dia = 119
	verificar("pedido de tres dias guarda dono e ano correto",prog.encomendar_arma("arco_longo",inv2) == "" and int(prog.encomenda_forja["jogador"]) == 2 and int(prog.encomenda_forja["dia_pronto"]) == 122 and prog.texto_encomenda_forja().contains("ANO 2"))
	while inv2.adicionar_arma_nova("espada_basica"): pass
	cal.dia = 122
	verificar("mochila cheia conserva direito a arma pronta",prog.retirar_encomenda_forja(inv2) == "" and prog.arma_liberada("arco_longo") and inv2.buscar_por_tipo("arco_longo") == null and not "arco_longo" in inv2.armas_permanentes_entregues)
	inv2.mochila[inv2.capacidade()-1] = null  # A casa 0 está reservada à arma equipada.
	inv2.entregar_armas_liberadas()
	verificar("liberar espaco entrega sem refazer ou cobrar",inv2.buscar_por_tipo("arco_longo") != null and inv2.quantidade_tipo("material:ferro") == 0)
	print("ENCOMENDAS: ",falhas," falhas")
	quit(falhas)
