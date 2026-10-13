extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_personagem.gd
# Cabelos e roupas do personagem (Codigos/DadosLocais/aparencia.gd) e a tela de criação de personagem (cenas/criacao_personagem.tscn):
#  - a lista e as texturas de CADA peça em CADA página de animação (andar, fazenda, forja, sentado, golpes, reação, arco);
#  - os índices antigos continuam apontando para as mesmas peças (os saves valem);
#  - o jogador veste a peça nova em todas as animações e carrega o save sem quebrar;
#  - a tela de criação: abas, escolha, cor, sorteio, confirmar grava o save, voltar, teclado/controle, e o layout cabe em 576x324, 720x324 e 4:3.
# ATENCAO: carrega a cena de jogo (pode regravar user://inventario.json); faça backup do user:// antes.

const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")
const CAMINHO_SAVE_TESTE := "user://teste_personagem.json"

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	await process_frame
	_testar_lista()
	_testar_texturas()
	_testar_saves_antigos()
	await _testar_jogador()
	await _testar_tela()
	if FileAccess.file_exists(CAMINHO_SAVE_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_SAVE_TESTE))
	print("--- teste_personagem: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)

# --- A lista ---------------------------------------------------------------------------------------------------

func _testar_lista() -> void:
	_verificar("sete cabelos (2 antigos + 5 novos)", Aparencia.total_cabelos() == 7, str(Aparencia.total_cabelos()))
	_verificar("42 roupas (12 antigas + 30 novas)", Aparencia.total_roupas() == 42, str(Aparencia.total_roupas()))
	var ids := {}
	var repetido := false
	var sem_nome := false
	for lista in [Aparencia.cabelos(), Aparencia.roupas()]:
		for item in lista:
			if ids.has(String(item["id"])):
				repetido = true
			ids[String(item["id"])] = true
			sem_nome = sem_nome or String(item["nome"]) == ""
	_verificar("cada peça tem id próprio e nome", not repetido and not sem_nome, "")
	_verificar("índices fora da lista caem na primeira peça", Aparencia.indice_cabelo(99) == 0 and Aparencia.indice_roupa(-1) == 0 and Aparencia.indice_roupa(500) == 0, "")
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = 7
	var sempre_vestida := true
	for i in 200:
		sempre_vestida = sempre_vestida and Aparencia.roupa_aleatoria(sorteio) >= 2 and Aparencia.cabelo_aleatorio(sorteio) < Aparencia.total_cabelos()
	_verificar("o sorteio nunca escolhe só a roupa íntima ou a cueca", sempre_vestida, "")

# --- Todas as peças em todas as páginas ------------------------------------------------------------------------

func _testar_texturas() -> void:
	var paginas: Array = Aparencia.PAGINAS_ANDAR + Aparencia.PAGINAS_COMBATE
	var faltando: Array = []
	var tamanho_errado: Array = []
	for pagina in paginas:
		for i in Aparencia.total_cabelos():
			var t := Aparencia.cabelo(i, pagina)
			if t == null:
				faltando.append("cabelo %d %s" % [i, pagina])
			elif t.get_size() != Vector2(512, 512):
				tamanho_errado.append("cabelo %d %s %s" % [i, pagina, t.get_size()])
		for i in Aparencia.total_roupas():
			var t := Aparencia.roupa(i, pagina)
			if t == null:
				faltando.append("roupa %d %s" % [i, pagina])
			elif t.get_size() != Vector2(512, 512):
				tamanho_errado.append("roupa %d %s %s" % [i, pagina, t.get_size()])
	_verificar("todo cabelo e toda roupa tem textura em todas as %d páginas" % paginas.size(), faltando.is_empty(), str(faltando.slice(0, 5)))
	_verificar("todas as folhas são de 512x512 (8x8 quadros de 64 px)", tamanho_errado.is_empty(), str(tamanho_errado.slice(0, 5)))
	# nas páginas de combate a roupa nova é a folha RECOLORIDA a partir do molde antigo (roupas/<id>_<pagina>.png), nunca a antiga com tinta
	var roupa_recolorida := true
	for pagina in Aparencia.PAGINAS_COMBATE:
		for i in range(2, Aparencia.total_roupas()):
			if int(Aparencia.roupas()[i]["legado"]) > 0:
				continue
			var textura := Aparencia.roupa(i, pagina)
			roupa_recolorida = roupa_recolorida and textura != null and textura.resource_path.ends_with("%s_%s.png" % [Aparencia.roupas()[i]["id"], pagina])
	_verificar("nas páginas de combate a roupa nova é a folha recolorida própria", roupa_recolorida, "")
	var cabelo_em_combate := true
	for pagina in Aparencia.PAGINAS_COMBATE:
		for i in range(2, Aparencia.total_cabelos()):
			var t := Aparencia.cabelo(i, pagina)
			cabelo_em_combate = cabelo_em_combate and t != null and t.resource_path.contains("Aparencia/cabelos/") and t.resource_path.ends_with("_%s.png" % pagina)
	_verificar("os cabelos novos têm folha de combate própria (sintetizada) em todas as páginas de combate: não trocam de cabelo ao golpear", cabelo_em_combate, "")
	_verificar("andar, fazenda e página 4 usam a arte nova", Aparencia.roupa(20, "andar").resource_path.contains("Aparencia/roupas/")
			and Aparencia.roupa(20, "fazenda").resource_path.ends_with("_p2.png") and Aparencia.roupa(20, "sentado").resource_path.ends_with("_p4.png")
			and Aparencia.cabelo(4, "forja").resource_path.ends_with("_p4.png"), Aparencia.roupa(20, "andar").resource_path)

# Os índices que os saves já guardam: 0 e 1 (cabelos) e 0 a 11 (roupas) apontam para os mesmos arquivos de sempre
func _testar_saves_antigos() -> void:
	_verificar("cabelo 0 e 1 são os arquivos antigos hair (1) e hair (2)", Aparencia.cabelo(0, "andar").resource_path.ends_with("hair (1).png") and Aparencia.cabelo(1, "espada").resource_path.ends_with("hair (2).png"), "")
	var certo := true
	for i in 12:
		certo = certo and Aparencia.roupa(i, "andar").resource_path.ends_with("outfit (%d).png" % (i + 1)) and Aparencia.roupa(i, "fazenda").resource_path.ends_with("roupa_%d.png" % (i + 1))
	_verificar("roupas 0 a 11 de andar e de fazenda: os mesmos arquivos de sempre", certo, "")
	_verificar("golpe de espada: roupa íntima (0) e cueca (1) agora batem com a de andar (os arquivos antigos estavam trocados)",
			Aparencia.roupa(0, "espada").resource_path.ends_with("outfit(2).png") and Aparencia.roupa(1, "espada").resource_path.ends_with("outfit(1).png")
			and Aparencia.roupa(0, "lanca").resource_path.ends_with("outfit (2).png") and Aparencia.roupa(0, "forja").resource_path.ends_with("outfit (2).png"), "")

# --- O jogador veste as peças -------------------------------------------------------------------------------

func _testar_jogador() -> void:
	var jogador_cena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(jogador_cena)
	current_scene = jogador_cena
	await _quadros(12)
	var jogador: Node = jogador_cena.get_node("Jogador")
	jogador.definir_aparencia(5, 20)
	_verificar("andar: o cabelo e a roupa novos", jogador.sprite_cabelo.texture == Aparencia.cabelo(5, "andar") and jogador.sprite_roupa.texture == Aparencia.roupa(20, "andar"), "")
	_verificar("golpe de espada e de lança: o cabelo novo (sintetizado) e a roupa substituta", jogador.cabelo_ataque.texture == Aparencia.cabelo(5, "espada") and jogador.roupa_ataque.texture == Aparencia.roupa(20, "espada")
			and jogador.cabelo_lanca_ataque.texture == Aparencia.cabelo(5, "lanca") and jogador.roupa_lanca_ataque.texture == Aparencia.roupa(20, "lanca"), "")
	_verificar("forja: a página 4 do cabelo e da roupa novos", jogador.sprite_cabelo_forja.texture == Aparencia.cabelo(5, "forja") and jogador.sprite_roupa_forja.texture == Aparencia.roupa(20, "forja"), "")
	jogador.no_fazenda._sincronizar_aparencia()
	jogador.no_reacao._familia = "lanca"
	jogador.no_reacao._sincronizar_aparencia()
	jogador.no_arco._pagina = 3
	jogador.no_arco._sincronizar_aparencia()
	_verificar("fazenda, reação (lança) e arco (p3) leem o índice do jogador", jogador.no_fazenda._roupa.texture == Aparencia.roupa(20, "fazenda") and jogador.no_fazenda._cabelo.texture == Aparencia.cabelo(5, "fazenda")
			and jogador.no_reacao._roupa.texture == Aparencia.roupa(20, "reacao_lanca") and jogador.no_arco._cabelo.texture == Aparencia.cabelo(5, "arco_p3"), "")
	var molde_legado: Texture2D = Aparencia._carregar(Aparencia._caminho_legado_roupa(int(Aparencia.roupas()[20]["combate"]) + 1, "espada"))
	_verificar("a roupa de combate e uma folha recolorida propria (nao o molde antigo) e sem tinta por cima", jogador.roupa_ataque.texture != null and jogador.roupa_ataque.texture != molde_legado
			and jogador.roupa_ataque.modulate == Color.WHITE and jogador.sprite_roupa.modulate == Color.WHITE, str(jogador.roupa_ataque.texture))
	jogador.cor_cabelo = Color(0.3, 0.6, 1.0)
	jogador.definir_aparencia(5, 20)
	_verificar("a cor do cabelo vai para todas as camadas de cabelo", jogador.sprite_cabelo.modulate == Color(0.3, 0.6, 1.0) and jogador.cabelo_ataque.modulate == Color(0.3, 0.6, 1.0)
			and jogador.cabelo_lanca_ataque.modulate == Color(0.3, 0.6, 1.0) and jogador.sprite_cabelo_forja.modulate == Color(0.3, 0.6, 1.0), "")
	# um save antigo e um save com peça nova
	jogador.aplicar_dados_carregados({"cabelo_atual": 1, "roupa_atual": 11, "cor_cabelo": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0}})
	_verificar("carregar um save antigo (cabelo 1, roupa 11) mantém as peças de sempre", jogador.cabelo_atual == 1 and jogador.roupa_atual == 11
			and jogador.sprite_roupa.texture.resource_path.ends_with("outfit (12).png") and jogador.sprite_cabelo.modulate == Color(1, 0, 0, 1), "")
	jogador.aplicar_dados_carregados({"cabelo_atual": 6, "roupa_atual": 41})
	_verificar("carregar um save com as peças mais novas (cabelo 6, roupa 41)", jogador.cabelo_atual == 6 and jogador.roupa_atual == 41 and jogador.sprite_roupa.texture == Aparencia.roupa(41, "andar"), "")
	jogador.aplicar_dados_carregados({"cabelo_atual": 99, "roupa_atual": 999})
	_verificar("um índice que não existe mais cai na primeira peça, sem quebrar", jogador.cabelo_atual == 0 and jogador.roupa_atual == 0 and jogador.sprite_roupa.texture != null, "")
	# sentado
	jogador.definir_aparencia(3, 25)
	jogador.sentar(jogador.global_position, 1, 5)
	_verificar("sentado: a roupa e o cabelo novos na página 4", jogador.sprite_roupa_forja.texture == Aparencia.roupa(25, "sentado") and jogador.sprite_cabelo_forja.texture == Aparencia.cabelo(3, "sentado"), "")
	jogador.levantar(jogador.global_position)
	jogador_cena.queue_free()
	await _quadros(3)

