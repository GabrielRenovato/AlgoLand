extends SceneTree
## Defesa da vila, loja do Tomás e cuidados da Rosa (só ouro). Precisa de janela e apaga o save isolado do percurso.
const PASTA := "user://percurso_primeira_raiz"
var falhas := 0
var cena: Node2D
var ultimo_texto := ""

func _initialize() -> void: rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame

func apagar(caminho: String) -> void:
	var dir := DirAccess.open(caminho)
	if dir == null: return
	for arquivo in dir.get_files(): DirAccess.remove_absolute(caminho.path_join(arquivo))
	for sub in dir.get_directories(): apagar(caminho.path_join(sub))
	DirAccess.remove_absolute(caminho)

func dialogo() -> Control:
	return cena.interface._telas.introducao

## Leva a fala à última página e espera o texto terminar de aparecer, para os botões aceitarem o clique.
func ate_as_opcoes() -> void:
	var d := dialogo()
	d._fechar_fala()
	for i in 240:
		await quadros(1)
		if d.visible and d._caixa_opcoes.visible and d._texto.visible_ratio >= 1.0 and d._espera <= 0.0: break

func escolher(indice: int) -> void:
	await ate_as_opcoes()
	ultimo_texto = dialogo()._texto.text
	dialogo()._caixa_opcoes.get_child(indice).pressed.emit()
	await quadros(20)

func abrir(id: String) -> void:
	cena._conversar_morador(id)
	await quadros(25)

func fechar_fala() -> void:
	var d := dialogo()
	for i in 8:
		if not d.visible: break
		if not d._opcoes.is_empty():
			await ate_as_opcoes()
			d._caixa_opcoes.get_child(d._opcoes.size() - 1).pressed.emit()
		else:
			d._fechar_fala()
		await quadros(15)

func objetivos(missao: String) -> Array:
	return cena.controlador.progresso.objetivos_cumpridos(missao)

func ouro() -> int:
	return int(root.get_node("DadosJogo").moedas)

