extends SceneTree

var falhas := 0
var capturar := false

func _initialize() -> void:
	_rodar()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ", mensagem)

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use save isolado para testar corte e crescimento.")
		quit(1)
		return
	await process_frame
	capturar = "--capturar" in OS.get_cmdline_user_args()
	var fazenda: Node = root.get_node("Fazenda")
	var calendario: Node = root.get_node("Calendario")
	calendario.dia = 1
	fazenda.removidos.clear()
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(16)
	var terreno: Node = cena.get_node("Terrains")
	var extracao: Node = terreno.get_node("Extracao")
	var recurso: Dictionary = extracao.recursos[0]
	var chave: String = recurso.chave
	var original: Sprite2D = terreno.get_node(recurso.no)
	var obstaculo: CollisionPolygon2D = terreno.get_node(recurso.obstaculo)
	verificar(original.texture.region.size == Vector2(128,128), "carvalho adulto usa a árvore aprovada")
	var ponto: Vector2 = terreno.to_global(recurso.pos)
	for i in 4:
		extracao.impacto("machado", ponto)
	verificar(fazenda.tem_toco(chave) and extracao._tocos.has(chave), "corte deixa toco")
	verificar(not original.visible, "árvore derrubada escondida")
	calendario.dia = 11
	calendario.dia_passou.emit(11)
	await quadros()
	verificar(fazenda.estagio_arvore(chave) == -1, "não cresce através do toco após dez dias")
	verificar(fazenda.salvar(), "salva toco")
	fazenda.removidos.clear()
	verificar(fazenda.carregar() and fazenda.tem_toco(chave), "toco persiste ao carregar")
	for i in 2:
		extracao.impacto("machado", ponto)
	await create_timer(0.5).timeout
	verificar(not fazenda.tem_toco(chave), "arranca toco")
	verificar(int(fazenda.removidos[chave].dia) == 11, "remoção reinicia o prazo")
	for idade in 6:
		calendario.dia = 11 + idade
		calendario.dia_passou.emit(calendario.dia)
		await quadros()
		var esperado: int = 4 if idade == 5 else mini(idade,3)
		verificar(fazenda.estagio_arvore(chave) == esperado, "estágio no dia " + str(idade))
		verificar(original.visible == (esperado == 4), "copa adulta apenas no fim do ciclo")
		verificar(obstaculo.disabled == (esperado < 3), "colisão acompanha crescimento")
		if esperado < 4:
			var jovem: Sprite2D = extracao._crescimentos[chave]
			verificar(jovem.texture.resource_path.ends_with(extracao.ESTAGIOS[esperado]+".png"), "textura do estágio")
		if idade == 2:
			verificar(fazenda.salvar(), "salva muda")
			fazenda.removidos.clear()
			verificar(fazenda.carregar() and fazenda.estagio_arvore(chave) == 2, "idade da muda persiste")
	verificar(not extracao.alvo("machado",ponto).is_empty(), "árvore adulta pode ser cortada novamente")
	# Retorno à cena real: uma muda salva volta com desenho e colisão corretos.
	fazenda.removidos[chave] = {"dia": calendario.dia-2,"tipo":"arvore","toco":false}
	fazenda.salvar()
	cena.queue_free()
	await quadros()
	cena = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(16)
	terreno = cena.get_node("Terrains")
	extracao = terreno.get_node("Extracao")
	original = terreno.get_node(recurso.no)
	verificar(not original.visible and extracao._crescimentos.has(chave), "reentrada conserva muda")
	var jogador: Node = cena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = recurso.pos - Vector2(0,48)
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-ciclo-carvalho")
	for estacao in 4:
		calendario.dia = 1 + estacao*30
		terreno.get_node("Estacoes").definir_estacao(estacao,true)
		verificar(extracao._textura("arvoreta").resource_path.ends_with(extracao.NOMES_ESTACAO[estacao]+"/arvoreta.png"), "arvoreta da mesma espécie e estação")
		for estado in 6:
			if estado == 4:
				fazenda.removidos.erase(chave)
			else:
				fazenda.removidos[chave] = {"dia":calendario.dia-mini(estado,3),"tipo":"arvore","toco":estado==5}
			extracao._atualizar_crescimento()
			await quadros()
			var meteorologia: Node = terreno.get_node("Estacoes").meteorologia
			meteorologia._coberto(ponto)
			for cobertura in meteorologia._cobertura_nos:
				verificar(is_instance_valid(cobertura), "clima não mantém broto liberado")
			if estado < 2:
				verificar(not meteorologia._cobertura_nos.has(extracao._crescimentos[chave]), "semente e broto não cobrem chuva numa área vazia")
			if estado < 4:
				verificar(extracao._crescimentos[chave].texture.resource_path.contains(extracao.NOMES_ESTACAO[estacao]), "crescimento troca de estação")
			elif estado == 5:
				verificar(extracao._tocos[chave].texture.resource_path.contains(extracao.NOMES_ESTACAO[estacao]), "toco troca de estação")
			if capturar:
				meteorologia.definir_clima(meteorologia.Estado.LIMPO,true)
				await quadros()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-ciclo-carvalho/%d_%d.png" % [estacao,estado])
		print("OK ciclo estação ",estacao)
	print("RESULTADO: ",falhas," falhas")
	cena.queue_free()
	await quadros()
	quit(1 if falhas else 0)
