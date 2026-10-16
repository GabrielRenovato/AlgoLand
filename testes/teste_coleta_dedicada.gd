extends SceneTree

## Executar na cópia de testes: valida entradas reais, migração e bloqueios sem tocar na partida do jogador.
var falhas := 0

func _initialize() -> void:
	rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 5) -> void:
	for i in n:
		await process_frame

func rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	var inv: Node = root.get_node("InventarioJogador")
	var fazenda: Node = root.get_node("Fazenda")
	var controle: Node = root.get_node("Controle")
	root.get_node("Calendario").dia = 1
	inv.limpar()
	inv.criar_itens_iniciais()
	verificar("kit inicial sem item de coleta", not fazenda.ferramentas().has("mao"))
	# Carrega um save antigo com a mão entre outros itens; mantém as casas e os objetos vizinhos.
	var antigo: Dictionary = {"mochila": []}
	for item in inv.mochila:
		antigo.mochila.append(item.para_dict() if item != null else null)
	antigo.mochila[4] = {"tipo": "mao", "categoria": "ferramenta"}
	var caminho := "user://teste_coleta_legado.json"
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(antigo))
	arquivo.close()
	verificar("save antigo carrega", inv.carregar(caminho))
	verificar("save antigo libera coleta sem mover enxada ou regador", inv.mochila[2].tipo == "enxada" and inv.mochila[3].tipo == "regador" and inv.mochila[4] == null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	fazenda.solo.clear()
	fazenda.entulho.clear()
	fazenda.entulho_iniciado = true
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(12)
	var plantio: Node = cena.get_node("Terrains/Plantio")
	var jogador: Node = cena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position = Vector2(320, 384)
	jogador.movimento_habilitado = true
	jogador.ataques_bloqueados = false
	fazenda.definir_ferramenta("regador")
	var celula: Vector2i = plantio.celula_alvo()
	verificar("alvo dentro da área", fazenda.AREA_PLANTIO.has_point(celula))
	fazenda.solo[celula] = {"molhado": false, "planta": "cenoura", "dias": 0, "murcha": false}
	plantio.pedir_coleta()
	verificar("planta verde não inicia coleta", not jogador.esta_em_acao_fazenda)
	fazenda.solo[celula]["dias"] = 99
	jogador.movimento_habilitado = false
	plantio.pedir_coleta()
	verificar("menu bloqueia coleta", not jogador.esta_em_acao_fazenda)
	jogador.movimento_habilitado = true
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_R
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await quadros()
	verificar("R inicia coleta mantendo regador equipado", jogador.esta_em_acao_fazenda and fazenda.ferramenta == "regador")
	var quantidade: int = fazenda.quantidade_colhida("cenoura")
	plantio._ao_impacto("colher", jogador.ponto_acao_fazenda())
	plantio._ao_impacto("colher", jogador.ponto_acao_fazenda())
	verificar("impacto colhe apenas uma vez", fazenda.quantidade_colhida("cenoura") == quantidade + 1 and fazenda.ferramenta == "regador")
	jogador.cancelar_acao_fazenda()
	fazenda.solo[celula] = {"molhado": false, "planta": "cenoura", "dias": 99, "murcha": false}
	var botao := InputEventJoypadButton.new()
	botao.button_index = JOY_BUTTON_Y
	botao.pressed = true
	Input.parse_input_event(botao)
	await quadros()
	verificar("botão Y do controle inicia coleta", jogador.esta_em_acao_fazenda)
	jogador.cancelar_acao_fazenda()
	fazenda.solo_alterado.emit(celula)
	plantio._atualizar_aviso_colher()
	verificar("balão de colher aparece sobre a planta madura", plantio._aviso_colher.visible)
	for layout in ["xbox", "playstation", "nintendo"]:
		controle.definir_preferencia_layout(layout)
		controle._definir(true)
		verificar("balão acompanha controle " + layout, plantio._tecla_colher.text == controle.rotulo_acao("colher"))
	controle._definir(false)
	plantio._tecla_colher.pressed.emit()
	verificar("balão coleta sem trocar ferramenta", jogador.esta_em_acao_fazenda and fazenda.ferramenta == "regador")
	jogador.cancelar_acao_fazenda()
	controle.usando_toque = true
	var toque: Node = load("res://codigo/ui/controles_toque.gd").new()
	root.add_child(toque)
	await quadros()
	toque._process(0.3)
	var coleta: Dictionary = toque._botao_da_acao(&"colher")
	verificar("mobile tem botão COLHER visível", coleta.rotulo == "COLHER" and coleta.visivel)
	verificar("mobile distingue coleta e usar ferramenta", coleta.centro.distance_to(toque._botao_da_acao(&"attack").centro) > coleta.raio + toque.RAIO_ATAQUE)
	toque._apertar_botao(coleta)
	await quadros()
	verificar("botão mobile inicia coleta", jogador.esta_em_acao_fazenda and fazenda.ferramenta == "regador")
	toque._largar_botao(coleta)
	toque._definir_ativo(false)
	verificar("menu esconde e solta botão mobile", not toque._ativo and not coleta.apertado)
	toque.queue_free()
	cena.queue_free()
	current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(falhas)
