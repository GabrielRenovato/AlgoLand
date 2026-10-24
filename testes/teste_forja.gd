extends SceneTree

const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Desafios := preload("res://codigo/dados/desafios_armas.gd")
var Dados: GDScript
var falhas := 0
var prog: Node
var inv: Node
var inv2: Node

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await physics_frame
		await process_frame

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	root.get_node("Saves").trocar("coop")
	prog = root.get_node("Progresso")
	prog.apagar()
	root.get_node("Introducao").pular_prologo()
	inv = root.get_node("InventarioJogador")
	inv2 = root.get_node("InventarioJogador2")
	for mochila in [inv, inv2]:
		mochila.limpar()
		mochila.criar_itens_iniciais()
	prog.iniciar_partida()
	for onda in range(1, 21):
		prog.registrar_onda_concluida(onda, onda % 10 == 0, false)
	verificar("vencer ondas nao aprende receitas nem entrega materiais ocultos", prog.armas_liberadas.is_empty() and prog.quantidade_material_forja("fragmento") == 0 and inv.buscar_por_tipo("arco_curto") == null)
	# Este cenário valida as seis receitas originais; o catálogo completo tem teste próprio.
	for tipo in Receitas.RECEITAS:
		if not Desafios.DESAFIOS.has(tipo): prog.armas_liberadas[tipo]=true
	var drops = load("res://codigo/logica/drops_forja.gd")
	verificar("ondas apenas habilitam quais receitas podem cair", drops.receita_pendente(2,self) == "" and drops.receita_pendente(3,self) == "arco_curto")
	var palco := Node2D.new()
	root.add_child(palco)
	var pergaminho: Node2D = drops.soltar_receita(3,Vector2.ZERO,palco)
	verificar("receita nasce fisicamente e nao duplica no chao", pergaminho != null and pergaminho.item.categoria == "receita" and drops.receita_pendente(3,self) == "")
	pergaminho._tentar_pegar()
	await quadros()
	verificar("coletar ocupa mochila sem aprender", inv.quantidade_tipo("receita:arco_curto") == 1 and not prog.receita_liberada("arco_curto"))
	verificar("so coletar ainda nao permite fabricar", prog.fabricar_arma("arco_curto") == "ENCONTRE E USE A RECEITA NA MOCHILA")
	var slot: Control = load("res://cenas/ui/componentes/slot_ui.tscn").instantiate()
	root.add_child(slot)
	slot.exibir(inv.buscar_por_tipo("receita:arco_curto"))
	slot._equipar_ou_desequipar()
	verificar("usar pela interface consome pergaminho e aprende", prog.receita_liberada("arco_curto") and inv.quantidade_tipo("receita:arco_curto") == 0 and not prog.arma_liberada("arco_curto"))
	slot.queue_free()
	verificar("nao usa receita ausente", prog.aprender_receita("machado",inv) == "RECEITA NAO ESTA NA MOCHILA")
	verificar("aprender receita ainda exige materiais fisicos", prog.fabricar_arma("arco_curto") == "FALTAM MATERIAIS NA MOCHILA")
	verificar("materiais entram na mochila do segundo jogador", prog.adicionar_materiais_forja(Receitas.RECEITAS["arco_curto"],inv2) and inv2.quantidade_tipo("material:madeira") == Receitas.RECEITAS.arco_curto.madeira)
	verificar("fabricacao nao usa materiais do outro jogador", prog.fabricar_arma("arco_curto",inv) == "FALTAM MATERIAIS NA MOCHILA" and inv2.quantidade_tipo("material:madeira") == Receitas.RECEITAS.arco_curto.madeira)
	verificar("fabricacao consome exatamente custos do dono e entrega aos dois", prog.fabricar_arma("arco_curto",inv2) == "" and inv2.quantidade_tipo("material:madeira") == 0 and inv.buscar_por_tipo("arco_curto") != null and inv2.buscar_por_tipo("arco_curto") != null)
	verificar("modelo nao cobra duas vezes", prog.fabricar_arma("arco_curto",inv2) == "MODELO JA FABRICADO")
	prog.carregar()
	inv2.carregar()
	verificar("receita e custo persistem juntos", prog.receita_liberada("arco_curto") and prog.arma_liberada("arco_curto") and inv2.quantidade_tipo("material:fragmento") == 0)
	inv.adicionar_coletavel("receita","espada_gemea")
	var caminho: String = prog.caminho_save
	var antes: Array = inv.fotografar_mochila()
	prog.caminho_save = "user://pasta_inexistente_forja/progresso.json"
	verificar("falha de escrita nao consome pergaminho nem aprende", prog.aprender_receita("espada_gemea",inv) != "" and not prog.receita_liberada("espada_gemea") and inv.fotografar_mochila() == antes)
	prog.caminho_save = caminho
	prog.aprender_receita("espada_gemea",inv)
	prog.adicionar_materiais_forja(Receitas.RECEITAS["espada_gemea"],inv)
	antes = inv.fotografar_mochila()
	prog.caminho_save = "user://pasta_inexistente_forja/progresso.json"
	verificar("falha de escrita desfaz custos e modelo", prog.fabricar_arma("espada_gemea",inv) != "" and not prog.arma_liberada("espada_gemea") and inv.fotografar_mochila() == antes)
	prog.caminho_save = caminho
	# O diário confirmado recupera a mochila mesmo se o segundo arquivo falhar.
	var caminho_inv: String = inv.caminho_save
	inv.caminho_save = "user://diario_forja_teste/inventario.json"
	verificar("progresso conserva transacao quando escrita da mochila falha", prog.fabricar_arma("espada_gemea",inv) == "" and not prog.mochila_pendente.is_empty())
	DirAccess.make_dir_recursive_absolute("user://diario_forja_teste")
	verificar("diario recupera custos sem duplicar arma", prog.resolver_mochila_pendente() and prog.mochila_pendente.is_empty())
	inv.caminho_save = caminho_inv
	inv.salvar()
	await _coletaveis(palco)
	palco.queue_free()
	await _arena()
	await _fazenda()
	await _vila()
	print("Forja: %d falhas" % falhas)
	quit(falhas)

