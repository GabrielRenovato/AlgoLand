extends Control

## Cinto de poções no canto de baixo à esquerda (só na arena: o HUD o cria quando a cena tem ondas).
## De baixo para cima:
##  - a casa da poção escolhida (ícone e quantidade) entre as teclas de troca (Q/E ou LB/RB) e a de beber (R ou X);
##  - os efeitos ativos (ícone da poção e os segundos que faltam);
##  - o nome da poção ao trocar/beber e o aviso de por que não bebeu (SEM POCOES, VIDA CHEIA);
##  - "+1 SEMENTE: TOMATE (RARA)" quando um saquinho de semente é recolhido (somando os da mesma planta em seguida),
##    na cor da raridade.
## O cinto some quando não há poção nem efeito ativo (quem nunca fez poção não vê uma casa vazia).

const EstiloSlot := preload("res://codigo/ui/estilo_slot.gd")
const TEMA := preload("res://recursos/ui/tema_menu.tres")
# Planes_ValMore: o Y da CraftPixNet Survival Kit (fonte do tema) parece um "y" minúsculo; letras de botão usam esta
const FONTE_TECLAS := preload("res://assets/ui/Planes_ValMore.ttf")
const Pocoes := preload("res://codigo/dados/pocoes.gd")

const LADO_CASA := 24
## No celular a casa cresce um pouco, para o dedo
const LADO_CASA_TOQUE := 30
const COR_NOME := Color(1, 0.96, 0.82)
const COR_AVISO := Color(1, 0.6, 0.5)
const COR_TECLA := Color(0.75, 0.7, 0.62)
const COR_SEMENTE := Color(0.7, 1, 0.55)
const DURACAO_NOME := 1.6
const DURACAO_AVISO := 1.8
## Saquinhos da mesma planta recolhidos dentro desta janela somam no mesmo aviso
const JANELA_SEMENTE := 2.0
## Os últimos segundos do efeito piscam
const PISCAR_ABAIXO_DE := 5.0
## Folga do canto direito no PC: a barra de energia vertical (10 px) fica ali
const MARGEM_DIREITA := 32.0

var efeitos: Node = null

var _coluna: VBoxContainer
var _aviso_semente: Label
var _aviso: Label
var _nome: Label
var _linha_efeitos: HBoxContainer
var _linha_cinto: HBoxContainer
var _tecla_anterior: Label
var _tecla_proxima: Label
var _tecla_beber: Label
var _icone: TextureRect
var _quantidade: Label
var _rotulos_efeitos: Dictionary = {}   # efeito -> {"caixa": Control, "tempo": Label}
var _tween_nome: Tween
var _tween_aviso: Tween
var _tween_semente: Tween
var _tween_equipamento: Tween
var _aviso_equipamento: Label
var _semente_atual := ""
var _semente_contagem := 0
var _semente_ate := 0.0

func _ready() -> void:
	theme = TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_montar()
	Controle.dicas_alteradas.connect(_atualizar_teclas)
	_atualizar_teclas()
	Fazenda.bolsas_alteradas.connect(_atualizar)
	if efeitos != null:
		efeitos.selecao_alterada.connect(_ao_selecao_alterada)
		efeitos.efeitos_alterados.connect(_refazer_efeitos)
		efeitos.pocao_bebida.connect(_ao_pocao_bebida)
	_refazer_efeitos()
	_atualizar()

func _process(_delta: float) -> void:
	if efeitos == null:
		return
	for efeito in _rotulos_efeitos:
		var restante: float = efeitos.restante(efeito)
		var rotulo: Label = _rotulos_efeitos[efeito]["tempo"]
		rotulo.text = str(ceili(restante))
		var caixa: Control = _rotulos_efeitos[efeito]["caixa"]
		caixa.modulate.a = (0.45 + 0.55 * absf(sin(restante * 6.0))) if restante < PISCAR_ABAIXO_DE else 1.0

## No toque fica no canto de baixo à esquerda (cresce para cima e para a direita). No PC o canto da esquerda é do chat,
## então o cinto vai para o canto de baixo à direita, afastado da barra de energia vertical
func _posicionar() -> void:
	var a_direita := not Controle.usando_toque
	_coluna.anchor_left = 1.0 if a_direita else 0.0
	_coluna.anchor_right = _coluna.anchor_left
	_coluna.grow_horizontal = Control.GROW_DIRECTION_BEGIN if a_direita else Control.GROW_DIRECTION_END
	_coluna.offset_left = -MARGEM_DIREITA if a_direita else 6.0
	_coluna.offset_right = _coluna.offset_left

