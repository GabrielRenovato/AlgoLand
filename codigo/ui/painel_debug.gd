extends CanvasLayer

## Painel de testes (só em build de debug, ou seja, rodando pelo editor): F3 abre/fecha.
## Troca a estação e o clima na hora e solta raios, para conferir os visuais sem jogar várias ondas.
## Os botões não pegam foco do teclado/controle, então o jogador continua andando com o painel aberto.
## Obs.: o início de cada onda sorteia o clima de novo, por cima do que foi escolhido aqui. Os botões de estação
## só mexem no visual na hora (o calendário não muda); PASSAR DIA avança o calendário de verdade (como dormir).

const Aparencia := preload("res://codigo/dados/aparencia.gd")
const TEMA := preload("res://recursos/ui/tema_menu.tres")
const Raridades := preload("res://codigo/dados/raridades.gd")
const CAMADA := 90
const ESTACOES := ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
# Mesma ordem do enum Estado de codigo/cenario/clima.gd
const CLIMAS := ["LIMPO", "NUBLADO", "CHUVA LEVE", "CHUVA FORTE", "TEMPESTADE", "NEVE LEVE", "NEVE FORTE"]
const AVISO_RAIO_TESTE := 1.0
const EquipamentoDropRoteiro := "res://codigo/logica/equipamento_drop.gd"
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
var _area: OptionButton
var _categoria: OptionButton
var _acao: OptionButton
var _opcoes: Dictionary = {}
var _acoes_atuais: Array = []
var _selecoes: Dictionary = {}
const AREAS := {
	"FAZENDA E VILA": ["OBRA DO OSVALDO", "GALINHEIRO", "FAZENDA E ITENS", "VISUAL DA FAZENDA"],
	"COMBATE": ["ANDARES", "MINOTAURO", "MEDUSA", "GOBLIN", "DRAGAO", "ARMAS RAVEN", "DROPS"],
	"PERSONAGEM": ["PERSONAGEM", "CONJUNTOS", "ANIMACOES"],
	"MUNDO": ["HORARIO", "CALENDARIO", "CLIMA", "ESTACAO", "TEMPESTADE"],
}
var _categorias_salvas: Dictionary = {}
var _aviso: Label
var _executando := false
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
	_painel.minimum_size_changed.connect(_ajustar_altura.call_deferred)

# A estação troca com fade e a onda pode sortear outro clima: o rótulo acompanha enquanto o painel está aberto
func _process(_delta: float) -> void:
	if _painel != null and _painel.visible:
		_atualizar_estado()

func _unhandled_key_input(evento: InputEvent) -> void:
	if Controle.digitando: return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F3:
		_painel.visible = not _painel.visible
		if _painel.visible:
			_ajustar_altura()
		get_viewport().set_input_as_handled()

