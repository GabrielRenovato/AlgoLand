extends SceneTree
## Integração visual real, sem acessar a partida do usuário.
const SAIDA := "res://arte/previas/personagens/base_vila_npc/jogavel/"

func _initialize() -> void:
	rodar.call_deferred()

func esperar(quadros: int) -> void:
	for i in quadros:
		await process_frame

func capturar(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA + nome + ".png")

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	# Acabamento não pode voltar a deformar as poses aprovadas ou mudar o aço.
	for acao in ["parado", "corrida", "espada"]:
		var aprovado := Image.load_from_file("res://arte/fontes/personagens/base_vila_npc/v4_geometria_nativa/%s.png" % acao)
		var atual := Image.load_from_file("res://assets/personagens/base_vila_nativa/%s.png" % acao)
		assert(aprovado.get_size() == atual.get_size())
		for y in aprovado.get_height():
			for x in aprovado.get_width():
				var anterior := aprovado.get_pixel(x, y)
				var novo := atual.get_pixel(x, y)
				assert(anterior.a == novo.a, "O acabamento mudou a máscara aprovada.")
				if anterior.a >= 0.5 and anterior.b > anterior.r * 1.08:
					assert(anterior == novo, "O acabamento alterou um pixel do aço/rastro.")
	DirAccess.make_dir_recursive_absolute(SAIDA)
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	root.get_node("Transicao").limpar()
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	assert(not jogador.has_node("HeroiBaseVila"), "Mana Seed deve ser o visual padrão.")
	assert(jogador.get_node("CompositeSprites").visible, "Não ocultar o personagem Mana Seed.")
	await capturar("mana_seed_padrao")
	var painel := root.get_node("PainelDebug")
	painel._ativar_base_vila()
	var visual := jogador.get_node_or_null("HeroiBaseVila")
	assert(visual != null, "A base experimental só aparece quando ativada pelo F3.")
	assert(visual.offset == Vector2(-40, -52) and visual.position.y == 11)
	assert(visual.material == null, "Não remontar a anatomia pelo shader rejeitado.")
	jogador.usando_espada = false
	jogador.velocity = Vector2.ZERO
	visual._process(0.0)
	assert(visual.visible and not jogador.get_node("CompositeSprites").visible)
	await capturar("parado")
	var direcoes := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
	for linha in 4:
		jogador._direcao_ataque = direcoes[linha]
		jogador.velocity = direcoes[linha] * 114
		visual._process(0.0)
		assert(visual._acao == "corrida" and visual._linha == linha)
		visual._tempo = 0.75
		visual._process(0.0)
		assert(visual.frame == linha * 8 + 7)
		visual._process(0.10)
		assert(visual.frame == linha * 8)
		await capturar("corrida_%d" % linha)
	jogador.velocity = Vector2.ZERO
	jogador.usando_espada = true
	jogador._esta_atacando = true
	jogador._temporizador.stop()
	for linha in 4:
		jogador._direcao_ataque = direcoes[linha]
		visual._process(0.0)
		for coluna in 8:
			visual._tempo = 0.25 if coluna == 0 else 0.45 + coluna * 0.1
			visual._process(0.0)
			assert(visual.frame == linha * 8 + coluna)
			if coluna == 4:
				await capturar("ataque_ativo_%d" % linha)
		await capturar("espada_%d" % linha)
	# Sincronização com o ataque real, sem alterar sua duração ou regras de dano.
	jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1", 0.8)
	await create_timer(0.61).timeout
	visual._process(0.0)
	assert(visual.frame % 8 >= 4)
	jogador._temporizador.stop()
	jogador._on_temporizador_ataque_timeout()
	jogador.esta_em_acao_fazenda = true
	visual._process(0.0)
	assert(not visual.visible and jogador.get_node("CompositeSprites").visible)
	jogador.esta_em_acao_fazenda = false
	visual._process(0.0)
	assert(visual.visible and not jogador.get_node("CompositeSprites").visible)
	painel._reaplicar_personagem()
	assert(not jogador.has_node("HeroiBaseVila"))
	jogador._instalar_base_vila()
	assert(not jogador.has_node("HeroiBaseVila"))
	painel._ativar_base_vila()
	assert(jogador.has_node("HeroiBaseVila"))
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F3
	tecla.pressed = true
	painel._unhandled_key_input(tecla)
	await esperar(3)
	await capturar("painel_f3")
	print("BASE_VILA_JOGAVEL_OK: Mana Seed padrão, protótipo opcional via F3, 4 corridas, 32 quadros de espada, timer real, ferramentas e alternância F3.")
	quit()