func _coletaveis(palco: Node2D) -> void:
	var item = load("res://codigo/modelos/dados_item.gd")
	var teste: Node = load("res://codigo/modelos/modelo_inventario.gd").new()
	root.add_child(teste)
	teste.caminho_save = "user://mochila_coletaveis_teste.json"
	for par in [["material","madeira"],["receita","maca"],["colheita","cenoura"],["pocao","cura"],["material","moeda_forja"],["material","pedra_vara"]]:
		verificar("coletavel %s:%s ocupa uma casa" % par, teste.adicionar_coletavel(par[0],par[1],2) and teste.quantidade_tipo(par[0]+":"+par[1]) == 2)
	verificar("tipos diferentes ocupam seis casas", teste.mochila.filter(func(i): return i != null).size() == 6)
	while teste.adicionar_arma_nova("espada_basica"): pass
	verificar("mochila cheia aceita pilha existente", teste.adicionar_coletavel("material","madeira",3) and teste.quantidade_tipo("material:madeira") == 5)
	verificar("mochila cheia rejeita novo material e receita", not teste.adicionar_coletavel("material","ferro") and not teste.adicionar_coletavel("receita","machado"))
	teste.salvar()
	teste.carregar()
	verificar("pilhas sobrevivem ao save", teste.quantidade_tipo("material:madeira") == 5 and teste.quantidade_tipo("receita:maca") == 2)
	# A mochila real cheia não usa a sacola nem venda automática para aceitar o drop.
	while inv.adicionar_arma_nova("espada_basica"): pass
	var drop: Node2D = load("res://codigo/logica/drops_forja.gd").soltar_material("nucleo",1,Vector2.ZERO,palco)
	var ouro: int = root.get_node("DadosJogo").moedas
	drop._tentar_pegar()
	verificar("sem espaco drop continua no chao sem conversao em ouro", not drop._pego and not drop.is_queued_for_deletion() and inv.quantidade_tipo("material:nucleo") == 0 and root.get_node("DadosJogo").moedas == ouro)
	inv.mochila[inv.capacidade()-1] = null
	drop._tentar_pegar()
	verificar("liberar uma casa permite recolher", drop._pego and inv.quantidade_tipo("material:nucleo") == 1)
	var permanentes: Array = []
	for i in inv.capacidade():
		inv.mochila[i] = item.de_coletavel("material","madeira",i+1)
	permanentes = inv.mochila.duplicate()
	inv.reiniciar_equipamento_da_partida()
	verificar("reset preserva todas as pilhas mesmo com mochila lotada", inv.quantidade_tipo("material:madeira") == inv.capacidade()*(inv.capacidade()+1)/2 and permanentes.all(func(i): return inv.mochila.has(i)))
	inv.limpar()
	inv.criar_itens_iniciais()
	var fazenda: Node = root.get_node("Fazenda")
	inv.adicionar_coletavel("colheita","cenoura",2)
	inv.adicionar_coletavel("colheita","morango",1)
	verificar("caldeirao troca ingredientes por pocao fisica", fazenda.fazer_pocao("cura") == "" and inv.quantidade_tipo("pocao:cura") == 1 and inv.quantidade_tipo("colheita:cenoura") == 0)
	verificar("consumir pocao libera a pilha", fazenda.gastar_pocao("cura") and inv.quantidade_tipo("pocao:cura") == 0)
	teste.queue_free()