func _montar() -> void:
	_painel = PanelContainer.new()
	_painel.theme = TEMA
	_painel.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(false,12))
	_painel.position = Vector2(4, 70)
	add_child(_painel)
	var geral := VBoxContainer.new()
	geral.add_theme_constant_override("separation", 4)
	_painel.add_child(geral)

	var cabecalho := HBoxContainer.new()
	geral.add_child(cabecalho)
	var titulo := _rotulo("TESTES  ·  F3")
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	cabecalho.add_child(_botao("FECHAR", func(): _painel.hide()))
	_rotulo_estado = _rotulo("")
	_rotulo_estado.modulate = Color(1, 0.85, 0.4)
	_rotulo_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_estado.custom_minimum_size.x = 180
	geral.add_child(_rotulo_estado)

	# Áreas curtas separam ferramentas sem esconder ações existentes.
	_opcoes = {
		"OBRA DO OSVALDO": [["INICIAR / VISITAR OBRA", _iniciar_obra_debug],
			["PROXIMA ETAPA", _avancar_etapa_obra_debug],
			["17H: FIM DO EXPEDIENTE", _horario_obra_debug.bind(17.0)],
			["22H: DORMIR EM CASA", _dormir_osvaldo_debug],
			["8H: RETOMAR TRABALHO", _horario_obra_debug.bind(8.0)],
			["CONCLUIR PRAZO DA OBRA", _concluir_obra_debug],
			["VISITAR OFICINA", _familia_carpinteiro_debug]],
		"GALINHEIRO": [["NIVEL 1 + 3 AVES", _preparar_galinheiro_debug.bind(1)],
			["NIVEL 2 + 6 AVES", _preparar_galinheiro_debug.bind(2)],
			["NIVEL 3 + 9 AVES", _preparar_galinheiro_debug.bind(3)],
			["IR PARA O QUINTAL", _visitar_galinheiro_debug.bind(false)],
			["ENTRAR NO GALINHEIRO", _visitar_galinheiro_debug.bind(true)],
			["ABRIR / FECHAR PORTINHA", _portinha_galinheiro_debug],
			["MANHA: SAIDA DAS AVES", _rotina_galinheiro_debug.bind(8.0,0)],
			["NOITE: VOLTAR AO ABRIGO", _rotina_galinheiro_debug.bind(18.0,0)],
			["CHUVA: VOLTAR AO ABRIGO", _rotina_galinheiro_debug.bind(12.0,2)],
			["OVOS NOS NINHOS", _ovos_galinheiro_debug],
			["FENO NA MOCHILA", _feno_galinheiro_debug],
			["VISITAR OSVALDO E FAMILIA", _familia_carpinteiro_debug]],
		"VISUAL DA FAZENDA": [["ORIGINAL / TINY RPG", _alternar_fazenda_tiny]],
		"PERSONAGEM": [["RAVEN: REAPLICAR VISUAL", _reaplicar_personagem]],
		"ARMAS RAVEN": [["RECEBER TODAS (MOCHILA)", _receber_armas_raven],
			["ALJAVA", _receber_armas_raven.bind("aljava_basica")]],
		"CONJUNTOS": [
			["MORDOMO (EQUIPAR)", _equipar_conjunto.bind("cavalheiro")],
			["CAVALEIRO RUBRO (EQUIPAR)", _equipar_conjunto.bind("cavaleiro_rubro")],
			["CARRASCO (EQUIPAR)", _equipar_conjunto.bind("carrasco")],
			["PEITORAL + BOTAS (TESTE)", _ao_armadura_teste],
			["RESTAURAR ROUPA", _restaurar_roupa],
		],
		"ANDARES": [["PROXIMO ANDAR", _ao_proximo_andar], ["IR DIRETO AO CHEFE", _ao_chefe_andar],
			["AVANCAR 1", _ao_avancar_onda.bind(1)], ["AVANCAR 10", _ao_avancar_onda.bind(10)]],
		"MINOTAURO": [["IR PARA ANDAR DO MINOTAURO", _ao_onda_minotauro],
			["INVESTIDA", _ao_ataque_minotauro.bind("investida")],
			["PISAO", _ao_ataque_minotauro.bind("pisao")],
			["VARRIDA DO MACHADO", _ao_ataque_minotauro.bind("machado")],
			["ESPECIAL: FURIA", _ao_ataque_minotauro.bind("furia")]],
		"MEDUSA": [["IR PARA ANDAR DA MEDUSA", _ao_onda_medusa],
			["GARRAS", _ao_ataque_medusa.bind("garras")], ["VARRIDA DE CAUDA", _ao_ataque_medusa.bind("cauda")],
			["BOTE", _ao_ataque_medusa.bind("bote")],
			["ESPECIAL FATAL: RUINA", _ao_ataque_medusa.bind("ruina")]],
		"GOBLIN": [["IR PARA ANDAR DO GOBLIN", _ao_onda_goblin],
			["PORRETADA", _ao_ataque_goblin.bind("porretada")], ["VARRIDA", _ao_ataque_goblin.bind("varrida")],
			["SALTO ESMAGADOR", _ao_ataque_goblin.bind("salto")], ["ESPECIAL: FURIA", _ao_ataque_goblin.bind("furia")],
			["HIT KILL: EXECUCAO", _ao_ataque_goblin.bind("execucao")]],
		"DRAGAO": [["IR PARA ANDAR DO DRAGAO", _ao_onda_dragao],
			["SOPRO DE FOGO", _ao_ataque_dragao.bind("sopro")],
			["VARRIDA DE CAUDA", _ao_ataque_dragao.bind("cauda")],
			["BATIDA DE ASAS", _ao_ataque_dragao.bind("asas")],
			["PATADA + SOPRO", _ao_ataque_dragao.bind("patada")],
			["ESPECIAL: CHUVA DE FOGO", _ao_ataque_dragao.bind("chuva")]],
		"CLIMA": [],
		"ESTACAO": [],
		"HORARIO": [["AVANCAR 1 HORA", _ao_avancar_hora.bind(1.0)],
			["AVANCAR 3 HORAS", _ao_avancar_hora.bind(3.0)]],
		"CALENDARIO": [["PASSAR DIA", _ao_passar_dia]],
		"TEMPESTADE": [["RAIO AGORA", _ao_raio]],
		"DROPS": [["CARRASCO (4 PECAS)", _ao_drop_carrasco], ["CAVALEIRO RUBRO (4 PECAS)", _ao_drop_conjunto.bind("cavaleiro_rubro")]],
		"ANIMACOES": [],
		"FAZENDA E ITENS": [["+100 OURO", _ao_ouro], ["+5 MOEDAS DE FORJA", _ao_moedas_forja], ["SEMENTES", _ao_sementes],
			["COLHEITA", _ao_colheita], ["POCOES", _ao_pocoes],
			["CRESCER 1 DIA", _ao_crescer], ["REGAR TUDO", _ao_regar_tudo]],
	}
	for tipo in preload("res://codigo/ui/icones_itens.gd").ARMAS_RAVEN:
		_opcoes["ARMAS RAVEN"].append([preload("res://codigo/modelos/dados_item.gd").NOMES[tipo], _receber_armas_raven.bind(tipo)])
	for i in CLIMAS.size():
		_opcoes["CLIMA"].append([CLIMAS[i], _ao_clima.bind(i)])
	for i in ESTACOES.size():
		_opcoes["ESTACAO"].append([ESTACOES[i], _ao_estacao.bind(i)])
	for raridade in Raridades.ORDEM:
		_opcoes["DROPS"].append([Raridades.nome(raridade), _ao_dropar_raridade.bind([raridade])])
	_opcoes["DROPS"].append(["TODAS AS RARIDADES", _ao_dropar_raridade.bind(Raridades.ORDEM)])
	for par in ACOES_FAZENDA:
		_opcoes["ANIMACOES"].append([par[0], _ao_acao_fazenda.bind(par[1])])
	_area = _seletor()
	for nome in AREAS:
		_area.add_item(nome)
	_area.item_selected.connect(_selecionar_area)
	_adicionar_campo(geral, "AREA", _area)
	_categoria = _seletor()
	_categoria.item_selected.connect(_selecionar_categoria)
	_adicionar_campo(geral, "ASSUNTO", _categoria)
	_acao = _seletor()
	_acao.item_selected.connect(_selecionar_acao)
	_adicionar_campo(geral, "ACAO", _acao)
	geral.add_child(_botao("EXECUTAR", _executar_selecao))
	_aviso = _rotulo("Escolha uma acao e clique em EXECUTAR.")
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	geral.add_child(_aviso)
	_selecionar_area(0)
	_ajustar_altura.call_deferred()

