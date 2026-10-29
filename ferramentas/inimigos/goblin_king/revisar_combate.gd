extends SceneTree
## Executa e fotografa o consumidor real, sem autoloads/saves da partida.
const SAIDA := "res://arte/previas/inimigos/goblin_king/combate/"
const ACOES := ["corte_direita", "corte_esquerda", "golpe_pesado", "combo_triplo", "giro_area", "impacto_area"]
const IMPACTOS := [1, 1, 1, 3, 3, 1]
var visual: Node2D
var recebidos: Array = []
var avisos: Array = []
var quadros := 0
var min_margem := 10000

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(512, 640)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	visual = load("res://cenas/inimigos/goblin_king_visual.tscn").instantiate()
	root.add_child(visual)
	visual.position = Vector2(256, 360)
	visual.scale = Vector2(2, 2)
	visual.impacto.connect(func(acao, tipo, indice, raio): recebidos.append([acao, tipo, indice, raio]))
	visual.aviso_area.connect(func(acao, raio): avisos.append([acao, raio]))
	assert(not visual.executar_ataque("inexistente"))
	# Reprodução real, com transições e callback de término do AnimationPlayer.
	for i in ACOES.size():
		recebidos.clear()
		assert(visual.executar_ataque(ACOES[i]))
		assert(not visual.executar_ataque("corte_direita"), "Ataque concorrente deve aguardar o atual")
		var limite := Time.get_ticks_msec()+5000
		while not visual._acao.is_empty() and Time.get_ticks_msec() < limite:
			await process_frame
		assert(visual._acao.is_empty(), "Ação não terminou: "+ACOES[i])
		assert(recebidos.size() == IMPACTOS[i], "Quantidade de impactos incorreta: "+ACOES[i])
		assert(visual.animador.current_animation == visual._clipes.parado)
	assert(avisos.size() == 2)
	# Cancelar antes do impacto não dispara dano. Salto temporal não perde o combo.
	recebidos.clear()
	assert(visual.executar_ataque("impacto_area"))
	visual.cancelar_ataque()
	for i in 4: await process_frame
	assert(recebidos.is_empty())
	visual.set_process(false)
	assert(visual.executar_combo())
	visual.animador.play(visual._clipes.combo_triplo, 0)
	visual.animador.speed_scale = 0
	visual.animador.seek(visual.animador.get_animation(visual._clipes.combo_triplo).length*.90, true)
	visual._process(0)
	assert(recebidos.size() == 3, "Salto de tempo perdeu um impacto do combo")
	visual._process(0)
	assert(recebidos.size() == 3, "Impactos duplicados no mesmo instante")
	visual.cancelar_ataque()
	var direcoes := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
	for acao in ACOES:
		for direcao in 4:
			visual.definir_direcao(direcoes[direcao])
			assert(visual.executar_ataque(acao))
			visual.animador.play(visual._clipes[acao], 0)
			visual.animador.speed_scale = 0
			var duracao: float = visual.animador.get_animation(visual._clipes[acao]).length
			var total := ceili(duracao*30) if direcao == 0 else 12
			for i in total+1:
				var instante := minf(i/30.0, duracao) if direcao == 0 else duracao*i/total
				visual.animador.seek(instante, true)
				visual._process(1.0/30 if direcao == 0 else duracao/total)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var render: Image = visual._viewport.get_texture().get_image()
				var usado := render.get_used_rect()
				assert(usado.has_area(), "Quadro vazio")
				var margem := mini(mini(usado.position.x, usado.position.y),
					mini(render.get_width()-usado.end.x, render.get_height()-usado.end.y))
				min_margem = mini(min_margem, margem)
				assert(margem >= 3, "Arma ou corpo cortado: %s direção %d quadro %d" % [acao, direcao, i])
				var caminho := SAIDA+"%s_%d_%03d.png" % [acao, direcao, i]
				assert(root.get_texture().get_image().save_png(caminho) == OK)
				quadros += 1
			visual.cancelar_ataque()
		print("COMBATE_CAPTURADO ", acao)
	var relatorio := {"acoes": ACOES, "impactos_por_acao": IMPACTOS,
		"reproducao_real": true, "retorno_parado": true, "cancelamento": true,
		"combo_sem_duplicacao": true, "salto_temporal_preserva_impactos": true,
		"direcoes": 4, "quadros": quadros, "margem_minima_texels": min_margem,
		"shader_personagem": visual._sprite.material.shader.resource_path, "save_carregado": false}
	FileAccess.open(SAIDA+"validacao.json", FileAccess.WRITE).store_string(JSON.stringify(relatorio, "\t")+"\n")
	print("GOBLIN_KING_COMBATE_OK ", JSON.stringify(relatorio))
	quit()
