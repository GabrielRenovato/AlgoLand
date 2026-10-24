extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 5) -> void:
	for i in n:
		await process_frame
		await physics_frame
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ",texto)
func tecla(codigo: int, caractere := 0) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.unicode = caractere
	evento.pressed = true
	Input.parse_input_event(evento)
	await quadros(2)
	evento.pressed = false
	Input.parse_input_event(evento)
	await quadros(2)

func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(35)
	var cena := current_scene
	var jogador: Node2D = cena.get_node("Jogador")
	var ui := cena.get_node("Interface")
	var tela: Control = ui._telas.lobby
	var controle := root.get_node("Controle")
	var sessao: Node = cena.get_node("LobbyCidade").sessao_de(jogador)
	# Só a entrada local está em teste: nunca conecta nem envia mensagens à rede.
	sessao.set_process(false)
	sessao.online = true
	sessao.conectado = true
	sessao._ocupado = true
	tela._atualizar()
	jogador.position = cena.get_node("Porta_sede").position
	await quadros()
	var origem := jogador.position
	for campo: LineEdit in [tela._historico_campo,tela._campo]:
		if campo == tela._campo: ui._abrir_tela("lobby")
		campo.text = ""
		campo.grab_focus()
		await quadros()
		conferir(controle.digitando,"foco de ambos os campos bloqueia os comandos")
		for letra in "mifwr123":
			await tecla(letra.to_upper().unicode_at(0),letra.unicode_at(0))
		await tecla(KEY_F3)
		await tecla(KEY_TAB)
		conferir(current_scene == cena,"F digitado perto da porta não entra na sede")
		conferir(not ui._telas_abertas.has("inventario") and not ui._telas_abertas.has("mapa_mundi") and not ui._telas_abertas.has("pausa"),"letras não abrem inventário, mapa ou pausa")
		conferir(jogador.position.distance_to(origem)<1 and not jogador.esta_em_dash,"digitação não move nem esquiva")
		conferir(campo.text == "mifwr123","teclas continuam escrevendo o texto")
		conferir(not jogador.pode_iniciar_interacao(),"interação por consulta direta também fica bloqueada")
		# Tab não pode tirar o foco e devolver as letras aos atalhos.
		conferir(campo.has_focus(),"campo mantém o foco durante a digitação")
		await tecla(KEY_ESCAPE)
		conferir(not controle.digitando,"Esc devolve o controle ao jogo")
		conferir(not ui._telas_abertas.has("pausa"),"Esc para sair do campo não abre a pausa")
		if ui._telas_abertas.has("lobby"): ui._fechar_tela("lobby")
	tela._historico_campo.text = "Mensagem de teste"
	tela._historico_campo.grab_focus()
	await quadros()
	await tecla(KEY_ENTER,13)
	conferir(sessao._mensagem == "Mensagem de teste" and not tela._historico_campo.has_focus(),"Enter envia o texto e devolve o controle")
	conferir(ui._telas_abertas.is_empty(),"Enter para enviar não abre outra janela")
	# Um campo comum também reserva as teclas, sem precisar de estado especial do chat.
	var campo_generico := LineEdit.new()
	campo_generico.position = Vector2(200,100)
	root.add_child(campo_generico)
	campo_generico.grab_focus()
	await quadros()
	conferir(controle.digitando,"detecção de foco vale para outros campos editáveis")
	await tecla(KEY_I,105)
	conferir(not ui._telas_abertas.has("inventario") and campo_generico.text=="i","campo genérico recebe I sem abrir mochila")
	campo_generico.release_focus()
	campo_generico.queue_free()
	await quadros()
	await tecla(KEY_I,105)
	conferir(ui._telas_abertas.has("inventario"),"atalhos voltam a funcionar fora dos campos")
	ui._fechar_tela("inventario")
	sessao.online = false
	print("DIGITACAO PC: ",falhas," falhas")
	quit(1 if falhas else 0)