func _adicionar_campo(geral: VBoxContainer, nome: String, seletor: OptionButton) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	var rotulo := _rotulo(nome)
	rotulo.custom_minimum_size.x = 52
	linha.add_child(rotulo)
	seletor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(seletor)
	geral.add_child(linha)

func _selecionar_area(indice: int) -> void:
	var nome := _area.get_item_text(indice)
	_categoria.clear()
	for categoria in AREAS[nome]:
		_categoria.add_item(categoria)
	_categoria.select(int(_categorias_salvas.get(nome, 0)))
	_selecionar_categoria(_categoria.selected)

func _seletor() -> OptionButton:
	var seletor := OptionButton.new()
	seletor.focus_mode = Control.FOCUS_NONE
	seletor.add_theme_font_size_override("font_size", 10)
	seletor.get_popup().add_theme_font_size_override("font_size", 10)
	seletor.fit_to_longest_item = false
	seletor.custom_minimum_size.x = 0
	seletor.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return seletor

func _selecionar_categoria(indice: int) -> void:
	var nome := _categoria.get_item_text(indice)
	_categorias_salvas[_area.get_item_text(_area.selected)] = indice
	_acoes_atuais = _opcoes[nome]
	_acao.clear()
	for par in _acoes_atuais:
		_acao.add_item(par[0])
	_acao.select(int(_selecoes.get(nome, 0)))
	_selecionar_acao(_acao.selected)