func _montar() -> void:
	_coluna = VBoxContainer.new()
	_coluna.name = "Coluna"
	_coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coluna.add_theme_constant_override("separation", 2)
	_coluna.anchor_top = 1.0
	_coluna.anchor_bottom = 1.0
	_coluna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coluna.offset_top = -6
	_coluna.offset_bottom = -6
	add_child(_coluna)
	_posicionar()
	Controle.modo_alterado.connect(func(_modo = null) -> void: _posicionar())
	_aviso_semente = _novo_rotulo(COR_SEMENTE)
	_aviso_semente.name = "AvisoSemente"
	_aviso_semente.modulate.a = 0.0
	_coluna.add_child(_aviso_semente)
	_aviso_equipamento = _novo_rotulo(COR_AVISO)
	_aviso_equipamento.name = "AvisoEquipamento"
	_aviso_equipamento.modulate.a = 0.0
	_coluna.add_child(_aviso_equipamento)
	_aviso = _novo_rotulo(COR_AVISO)
	_aviso.name = "Aviso"
	_aviso.modulate.a = 0.0
	_coluna.add_child(_aviso)
	_nome = _novo_rotulo(COR_NOME)
	_nome.name = "Nome"
	_nome.modulate.a = 0.0
	_coluna.add_child(_nome)
	_linha_efeitos = HBoxContainer.new()
	_linha_efeitos.name = "assets/efeitos"
	_linha_efeitos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha_efeitos.add_theme_constant_override("separation", 4)
	_coluna.add_child(_linha_efeitos)
	_linha_cinto = HBoxContainer.new()
	_linha_cinto.name = "Cinto"
	_linha_cinto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha_cinto.add_theme_constant_override("separation", 3)
	_coluna.add_child(_linha_cinto)
	_tecla_anterior = _novo_rotulo(COR_TECLA)
	_linha_cinto.add_child(_tecla_anterior)
	_linha_cinto.add_child(_nova_casa())
	_tecla_proxima = _novo_rotulo(COR_TECLA)
	_linha_cinto.add_child(_tecla_proxima)
	var espaco := Control.new()
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	espaco.custom_minimum_size = Vector2(6, 0)
	_linha_cinto.add_child(espaco)
	_tecla_beber = _novo_rotulo(COR_NOME)
	_tecla_beber.name = "TeclaBeber"
	_linha_cinto.add_child(_tecla_beber)

func _ao_casa_tocada(evento: InputEvent) -> void:
	if efeitos != null and evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		efeitos.trocar(1)
		accept_event()

func _nova_casa() -> Control:
	var casa := Control.new()
	casa.name = "Casa"
	# Tocar (ou clicar) na casa passa para a próxima poção: no celular não há Q/E
	casa.mouse_filter = Control.MOUSE_FILTER_STOP
	casa.add_to_group("toque_hud")
	casa.gui_input.connect(_ao_casa_tocada)
	var lado := LADO_CASA_TOQUE if Controle.usando_toque else LADO_CASA
	casa.custom_minimum_size = Vector2(lado, lado)
	var fundo := Panel.new()
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_theme_stylebox_override("panel", EstiloSlot.caixa())
	casa.add_child(fundo)
	_icone = TextureRect.new()
	_icone.name = "Icone"
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icone.set_anchors_preset(Control.PRESET_CENTER)
	_icone.offset_left = -8
	_icone.offset_right = 8
	_icone.offset_top = -8
	_icone.offset_bottom = 8
	casa.add_child(_icone)
	_quantidade = _novo_rotulo(COR_NOME)
	_quantidade.name = "Quantidade"
	_quantidade.add_theme_font_size_override("font_size", 9)
	_quantidade.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantidade.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quantidade.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_quantidade.offset_right = -1
	_quantidade.offset_bottom = 2
	casa.add_child(_quantidade)
	return casa

