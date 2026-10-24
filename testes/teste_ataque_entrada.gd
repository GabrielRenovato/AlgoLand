extends SceneTree
## Regressão: arma salva deve atacar ao entrar e depois de consultar o mapa, sem abrir mochila.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func toque(ponto: Vector2, apertado: bool, dedo := 7) -> void:
	var evento := InputEventScreenTouch.new()
	evento.index = dedo
	evento.position = ponto
	evento.pressed = apertado
	root.push_input(evento, true)
func atacar(jogador: Node, controles: Node, nome: String) -> void:
	var foco := root.gui_get_focus_owner()
	print("ESTADO ", nome, " espada=", jogador.usando_espada, " bloqueado=", jogador.ataques_bloqueados, " movimento=", jogador.movimento_habilitado, " foco=", foco.name if foco != null else "nenhum")
	var botao: Dictionary = controles._botao_da_acao(&"attack")
	toque(botao.centro, true)
	toque(botao.centro, false)
	await quadros(2)
	verificar(nome, jogador._esta_atacando)
	await create_timer(0.8).timeout
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.get_node("Controle").usando_toque = true
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais(false)
	inv.salvar()
	inv.limpar()
	verificar("save com espada foi recarregado", inv.carregar() and inv.equipados.arma != null)
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(576,324)
	root.content_scale_size = Vector2i(576,324)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	root.get_node("Transicao").estado = {"onda_atual":3}
	var interface_cidade: Node = root.get_node("EventosJogo").interface_de(current_scene.get_node("Jogador"))
	interface_cidade._abrir_tela("desafio_arena")
	await quadros()
	# Reproduz o bloqueio residual que a chegada deve normalizar sem depender da mochila.
	scene_changed.connect(func():
		var chegando: Node = current_scene.get_node("Jogador")
		chegando.desabilitar_todas_acoes(true), CONNECT_ONE_SHOT)
	interface_cidade._telas["desafio_arena"]._iniciar_desafio()
	await root.get_node("Transicao").troca_concluida
	await quadros(40)
	current_scene.get_node("enemySpawner/GerenciadorOndas").set_physics_process(false)
	var jogador := current_scene.get_node("Jogador")
	var controles: Node
	for candidato in current_scene.find_children("*", "CanvasLayer", true, false):
		if candidato.get_script() == load("res://codigo/ui/controles_toque.gd"):
			controles = candidato
	controles._modo_mouse = false
	verificar("arma do save está ativa no jogador", jogador.usando_espada and jogador.inventario.equipados.arma != null)
	await atacar(jogador,controles,"primeiro ataque após entrar sem mochila")
	var hud := get_first_node_in_group("hud_p1")
	var mapa: Control = hud.get_node("MinimapaAndar")
	var botao: Button = hud.find_child("BotaoMapaMundi",true,false)
	var ponto: Vector2 = botao.get_global_transform_with_canvas() * (botao.size * 0.5)
	toque(ponto,true)
	toque(ponto,false)
	await quadros()
	verificar("toque abriu mapa",mapa._grande)
	var centro: Vector2 = mapa._painel.get_global_transform_with_canvas() * (mapa._painel.size * 0.5)
	toque(centro,true)
	toque(centro,false)
	await quadros()
	verificar("toque fechou mapa",not mapa._grande)
	await atacar(jogador,controles,"ataque depois de consultar mapa sem mochila")
	var interface: Node = root.get_node("EventosJogo").interface_de(jogador)
	interface._abrir_tela("inventario")
	root.get_node("Transicao").troca_concluida.emit(current_scene.scene_file_path)
	verificar("menu aberto mantém ataque bloqueado na chegada",jogador.ataques_bloqueados)
	await quadros()
	interface._fechar_tela("inventario")
	await create_timer(0.4).timeout
	await atacar(jogador,controles,"ataque depois de abrir e fechar mochila")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Ataque na entrada: %d falhas" % falhas)
	quit(1 if falhas else 0)