func _selecionar_acao(indice: int) -> void:
	var categoria := _categoria.get_item_text(_categoria.selected)
	_selecoes[categoria] = indice
	_acao.tooltip_text = _acao.get_item_text(indice)
	if _aviso != null:
		_aviso.text = "Obra com materiais gratis; no nivel maximo, testa uma reforma." if categoria == "OBRA DO OSVALDO" and indice == 0 else "Altera a partida de teste atual."
	_ajustar_altura.call_deferred()

func _executar_selecao() -> void:
	if _executando or Transicao.ocupada: return
	if _acao.selected >= 0 and _acao.selected < _acoes_atuais.size():
		_executando = true
		var acao: Callable = _acoes_atuais[_acao.selected][1]
		await acao.call()
		_executando = false
		_atualizar_estado()

## O painel compacto fica na tela sem ScrollContainer.
func _ajustar_altura() -> void:
	if _painel == null:
		return
	var tela := get_viewport().get_visible_rect().size
	var largura := minf(310.0, tela.x - 12.0)
	_painel.custom_minimum_size.x = largura
	_rotulo_estado.custom_minimum_size.x = 0
	_painel.size = Vector2(largura, 0)
	var minimo := _painel.get_combined_minimum_size()
	_painel.position.y = clampf(70.0, MARGEM_BAIXO, maxf(MARGEM_BAIXO, tela.y - minimo.y - MARGEM_BAIXO))
	_painel.size = Vector2(largura, minimo.y)

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

## Usa o relógio do mapa para atualizar também a luz e os sistemas que acompanham o horário.
func _ao_avancar_hora(quantidade: float) -> void:
	var iluminacao := get_tree().get_first_node_in_group("iluminacao")
	if iluminacao == null:
		return
	iluminacao.definir_hora(iluminacao.hora + quantidade)
	iluminacao._aplicar()

func _ao_proximo_andar() -> void:
	var gerente := get_tree().get_first_node_in_group("gerenciador_ondas")
	var cena := get_tree().current_scene
	if gerente == null or cena == null or not cena.get_meta("andar_fenda",false) or Transicao.ocupada:
		return
	gerente.avancar_onda_debug(1)

func _ao_chefe_andar() -> void:
	var gerente := get_tree().get_first_node_in_group("gerenciador_andar")
	if gerente != null and not Transicao.ocupada:
		gerente.ir_ao_guardiao_debug()

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

func _ao_onda_medusa() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		var primeira: int = maxi(1, gerenciador.intervalo_chefe) * 2
		var periodo: int = maxi(1, gerenciador.intervalo_chefe) * gerenciador.CHEFES.size()
		var destino: int = primeira if gerenciador.onda_atual < primeira else primeira + (int((gerenciador.onda_atual - primeira) / periodo) + 1) * periodo
		gerenciador.avancar_onda_debug(destino - gerenciador.onda_atual)

func _ao_ataque_medusa(tipo: String) -> void:
	var chefe := get_tree().get_first_node_in_group("boss_medusa")
	if chefe != null:
		chefe.forcar_ataque_debug(tipo)

func _ao_onda_goblin() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		var primeira: int = maxi(1, gerenciador.intervalo_chefe) * 3
		var periodo: int = maxi(1, gerenciador.intervalo_chefe) * gerenciador.CHEFES.size()
		var destino: int = primeira if gerenciador.onda_atual < primeira else primeira + (int((gerenciador.onda_atual - primeira) / periodo) + 1) * periodo
		gerenciador.avancar_onda_debug(destino - gerenciador.onda_atual)

func _ao_ataque_goblin(tipo: String) -> void:
	var chefe := get_tree().get_first_node_in_group("boss_goblin_maromba")
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

