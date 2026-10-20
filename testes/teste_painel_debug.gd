extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func quadros(n := 8) -> void:
	for i in n: await process_frame
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-f3-" + nome + ".png")
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	var painel := root.get_node("PainelDebug")
	var fazenda := root.get_node("Fazenda")
	var calendario := root.get_node("Calendario")
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	fazenda.apagar()
	root.get_node("Cidade").apagar()
	calendario.dia = 1
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)
	verificar("quatro areas curtas preservam todas as categorias", painel.AREAS.size() == 4 and painel._opcoes.size() == 18)
	var categorias := []
	for area in painel.AREAS:
		for categoria in painel.AREAS[area]: categorias.append(categoria)
	verificar("nenhuma ferramenta fica fora das areas", categorias.size() == painel._opcoes.size() and painel._opcoes.keys().all(func(c): return c in categorias))
	painel._area.select(1)
	painel._selecionar_area(1)
	painel._categoria.select(4)
	painel._selecionar_categoria(4)
	painel._acao.select(3)
	painel._selecionar_acao(3)
	painel._area.select(0)
	painel._selecionar_area(0)
	painel._area.select(1)
	painel._selecionar_area(1)
	verificar("lembra assunto e acao ao trocar area", painel._categoria.selected == 4 and painel._acao.selected == 3)
	painel._area.select(0)
	painel._area.select(0)
	painel._selecionar_area(0)
	painel._painel.show()
	for tamanho in [Vector2i(576,324), Vector2i(480,270), Vector2i(288,512), Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros()
		painel._ajustar_altura()
		await quadros()
		var retangulo: Rect2 = painel._painel.get_global_rect()
		verificar("painel cabe em %s" % tamanho, Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(retangulo))
		for controle in [painel._area,painel._categoria,painel._acao,painel._rotulo_estado,painel._aviso]:
			verificar("margens de %s em %s" % [controle.get_class(), tamanho], retangulo.grow(-10).encloses(controle.get_global_rect()))
		await foto("menu-%dx%d" % [tamanho.x,tamanho.y])
		painel._acao.show_popup()
		await quadros()
		verificar("lista de acoes cabe em %s" % tamanho, painel._acao.get_popup().size.x <= tamanho.x and painel._acao.get_popup().size.y <= tamanho.y)
		await foto("acoes-%dx%d" % [tamanho.x,tamanho.y])
		painel._acao.get_popup().hide()
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var jogador := current_scene.get_node("Jogador")
	jogador.inventario.limpar()
	await painel._executar_selecao()
	verificar("execucao libera botao apos concluir", not painel._executando)
	await quadros(60)
	verificar("inicia contrato real sem exigir materiais", fazenda.galinheiro.obra == 1 and fazenda.galinheiro.inicio_obra == 1 and fazenda.galinheiro.pronto_dia == 3)
	var inicio: int = fazenda.galinheiro.inicio_obra
	await painel._iniciar_obra_debug()
	verificar("visitar obra nao reinicia prazo", fazenda.galinheiro.inicio_obra == inicio and fazenda.galinheiro.pronto_dia == 3)
	var criacao := load("res://codigo/fazenda/criacao_galinhas.gd")
	for etapa in [1,2]:
		painel._avancar_etapa_obra_debug()
		await quadros()
		verificar("atalho chega a etapa %d" % etapa, criacao.etapa_obra(fazenda.galinheiro, calendario.dia, root.get_node("Transicao").hora_salva) == etapa and fazenda.galinheiro.obra == 1)
	painel._horario_obra_debug(17.0)
	await quadros(40)
	var npc: Node = current_scene.get_node("ObraCarpinteiro").moradores.osvaldo
	verificar("fim do expediente manda carpinteiro para casa", npc.agenda.local == "carpintaria")
	await painel._dormir_osvaldo_debug()
	await quadros(40)
	verificar("atalho noturno visita a casa e ativa descanso", current_scene.scene_file_path.ends_with("carpintaria.tscn") and current_scene.moradores.osvaldo.agenda.get("dormindo", false))
	painel._concluir_obra_debug()
	await quadros()
	verificar("conclusao usa passagem dos dias e entrega aves", fazenda.galinheiro.obra == 0 and fazenda.galinheiro.nivel == 1 and fazenda.galinheiro.aves.size() == 3)
	var aves: Array = fazenda.galinheiro.aves.duplicate(true)
	await painel._iniciar_obra_debug()
	verificar("ampliacao conserva bando e nivel existente", fazenda.galinheiro.obra == 2 and fazenda.galinheiro.nivel == 1 and fazenda.galinheiro.aves == aves)
	await quadros(30)
	await foto("obra")
	painel._concluir_obra_debug()
	await painel._iniciar_obra_debug()
	painel._concluir_obra_debug()
	var bando_maximo: Array = fazenda.galinheiro.aves.duplicate(true)
	await painel._iniciar_obra_debug()
	verificar("nivel maximo permite testar reforma sem remover aves", fazenda.galinheiro.nivel == 3 and fazenda.galinheiro.obra == 3 and fazenda.galinheiro.aves == bando_maximo)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(15)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
