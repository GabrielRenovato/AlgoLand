extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_personagem.gd
# Cabelos e roupas do personagem (codigo/dados/aparencia.gd) e a tela de criação de personagem (cenas/criacao_personagem.tscn):
#  - a lista e as texturas de CADA peça em CADA página de animação (andar, fazenda, forja, sentado, golpes, reação, arco);
#  - os índices antigos continuam apontando para as mesmas peças (os saves valem);
#  - o jogador veste a peça nova em todas as animações e carrega o save sem quebrar;
#  - a tela de criação: abas, escolha, cor, sorteio, confirmar grava o save, voltar, teclado/controle, e o layout cabe em 576x324, 720x324 e 4:3.
# ATENCAO: carrega a cena de jogo (pode regravar user://inventario.json); faça backup do user:// antes.

const Aparencia := preload("res://codigo/dados/aparencia.gd")
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
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
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
	for id in Node.get_orphan_node_ids():
		var orfao = instance_from_id(id)
		if is_instance_valid(orfao) and orfao is Node: orfao.free()
	quit.call_deferred(1 if _falhas > 0 else 0)

# --- A lista ---------------------------------------------------------------------------------------------------

func _testar_lista() -> void:
	_verificar("sete cabelos (2 antigos + 5 novos)", Aparencia.total_cabelos() == 7, str(Aparencia.total_cabelos()))
	_verificar("46 entradas preservadas (12 bases, 30 migradas e 4 prévias)", Aparencia.total_roupas() == 46, str(Aparencia.total_roupas()))
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
	# Os trinta pacotes incompletos conservam o id do save, mas usam uma
	# roupa completa em todas as poses para não trocar de modelo ao atacar.
	var migracoes := true
	for i in range(12, 42):
		var substituta: int = Aparencia.roupas()[i]["combate"]
		migracoes = migracoes and not Aparencia.roupa_completa(i) and Aparencia.indice_roupa(i) == substituta
		for pagina in paginas:
			migracoes = migracoes and Aparencia.roupa(i, pagina) == Aparencia.roupa(substituta, pagina)
	_verificar("pacotes incompletos migram para a mesma roupa em todas as poses", migracoes, "")
	var cabelo_em_combate := true
	for pagina in Aparencia.PAGINAS_COMBATE:
		for i in range(2, Aparencia.total_cabelos()):
			var t := Aparencia.cabelo(i, pagina)
			cabelo_em_combate = cabelo_em_combate and t != null and t.resource_path.begins_with(Aparencia.PASTA_NOVAS + "cabelos/") and t.resource_path.ends_with("_%s.png" % pagina)
	_verificar("cabelos novos mantêm suas folhas próprias de combate", cabelo_em_combate, "")
	var previas := true
	for i in range(42, 46):
		var id: String = Aparencia.roupas()[i]["id"]
		previas = previas and Aparencia.roupa_completa(i) and id in ["armadura_teste", "armadura_cavaleiro", "armadura_cavaleiro_rubro", "traje_cavalheiro"]
	_verificar("prévias completas continuam acrescentadas após os índices legados", previas, "")

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
	_verificar("andar: o cabelo e a roupa novos", jogador.sprite_cabelo.texture == Aparencia.cabelo_refinado(5, "andar") and jogador.sprite_roupa.texture == Aparencia.roupa_refinada(20, "andar"), "")
	_verificar("golpe de espada e de lança: o cabelo novo (sintetizado) e a roupa substituta", jogador.cabelo_ataque.texture == Aparencia.cabelo_refinado(5, "espada") and jogador.roupa_ataque.texture == Aparencia.roupa_refinada(20, "espada")
			and jogador.cabelo_lanca_ataque.texture == Aparencia.cabelo_refinado(5, "lanca") and jogador.roupa_lanca_ataque.texture == Aparencia.roupa_refinada(20, "lanca"), "")
	_verificar("forja: a página 4 do cabelo e da roupa novos", jogador.sprite_cabelo_forja.texture == Aparencia.cabelo_refinado(5, "forja") and jogador.sprite_roupa_forja.texture == Aparencia.roupa_refinada(20, "forja"), "")
	jogador.no_fazenda._sincronizar_aparencia()
	jogador.no_reacao._familia = "lanca"
	jogador.no_reacao._sincronizar_aparencia()
	jogador.no_arco._pagina = 3
	jogador.no_arco._sincronizar_aparencia()
	_verificar("fazenda, reação (lança) e arco (p3) leem o índice do jogador", jogador.no_fazenda._roupa.texture == Aparencia.roupa_refinada(20, "fazenda") and jogador.no_fazenda._cabelo.texture == Aparencia.cabelo_refinado(5, "fazenda")
			and jogador.no_reacao._roupa.texture == Aparencia.roupa_refinada(20, "reacao_lanca") and jogador.no_arco._cabelo.texture == Aparencia.cabelo_refinado(5, "arco_p3"), "")
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
			and jogador.sprite_roupa.texture == Aparencia.roupa_refinada(11, "andar") and jogador.sprite_cabelo.modulate == Color(1, 0, 0, 1), "")
	jogador.aplicar_dados_carregados({"cabelo_atual": 6, "roupa_atual": 41})
	_verificar("save com pacote incompleto conserva cabelo e migra a roupa 41", jogador.cabelo_atual == 6 and jogador.roupa_atual == Aparencia.roupas()[41]["combate"] and jogador.sprite_roupa.texture == Aparencia.roupa_refinada(41, "andar"), "")
	jogador.aplicar_dados_carregados({"cabelo_atual": 99, "roupa_atual": 999})
	_verificar("um índice que não existe mais cai na primeira peça, sem quebrar", jogador.cabelo_atual == 0 and jogador.roupa_atual == 0 and jogador.sprite_roupa.texture != null, "")
	# sentado
	jogador.definir_aparencia(3, 25)
	jogador.sentar(jogador.global_position, 1, 5)
	_verificar("sentado: a roupa e o cabelo novos na página 4", jogador.sprite_roupa_forja.texture == Aparencia.roupa_refinada(25, "sentado") and jogador.sprite_cabelo_forja.texture == Aparencia.cabelo_refinado(3, "sentado"), "")
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
	# O catálogo Mana Seed acima continua validando saves/NPCs; a tela agora é Raven.
	var raven := preload("res://codigo/dados/aparencia_raven.gd")
	var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
	tela.trocar_cena = false
	tela.caminho_save = CAMINHO_SAVE_TESTE
	root.add_child(tela)
	current_scene = tela
	await _quadros(8)
	_verificar("tela Raven: 28 cabelos e opção sem cabelo, nove opções de roupa", tela._casas_cabelo.size() == 29 and tela._casas_roupa.size() == 9)
	_verificar("tela Raven: começa no corpo base sem cabelo", tela.cabelo == 0 and tela.roupa == 0)
	tela._casas_cabelo[28].botao.pressed.emit()
	tela._casas_roupa[8].botao.pressed.emit()
	tela._botoes_pele[2].pressed.emit()
	_verificar("tela Raven: prévia usa as camadas escolhidas", tela._previa_cabelo.texture == raven.cabelo(28,"andar") and tela._previa_roupa.texture == raven.roupa_refinada(8,"andar") and tela._previa_corpo.texture == raven.corpo("andar",2))
	tela._abrir_aba(1)
	_tecla_aba("ferramenta_proxima")
	await _quadros(2)
	_verificar("tela Raven: Q/E e LB/RB trocam abas", tela.aba == tela.Aba.COR)
	tela._casas_cor[10].pressed.emit()
	_verificar("tela Raven: tinta aplicada ao cabelo", tela._previa_cabelo.modulate == tela.PALETA[10])
	tela._ao_nome_alterado("ana")
	tela.confirmar()
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_SAVE_TESTE))
	_verificar("tela Raven: salva opções separadas dos IDs antigos", dados.apelido == "ANA" and dados.aparencia_raven.cabelo == 28 and dados.aparencia_raven.roupa == 8 and dados.aparencia_raven.pele == 2 and dados.cabelo_atual == 0 and dados.roupa_atual == 2)
	for i in 12:
		tela.sortear()
		_verificar("tela Raven: sorteio válido", tela.cabelo >= 0 and tela.cabelo <= 28 and tela.roupa >= 0 and tela.roupa <= 8 and tela.pele >= 0 and tela.pele <= 2)
	tela.queue_free()
	await _quadros(3)
