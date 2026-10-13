extends CanvasLayer

## Painel de testes (só em build de debug, ou seja, rodando pelo editor): F3 abre/fecha.
## Troca a estação e o clima na hora e solta raios, para conferir os visuais sem jogar várias ondas.
## Os botões não pegam foco do teclado/controle, então o jogador continua andando com o painel aberto.
## Obs.: o início de cada onda sorteia o clima de novo, por cima do que foi escolhido aqui. Os botões de estação
## só mexem no visual na hora (o calendário não muda); PASSAR DIA avança o calendário de verdade (como dormir).

const TEMA := preload("res://recursos/ui/tema_menu.tres")
const Raridades := preload("res://Codigos/DadosLocais/raridades.gd")
const CAMADA := 90
const ESTACOES := ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
# Mesma ordem do enum Estado de Codigos/Design/clima.gd
const CLIMAS := ["LIMPO", "NUBLADO", "CHUVA LEVE", "CHUVA FORTE", "TEMPESTADE", "NEVE LEVE", "NEVE FORTE"]
const AVISO_RAIO_TESTE := 1.0
const EquipamentoDropRoteiro := "res://Codigos/Logicas/equipamento_drop.gd"
## Quanto à frente do jogador cada arma do teste cai (fora do ímã, para dar tempo de ver antes de pegar) e o espaço entre elas
const DISTANCIA_DROP_TESTE := 70.0
const ESPACO_DROP_TESTE := 34.0
# [texto do botão, ação em fazenda_jogador.gd]
const ACOES_FAZENDA := [["ENXADA", "enxada"], ["MACHADO", "machado"], ["PICARETA", "picareta"],
	["PLANTAR", "plantar"], ["REGAR", "regar"], ["COLHER", "colher"]]

## Folga em relação às bordas da tela.
const MARGEM_BAIXO := 6.0

var _painel: PanelContainer
var _rotulo_estado: Label
var _categoria: OptionButton
var _acao: OptionButton
var _opcoes: Dictionary = {}
var _acoes_atuais: Array = []
var _selecoes: Dictionary = {}
var _roupa_antes_armadura := -1
var _jogador_armadura: Node

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_painel.visible = false
	get_viewport().size_changed.connect(_ajustar_altura)

# A estação troca com fade e a onda pode sortear outro clima: o rótulo acompanha enquanto o painel está aberto
func _process(_delta: float) -> void:
	if _painel != null and _painel.visible:
		_atualizar_estado()

func _unhandled_key_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F3:
		_painel.visible = not _painel.visible
		if _painel.visible:
			_ajustar_altura()
		get_viewport().set_input_as_handled()

