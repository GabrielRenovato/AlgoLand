extends SceneTree
var falhas := 0
var capturar := false
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-jornada-"+nome+".png")
func margens_do_objetivo(objetivo: Control) -> bool:
	var area := objetivo.get_global_rect().grow(-9.5)
	return area.encloses(objetivo._titulo.get_global_rect()) and area.encloses(objetivo._texto.get_global_rect()) \
		and is_equal_approx(objetivo._titulo.position.x,objetivo._texto.position.x) \
		and objetivo._titulo.get_global_rect().end.y+1 <= objetivo._texto.get_global_rect().position.y
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var cidade = root.get_node("Cidade")
	var prog = root.get_node("Progresso")
	var inv = root.get_node("InventarioJogador")
	root.get_node("Introducao").pular_prologo()
	cidade.apagar()
	prog.apagar()
	inv.limpar()
	inv.criar_itens_iniciais()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	var jogador = current_scene.get_node("Jogador")
	var selo = current_scene.get_node("SeloDoLimiar")
	var hud = get_first_node_in_group("hud_p1")
	var objetivo = hud.get_node("ObjetivoPrincipal")
	verificar("HUD destaca primeiro contato da missão principal",objetivo._texto.text.contains("LIA") and objetivo.visible)
	verificar("objetivo alinhado à esquerda do HUD",is_equal_approx(objetivo.position.x,hud.get_node("Status").position.x))
	verificar("objetivo ocupa cartão compacto",objetivo.size.y < 60 and objetivo.size.x <= 148)
	verificar("textos alinhados com folga em todas as bordas",margens_do_objetivo(objetivo))
	var lia = get_nodes_in_group("moradores_cidade").filter(func(n): return n.id == "lia")[0]
	verificar("morador da missão principal tem marcador próprio",lia.get_node("IndicadorPedido").principal)
	var indicador = lia.get_node("IndicadorPedido")
	verificar("missão principal disponível usa exclamação",indicador._rotulo.visible and indicador._rotulo.text == "!")
	if capturar:
		var posicao_anterior: Vector2 = lia.global_position
		var visivel_anterior: bool = lia.visible
		lia.set_physics_process(false)
		lia.global_position = jogador.global_position+Vector2(40,0)
		lia.visible = true
		await foto("principal-icone")
		lia.global_position = posicao_anterior
		lia.visible = visivel_anterior
		lia.set_physics_process(true)
	var interface = current_scene.get_node("Interface")
	interface._abrir_tela("mapa_mundi")
	await quadros()
	var mapa = interface._telas.mapa_mundi
	verificar("mapa destaca NPC e objetivo principal",mapa._atores.npc_lia.get_node("MissaoPrincipal").visible and mapa._objetivo_principal.text.contains("LIA"))
	await foto("principal-mapa")
	interface._fechar_tela("mapa_mundi")
	await foto("principal-hud")
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros()
	var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(hud)
	verificar("objetivo cabe no celular sem cobrir status",Rect2(Vector2.ZERO,tela).encloses(objetivo.get_global_rect()) and objetivo.size.y < 60 and not objetivo.get_global_rect().intersects(hud.get_node("Status").get_global_rect()))
	verificar("celular preserva margens e separação dos textos",margens_do_objetivo(objetivo))
	await foto("principal-mobile")
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	await quadros()
	verificar("fonte permanece inativa antes do arco",not selo.visible and not selo.recuperar(jogador))
	verificar("capitulos devem ser aceitos na ordem",not cidade.aceitar("limiar_selo") and cidade.aceitar("limiar_vigilia"))
	verificar("primeira entrega exige guardiao",not cidade.concluir("limiar_vigilia","lia",jogador))
	verificar("aceitar muda objetivo e anuncia atualização",objetivo._texto.text.contains("andar 1") and objetivo.atualizacoes == 1)
	await quadros()
	verificar("objetivo longo quebra linha dentro da moldura",margens_do_objetivo(objetivo))
	prog.iniciar_partida()
	prog.registrar_onda_concluida(1,true,false)
	objetivo.atualizar()
	verificar("vitória orienta retorno ao NPC",objetivo._texto.text.contains("Volte a LIA"))
	verificar("primeira vitoria libera projeto e próximo objetivo",cidade.concluir("limiar_vigilia","lia",jogador) and prog.receita_liberada("lanca_basica") and cidade.aceitar("limiar_raizes"))
	verificar("próximo capítulo acompanha campanha no HUD",objetivo._texto.text.contains("colheitas"))
	var brasas: int = prog.brasas
	verificar("recompensa unica",not cidade.concluir("limiar_vigilia","lia",jogador) and prog.brasas == brasas)
	inv.adicionar_coletavel("colheita","cenoura",2)
	verificar("horta contribui com colheitas reais",cidade.concluir("limiar_raizes","bento",jogador) and inv.quantidade_tipo("colheita:cenoura") == 0 and prog.receita_liberada("aljava_basica"))
	cidade.salvar()
	cidade.carregar()
	verificar("arco persiste sem apagar mundo",cidade.missoes.limiar_raizes.estado == "concluida" and cidade.aceitar("limiar_ecos"))
	prog.registrar_onda_concluida(6,true,false)
	verificar("ruinas liberam armadura",cidade.concluir("limiar_ecos","ferreiro",jogador) and prog.receita_liberada("armadura_basica") and cidade.aceitar("limiar_selo"))
	verificar("ultima vigilia exige tres andares novos",cidade.progresso_missao("limiar_selo",jogador) == Vector2i(0,3) and not cidade.concluir("limiar_selo","mistica",jogador))
	cidade.registrar_onda(1)
	cidade.salvar()
	cidade.carregar()
	verificar("save anterior preserva progresso da ronda",cidade.progresso_missao("limiar_selo",jogador) == Vector2i(1,3))
	objetivo.atualizar()
	await foto("ultima-vigilia")
	verificar("HUD acompanha andares da ronda",preload("res://codigo/cidade/jornada_limiar.gd").rastreio(cidade,jogador).texto.contains("1/3"))
	cidade.registrar_onda(2)
	verificar("dois andares ainda nao completam",not cidade.concluir("limiar_selo","mistica",jogador))
	cidade.registrar_onda(3)
	verificar("tres andares encerram primeiro arco e mudam a vila",cidade.concluir("limiar_selo","mistica",jogador) and selo.visible)
	var recompensa: int = prog.brasas
	cidade.salvar()
	cidade.carregar()
	verificar("conclusao antiga mantem beneficio sem premio repetido",preload("res://codigo/cidade/jornada_limiar.gd").concluida(cidade) and not cidade.concluir("limiar_selo","mistica",jogador) and prog.brasas == recompensa)
	var fazenda = root.get_node("Fazenda")
	fazenda._definir_energia(1,100)
	verificar("fonte restaura energia uma vez por dia",selo.recuperar(jogador) and fazenda.energia_de(1) == 130 and not selo.recuperar(jogador))
	cidade.salvar()
	cidade.carregar()
	verificar("recarregar não repete beneficio diário",not selo.recuperar(jogador))
	root.get_node("Calendario").dia += 1
	verificar("dia seguinte renova beneficio",selo.recuperar(jogador) and fazenda.energia_de(1) == 160)
	jogador.global_position = selo.global_position + Vector2(0,34)
	await quadros()
	verificar("fonte oferece interação real após conclusão",selo.get_node("InteracaoFonte").jogador_perto and selo.get_node("InteracaoFonte").pode_interagir())
	await create_timer(7.0).timeout
	for estacao in 4:
		current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
		await foto("selo-%d" % estacao)
	var ui = current_scene.get_node("Interface")
	ui._abrir_tela("inventario")
	ui._telas.inventario.selecionar_pagina(1)
	await create_timer(0.4).timeout
	await foto("diario")
	var diario = ui._telas.inventario.get_node("Missoes") if ui._telas.inventario.has_node("Missoes") else ui._telas.inventario.find_child("Missoes",true,false)
	verificar("diário separa missão principal de pedidos",diario != null and diario._lista.get_child(0).text == "MISSAO PRINCIPAL" and not diario._lista.has_node("MissaoPrincipal"))
	print("FALHAS: ",falhas)
	quit(falhas)
