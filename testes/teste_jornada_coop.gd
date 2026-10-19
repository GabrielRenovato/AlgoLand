extends SceneTree

## Integra escolhas compartilhadas e benefícios individuais usando dois jogadores reais.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena = false
	var coop = root.get_node("Cooperativo")
	var prog = root.get_node("Progresso")
	prog.iniciar_partida()
	var transicao = root.get_node("Transicao")
	transicao.retornando = true
	transicao.estado = {"onda_atual":4}
	change_scene_to_file("res://cenas/fendas/andar_04.tscn")
	await quadros(30)
	transicao.retornando = false
	var gerente = current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerente.iniciar_onda(true)
	await quadros()
	var p1 = coop._jogador1()
	var p2 = coop.jogador2()
	for lado in [1,2]:
		var hud = get_first_node_in_group("hud_p%d" % lado)
		var objetivo: Control = hud.get_node("ObjetivoPrincipal")
		var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(hud)
		verificar("objetivo compacto cabe na metade de P%d" % lado,objetivo.size.y < 60 and Rect2(Vector2.ZERO,tela).encloses(objetivo.get_global_rect()))
		var area := objetivo.get_global_rect().grow(-9.5)
		verificar("textos mantêm folga nas bordas para P%d" % lado,area.encloses(objetivo._titulo.get_global_rect()) and area.encloses(objetivo._texto.get_global_rect()))
	for quem in [p1,p2]:
		quem.invulneravel = true
		quem.hp_atual = 1
	var encontro = gerente.encontro
	p2.global_position = encontro.global_position + Vector2(0,20)
	await quadros()
	verificar("P2 pode interagir com o eco",encontro._zona.pode_interagir_para(p2))
	encontro._zona.abrir_tela_p2()
	verificar("escolha abre na metade de P2 e pausa o grupo",paused and encontro._painel.get_viewport() == p2.get_viewport())
	for i in 4: await process_frame
	var painel: Control = encontro._painel._painel
	verificar("painel cabe na metade de P2",Rect2(Vector2.ZERO,p2.get_viewport_rect().size).encloses(painel.get_global_rect()))
	var cancelar := InputEventAction.new()
	cancelar.action = "ui_cancel"
	cancelar.pressed = true
	encontro._painel._unhandled_input(cancelar)
	await quadros()
	verificar("cancelar retoma os dois sem consumir encontro",not paused and not encontro.usado)
	encontro._zona.abrir_tela_p2()
	encontro._painel._escolher("descanso")
	var esperado1: int = 1 + roundi(p1.estatisticas.hp_maximo*0.30)
	var esperado2: int = 1 + roundi(p2.estatisticas.hp_maximo*0.30)
	verificar("descanso escolhido por P2 cura ambos uma vez",not paused and p1.hp_atual == esperado1 and p2.hp_atual == esperado2)
	encontro.aplicar("descanso")
	verificar("grupo não pode duplicar a cura",p1.hp_atual == esperado1 and p2.hp_atual == esperado2)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	p1 = coop._jogador1()
	p2 = coop.jogador2()
	var cidade = root.get_node("Cidade")
	var inv1 = root.get_node("InventarioJogador")
	var inv2 = root.get_node("InventarioJogador2")
	cidade.missoes["limiar_vigilia"] = {"estado":"concluida"}
	cidade.aceitar("limiar_raizes")
	var fora_da_estacao := ""
	for planta in root.get_node("Fazenda").PLANTAS:
		if planta not in cidade.colheitas_aceitas("limiar_raizes"):
			fora_da_estacao = planta
			break
	verificar("missão da horta tem restrição sazonal",fora_da_estacao != "")
	if fora_da_estacao != "":
		inv2.adicionar_coletavel("colheita",fora_da_estacao,2)
		verificar("colheitas de outra estação não concluem missão",not cidade.concluir("limiar_raizes","bento",p2))
	inv1.adicionar_coletavel("colheita","cenoura",2)
	inv2.adicionar_coletavel("colheita","cenoura",2)
	verificar("entrega de P2 consome somente sua colheita",cidade.concluir("limiar_raizes","bento",p2) and inv2.quantidade_tipo("colheita:cenoura") == 0 and inv1.quantidade_tipo("colheita:cenoura") == 2)
	cidade.missoes["limiar_selo"] = {"estado":"concluida"}
	cidade.alterado.emit()
	var fonte = current_scene.get_node("SeloDoLimiar")
	var fazenda = root.get_node("Fazenda")
	fazenda._definir_energia(1,100)
	fazenda._definir_energia(2,80)
	verificar("fonte de P2 não gasta benefício de P1",fonte.recuperar(p2) and fazenda.energia_de(2) == 110 and fazenda.energia_de(1) == 100 and fonte.recuperar(p1) and fazenda.energia_de(1) == 130)
	verificar("fonte limita cada jogador ao benefício diário",not fonte.recuperar(p1) and not fonte.recuperar(p2))
	print("FALHAS: ",falhas)
	quit(falhas)