func _montar() -> void:
	_painel = PanelContainer.new()
	_painel.theme = TEMA
	_painel.position = Vector2(4, 70)
	add_child(_painel)
	var geral := VBoxContainer.new()
	geral.add_theme_constant_override("separation", 2)
	_painel.add_child(geral)

	geral.add_child(_rotulo("DEBUG  (F3 FECHA)"))
	_rotulo_estado = _rotulo("")
	_rotulo_estado.modulate = Color(1, 0.85, 0.4)
	_rotulo_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_estado.custom_minimum_size.x = 180
	geral.add_child(_rotulo_estado)

	# Seleção em duas etapas mantém todas as ferramentas acessíveis sem rolar o painel.
	_opcoes = {
		"CONJUNTOS": [
			["MORDOMO (EQUIPAR)", _equipar_conjunto.bind("cavalheiro")],
			["CAVALEIRO RUBRO (EQUIPAR)", _equipar_conjunto.bind("cavaleiro_rubro")],
			["CARRASCO (EQUIPAR)", _equipar_conjunto.bind("carrasco")],
			["PEITORAL + BOTAS (TESTE)", _ao_armadura_teste],
			["RESTAURAR ROUPA", _restaurar_roupa],
		],
		"ONDAS": [["AVANCAR 1", _ao_avancar_onda.bind(1)], ["AVANCAR 10", _ao_avancar_onda.bind(10)]],
		"MINOTAURO": [["IR PARA ONDA DO MINOTAURO", _ao_onda_minotauro],
			["INVESTIDA", _ao_ataque_minotauro.bind("investida")],
			["PISAO", _ao_ataque_minotauro.bind("pisao")],
			["VARRIDA DO MACHADO", _ao_ataque_minotauro.bind("machado")],
			["ESPECIAL: FURIA", _ao_ataque_minotauro.bind("furia")]],
		"DRAGAO": [["IR PARA ONDA DO DRAGAO", _ao_onda_dragao],
			["SOPRO DE FOGO", _ao_ataque_dragao.bind("sopro")],
			["VARRIDA DE CAUDA", _ao_ataque_dragao.bind("cauda")],
			["BATIDA DE ASAS", _ao_ataque_dragao.bind("asas")],
			["PATADA + SOPRO", _ao_ataque_dragao.bind("patada")],
			["ESPECIAL: CHUVA DE FOGO", _ao_ataque_dragao.bind("chuva")]],
		"CLIMA": [],
		"ESTACAO": [],
		"CALENDARIO": [["PASSAR DIA", _ao_passar_dia]],
		"TEMPESTADE": [["RAIO AGORA", _ao_raio]],
		"DROPS": [["CARRASCO (4 PECAS)", _ao_drop_carrasco], ["CAVALEIRO RUBRO (4 PECAS)", _ao_drop_conjunto.bind("cavaleiro_rubro")]],
		"ANIMACOES": [],
		"FAZENDA E ITENS": [["+100 OURO", _ao_ouro], ["SEMENTES", _ao_sementes],
			["COLHEITA", _ao_colheita], ["POCOES", _ao_pocoes],
			["CRESCER 1 DIA", _ao_crescer], ["REGAR TUDO", _ao_regar_tudo]],
	}
	for i in CLIMAS.size():
		_opcoes["CLIMA"].append([CLIMAS[i], _ao_clima.bind(i)])
	for i in ESTACOES.size():
		_opcoes["ESTACAO"].append([ESTACOES[i], _ao_estacao.bind(i)])
	for raridade in Raridades.ORDEM:
		_opcoes["DROPS"].append([Raridades.nome(raridade), _ao_dropar_raridade.bind([raridade])])
	_opcoes["DROPS"].append(["TODAS AS RARIDADES", _ao_dropar_raridade.bind(Raridades.ORDEM)])
	for par in ACOES_FAZENDA:
		_opcoes["ANIMACOES"].append([par[0], _ao_acao_fazenda.bind(par[1])])
	_categoria = _seletor()
	for nome in _opcoes:
		_categoria.add_item(nome)
	_categoria.item_selected.connect(_selecionar_categoria)
	geral.add_child(_categoria)
	_acao = _seletor()
	_acao.item_selected.connect(_selecionar_acao)
	geral.add_child(_acao)
	geral.add_child(_botao("EXECUTAR", _executar_selecao))
	_selecionar_categoria(0)
	_ajustar_altura.call_deferred()

func _seletor() -> OptionButton:
	var seletor := OptionButton.new()
	seletor.focus_mode = Control.FOCUS_NONE
	seletor.fit_to_longest_item = false
	seletor.custom_minimum_size.x = 180
	return seletor

func _selecionar_categoria(indice: int) -> void:
	var nome := _categoria.get_item_text(indice)
	_acoes_atuais = _opcoes[nome]
	_acao.clear()
	for par in _acoes_atuais:
		_acao.add_item(par[0])
	_acao.select(int(_selecoes.get(nome, 0)))

func _selecionar_acao(indice: int) -> void:
	_selecoes[_categoria.get_item_text(_categoria.selected)] = indice

func _executar_selecao() -> void:
	if _acao.selected >= 0 and _acao.selected < _acoes_atuais.size():
		var acao: Callable = _acoes_atuais[_acao.selected][1]
		acao.call()
		_atualizar_estado()

## O painel compacto fica na tela sem ScrollContainer.
func _ajustar_altura() -> void:
	if _painel == null:
		return
	var tela := get_viewport().get_visible_rect().size
	var minimo := _painel.get_combined_minimum_size()
	_painel.position.y = clampf(70.0, MARGEM_BAIXO, maxf(MARGEM_BAIXO, tela.y - minimo.y - MARGEM_BAIXO))
	_painel.size = Vector2.ZERO

func _restaurar_roupa() -> void:
	if is_instance_valid(_jogador_armadura) and _roupa_antes_armadura >= 0:
		_jogador_armadura.definir_aparencia(_jogador_armadura.cabelo_atual, _roupa_antes_armadura)
		_roupa_antes_armadura = -1

func _rotulo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	return rotulo

func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.focus_mode = Control.FOCUS_NONE
	botao.pressed.connect(acao)
	return botao

func _estacoes() -> Node:
	var cena := get_tree().current_scene
	return cena.find_child("Estacoes", true, false) if cena else null

func _clima() -> Node:
	return get_tree().get_first_node_in_group("clima")

func _ao_estacao(indice: int) -> void:
	var estacoes := _estacoes()
	if estacoes == null:
		return
	estacoes.definir_estacao(indice)

func _ao_clima(estado: int) -> void:
	var clima := _clima()
	if clima == null:
		return
	clima.definir_clima(estado)