func _novo_rotulo(cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", 10)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1))
	rotulo.add_theme_constant_override("outline_size", 3)
	return rotulo

func _atualizar_teclas() -> void:
	for rotulo in [_tecla_anterior, _tecla_proxima, _tecla_beber]:
		rotulo.add_theme_font_override("font", FONTE_TECLAS)
	_tecla_anterior.text = Controle.rotulo_acao("ferramenta_anterior")
	_tecla_proxima.text = Controle.rotulo_acao("ferramenta_proxima")
	_tecla_beber.text = Controle.rotulo_acao("usar_pocao") + " BEBER"
	# No celular os botões da tela já têm o nome: as dicas de tecla só ocupariam lugar
	for rotulo in [_tecla_anterior, _tecla_proxima, _tecla_beber]:
		rotulo.visible = not Controle.usando_toque

func _ao_selecao_alterada(id: String) -> void:
	_atualizar()
	if id != "":
		_mostrar(_nome, String(Pocoes.dados(id)["nome"]), DURACAO_NOME, "_tween_nome")

func _ao_pocao_bebida(id: String) -> void:
	_mostrar(_nome, "%s: %s" % [String(Pocoes.dados(id)["nome"]), Pocoes.texto_efeito(id)], DURACAO_NOME, "_tween_nome")

## A casa mostra a poção escolhida e quanto resta; sem poção nem efeito, o cinto todo some
func _atualizar() -> void:
	var id: String = efeitos.selecionada if efeitos != null else ""
	var tem := id != "" and Fazenda.quantidade_pocoes(id,EventosJogo.dono(self)) > 0
	_icone.texture = Pocoes.icone(id) if tem else null
	_quantidade.text = str(Fazenda.quantidade_pocoes(id,EventosJogo.dono(self))) if tem else ""
	_linha_cinto.visible = tem
	_linha_efeitos.visible = not _rotulos_efeitos.is_empty()

func _refazer_efeitos() -> void:
	for filho in _linha_efeitos.get_children():
		_linha_efeitos.remove_child(filho)
		filho.queue_free()
	_rotulos_efeitos.clear()
	if efeitos != null:
		for efeito in efeitos.ativos:
			var caixa := HBoxContainer.new()
			caixa.name = "Efeito_" + String(efeito)
			caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caixa.add_theme_constant_override("separation", 1)
			var icone := TextureRect.new()
			icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icone.texture = Pocoes.icone(String(efeitos.ativos[efeito]["pocao"]))
			icone.custom_minimum_size = Vector2(16, 16)
			caixa.add_child(icone)
			var tempo := _novo_rotulo(COR_NOME)
			tempo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			caixa.add_child(tempo)
			_linha_efeitos.add_child(caixa)
			_rotulos_efeitos[efeito] = {"caixa": caixa, "tempo": tempo}
	_process(0.0)
	_atualizar()

## Motivo de não ter bebido (o Jogador chama pelo HUD)
func mostrar_aviso(texto: String) -> void:
	_mostrar(_aviso, texto, DURACAO_AVISO, "_tween_aviso")

## Saquinho recolhido: "+1 SEMENTE: TOMATE (4 DIAS)"; outro da mesma planta logo em seguida vira "+2"
func avisar_semente(id: String) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if id == _semente_atual and agora <= _semente_ate:
		_semente_contagem += 1
	else:
		_semente_atual = id
		_semente_contagem = 1
	_semente_ate = agora + JANELA_SEMENTE
	var nome := String(Fazenda.PLANTAS[id]["nome"]) if Fazenda.PLANTAS.has(id) else id.to_upper()
	# Cor da raridade; as raras e épicas dizem a raridade no texto
	var raridade := String(Fazenda.PLANTAS[id].get("raridade", "comum")) if Fazenda.PLANTAS.has(id) else "comum"
	var texto := "+%d SEMENTE: %s (%s" % [_semente_contagem, nome, Fazenda.texto_crescimento(id)]
	if raridade in ["raro", "epico"]:
		texto += ", %s" % String(Fazenda.NOME_RARIDADE[raridade])
	texto += ")"
	_aviso_semente.add_theme_color_override("font_color", Fazenda.COR_RARIDADE.get(raridade, COR_SEMENTE))
	_mostrar(_aviso_semente, texto, JANELA_SEMENTE, "_tween_semente")

## Equipamento recolhido ou vendido, ou mochila cheia: texto na cor da raridade
func avisar_equipamento(texto: String, cor: Color) -> void:
	_aviso_equipamento.add_theme_color_override("font_color", cor)
	_mostrar(_aviso_equipamento, texto, DURACAO_AVISO, "_tween_equipamento")

func _mostrar(rotulo: Label, texto: String, duracao: float, campo_tween: String) -> void:
	rotulo.text = texto
	var anterior: Tween = get(campo_tween)
	if anterior != null and anterior.is_valid():
		anterior.kill()
	rotulo.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(duracao)
	tween.tween_property(rotulo, "modulate:a", 0.0, 0.4)
	set(campo_tween, tween)
