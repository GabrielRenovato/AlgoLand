extends SceneTree

## Ligação fazenda -> arena (pedido de 2026-10-16): o Caio cozinha com a colheita e o prato vale a próxima partida
## (soma nas melhorias de vida, dano, defesa, fôlego e ouro); a Lia troca colheita por Brasas. Saves isolados obrigatórios.

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	var progresso: Node = root.get_node("Progresso")
	var fazenda: Node = root.get_node("Fazenda")
	var refeicoes = load("res://codigo/dados/refeicoes.gd")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	progresso.refeicao = ""
	progresso.brasas = 0

	# --- Dados ---
	for id in refeicoes.ORDEM:
		var receita: Dictionary = refeicoes.dados(id)["receita"]
		verificar("%s: receita so com plantas que existem" % id, receita.keys().all(func(p): return fazenda.PLANTAS.has(p)))
		verificar("%s: tem bonus e texto" % id, refeicoes.texto_bonus(id) != "" and refeicoes.icone(id) != null)

	# --- Cozinhar ---
	fazenda.colheita = {"cenoura": 1, "batata": 2}
	verificar("falta ingrediente nao cozinha", fazenda.cozinhar("sopa_raizes") != "" and progresso.refeicao == "")
	fazenda.colheita = {"cenoura": 3, "batata": 2}
	var vigor_antes: float = progresso.bonus("vigor")
	verificar("com a colheita cozinha", fazenda.cozinhar("sopa_raizes") == "")
	verificar("gastou so a receita", fazenda.quantidade_colhida("cenoura") == 1 and fazenda.quantidade_colhida("batata") == 0)
	verificar("prato ativo", progresso.refeicao == "sopa_raizes")
	verificar("prato soma +30% de vida", is_equal_approx(progresso.bonus("vigor"), vigor_antes + 0.30))
	verificar("tela da Lia ve so as melhorias", is_equal_approx(progresso.bonus_melhoria("vigor"), vigor_antes))
	fazenda.colheita = {"tomate": 2, "melancia": 1}
	verificar("um prato por vez", fazenda.cozinhar("salada_verao") != "" and progresso.refeicao == "sopa_raizes")
	progresso.salvar()
	progresso.refeicao = ""
	progresso.carregar()
	verificar("prato sobrevive ao save", progresso.refeicao == "sopa_raizes")

	# --- O jogador sente o prato ---
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	var jogador: Node = current_scene.get_node("Jogador")
	var vida_com_prato: int = jogador.estatisticas.hp_maximo
	progresso.iniciar_partida()
	await quadros(4)
	progresso.encerrar_partida()
	await quadros(4)
	verificar("fim da partida acaba o prato", progresso.refeicao == "")
	verificar("vida maxima cai quando o prato acaba (%d -> %d)" % [vida_com_prato, jogador.estatisticas.hp_maximo], jogador.estatisticas.hp_maximo < vida_com_prato)
	verificar("sem prato o bonus volta ao das melhorias", is_equal_approx(progresso.bonus("vigor"), vigor_antes))

	# --- Venda para a Lia ---
	var brasas: int = progresso.brasas
	fazenda.colheita = {"tomate": 3, "cenoura": 2}
	var ganho: int = fazenda.vender_colheita("tomate")
	verificar("3 tomates (raro) = 18 Brasas", ganho == 18 and progresso.brasas == brasas + 18 and fazenda.quantidade_colhida("tomate") == 0)
	verificar("colheita comum vale mais que a semente (3 > 2)", fazenda.brasas_por_colheita("cenoura") > 2)
	verificar("vender o que nao tem nao paga", fazenda.vender_colheita("uva") == 0)

	# --- Botões na conversa ---
	var cidade: Node = root.get_node("Cidade")
	fazenda.colheita = {"cenoura": 2, "batata": 2}
	change_scene_to_file("res://cenas/cidade/pousada.tscn")
	await quadros(35)
	jogador=current_scene.get_node("Jogador")
	jogador.position=current_scene.get_node("Interior/Cozinha").position+Vector2(0,16)
	current_scene.get_node("Interior/Cozinha").abrir_tela()
	await quadros(10)
	var dialogo: Node = _dialogo()
	verificar("conversa com o Caio aberta", dialogo != null and dialogo.visible)
	if dialogo != null:
		verificar("móvel da cozinha abre o serviço", dialogo._atendimento=="cozinha")
		dialogo._abrir_submenu("cozinha")
		await quadros(4)
		var pratos: Array = dialogo._botoes.filter(func(b): return b.text.begins_with("SOPA DE RAIZES"))
		verificar("cozinha lista a sopa liberada", pratos.size() == 1 and not pratos[0].disabled)
		if not pratos.is_empty(): pratos[0].pressed.emit()
		await quadros(4)
		verificar("botao cozinha e come", progresso.refeicao == "sopa_raizes")
		dialogo._abrir_submenu("venda")
		await quadros(2)
		dialogo._abrir_submenu("")
		await quadros(2)
	progresso.encerrar_partida()
	progresso.refeicao = ""
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

func _dialogo() -> Node:
	for no in get_nodes_in_group("interface"):
		var tela = no._telas.get("conversa_cidade") if "_telas" in no else null
		if tela != null:
			return tela
	return null

func _textos(dialogo: Node) -> Array:
	return dialogo._botoes.map(func(b): return b.text)