# --- A tela de criação -----------------------------------------------------------------------------------------

func _tecla_aba(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	Input.parse_input_event(ev)
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	Input.parse_input_event(solta)

func _testar_tela() -> void:
	root.size = Vector2i(720, 324)
	await _quadros(2)
	var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
	tela.trocar_cena = false
	tela.caminho_save = CAMINHO_SAVE_TESTE
	root.add_child(tela)
	current_scene = tela
	await _quadros(8)
	_verificar("tela: uma casinha para cada cabelo e cada roupa", tela._casas_cabelo.size() == Aparencia.total_cabelos() and tela._casas_roupa.size() == Aparencia.total_roupas(), "")
	_verificar("tela: abre na aba CABELO, com o primeiro cabelo, a roupa de camponês e o loiro", tela.aba == tela.Aba.CABELO and tela.cabelo == 0 and tela.roupa == 2
			and tela.cor.is_equal_approx(tela.COR_INICIAL) and tela._paginas[0].visible and not tela._paginas[1].visible and not tela._paginas[2].visible, "")
	_verificar("tela: a prévia mostra o cabelo, a roupa e a cor escolhidos", tela._previa_cabelo.texture == Aparencia.cabelo(0, "andar") and tela._previa_roupa.texture == Aparencia.roupa(2, "andar")
			and tela._previa_cabelo.modulate.is_equal_approx(tela.COR_INICIAL), "")
	# escolher
	tela._casas_cabelo[4]["botao"].pressed.emit()
	tela._casas_roupa[20]["botao"].pressed.emit()
	_verificar("tela: tocar numa casinha escolhe o cabelo e a roupa (a prévia muda)", tela.cabelo == 4 and tela.roupa == 20 and tela._previa_cabelo.texture == Aparencia.cabelo(4, "andar")
			and tela._previa_roupa.texture == Aparencia.roupa(20, "andar"), "")
	_verificar("tela: só a escolhida fica na moldura dourada",
			tela._casas_cabelo[4]["botao"].get_theme_stylebox("normal") == tela._dourada and tela._casas_cabelo[3]["botao"].get_theme_stylebox("normal") == tela._normal
			and tela._casas_roupa[20]["botao"].get_theme_stylebox("normal") == tela._dourada, "")
	_verificar("tela: as miniaturas mostram a roupa e o cabelo escolhidos", tela._casas_cabelo[0]["roupa"].texture.atlas == Aparencia.roupa(20, "andar")
			and tela._casas_roupa[0]["cabelo"].texture.atlas == Aparencia.cabelo(4, "andar"), "")
	# abas
	tela._botoes_aba[1].pressed.emit()
	_verificar("tela: a aba ROUPA mostra a lista de roupas", tela.aba == tela.Aba.ROUPA and tela._paginas[1].visible and not tela._paginas[0].visible, "")
	_tecla_aba("ferramenta_proxima")
	await _quadros(2)
	_verificar("tela: Q/E (LB/RB) trocam de aba (ROUPA -> COR)", tela.aba == tela.Aba.COR and tela._paginas[2].visible, "aba=%d" % tela.aba)
	_tecla_aba("ferramenta_anterior")
	await _quadros(2)
	_verificar("tela: e voltam (COR -> ROUPA)", tela.aba == tela.Aba.ROUPA, "aba=%d" % tela.aba)
	# cor
	tela._abrir_aba(tela.Aba.COR)
	tela._casas_cor[10].pressed.emit()
	_verificar("tela: uma cor da paleta tinge o cabelo da prévia", tela.cor.is_equal_approx(tela.PALETA[10]) and tela._previa_cabelo.modulate.is_equal_approx(tela.PALETA[10]), "")
	_verificar("tela: os controles de matiz, força e brilho acompanham a cor", absf(tela._slider_matiz.value - tela.PALETA[10].h * 360.0) <= 1.0 and absf(tela._slider_brilho.value - tela.PALETA[10].v * 100.0) <= 1.0, "")
	tela._slider_matiz.value = 120.0
	tela._slider_saturacao.value = 100.0
	tela._slider_brilho.value = 100.0
	_verificar("tela: ajustar os controles muda a cor (matiz 120 = verde)", tela.cor.g > 0.9 and tela.cor.r < 0.1 and tela._previa_cabelo.modulate.is_equal_approx(tela.cor), str(tela.cor))
	# girar
	var direcao: int = tela._direcao
	tela._girar(1)
	_verificar("tela: girar muda a direção da prévia (quadro da folha)", tela._direcao == posmod(direcao + 1, 4) and tela._previa_corpo.frame == int(tela.LINHAS_DIRECAO[tela._direcao]) * 8, "")
	# sorteio
	for i in 20:
		tela.sortear()
		if not (tela.cabelo >= 0 and tela.cabelo < Aparencia.total_cabelos() and tela.roupa >= 2 and tela.roupa < Aparencia.total_roupas()):
			_verificar("tela: ALEATORIO escolhe peças válidas", false, "%d %d" % [tela.cabelo, tela.roupa])
			break
	_verificar("tela: ALEATORIO escolhe cabelo, roupa e cor válidos", tela.cabelo >= 0 and tela.cabelo < Aparencia.total_cabelos() and tela.roupa >= 2, "")
	# confirmar grava o save e o jogador o carrega
	tela._casas_cabelo[5]["botao"].pressed.emit()
	tela._casas_roupa[30]["botao"].pressed.emit()
	tela._casas_cor[2].pressed.emit()
	tela._campo_nome.text = "ana"
	tela._campo_nome.text_changed.emit("ana")
	var confirmado := [{}]
	tela.confirmada.connect(func(d: Dictionary) -> void: confirmado[0] = d)
	tela._botao_confirmar.pressed.emit()
	await _quadros(2)
	var gravado = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_SAVE_TESTE))
	_verificar("tela: CONFIRMAR grava o save com o formato de sempre", gravado is Dictionary and int(gravado["cabelo_atual"]) == 5 and int(gravado["roupa_atual"]) == 30
			and gravado["apelido"] == "ANA" and absf(float(gravado["cor_cabelo"]["r"]) - tela.PALETA[2].r) < 0.001 and gravado["cor_cabelo"].has("a"), str(gravado))
	_verificar("tela: e avisa com os mesmos dados", confirmado[0].get("roupa_atual", -1) == 30, "")
	tela._campo_nome.text = ""
	tela._campo_nome.text_changed.emit("")
	_verificar("tela: sem nome, o personagem se chama HEROI", tela.dados_do_personagem()["apelido"] == "HEROI", "")
	# o jogador carrega o que a tela gravou
	var jogo: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(jogo)
	await _quadros(10)
	var jogador: Node = jogo.get_node("Jogador")
	jogador.aplicar_dados_carregados(gravado)
	_verificar("o jogador carrega o save da tela: peça, roupa e cor", jogador.cabelo_atual == 5 and jogador.roupa_atual == 30 and jogador.sprite_roupa.texture == Aparencia.roupa(30, "andar")
			and jogador.sprite_cabelo.modulate.is_equal_approx(tela.PALETA[2]), "")
	jogo.queue_free()
	await _quadros(2)
	# controle: foco e teclado virtual
	tela._abrir_aba(tela.Aba.CABELO)
	tela._focar_inicio()
	await _quadros(2)
	var evento_a := InputEventJoypadButton.new()
	evento_a.button_index = JOY_BUTTON_A
	evento_a.pressed = true
	tela._ao_entrada_nome(evento_a)
	_verificar("tela: A no campo de nome (controle) abre o teclado virtual", tela._teclado.visible, "")
	tela._teclado.texto = "LEO"
	tela._teclado.fechar()
	_verificar("tela: o nome do teclado virtual vai para o campo", tela._campo_nome.text == "LEO" and tela.apelido == "LEO", tela._campo_nome.text)
	# toque: tamanho dos alvos
	var pequeno := false
	for casa in tela._casas_cabelo + tela._casas_roupa:
		var s: Vector2 = casa["botao"].custom_minimum_size
		pequeno = pequeno or s.x < 30.0 or s.y < 30.0
	for casa in tela._casas_cor:
		pequeno = pequeno or casa.custom_minimum_size.x < 30.0
	_verificar("tela: todas as casinhas têm pelo menos 30 unidades (dedo)", not pequeno and tela._botao_confirmar.custom_minimum_size.y >= 24.0, "")
	# voltar não troca de cena quando desligada (teste)
	tela.voltar()
	_verificar("tela: VOLTAR com a troca de cena desligada não faz nada (e não quebra)", not tela._saindo, "")
	# layout em três proporções
	for tamanho in [Vector2i(576, 324), Vector2i(720, 324), Vector2i(576, 432)]:
		root.size = tamanho
		await _quadros(4)
		var tela_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var dentro := true
		var detalhe := ""
		for no in [tela._botao_confirmar, tela._botao_voltar, tela._botao_aleatorio, tela._campo_nome, tela._botoes_aba[0], tela._botoes_aba[2], tela._rotulo_cabelo, tela._rotulo_roupa]:
			var r: Rect2 = no.get_global_rect()
			if not tela_rect.encloses(r.grow(-0.5)):
				dentro = false
				detalhe += " %s=%s" % [no.name, r]
		_verificar("layout %s: botões, nome, abas e rótulos dentro da tela" % tamanho, dentro, "tela=%s%s" % [tela_rect, detalhe])
		var casas_visiveis := 0
		for c in tela._casas_roupa:
			if tela_rect.intersects(c["botao"].get_global_rect()):
				casas_visiveis += 1
		_verificar("layout %s: a lista de roupas aparece (ao menos 12 casinhas à vista)" % tamanho, casas_visiveis >= 12, str(casas_visiveis))
	# confirmar de verdade (com a troca de cena ligada) entra na arena
	tela.trocar_cena = true
	tela._botao_confirmar.pressed.emit()
	await create_timer(1.6).timeout
	_verificar("tela: CONFIRMAR entra no jogo (cena da arena)", current_scene != null and current_scene.scene_file_path == "res://cenas/cenario.tscn", str(current_scene))