func _ao_moedas_forja() -> void:
	InventarioJogador.adicionar_moedas_forja(5)
	InventarioJogador.salvar()
	get_tree().call_group("hud", "avisar_moeda_forja")

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
	var conjuntos := load("res://codigo/dados/conjuntos_armadura.gd")
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
	var aparencia := load("res://codigo/dados/aparencia.gd")
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
	var conjuntos := load("res://codigo/dados/conjuntos_armadura.gd")
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
	var aparencia := load("res://codigo/dados/aparencia.gd")
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
	var aparencia := load("res://codigo/dados/aparencia.gd")
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
	_rotulo_estado.text = "%s · %s\n%s" % [texto_estacao, texto_clima, Calendario.texto_data()]
	var cena := get_tree().current_scene
	var comparacao := cena.get_node_or_null("ComparacaoTiny") if cena != null else null
	if comparacao != null:
		_rotulo_estado.text += " / FAZENDA: " + ("TINY RPG" if comparacao.ativo else "ORIGINAL")
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		_rotulo_estado.text += " / ANDAR %d" % gerenciador.onda_atual

## Reaplica a base refinada sem alterar a aparência salva ou os equipamentos.
## Protótipo: liga/desliga o herói do Tiny RPG (codigo/jogador/heroi_tiny.gd) no jogador da cena
## Atalhos explícitos de debug: preservam as aves existentes, nomes e vínculo.
func _preparar_galinheiro_debug(nivel: int) -> void:
	if Transicao.ocupada: return
	var criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
	var antes: Dictionary = Fazenda.galinheiro.duplicate(true)
	var estado: Dictionary = Fazenda.galinheiro
	# Não descarta aves se o jogador pedir um modelo menor que o bando atual.
	estado.nivel = clampi(maxi(nivel,ceili(estado.aves.size()/4.0)),1,3)
	estado.obra = 0
	estado.pronto_dia = -1
	while estado.aves.size() < mini(nivel*3,criacao.CAPACIDADES[estado.nivel]):
		estado.aves.append(criacao.nova_ave(estado.aves.size(),"galo" if estado.aves.size() == 2 else "galinha"))
	estado.portinha_aberta = true
	if not Fazenda.salvar():
		Fazenda.galinheiro = antes
		return
	Fazenda.galinheiro_alterado.emit()
	await _visitar_galinheiro_debug(false)
	_rotina_galinheiro_debug(8.0,0)

func _visitar_galinheiro_debug(interior: bool) -> void:
	if Transicao.ocupada or Fazenda.galinheiro.nivel == 0: return
	var destino := "res://cenas/galinheiro.tscn" if interior else "res://cenas/fazenda.tscn"
	var ponto := "porta" if interior else "galinheiro"
	var cena := get_tree().current_scene
	if cena == null: return
	if cena.scene_file_path != destino:
		await Transicao.ir_para(destino,ponto)
	else:
		# Em coop, traz de volta também quem estiver num outro ambiente.
		for jogador in [Cooperativo._jogador1(),Cooperativo.jogador2()]:
			if jogador == null: continue
			if Cooperativo.com_dois() and Cooperativo.cena_de(jogador) != cena:
				Cooperativo.viajar_local(jogador,destino,ponto)
			else:
				var chegada := cena.find_child("Chegada_"+ponto,true,false) as Node2D
				if chegada != null:
					jogador.global_position = chegada.global_position+Vector2(16 if jogador.eh_p2 else -16,4)
	_painel.visible = false

func _portinha_galinheiro_debug() -> void:
	var jogador := Cooperativo._jogador1()
	if jogador != null:
		preload("res://codigo/fazenda/criacao_galinhas.gd").executar(Fazenda,jogador,"portinha")

func _rotina_galinheiro_debug(hora: float, clima: int) -> void:
	Fazenda.definir_clima_hoje(clima)
	for iluminacao in get_tree().get_nodes_in_group("iluminacao"):
		iluminacao.definir_hora(hora)
		iluminacao._aplicar()
	Transicao.hora_salva = hora

func _ovos_galinheiro_debug() -> void:
	var antes: Dictionary = Fazenda.galinheiro.duplicate(true)
	for ave in Fazenda.galinheiro.aves:
		if ave.get("sexo","galinha") == "galinha" and preload("res://codigo/fazenda/criacao_galinhas.gd").adulta(ave,Calendario.dia): ave.ovos = 7
	if not Fazenda.salvar():
		Fazenda.galinheiro = antes
		return
	Fazenda.galinheiro_alterado.emit()

