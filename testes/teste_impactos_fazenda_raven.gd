extends SceneTree

var falhas := 0
var impactos: Array[String] = []
var concluidas: Array[String] = []

func _initialize() -> void:
	rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 8) -> void:
	for i in n: await process_frame

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	var inv: Node = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(12)
	var jogador: Node = cena.get_node("Jogador")
	jogador.set_physics_process(false)
	var animacao: Node = jogador.no_fazenda
	animacao.impacto.connect(func(acao: String): impactos.append(acao))
	animacao.terminou.connect(func(acao: String): concluidas.append(acao))
	# Mesmo com um quadro longo, cada ação precisa aplicar exatamente um impacto.
	animacao.set_process(false)
	for acao in animacao.ACOES:
		impactos.clear()
		concluidas.clear()
		animacao.tocar(acao, Vector2.DOWN)
		verificar(acao+": não aplica antes da hora", impactos.is_empty())
		animacao._process(2.0)
		verificar(acao+": impacto e término únicos", impactos == [acao] and concluidas == [acao])
	impactos.clear()
	animacao.tocar("machado", Vector2.DOWN)
	animacao._process(0.15)
	animacao.parar()
	animacao._process(1.0)
	verificar("cancelar antes do impacto não acerta o recurso", impactos.is_empty())
	animacao.set_process(true)
	var extracao: Node = cena.find_child("Extracao", true, false)
	var plantio: Node = cena.find_child("Plantio", true, false)
	verificar("extração e plantio reais carregados", extracao != null and plantio != null)
	if extracao != null and plantio != null:
		var arvore: Dictionary = {}
		for recurso in extracao.recursos:
			if recurso.tipo == "arvore":
				arvore = recurso
				break
		verificar("árvore real disponível", not arvore.is_empty())
		if not arvore.is_empty():
			var fazenda: Node = root.get_node("Fazenda")
			fazenda.definir_ferramenta("machadinha")
			jogador._direcao_ataque = Vector2.DOWN
			jogador.global_position = extracao.to_global(arvore.pos) - Vector2(0, 11 + jogador.ALCANCE_ACAO_FAZENDA)
			impactos.clear()
			plantio._ao_ferramenta_pedida()
			verificar("usar machadinha inicia o corte", jogador.esta_em_acao_fazenda)
			await create_timer(0.16).timeout
			verificar("árvore inteira antes do contato", not extracao._vida.has(arvore.chave))
			await create_timer(0.65).timeout
			verificar("golpe reduz vida da árvore uma vez", impactos == ["machado"] and extracao._vida.get(arvore.chave, 4) == 3)
	cena.queue_free()
	await quadros()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
