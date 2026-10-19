extends SceneTree
const Controles := preload("res://codigo/dados/controles_personalizados.gd")
var falhas := 0
var capturar := false
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
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
func tecla(codigo: Key) -> void:
	var entrada := InputEventKey.new()
	entrada.keycode = codigo
	entrada.physical_keycode = codigo
	entrada.pressed = true
	Input.parse_input_event(entrada)
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	var opcoes := preload("res://codigo/globais/opcoes_jogo.gd").carregar()
	opcoes.tela_cheia = false
	preload("res://codigo/globais/opcoes_jogo.gd").salvar(opcoes)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await quadros(35)
	var inicio = current_scene
	inicio.botao_opcoes.pressed.emit()
	await create_timer(0.4).timeout
	var chaves: Array = inicio._linhas.map(func(l): return l.chave)
	verificar("titulo oferece tres volumes independentes",chaves.has("volume_musica") and chaves.has("volume_efeitos") and chaves.has("volume_ambiente"))
	var linha_musica: Dictionary = inicio._linhas.filter(func(l): return l.chave == "volume_musica")[0]
	var volume_antes: float = inicio._opcoes.volume_musica
	linha_musica.mais.pressed.emit()
	verificar("botao de musica altera o canal correto",is_equal_approx(inicio._opcoes.volume_musica,minf(volume_antes+0.1,1.0)) and not inicio._opcoes.tela_cheia)
	await foto("opcoes-pc")
	var tela = load("res://codigo/ui/tela_controles.gd").new()
	tela.abrir(inicio.botao_opcoes)
	await quadros()
	tela._capturar("attack")
	tecla(KEY_K)
	await quadros()
	verificar("captura real do teclado salva e atualiza dica",Controles.rotulo("attack",1,false) == "K" and tela._aviso.text == "COMANDO SALVO")
	await foto("controles-pc")
	Controles.restaurar()
	tela._fechar()
	await quadros()
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros(20)
	await foto("opcoes-mobile")
	tela = load("res://codigo/ui/tela_controles.gd").new()
	tela.abrir(inicio.botao_opcoes)
	await quadros()
	await foto("controles-mobile")
	verificar("lista de comandos rola sem perder voltar",tela._botoes.size() == Controles.ACOES.size())
	tela._fechar()
	await quadros()
	var coop = root.get_node("Cooperativo")
	coop.entrar(1)
	var antes := Controles.rotulo("attack",1,true)
	var botao := InputEventJoypadButton.new()
	botao.device = 1
	botao.button_index = JOY_BUTTON_MISC1
	tela = load("res://codigo/ui/tela_controles.gd").new()
	tela.abrir(inicio.botao_opcoes,2)
	tela._capturar("attack")
	botao.pressed = true
	Input.parse_input_event(botao)
	await quadros()
	verificar("jogador 2 tem captura e remapeamento proprios",tela._aviso.text == "COMANDO SALVO" and Controles.rotulo("attack",1,true) == antes)
	tela._fechar()
	await quadros()
	coop._reconfigurar_entrada()
	verificar("reconectar preserva comando do jogador 2",Controles.rotulo("attack",2,true) == "BOTAO %d" % JOY_BUTTON_MISC1)
	Controles.restaurar(2,true)
	coop.sair()
	print("FALHAS: ",falhas)
	quit(falhas)