func _alternar_fazenda_tiny() -> void:
	var cena := get_tree().current_scene
	var comparacao := cena.get_node_or_null("ComparacaoTiny") if cena != null else null
	if comparacao != null:
		comparacao.alternar()

func _alternar_heroi_tiny() -> void:
	_desativar_base_vila()
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	var atual := jogador.get_node_or_null("HeroiTiny")
	if atual != null:
		jogador.remove_child(atual)
		atual.free()
		return
	_remover_prototipo(jogador, "HeroiGerado")
	jogador.add_child(HeroiTiny.new())

func _remover_prototipo(jogador: Node, nome: String) -> void:
	var atual := jogador.get_node_or_null(nome)
	if atual != null:
		jogador.remove_child(atual)
		atual.free()

func _desativar_base_vila() -> void:
	get_tree().set_meta("visual_base_vila", false)
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		_remover_prototipo(jogador, "HeroiBaseVila")

func _ativar_base_vila() -> void:
	get_tree().set_meta("visual_base_vila", true)
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		for nome in ["HeroiTiny", "HeroiGerado", "HeroiCraftpix"]:
			_remover_prototipo(jogador, nome)
		jogador._instalar_base_vila()

func _ativar_heroi_gerado(correndo: bool) -> void:
	_desativar_base_vila()
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	_remover_prototipo(jogador, "HeroiTiny")
	var visual := jogador.get_node_or_null("HeroiGerado")
	if visual == null:
		visual = preload("res://codigo/jogador/heroi_gerado.gd").new()
		visual.name = "HeroiGerado"
		visual.correndo = correndo
		jogador.add_child(visual)
	else:
		visual.correndo = correndo
		visual._aplicar_folha()
	visual.teste_espada = false
	# O teste abre olhando para a direção que já tem as poses desenhadas.
	jogador._direcao_ataque = Vector2.RIGHT
	jogador.virar_para(Vector2.RIGHT)
	visual._process(0.0)

func _ativar_heroi_craftpix() -> void:
	_desativar_base_vila()
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador == null:
		return
	_remover_prototipo(jogador, "HeroiTiny")
	_remover_prototipo(jogador, "HeroiGerado")
	if not jogador.has_node("HeroiCraftpix"):
		jogador.add_child(preload("res://codigo/jogador/heroi_craftpix.gd").new())
	jogador.get_node("HeroiCraftpix")._process(0.0)

func _ativar_espada_gerada() -> void:
	_ativar_heroi_gerado(true)
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador != null and jogador.has_node("HeroiGerado"):
		jogador.get_node("HeroiGerado").teste_espada = true

func _reaplicar_personagem() -> void:
	_desativar_base_vila()
	Aparencia._cache_cavaleiro.clear()
	var cena := get_tree().current_scene
	var jogador := cena.get_node_or_null("Jogador") if cena != null else null
	if jogador != null:
		_remover_prototipo(jogador, "HeroiTiny")
		_remover_prototipo(jogador, "HeroiGerado")
		_remover_prototipo(jogador, "HeroiCraftpix")
		jogador._aplicar_aparencia()
		if jogador.usando_espada:
			jogador.atualizar_texturas_espada()
		if jogador.usando_lanca:
			jogador.atualizar_texturas_lanca()
		if jogador.usando_escudo and not jogador.usando_arco:
			jogador.atualizar_texturas_escudo()
		jogador.definir_sprites_visiveis(false)

func _feno_galinheiro_debug() -> void:
	InventarioJogador.adicionar_coletavel("produto","feno",14)
	InventarioJogador.salvar()

func _familia_carpinteiro_debug() -> void:
	if Transicao.ocupada: return
	await Transicao.ir_para("res://cenas/cidade/carpintaria.tscn","entrada")
	_rotina_galinheiro_debug(9.0,0)
	_painel.visible = false