## Solta um raio perto do jogador (ou de um inimigo), com o aviso no chão, em qualquer clima
func _ao_raio() -> void:
	var clima := _clima()
	if clima == null or clima.get("_jogador") == null:
		return
	clima.criar_raio(clima.sortear_ponto_raio(), AVISO_RAIO_TESTE)

## Avança o calendário um dia (o que dormir faz, sem cura nem fade); a estação visual acompanha se ela virar
func _ao_passar_dia() -> void:
	Calendario.dormir()

func _ao_avancar_onda(quantidade: int) -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		gerenciador.avancar_onda_debug(quantidade)

func _ao_onda_dragao() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		var intervalo: int = maxi(1, gerenciador.intervalo_chefe) * gerenciador.CHEFES.size()
		var destino: int = (int(gerenciador.onda_atual / intervalo) + 1) * intervalo
		gerenciador.avancar_onda_debug(destino - gerenciador.onda_atual)

func _ao_onda_minotauro() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		var primeira: int = maxi(1, gerenciador.intervalo_chefe)
		var periodo: int = primeira * gerenciador.CHEFES.size()
		var destino: int = primeira if gerenciador.onda_atual < primeira else primeira + (int((gerenciador.onda_atual - primeira) / periodo) + 1) * periodo
		gerenciador.avancar_onda_debug(destino - gerenciador.onda_atual)

func _ao_ataque_minotauro(tipo: String) -> void:
	var chefe := get_tree().get_first_node_in_group("boss_minotauro")
	if chefe != null:
		chefe.forcar_ataque_debug(tipo)

func _ao_ataque_dragao(tipo: String) -> void:
	var chefe := get_tree().get_first_node_in_group("boss_dragao")
	if chefe != null:
		chefe.forcar_ataque_debug(tipo)

## Solta no chão, à frente do jogador, uma arma ou escudo sorteado de cada raridade pedida (para ver o brilho, a cor e o tooltip)
func _ao_dropar_raridade(raridades: Array) -> void:
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") as Node2D if cena != null else null
	if jogador == null:
		return
	var roteiro := load(EquipamentoDropRoteiro) as GDScript
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda: int = maxi(int(gerenciador.get("onda_atual")) if gerenciador != null else 1, 1)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var primeiro := -(raridades.size() - 1) * ESPACO_DROP_TESTE * 0.5
	for i in raridades.size():
		var item = roteiro.criar_item(rng, onda, false, false, String(raridades[i]))
		var onde: Vector2 = jogador.global_position + Vector2(primeiro + i * ESPACO_DROP_TESTE, DISTANCIA_DROP_TESTE)
		roteiro.soltar_item(item, onde, cena, rng)

func _ao_ouro() -> void:
	DadosJogo.moedas += 100
	DadosJogo.atualizar_ui_moedas()

## Troca visual reversível para conferir as peças nas animações; não altera itens nem atributos.
func _ao_armadura_teste() -> void:
	_alternar_armadura("armadura_teste")

func _ao_set_cavaleiro() -> void:
	_alternar_armadura("armadura_cavaleiro")

func _equipar_conjunto(id: String) -> void:
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	var conjuntos := load("res://Codigos/DadosLocais/conjuntos_armadura.gd")
	var conjunto: GDScript = null
	for candidato in conjuntos.CONJUNTOS:
		if candidato.ID == id:
			conjunto = candidato
			break
	if conjunto == null:
		return
	var inventario := get_node("/root/InventarioJogador")
	var drop := load(EquipamentoDropRoteiro)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda: int = maxi(int(gerenciador.get("onda_atual")) if gerenciador != null else 1, 1)
	var pecas := {}
	for tipo in conjunto.TIPOS:
		var item: DadosItem = inventario.buscar_por_tipo(tipo)
		if item == null:
			item = drop.criar_item(rng, onda, false, false, conjunto.RARIDADE, tipo)
		pecas[item.categoria] = item
	if not inventario.equipar_conjunto_armadura(pecas):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("avisar_equipamento_cheio"):
			hud.avisar_equipamento_cheio()
		push_warning("MOCHILA CHEIA: libere espaço para guardar a armadura anterior.")
		return
	for item in pecas.values():
		item.raridade = conjunto.RARIDADE
	# Os slots reais determinam a aparência. Retira qualquer prévia cosmética
	# que poderia continuar mascarando mudanças feitas depois no inventário.
	var aparencia := load("res://Codigos/DadosLocais/aparencia.gd")
	if not aparencia.raiz_armadura_visual(jogador.roupa_atual).is_empty():
		var base := _roupa_antes_armadura if jogador == _jogador_armadura and _roupa_antes_armadura >= 0 else 2
		jogador.definir_aparencia(jogador.cabelo_atual, base)
		_roupa_antes_armadura = -1
	if jogador.has_method("_aplicar_modelo"):
		jogador._aplicar_modelo()
	inventario.salvar()

