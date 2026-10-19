extends SceneTree

const Mordomo := preload("res://assets/personagens/conjuntos/cavalheiro/definicao.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _preparar_proc(jogador: Node) -> void:
	# Semente com primeiro sorteio favorável para testar o caminho real de acerto.
	for semente in 1000:
		jogador._rng_mordomo.seed = semente
		if jogador._rng_mordomo.randf() < Mordomo.CHANCE_BONUS:
			jogador._rng_mordomo.seed = semente
			jogador._recarga_mordomo = 0.0
			return

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 4:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador := arena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.definir_aparencia(1, 2)
	root.get_node("PainelDebug")._equipar_conjunto("cavalheiro")
	var comuns := true
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		comuns = comuns and inv.equipados[slot].raridade == "comum" and inv.equipados[slot].nome().contains("MORDOMO")
	_verificar("F3 equipa quatro peças comuns do Mordomo", comuns and Mordomo.mascara(inv.equipados) == 15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 331
	var ativacoes := 0
	for i in 10000:
		if Mordomo.pode_ativar(inv.equipados, 0.0, rng.randf()):
			ativacoes += 1
	_verificar("chance baixa de 10% e recarga de dois segundos", Mordomo.CHANCE_BONUS == 0.1 and Mordomo.RECARGA_BONUS == 2.0 and ativacoes > 850 and ativacoes < 1150)
	var antigo := Dados.new()
	antigo.tipo = "elmo_cavalheiro"
	antigo.categoria = "cabeca"
	antigo.nivel = 3
	var migrado := Dados.de_dict(antigo.para_dict())
	_verificar("peça comum antiga mantém raridade, id e melhoria", migrado.raridade == "comum" and migrado.tipo == antigo.tipo and migrado.nivel == 3)
	var slime = load("res://cenas/inimigos/slime.tscn").instantiate()
	arena.add_child(slime)
	slime.global_position = jogador.global_position + Vector2(80, 0)
	slime.vida = 10000
	slime.vida_maxima = 10000
	slime.set_physics_process(false)
	_verificar("acerto desfavorável não congela", not jogador._tentar_congelamento_mordomo(slime, 0.5) and not slime.esta_congelado())
	_preparar_proc(jogador)
	jogador.aplicar_golpe(slime, Vector2.RIGHT)
	_verificar("acerto real congela por dois segundos", slime.esta_congelado() and slime._congelado_restante == 2.0 and slime.velocity == Vector2.ZERO)
	_verificar("congelamento pausa animação e ataques", not slime.arvore_animacao.active and slime.esta_atordoado())
	var gelo = slime.get_node("GeloMordomo")
	_verificar("mob recebe casca pixel art de seis estados", gelo._sprite.hframes == 6 and gelo._sprite.texture != null and gelo._sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var inicio: Vector2 = slime.global_position
	slime._physics_process(0.25)
	_verificar("mob congelado não anda mesmo recebendo empurrão", slime.global_position == inicio and slime.velocity == Vector2.ZERO)
	gelo._process(0.2)
	_verificar("formação entra no laço de gelo completo", gelo._sprite.frame in [2, 3])
	_verificar("durante recarga nem sorteio favorável renova gelo", not jogador._tentar_congelamento_mordomo(slime, 0.0) and slime._congelado_restante < 2.0)
	_preparar_proc(jogador)
	jogador.aplicar_golpe(slime, Vector2.RIGHT)
	_verificar("novo acerto renova efeito sem duplicar blocos", slime._congelado_restante == 2.0 and slime.get_node("GeloMordomo") == gelo)
	slime._atualizar_efeitos(2.1)
	_verificar("fim do tempo restaura movimento e animação", not slime.esta_congelado() and slime.arvore_animacao.active and not slime.esta_atordoado() and gelo._quebrando)
	# Espada, lança e flecha usam aplicar_golpe; este segundo acerto testa outro alvo.
	var esqueleto = load("res://cenas/inimigos/esqueleto_arqueiro.tscn").instantiate()
	arena.add_child(esqueleto)
	esqueleto.vida = 10000
	esqueleto.set_physics_process(false)
	_preparar_proc(jogador)
	jogador.aplicar_golpe(esqueleto, Vector2.LEFT)
	_verificar("arqueiro congelado também bloqueia ataques", esqueleto.esta_congelado() and esqueleto.esta_atordoado())
	slime._atualizar_efeitos(2.1)
	var flecha = load("res://codigo/jogador/flecha.gd").new()
	arena.add_child(flecha)
	flecha.iniciar(jogador, Vector2.RIGHT)
	_preparar_proc(jogador)
	flecha._ao_alvo_entrar(slime)
	_verificar("flecha real também ativa o congelamento", slime.esta_congelado())
	slime._atualizar_efeitos(2.1)
	var golem = load("res://cenas/inimigos/golem.tscn").instantiate()
	arena.add_child(golem)
	golem.vida = 10000
	golem.set_physics_process(false)
	_preparar_proc(jogador)
	jogador.aplicar_golpe(golem, Vector2.RIGHT)
	var quadro_golem: int = golem.sprite.frame
	golem._physics_process(0.1)
	_verificar("chefe congelado mantém quadro e movimento parados", golem.esta_congelado() and golem.sprite.frame == quadro_golem and golem.velocity == Vector2.ZERO)
	var gelo_chefe = golem.get_node("GeloMordomo")
	golem.morrer()
	_verificar("morte do chefe remove gelo e libera animação de morte", not golem.esta_congelado() and gelo_chefe.is_queued_for_deletion() and golem._animacao == "dead")
	inv.remover_da_mochila(inv.buscar_por_tipo("lanca_basica"))
	inv.desequipar("botas")
	jogador._recarga_mordomo = 0.0
	_verificar("três peças permitem congelamento com sorteio favorável", jogador._tentar_congelamento_mordomo(slime, 0.0) and slime.esta_congelado())
	jogador._recarga_mordomo = 0.0
	_verificar("três peças têm metade da chance", not jogador._tentar_congelamento_mordomo(slime, 0.075))
	root.get_node("PainelDebug")._equipar_conjunto("cavaleiro_rubro")
	_verificar("outro conjunto não dispara gelo", not jogador._tentar_congelamento_mordomo(slime, 0.0))
	print("Falhas: ", _falhas)
	quit(_falhas)
