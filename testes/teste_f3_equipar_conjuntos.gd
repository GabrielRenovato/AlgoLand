extends SceneTree

## Arena e inventário somente na cópia isolada do projeto.
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Teste requer a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	# Trocar os três conjuntos seguidos guarda 12 peças na mochila; o kit agora ocupa 3 casas com as ferramentas da fazenda
	inv.definir_linhas_extras(1)
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 4:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador := arena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.definir_aparencia(1, 2)
	inv.equipar(inv.buscar_por_tipo("espada_basica"))
	var visual := jogador.get_node("HeroiRaven")
	var painel := root.get_node("PainelDebug")
	var arma = inv.equipados["arma"]
	# Usa os callbacks que o dropdown oferece, não apenas o método interno.
	for i in 3:
		painel._opcoes["CONJUNTOS"][i][1].call()
		visual._process(0.0)
		var id: String = ["cavalheiro", "cavaleiro_rubro", "carrasco"][i]
		var completo := true
		for slot in ["cabeca", "corpo", "luvas", "botas"]:
			var item: Dados = inv.equipados[slot]
			var conjunto := Conjuntos.de_tipo(item.tipo) if item != null else null
			completo = completo and conjunto != null and conjunto.ID == id and item.categoria == slot
			_verificar(id + "/" + slot + ": nome e ícone de item real", item != null and not item.nome().is_empty() and Icones.obter(item, self) != null)
		_verificar(id + ": dropdown equipa os quatro slots reais", completo and jogador.pecas_cavaleiro == 15 and inv.equipados["arma"] == arma)
		_verificar(id + ": visual vem dos slots sem prévia sobreposta", jogador.raizes_armadura.size() == 4 and Aparencia.raiz_armadura_visual(jogador.roupa_atual).is_empty())
		if id == "cavalheiro":
			_verificar("cartola equipada mantém o cabelo composto", not visual._camadas[6].texture.atlas.resource_path.ends_with("vazio.png") and visual._camadas[9].texture.atlas.resource_path.ends_with("cavalheiro/raven_elmo.png") and visual._camadas[9].z_index>visual._camadas[6].z_index)
			_verificar("Mordomo comum congela sem multiplicador de status", jogador.estatisticas.bonus_defesa_conjunto == 0 and Conjuntos.de_tipo("elmo_cavalheiro").RARIDADE == "comum" and Conjuntos.de_tipo("elmo_cavalheiro").TIPO_BONUS == "congelamento" and Conjuntos.de_tipo("elmo_cavalheiro").chance_drop(99, true, true) == 0.1)
		if id == "cavaleiro_rubro":
			_verificar("Rubro ativa os 10% pelas quatro peças reais", jogador.estatisticas.bonus_defesa_conjunto == 0.1 and jogador.estatisticas.bonus_vitalidade_conjunto == 0.1)
		var anteriores: Dictionary = inv.equipados.duplicate()
		var mochila: Array = inv.mochila.duplicate()
		inv.equipados["corpo"].nivel = 3
		painel._opcoes["CONJUNTOS"][i][1].call()
		_verificar(id + ": repetir preserva instâncias, nível e mochila", inv.equipados == anteriores and inv.mochila == mochila and inv.equipados["corpo"].nivel == 3)
	# Todos os itens antigos permanecem disponíveis após trocar de conjunto.
	for conjunto in Conjuntos.CONJUNTOS:
		for tipo in conjunto.TIPOS:
			_verificar(tipo + ": peça não perdida nas trocas", inv.buscar_por_tipo(tipo) != null)
	painel._alternar_armadura("traje_cavalheiro")
	painel._equipar_conjunto("cavalheiro")
	_verificar("equipar retira prévia cosmética e conserva a roupa base", jogador.roupa_atual == 2 and jogador.raizes_armadura["elmo"].ends_with("cavalheiro/"))
	inv.remover_da_mochila(inv.buscar_por_tipo("lanca_basica"))
	_verificar("retirada da cartola tem espaço reservado na mochila", inv.desequipar("cabeca"))
	visual._process(0.0)
	_verificar("retirar cartola pelo inventário remove o visual e restaura cabelo", jogador.pecas_cavaleiro == 14 and not visual._camadas[6].texture.atlas.resource_path.ends_with("vazio.png") and visual._camadas[9].texture.atlas.resource_path.ends_with("vazio.png"))
	painel._equipar_conjunto("cavalheiro")
	for acao in ["arco","ferido","picareta"]:
		visual._aplicar_aparencia(acao)
		_verificar("ação Raven conserva cartola e cabelo pelos slots: "+acao, visual._camadas[9].texture.atlas.resource_path.ends_with("cavalheiro/raven_elmo.png") and not visual._camadas[6].texture.atlas.resource_path.ends_with("vazio.png"))
	inv.salvar("user://teste_f3_conjuntos.json")
	var copia = load("res://codigo/modelos/modelo_inventario.gd").new()
	copia.carregar("user://teste_f3_conjuntos.json")
	_verificar("save mantém as quatro peças nos slots", Conjuntos.de_tipo("elmo_cavalheiro").mascara(copia.equipados) == 15 and copia.equipados["corpo"].nivel == 3)
	copia.free()
	# Mistura peças reais sem perder o roteamento visual nem somar bônus de sets diferentes.
	_verificar("equipa peitoral Rubro independente",inv.equipar(inv.buscar_por_tipo("peitoral_cavaleiro_rubro")))
	_verificar("equipa luvas Carrasco independentes",inv.equipar(inv.buscar_por_tipo("luvas_carrasco")))
	_verificar("mistura não ativa bônus completo do Rubro",jogador.estatisticas.bonus_defesa_conjunto==0.0 and Conjuntos.de_tipo("elmo_cavalheiro").quantidade(inv.equipados)==2)
	var vp := SubViewport.new()
	vp.size=Vector2i(320,320)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo := ColorRect.new()
	fundo.size=vp.size
	fundo.color=Color("34414b")
	fundo.z_index=-100
	vp.add_child(fundo)
	for d in 4:
		visual._direcao=d
		for a in 4:
			visual._aplicar_aparencia(["correr","espada","arco","picareta"][a])
			visual.frame=d*4+2
			for camada in visual._camadas: camada.frame=visual.frame
			for i in 4:
				_verificar("peça mista mantém a origem em ação/direção",visual._camadas[9+i].texture.atlas.resource_path.contains("/"+["cavalheiro","cavaleiro_rubro","carrasco","cavalheiro"][i]+"/raven_"))
			var previa: Sprite2D=visual.criar_rastro()
			previa.position=Vector2(d*80+40,a*80+56)
			vp.add_child(previa)
	if DisplayServer.get_name()!="headless":
		var saida := ProjectSettings.globalize_path("res://arte/previas/armaduras_raven")
		DirAccess.make_dir_recursive_absolute(saida)
		for quadro in 2: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(saida+"/misto.png")
	vp.free()
	# Mochila cheia com peças do conjunto disponíveis ainda permite troca simples.
	while inv.tem_espaco():
		inv.adicionar(Dados.new())
	painel._equipar_conjunto("carrasco")
	_verificar("mochila cheia permite trocar por peças que já estão nela", Conjuntos.de_tipo("elmo_carrasco").mascara(inv.equipados) == 15)
	var novos := {}
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		var novo := Dados.new()
		novo.categoria = slot
		novo.tipo = inv.equipados[slot].tipo
		novos[slot] = novo
	var antes: Dictionary = inv.equipados.duplicate()
	var bag: Array = inv.mochila.duplicate()
	_verificar("sem espaço para peças anteriores recusa a troca inteira", not inv.equipar_conjunto_armadura(novos) and inv.equipados == antes and inv.mochila == bag)
	print("Falhas: ", _falhas)
	quit(_falhas)