## Usa a contratação real, concedendo apenas os materiais que faltam.
func _iniciar_obra_debug() -> void:
	var criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
	if Fazenda.galinheiro.obra == 0:
		if Fazenda.galinheiro.nivel >= 3:
			# Reforma de demonstração: mantém abrigo, aves e capacidade no nível máximo.
			var antes: Dictionary = Fazenda.galinheiro.duplicate(true)
			Fazenda.galinheiro.obra = 3
			Fazenda.galinheiro.inicio_obra = Calendario.dia
			Fazenda.galinheiro.pronto_dia = Calendario.dia + criacao.PRAZOS[3]
			if not Fazenda.salvar():
				Fazenda.galinheiro = antes
				_aviso.text = "Nao foi possivel salvar a obra de teste."
				return
			Fazenda.galinheiro_alterado.emit()
			await _ir_obra_debug()
			return
		var jogador := Cooperativo._jogador1()
		if jogador == null: return
		var nivel: int = Fazenda.galinheiro.nivel + 1
		for material in criacao.CUSTOS[nivel]:
			var falta: int = int(criacao.CUSTOS[nivel][material]) - jogador.inventario.quantidade_tipo("material:" + material)
			if falta > 0: jogador.inventario.adicionar_coletavel("material", material, falta)
		var erro: String = criacao.executar(Fazenda, jogador, "construir")
		if erro != "":
			_aviso.text = erro
			return
	await _ir_obra_debug()

func _ir_obra_debug() -> void:
	# A fundação ainda não tem nível pronto, por isso não usa o atalho das aves.
	if get_tree().current_scene.scene_file_path != "res://cenas/fazenda.tscn":
		await Transicao.ir_para("res://cenas/fazenda.tscn", "galinheiro")
	else:
		_visitar_ponto_obra_debug()
	_rotina_galinheiro_debug(9.0, 0)
	_painel.hide()

func _visitar_ponto_obra_debug() -> void:
	var jogador := Cooperativo._jogador1()
	var chegada := get_tree().current_scene.find_child("Chegada_galinheiro", true, false) as Node2D
	if jogador != null and chegada != null: jogador.global_position = chegada.global_position

func _horario_obra_debug(hora: float) -> void:
	_rotina_galinheiro_debug(hora, 0)
	_painel.hide()

func _dormir_osvaldo_debug() -> void:
	await Transicao.ir_para("res://cenas/cidade/carpintaria.tscn", "entrada")
	_horario_obra_debug(22.0)

func _avancar_etapa_obra_debug() -> void:
	var criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
	var estado: Dictionary = Fazenda.galinheiro
	if estado.obra == 0:
		_aviso.text = "Inicie uma obra primeiro."
		return
	var hora := 9.0
	var luz := get_tree().get_first_node_in_group("iluminacao")
	if luz != null: hora = luz.hora_do_mundo()
	var etapa: int = criacao.etapa_obra(estado, Calendario.dia, hora)
	if etapa >= 2:
		_aviso.text = "Acabamento pronto para testar. Use CONCLUIR PRAZO DA OBRA."
		return
	var prazo: int = estado.pronto_dia - estado.inicio_obra
	var decorrido := (float(etapa + 1) + 0.1) / 3.0 * prazo
	var dia_alvo: int = estado.inicio_obra + floori(decorrido)
	while Calendario.dia < dia_alvo: Calendario.dormir()
	_rotina_galinheiro_debug(8.0 + fposmod(decorrido, 1.0) * 9.0, 0)
	Fazenda.galinheiro_alterado.emit()
	_painel.hide()

func _concluir_obra_debug() -> void:
	if Fazenda.galinheiro.obra == 0:
		_aviso.text = "Nenhuma obra em andamento."
		return
	var pronto: int = Fazenda.galinheiro.pronto_dia
	while Calendario.dia < pronto: Calendario.dormir()
	Fazenda.galinheiro_alterado.emit()
	_horario_obra_debug(9.0)

## Entrega peças nativas para selecionar pela barra; repetir não duplica itens.
func _receber_armas_raven(tipo: String = "") -> void:
	var inventario := get_node("/root/InventarioJogador")
	var tipos: Array = [tipo] if not tipo.is_empty() else preload("res://codigo/ui/icones_itens.gd").ARMAS_RAVEN + ["aljava_basica"]
	var faltaram := 0
	for modelo in tipos:
		if inventario.buscar_por_tipo(modelo) != null:
			continue
		var item = preload("res://codigo/dados/forja_armas.gd").criar_item(modelo)
		if item == null or inventario.adicionar(item) < 0:
			faltaram += 1
	inventario.salvar()
	_aviso.text = "Armas na mochila. Selecione pela barra de itens." if faltaram == 0 else "MOCHILA CHEIA: libere espaco e tente novamente."