func _arena() -> void:
	# Concluir a onda mantém o fragmento; receitas dependem do sorteio, sem aprendizado automático.
	prog.armas_liberadas.erase("maca")
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(20)
	var gerenciador: Node = current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerenciador.chance_onda_bonus = 0.0
	gerenciador.onda_atual = 8
	gerenciador.iniciar_onda()
	var tentativas := 0
	while gerenciador.onda_em_andamento and tentativas < 100:
		for inimigo in get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and inimigo.has_method("receber_dano"):
				inimigo.receber_dano(99999,Vector2.ZERO)
		await create_timer(0.3).timeout
		tentativas += 1
	verificar("concluir onda nao aprende receita automaticamente", not gerenciador.onda_em_andamento and not prog.receita_liberada("maca"))
	verificar("fragmento e item fisico de fim da onda", inv.quantidade_tipo("material:fragmento") > 0 or get_nodes_in_group("equipamento_drop").any(func(d): return d.item.tipo == "material:fragmento"))

func _fazenda() -> void:
	root.get_node("Fazenda").apagar()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	var extracao: Node = current_scene.find_child("Extracao", true, false)
	verificar("fazenda oferece extracao real", extracao != null)
	if extracao == null:
		return
	var recurso: Dictionary = extracao.recursos.filter(func(r): return r["tipo"] == "pedra")[0]
	var ferro: int = prog.quantidade_material_forja("ferro")
	for i in 2:
		extracao.impacto("picareta", recurso["pos"])
	verificar("golpes parciais nao concedem minerio", prog.quantidade_material_forja("ferro") == ferro)
	extracao.impacto("picareta", recurso["pos"])
	var pedras: Array = get_nodes_in_group("equipamento_drop").filter(func(d): return d.item.tipo == "material:pedra")
	verificar("pedra da fazenda solta pedra fisica sem ferro",not pedras.is_empty() and get_nodes_in_group("equipamento_drop").all(func(d): return d.item.tipo != "material:ferro"))
	for drop in pedras: drop._tentar_pegar()
	verificar("fazenda nao concede ferro",prog.quantidade_material_forja("ferro")==ferro)
	await quadros()
	extracao.impacto("picareta",recurso["pos"])
	verificar("pedra removida nao concede ferro ao repetir",prog.quantidade_material_forja("ferro")==ferro)
	var fazenda: Node = root.get_node("Fazenda")
	var celula := Vector2i(18, 8)
	fazenda.entulho[celula] = "mato"
	var fibra: int = prog.quantidade_material_forja("fibra")
	fazenda.remover_entulho(celula)
	fazenda.remover_entulho(celula)
	verificar("retirar mato concede fibra uma vez", prog.quantidade_material_forja("fibra") == fibra + 1)

func _vila() -> void:
	var calendario: Node = root.get_node("Calendario")
	calendario.dia = 1
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	var cidade: Node = current_scene
	verificar("vila integra casa e morador", cidade.moradores.has("ferreiro") and cidade.get_node_or_null("Terrains/Construcoes/Forja") != null)
	var rota: PackedVector2Array = cidade.caminho_entre(Vector2(336, 272), cidade.porta_do_local("forja"))
	verificar("acesso da forja liga a praca", rota.size() > 1 and rota[-1].distance_to(cidade.porta_do_local("forja")) < 20)
	verificar("Ivo trabalha dorme e folga", Dados.agenda("ferreiro",12,0,0,0)["local"] == "forja" and Dados.agenda("ferreiro",23,0,0,0).get("dormindo",false) and Dados.servico_fechado("ferreiro",12,2) == "FOLGA HOJE")
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(20)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var moeda: Node2D = load("res://codigo/logica/drops_forja.gd").soltar_material("moeda_forja",1,Vector2.ZERO,current_scene)
	moeda._tentar_pegar()
	var hud: Node = get_first_node_in_group("hud_p1")
	verificar("pickup de moeda fisica atualiza contador do HUD", inv.moedas_forja > 0 and hud != null and hud.rotulo_moeda_forja.text == str(inv.moedas_forja))
	var ui: Node = root.get_node("Cooperativo").interface_p2()
	var zona: Area2D = current_scene.get_node("Bigorna")
	root.get_node("Cooperativo").jogador2().position = zona.position + Vector2(0,10)
	await quadros(8)
	verificar("bigorna detecta segundo jogador no lugar correto",zona.p2_perto)
	zona.abrir_tela_p2()
	await quadros(8)
	var tela: Control = ui._telas["forja"]
	verificar("oficina abre receitas custos e retirada", tela.visible and tela._botoes.size() == Receitas.receitas_ativas().size()+4 and tela._custos.find_children("*", "Label", true, false).any(func(rotulo): return rotulo.text.contains("MADEIRA")))
	inv2.adicionar_coletavel("receita","lanca_basica")
	prog.aprender_receita("lanca_basica",inv2)
	prog.adicionar_materiais_forja(Receitas.RECEITAS["lanca_basica"],inv2)
	tela._selecionar("lanca_basica")
	tela._fabricar.pressed.emit()
	var trabalho: Node = current_scene.get_node("Bigorna/TrabalhoFerreiro")
	var limite := Time.get_ticks_msec()+30000
	while trabalho.ocupado() and Time.get_ticks_msec()<limite:
		await physics_frame
	await quadros()
	verificar("fabricacao no coop fica encomendada sem liberar antes do prazo",not prog.arma_liberada("lanca_basica") and not prog.encomenda_forja.is_empty())
	calendario.dia = 4  # Dois dias de prazo; na quarta o Ivo está de folga.
	root.get_node("Cidade").trajetos_moradores.erase("ferreiro")
	current_scene.moradores["ferreiro"]._saindo = false
	current_scene.moradores["ferreiro"].atualizar_rotina(true)
	tela._ao_fabricar()
	await quadros()
	verificar("botao do Ivo fabrica no coop e atualiza a tela", prog.arma_liberada("lanca_basica") and inv2.buscar_por_tipo("lanca_basica") != null and tela._fabricar.text == "JA FABRICADA")
	verificar("Ivo tem retrato animado no dialogo", ResourceLoader.exists("res://assets/npcs/retratos/ivo.png"))
	if "--capturar" in OS.get_cmdline_user_args():
		await _capturas(tela, ui)