func _ao_drop_carrasco() -> void:
	_ao_drop_conjunto("carrasco")

func _ao_drop_conjunto(id: String) -> void:
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	var drop := load(EquipamentoDropRoteiro)
	var conjuntos := load("res://Codigos/DadosLocais/conjuntos_armadura.gd")
	var conjunto: GDScript = null
	for candidato in conjuntos.CONJUNTOS:
		if candidato.ID == id:
			conjunto = candidato
			break
	if conjunto == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda: int = maxi(int(gerenciador.get("onda_atual")) if gerenciador != null else 1, 1)
	var i := 0
	for tipo in conjunto.TIPOS:
		var item: DadosItem = drop.criar_item(rng, onda, false, false, conjunto.RARIDADE, tipo)
		drop.soltar_item(item, jogador.global_position + Vector2((i - 1.5) * ESPACO_DROP_TESTE, DISTANCIA_DROP_TESTE), cena, rng)
		i += 1

func _ao_peca_rubra(peca: String) -> void:
	_alternar_peca_visual(peca, "armadura_cavaleiro_rubro")

func _ao_peca_cavaleiro(peca: String) -> void:
	_alternar_peca_visual(peca, "armadura_cavaleiro")

func _alternar_peca_visual(peca: String, id: String) -> void:
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	var aparencia := load("res://Codigos/DadosLocais/aparencia.gd")
	var indice := -1
	for i in aparencia.roupas().size():
		if aparencia.roupas()[i]["id"] == id:
			indice = i
			break
	if indice < 0:
		return
	if jogador.roupa_atual != indice:
		_roupa_antes_armadura = jogador.roupa_atual
		_jogador_armadura = jogador
		jogador.pecas_cavaleiro = 0
		jogador.definir_aparencia(jogador.cabelo_atual, indice)
	var bit: int = aparencia.PECAS_CAVALEIRO[peca]
	jogador.definir_peca_cavaleiro(peca, (jogador.pecas_cavaleiro & bit) == 0)

func _alternar_armadura(id: String) -> void:
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	var aparencia := load("res://Codigos/DadosLocais/aparencia.gd")
	var indice := -1
	for i in aparencia.roupas().size():
		if aparencia.roupas()[i]["id"] == id:
			indice = i
			break
	if indice < 0:
		return
	if jogador.roupa_atual == indice and jogador == _jogador_armadura and _roupa_antes_armadura >= 0:
		jogador.definir_aparencia(jogador.cabelo_atual, _roupa_antes_armadura)
		_roupa_antes_armadura = -1
	else:
		if jogador != _jogador_armadura or _roupa_antes_armadura < 0:
			_roupa_antes_armadura = jogador.roupa_atual
		_jogador_armadura = jogador
		if id in aparencia.ARMADURAS_VISUAIS:
			jogador.pecas_cavaleiro = 15
		jogador.definir_aparencia(jogador.cabelo_atual, indice)

## 5 sementes de cada planta da estação atual (no inverno não há nenhuma)
func _ao_sementes() -> void:
	Fazenda.dar_sementes_debug()

## 5 de cada planta na bolsa de colheita (para testar o caldeirão)
func _ao_colheita() -> void:
	Fazenda.dar_colheita_debug()

## 3 poções de cada tipo (para testar o cinto na arena)
func _ao_pocoes() -> void:
	Fazenda.dar_pocoes_debug()

## As plantas vivas crescem 1 dia sem precisar regar nem dormir
func _ao_crescer() -> void:
	Fazenda.crescer_um_dia_debug()

func _ao_regar_tudo() -> void:
	Fazenda.regar_tudo_debug()

func _ao_acao_fazenda(acao: String) -> void:
	for no in get_tree().get_nodes_in_group("character"):
		if no is CharacterBody2D and no.has_method("acao_fazenda"):
			no.acao_fazenda(acao)
			return

func _atualizar_estado() -> void:
	var estacoes := _estacoes()
	var clima := _clima()
	var texto_estacao := "-"
	var texto_clima := "-"
	if estacoes != null:
		texto_estacao = ESTACOES[clampi(estacoes.estacao_atual, 0, ESTACOES.size() - 1)]
	if clima != null:
		texto_clima = CLIMAS[clampi(clima.clima_atual, 0, CLIMAS.size() - 1)]
	_rotulo_estado.text = "%s / %s / %s" % [texto_estacao, texto_clima, Calendario.texto_data()]
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		_rotulo_estado.text += " / ONDA %d" % gerenciador.onda_atual