func caber(nome: String) -> void:
	var anterior_escala := root.content_scale_size
	var anterior_tamanho := root.size
	for tamanho in [Vector2i(576, 324), Vector2i(288, 512)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros(4)
		var d := dialogo()
		var caixa: Rect2 = d.painel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, d.painel.size)
		verificar("%s cabe na tela %s" % [nome, tamanho], Rect2(Vector2.ZERO, Vector2(tamanho)).encloses(caixa))
	root.content_scale_size = anterior_escala
	root.size = anterior_tamanho
	await quadros(3)

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1); return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	apagar(PASTA)
	var c = load("res://codigo/campanha/controlador_campanha.gd").new()
	verificar("save de teste inicia", c.iniciar(PASTA, "prototipo") == OK)
	var catalogo: Dictionary = load("res://codigo/campanha/catalogo_campanha.gd").dados()
	for missao in ["sobreviver_queda", "estrada_interrompida", "acolhimento", "pomar_sulcos"]:
		for o in catalogo.missoes[missao].objetivos:
			var erro: Error = c.progresso.registrar_preparo("ligacao_ferro") if o.id == "oficio" else c.progresso.registrar_objetivo(missao, o.id)
			if erro != OK: verificar("preparar %s:%s" % [missao, o.id], false)
	c = null
	set_meta("campanha_nova_instancia", false)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(50)
	cena = current_scene
	verificar("vila abre depois do pomar", cena.abrir_regiao("vila", false) == OK)
	await quadros(40)
	cena.registro_run.apresentada = true ## o relatório da região não deve abrir por cima das falas
	var progresso = cena.controlador.progresso
	var inv = cena.jogador.inventario
	cena.jogador.adicionar_moedas(200)

	# Loja do Tomás
	await abrir("tomas")
	await ate_as_opcoes()
	verificar("Tomás oferece comprar, vender e sair", dialogo()._opcoes.size() == 3)
	await caber("menu do Tomás")
	await ate_as_opcoes()
	dialogo()._caixa_opcoes.get_child(0).pressed.emit()
	await quadros(20)
	await ate_as_opcoes()
	verificar("compra oferece três materiais e voltar", dialogo()._opcoes.size() == 4)
	await caber("lista de compra")
	await ate_as_opcoes()
	var ouro_antes := ouro()
	var ferro_antes: int = inv.quantidade_tipo("material:ferro")
	dialogo()._caixa_opcoes.get_child(0).pressed.emit()
	await quadros(20)
	await ate_as_opcoes()
	verificar("compra de ferro cobra ouro e entrega o material", ouro() == ouro_antes - 12 and inv.quantidade_tipo("material:ferro") == ferro_antes + 1)
	verificar("menu volta com o resultado da compra", dialogo()._texto.text != "" and dialogo()._opcoes.size() == 4)
	await escolher(3)
	await ate_as_opcoes()
	verificar("voltar abre o menu principal", dialogo()._opcoes.size() == 3)
	inv.receber_materiais({"madeira": 8})
	var madeira_antes: int = inv.quantidade_tipo("material:madeira")
	ouro_antes = ouro()
	dialogo()._caixa_opcoes.get_child(1).pressed.emit()
	await quadros(20)
	await ate_as_opcoes()
	verificar("vender excedentes deixa 5 de cada", inv.quantidade_tipo("material:madeira") == 5 and ouro() == ouro_antes + (madeira_antes - 5) * 2)
	await escolher(2)
	await fechar_fala()

	# Cuidados da Rosa
	cena.jogador.hp_atual = 1
	await abrir("rosa")
	await ate_as_opcoes()
	verificar("Rosa oferece tratar, comprar cura e sair", dialogo()._opcoes.size() == 3)
	ouro_antes = ouro()
	dialogo()._caixa_opcoes.get_child(0).pressed.emit()
	await quadros(20)
	await ate_as_opcoes()
	verificar("tratamento cobra 10 e recupera a vida", ouro() == ouro_antes - 10 and int(cena.jogador.hp_atual) == int(cena.jogador.estatisticas.hp_maximo))
	var curas_antes: int = inv.quantidade_tipo("pocao:cura")
	ouro_antes = ouro()
	dialogo()._caixa_opcoes.get_child(1).pressed.emit()
	await quadros(20)
	await ate_as_opcoes()
	verificar("poção de cura custa 20 e vai para a mochila", ouro() == ouro_antes - 20 and inv.quantidade_tipo("pocao:cura") == curas_antes + 1)
	await escolher(2)
	await fechar_fala()

	# Defesa da vila
	verificar("defesa ainda não começou", not "aviso" in objetivos("defesa_da_vila"))
	await abrir("lia")
	await fechar_fala()
	verificar("Lia dá o aviso dos sulcos", "aviso" in objetivos("defesa_da_vila"))
	cena.jogador.position = cena.alvos["barricada_vila"].no.position
	await quadros(3)
	verificar("barreira da entrada aceita a ligação", cena.interagir_proximo() == OK and "barreira" in objetivos("defesa_da_vila"))
	await quadros(25)
	verificar("texto da barreira cita a ligação de ferro", "ferro" in dialogo()._texto.text.to_lower())
	await fechar_fala()
	cena.jogador.position = cena.alvos["barricada_vila"].no.position
	await quadros(3)
	verificar("segunda interação chama a defesa", cena.interagir_proximo() == OK and cena.encontro.ativa)
	var primeira := -1
	for i in 900:
		await quadros(3)
		if not cena.encontro.ativa: break
		if cena.encontro.onda == 1 and primeira < 0: primeira = cena.encontro.criaturas.size()
		for criatura in cena.encontro.criaturas:
			if is_instance_valid(criatura) and not criatura.esta_morto: criatura.receber_dano(9999)
	verificar("ligação de ferro tira um rebento da primeira onda", primeira == 2)
	verificar("três ondas foram chamadas", cena.encontro.onda == 3)
	verificar("defesa concluída registra o objetivo", "defesa" in objetivos("defesa_da_vila") and not cena.encontro.ativa)
	await quadros(10)
	var ouro_defesa := ouro()
	await abrir("osvaldo")
	await fechar_fala()
	verificar("Osvaldo conclui os reparos e a missão", progresso.missao_concluida("defesa_da_vila"))
	await quadros(20)
	verificar("defesa paga 80 de ouro uma vez", ouro() == ouro_defesa + 80 and "defesa_da_vila" in progresso.recompensas)
	await abrir("lia")
	verificar("Lia comenta a rua de pé na segunda conversa", dialogo()._texto.text.to_lower().contains("rua"))
	await fechar_fala()

	print("FALHAS: ", falhas)
	apagar(PASTA)
	quit(1 if falhas > 0 else 0)