func _capturas(tela: Control, ui: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-forja-capturas")
	root.mode = Window.MODE_WINDOWED
	await _foto("receitas_coop")
	ui._fechar_tela("forja")
	root.get_node("Cooperativo").sair()
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(24)
	ui = current_scene.get_node("Interface")
	ui._abrir_tela("forja")
	tela = ui._telas["forja"]
	await _foto("receitas_pc")
	ui._fechar_tela("forja")
	root.get_node("Cidade").conversar("ferreiro",current_scene.get_node("Jogador"))
	await quadros(5)
	ui._telas["conversa_cidade"]._avancar_fala()
	await _foto("dialogo_ivo")
	ui._fechar_tela("conversa_cidade")
	ui._abrir_tela("forja")
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros(12)
	verificar("forja cabe na interface mobile", tela.painel.size.x <= tela.size.x and tela.painel.size.y <= tela.size.y)
	await _foto("receitas_mobile")
	ui._fechar_tela("forja")
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(704,576)
	root.size = Vector2i(1408,1152)
	for local in ["forja", "cidade"]:
		change_scene_to_file("res://cenas/cidade/forja.tscn" if local == "forja" else "res://cenas/cidade.tscn")
		await quadros(24)
		current_scene.get_node("Iluminacao").definir_hora(12)
		current_scene.get_node("Iluminacao").set_process(false)
		var jogador: Node2D = current_scene.get_node("Jogador")
		jogador.position = Vector2(352,288) if local == "cidade" else Vector2(264,148)
		jogador.camera.zoom = Vector2.ONE
		jogador.camera.position_smoothing_enabled = false
		for i in 4:
			root.get_node("Calendario").dia = i*30+1
			root.get_node("Calendario").estacao_mudou.emit(i)
			call_group("hud", "atualizar_data")
			var estacoes := current_scene.get_node_or_null("Terrains/Estacoes")
			if estacoes != null:
				estacoes.definir_estacao(i, true)
			await _foto(local+"_"+str(i))
			if local == "cidade":
				jogador.position = Vector2(192,145)
				jogador.camera.offset = Vector2(0,-24)
				jogador.camera.zoom = Vector2(2.5,2.5)
				await _foto("fachada_"+str(i))
				jogador.position = Vector2(352,288)
				jogador.camera.zoom = Vector2.ONE
				jogador.camera.offset = Vector2.ZERO

func _foto(nome: String) -> void:
	await root.get_node("Transicao").clarear(0.0)
	await quadros(12)
	if nome.begins_with("receitas"):
		for interface in get_nodes_in_group("interface"):
			var tela: Control = interface._telas["forja"]
			if tela.visible:
				print("PAINEL ", nome, " tela=",tela.size," painel=",tela.painel.size," pos=",tela.painel.position," min=",tela.painel.get_combined_minimum_size())
				verificar("painel inteiro dentro da tela: "+nome, Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_rect()))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-forja-capturas/"+nome+".png")
