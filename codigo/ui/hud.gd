extends CanvasLayer

const FRACAO_VIDA_BAIXA := 0.3
# A fita do pack tem 16px de altura: em 2x o banner fica legível no centro da tela
const ESCALA_BANNER := Vector2(2, 2)
const COR_STAMINA := Color(1, 0.85, 0.3)
const COR_STAMINA_VAZIA := Color(1, 0.3, 0.3)
const CintoPocoes := preload("res://codigo/ui/cinto_pocoes.gd")
const BarraArmas := preload("res://codigo/ui/barra_armas.gd")
const MiniTutorial := preload("res://codigo/ui/mini_tutorial.gd")

@onready var coracao: TextureRect = %Coracao
@onready var barra_vida: Control = %BarraVida
@onready var rotulo_vida: Label = %RotuloVida
@onready var barra_stamina: Control = %BarraStamina
@onready var icone_stamina: TextureRect = %IconeStamina
@onready var rotulo_moedas: Label = %RotuloMoedas
@onready var rotulo_brasas: Label = %RotuloBrasas
var rotulo_moeda_forja: Label
@onready var rotulo_data: Label = %RotuloData
@onready var relogio: TextureRect = %Relogio
@onready var rotulo_hora: Label = %RotuloHora
@onready var painel_onda: Control = %PainelOnda
@onready var rotulo_onda: Label = %RotuloOnda
@onready var rotulo_evento: Label = %RotuloEvento
@onready var linha_inimigos: Control = %LinhaInimigos
@onready var rotulo_inimigos: Label = %RotuloInimigos
@onready var barra_inimigos: Control = %BarraInimigos
@onready var rotulo_espera: Label = %RotuloEspera
@onready var painel_chefe: Control = %PainelChefe
@onready var nome_chefe: Label = %NomeChefe
@onready var barra_chefe: Control = %BarraChefe
@onready var faixa_banner: Control = %FaixaBanner
@onready var rotulo_banner: Label = %RotuloBanner
@onready var subtitulo_banner: Label = %SubtituloBanner

# Folha 6x3 de quadros 32x32 (assets/ui/Clock/Others/clock.png do Farm RPG): colunas = hora do dia, linhas = estação
const TEXTURA_RELOGIO := preload("res://assets/ui/fazenda/relogio.png")
const LADO_RELOGIO := 32
# primavera e verão usam a paisagem verde; outono a laranja; inverno a de neve
const LINHA_RELOGIO_POR_ESTACAO := [0, 0, 1, 2]
# [de, até, coluna]: as cores do céu acompanham os pontos do dia de iluminacao.gd
const FAIXAS_RELOGIO := [
	[0.0, 4.5, 4], [4.5, 7.5, 5], [7.5, 11.0, 0], [11.0, 16.0, 1],
	[16.0, 19.5, 2], [19.5, 21.0, 3], [21.0, 24.0, 4],
]

var _vida_atual := -1
var _quadro_relogio := AtlasTexture.new()
var _iluminacao: Node
var _tween_coracao: Tween
var _tween_banner: Tween
var _tween_stamina: Tween
var _vida_baixa := false
var _gerenciador: Node
## A barra de baixo (primeira linha da mochila): na arena troca a arma; na fazenda (meta "barra_ferramentas" da cena), a ferramenta
var barra_armas: Control = null
## Só na arena (cena com ondas): as poções do jogador
var cinto_pocoes: Control = null

# Celular: o recorte da câmera e os cantos arredondados não podem cobrir a vida, o relógio e a onda
func _respeitar_area_segura() -> void:
	var m: Vector4 = Controle.margens_seguras()
	if m == Vector4.ZERO:
		return
	var status: Control = $Status
	status.offset_left += m.x
	status.offset_right += m.x
	status.offset_top += m.y
	status.offset_bottom += m.y
	var canto: Control = $CantoDireito
	canto.offset_left -= m.z
	canto.offset_right -= m.z
	canto.offset_top += m.y
	canto.offset_bottom += m.y

## A cena do jogo (o HUD pode estar dentro da metade de um jogador na tela dividida, não direto na cena)
func _cena() -> Node:
	return Cooperativo.cena_de(self) if is_inside_tree() else null

func _ready() -> void:
	# No cooperativo o HUD do jogador 2 recebe os avisos dele por outro grupo
	# "hud" = anúncios para os dois; "hud_p1"/"hud_p2" = vida, fôlego, ouro e avisos de um jogador só (cooperativo)
	add_to_group("hud")
	add_to_group("hud_p2" if EventosJogo.eh_do_p2(self) else "hud_p1")
	if not EventosJogo.eh_do_p2(self):
		add_child(MiniTutorial.new())
	if get_viewport().has_meta("dono"):
		# Vida e relógio dividem o topo; a barra do chefe fica em uma linha própria.
		painel_chefe.offset_top += 48
		painel_chefe.offset_bottom += 48
	_respeitar_area_segura()
	faixa_banner.hide()
	rotulo_evento.hide()
	_mostrar_inimigos(false)
	atualizar_moedas(EventosJogo.moedas_de(self))
	atualizar_brasas(Progresso.brasas)
	Progresso.brasas_alteradas.connect(atualizar_brasas)
	_criar_contador_moeda_forja()
	_capacidade_mochila = EventosJogo.inventario_de(self).capacidade()
	EventosJogo.inventario_de(self).capacidade_alterada.connect(_ao_capacidade_alterada)
	atualizar_data()
	Calendario.dia_passou.connect(_ao_dia_passou)
	Calendario.estacao_mudou.connect(_ao_estacao_mudou)
	_montar_relogio()
	if _cena() != null and bool(_cena().get_meta("barra_ferramentas", false)):
		# Fazenda: a mesma barra da arena, escolhendo ferramenta e semente
		_criar_barra(true)
	# O Jogador fica antes na árvore e já atualizou a vida antes deste nó entrar no grupo
	var jogador := EventosJogo.dono(self)
	if jogador:
		jogador.atualizar_barra_hp()
		atualizar_stamina(jogador.stamina, jogador.stamina_maxima)
	_conectar_gerenciador()

func _conectar_gerenciador() -> void:
	var gerenciador: Node = null
	if is_inside_tree() and get_tree():
		gerenciador = get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador == null and _cena():
		gerenciador = _cena().get_node_or_null("enemySpawner/GerenciadorOndas")
	if gerenciador == null:
		if not is_inside_tree() or get_tree() == null:
			return
		await get_tree().process_frame
		if not is_inside_tree() or get_tree() == null:
			return
		gerenciador = get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador == null:
		_modo_sem_ondas()
		return
	_gerenciador = gerenciador
	_criar_cinto_pocoes()
	# A barra de baixo não depende do cinto (antes só nascia junto dele e, sem o cinto, a arena ficava sem barra)
	_criar_barra(false)
	gerenciador.onda_iniciada.connect(_ao_onda_iniciada)
	gerenciador.onda_completada.connect(_ao_onda_completada)
	gerenciador.sinal_ondas_paradas.connect(_ao_ondas_paradas)
	gerenciador.inimigos_alterados.connect(_ao_inimigos_alterados)
	gerenciador.evento_alterado.connect(_ao_evento_alterado)
	rotulo_onda.text = "ONDA %d" % gerenciador.onda_atual

## Data do calendário ("PRIMAVERA - DIA 3"), nas cenas de jogo
func atualizar_data() -> void:
	if get_viewport().has_meta("dono"):
		rotulo_data.text = "%s  DIA %d\n%s" % [Calendario.nome_dia_semana(), Calendario.dia_na_estacao(), Calendario.nome_estacao()]
	else:
		rotulo_data.text = "%s  %s" % [Calendario.nome_dia_semana(), Calendario.texto_data()]

func _ao_dia_passou(_dia: int) -> void:
	atualizar_data()

func _ao_estacao_mudou(_estacao: int) -> void:
	_atualizar_relogio()

# --- Relógio (janelinha do Farm RPG: a paisagem muda com a estação e o céu com a hora do dia) --------------

func _montar_relogio() -> void:
	_quadro_relogio.atlas = TEXTURA_RELOGIO
	relogio.texture = _quadro_relogio
	# A Iluminacao (que conta as horas) pode entrar na árvore depois do HUD
	_ligar_iluminacao.call_deferred()

## O relógio segue a iluminação do mundo onde o dono do HUD está (no cooperativo cada um pode estar num ambiente; a casa
## não tem iluminação própria, aí vale a primeira que houver). O Cooperativo chama de novo depois de cada viagem
func _ligar_iluminacao() -> void:
	if is_instance_valid(_iluminacao) and _iluminacao.hora_mudou.is_connected(_ao_hora_mudou):
		_iluminacao.hora_mudou.disconnect(_ao_hora_mudou)
	_iluminacao = null
	if is_inside_tree():
		var dono := EventosJogo.dono(self)
		var lugar: Node = Cooperativo.cena_de(dono) if dono != null else null
		for luz in get_tree().get_nodes_in_group("iluminacao"):
			if lugar != null and Cooperativo.cena_de(luz) == lugar:
				_iluminacao = luz
				break
		if _iluminacao == null:
			_iluminacao = get_tree().get_first_node_in_group("iluminacao")
	if _iluminacao != null and _iluminacao.has_signal("hora_mudou"):
		_iluminacao.hora_mudou.connect(_ao_hora_mudou)
	_atualizar_relogio()

func _ao_hora_mudou(_hora: int, _minuto: int) -> void:
	_atualizar_relogio()

func _atualizar_relogio() -> void:
	var hora := 6.0
	if is_instance_valid(_iluminacao):
		hora = float(_iluminacao.hora)
	var linha: int = LINHA_RELOGIO_POR_ESTACAO[clampi(Calendario.estacao(), 0, 3)]
	_quadro_relogio.region = Rect2(coluna_relogio(hora) * LADO_RELOGIO, linha * LADO_RELOGIO, LADO_RELOGIO, LADO_RELOGIO)
	rotulo_hora.text = texto_hora(hora)
	rotulo_hora.visible = is_instance_valid(_iluminacao)
	_avisar_cansaco(hora)

## Depois da meia-noite o relógio fica laranja e, a partir da 01:00, pisca em vermelho: às 02:00 o jogador desmaia de
## cansaço e acorda na casa da fazenda (Transicao.desmaiar). Na arena o mundo está parado: sem aviso
var _tween_cansaco: Tween
var _avisou_meia_noite := false
var _avisou_uma_hora := false

func _avisar_cansaco(hora: float) -> void:
	var na_arena: bool = is_instance_valid(_iluminacao) and bool(_iluminacao.get("em_arena"))
	var madrugada := hora < 2.0 and not na_arena and is_instance_valid(_iluminacao) and not Introducao.ativa()
	var urgente := madrugada and hora >= 1.0
	if not madrugada:
		_avisou_meia_noite = false
		_avisou_uma_hora = false
	if madrugada and not _avisou_meia_noite:
		_avisou_meia_noite = true
		anunciar("MEIA-NOITE", "VA PARA CASA DORMIR ANTES DAS 2H", 3.0)
	if urgente and not _avisou_uma_hora:
		_avisou_uma_hora = true
		anunciar("VOCE ESTA EXAUSTO", "AS 2H VOCE DESMAIA NA RUA", 3.0)
	if urgente:
		if _tween_cansaco == null or not _tween_cansaco.is_valid():
			_tween_cansaco = create_tween().set_loops()
			_tween_cansaco.tween_property(rotulo_hora, "modulate", Color(1.0, 0.35, 0.3), 0.35)
			_tween_cansaco.tween_property(rotulo_hora, "modulate", Color.WHITE, 0.35)
	else:
		if _tween_cansaco != null and _tween_cansaco.is_valid():
			_tween_cansaco.kill()
		rotulo_hora.modulate = Color(1.0, 0.7, 0.35) if madrugada else Color.WHITE

## Coluna da folha do relógio para a hora (0..24): manhã, dia, tarde, anoitecer, noite e madrugada
static func coluna_relogio(hora: float) -> int:
	for faixa in FAIXAS_RELOGIO:
		if hora >= faixa[0] and hora < faixa[1]:
			return int(faixa[2])
	return 4

## "06:30": minutos de 10 em 10, como nos relógios de fazenda (o ciclo anda rápido e o número não fica piscando)
static func texto_hora(hora: float) -> String:
	var minutos_totais := int(floor(hora * 60.0))
	return "%02d:%02d" % [(minutos_totais / 60) % 24, (minutos_totais % 60) / 10 * 10]

func _criar_cinto_pocoes() -> void:
	var jogador := EventosJogo.dono(self)
	if jogador == null or jogador.get("efeitos_pocao") == null or cinto_pocoes != null:
		return
	cinto_pocoes = CintoPocoes.new()
	cinto_pocoes.name = "CintoPocoes"
	cinto_pocoes.efeitos = jogador.efeitos_pocao
	add_child(cinto_pocoes)

func _criar_barra(na_fazenda: bool) -> void:
	if barra_armas != null:
		return
	barra_armas = BarraArmas.new()
	barra_armas.name = "BarraArmas"
	barra_armas.modo_fazenda = na_fazenda
	add_child(barra_armas)

## Por que a poção não foi bebida (SEM POCOES, VIDA CHEIA...)
func avisar_pocao(texto: String) -> void:
	if cinto_pocoes != null:
		cinto_pocoes.mostrar_aviso(texto)

## Saquinho de semente recolhido na arena
func avisar_semente(id: String) -> void:
	if cinto_pocoes != null:
		cinto_pocoes.avisar_semente(id)

var _capacidade_mochila := 0

## A mochila ganhou uma linha ao vencer a onda do requisito
func _ao_capacidade_alterada(capacidade: int) -> void:
	var ganho := capacidade - _capacidade_mochila
	_capacidade_mochila = capacidade
	if ganho > 0 and cinto_pocoes != null:
		cinto_pocoes.avisar_equipamento("MOCHILA AMPLIADA: +%d ESPACOS" % ganho, Color(0.55, 0.95, 0.65))
		Sons.tocar("melhoria", 0.0)

## Equipamento recolhido na arena: o nome na cor da raridade ("ESPADA GEMEA LENDARIO")
func avisar_equipamento(item: DadosItem) -> void:
	if cinto_pocoes != null:
		cinto_pocoes.avisar_equipamento("+ %s %s" % [item.nome(), item.nome_raridade()], item.cor_raridade())

func avisar_moeda_forja() -> void:
	if cinto_pocoes != null:
		cinto_pocoes.avisar_equipamento("+ MOEDA DE FORJA (TEM %d)" % EventosJogo.inventario_de(self).moedas_forja, Color(1, 0.8, 0.35))

func avisar_equipamento_cheio(texto := "MOCHILA CHEIA") -> void:
	if cinto_pocoes != null:
		cinto_pocoes.avisar_equipamento(texto, Color(1, 0.6, 0.5))

## Mochila cheia: o equipamento foi para o saque da partida (aba SAQUE entre as ondas)
func avisar_equipamento_no_saque(item: DadosItem) -> void:
	if cinto_pocoes != null:
		cinto_pocoes.avisar_equipamento("+ %s %s (SAQUE %d/%d)" % [item.nome(), item.nome_raridade(), Saque.quantidade(), Saque.CAPACIDADE], item.cor_raridade())

func avisar_equipamento_vendido(item: DadosItem, valor: int) -> void:
	if cinto_pocoes != null:
		cinto_pocoes.avisar_equipamento("%s %s VENDIDO +%d" % [item.nome(), item.nome_raridade(), valor], item.cor_raridade())

## Aviso de por que a ferramenta não pôde ser usada (só existe na fazenda)
func avisar_ferramenta(texto: String) -> void:
	if barra_armas != null:
		barra_armas.mostrar_aviso(texto)

## Fazenda e casa não têm ondas: o quadro da onda some e o relógio sobe para o canto
## (o título guarda o nome do lugar, meta "titulo_hud" da cena)
func _modo_sem_ondas() -> void:
	var titulo := ""
	if _cena() != null:
		titulo = String(_cena().get_meta("titulo_hud", ""))
	rotulo_onda.text = titulo if titulo != "" else "FAZENDA"
	rotulo_evento.hide()
	linha_inimigos.hide()
	rotulo_espera.hide()
	painel_onda.hide()

func atualizar_vida(atual: int, maximo: int) -> void:
	var levou_dano := _vida_atual >= 0 and atual < _vida_atual
	_vida_atual = atual
	barra_vida.definir(atual, maximo, levou_dano)
	rotulo_vida.text = "%d/%d" % [atual, maximo]
	if levou_dano:
		_pulsar_coracao()
	_definir_vida_baixa(maximo > 0 and float(atual) / maximo <= FRACAO_VIDA_BAIXA)

func mostrar_chefe(nome: String, vida: int, vida_maxima: int) -> void:
	nome_chefe.text = nome
	barra_chefe.definir(vida, vida_maxima, false)
	painel_chefe.modulate.a = 0.0
	painel_chefe.show()
	create_tween().tween_property(painel_chefe, "modulate:a", 1.0, 0.4)
	_mostrar_banner(nome, "BATALHA DE CHEFE", 2.2)

func atualizar_chefe(vida: int, vida_maxima: int) -> void:
	barra_chefe.definir(vida, vida_maxima)

func esconder_chefe() -> void:
	if not painel_chefe.visible:
		return
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(painel_chefe, "modulate:a", 0.0, 0.4)
	tween.tween_callback(painel_chefe.hide)

func atualizar_stamina(atual: float, maximo: float) -> void:
	barra_stamina.definir(atual, maximo, false)

func avisar_stamina_insuficiente() -> void:
	if _tween_stamina and _tween_stamina.is_running():
		return
	_tween_stamina = create_tween()
	for i in 2:
		_tween_stamina.tween_property(icone_stamina, "modulate", COR_STAMINA_VAZIA, 0.08)
		_tween_stamina.tween_property(icone_stamina, "modulate", COR_STAMINA, 0.08)

## Moeda de forja ao lado do ouro e das brasas: o ícone da moeda em vermelho e a quantidade
func _criar_contador_moeda_forja() -> void:
	var linha: Node = rotulo_brasas.get_parent()
	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(4, 0)
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(espaco)
	var icone := TextureRect.new()
	icone.name = "IconeMoedaForja"
	icone.texture = load("res://assets/ui/icons-coin/32x32/3.png")
	icone.custom_minimum_size = Vector2(10, 10)
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.self_modulate = Color(1, 0.35, 0.3)
	linha.add_child(icone)
	rotulo_moeda_forja = Label.new()
	rotulo_moeda_forja.name = "RotuloMoedaForja"
	rotulo_moeda_forja.label_settings = rotulo_brasas.label_settings
	rotulo_moeda_forja.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo_moeda_forja)
	atualizar_moeda_forja(EventosJogo.inventario_de(self).moedas_forja)
	EventosJogo.inventario_de(self).moedas_forja_alteradas.connect(atualizar_moeda_forja)

func atualizar_moeda_forja(quantidade: int) -> void:
	rotulo_moeda_forja.text = str(quantidade)

func atualizar_moedas(quantidade: int) -> void:
	rotulo_moedas.text = str(quantidade)

func atualizar_brasas(quantidade: int) -> void:
	rotulo_brasas.text = str(quantidade)

## Rótulo da onda fora dos eventos do gerenciador (a Mística muda a onda inicial)
func atualizar_rotulo_onda(onda: int) -> void:
	rotulo_onda.text = "ONDA %d" % onda

## Banner no centro da tela para avisos de outros sistemas (reviver, estações, eventos)
func anunciar(texto: String, subtitulo := "", tempo_visivel := 1.5) -> void:
	_mostrar_banner(texto, subtitulo, tempo_visivel)

func _ao_onda_iniciada(onda: int) -> void:
	_mostrar_inimigos(true)
	if _gerenciador != null and _gerenciador.onda_bonus:
		rotulo_onda.text = "BONUS"
		_mostrar_banner("ESTAGIO BONUS", "MIMICOS! MAIS OURO", 2.2)
		return
	# Na onda do chefe o anúncio é dele (mostrar_chefe), não da onda
	if _eh_onda_chefe(onda):
		rotulo_onda.text = "CHEFE"
		return
	rotulo_onda.text = "ONDA %d" % onda
	# O evento (se houver) entra como subtítulo do banner da onda
	var evento: Dictionary = _gerenciador.evento_atual if _gerenciador != null else {}
	if evento.is_empty():
		_mostrar_banner("ONDA %d" % onda)
	else:
		_mostrar_banner("ONDA %d" % onda, "%s - %s" % [evento["nome"], evento["resumo"]], 2.4)

## Indicador fixo no painel da onda enquanto o evento durar
func _ao_evento_alterado(evento: Dictionary) -> void:
	rotulo_evento.visible = not evento.is_empty()
	if evento.is_empty():
		return
	rotulo_evento.text = evento["nome"]
	rotulo_evento.modulate = evento["cor"]

func _ao_onda_completada(onda: int) -> void:
	_mostrar_inimigos(false)
	# O bônus não avança a onda: a próxima é a mesma que ficou esperando
	if _gerenciador != null and _gerenciador.onda_bonus:
		rotulo_onda.text = "ONDA %d" % onda
		_mostrar_banner("BONUS CONCLUIDO", "PROXIMA: ONDA %d" % onda)
		return
	rotulo_onda.text = "ONDA %d" % (onda + 1)
	if _eh_onda_chefe(onda):
		_mostrar_banner("CHEFE DERROTADO", "ONDA %d CONCLUIDA" % onda)
	else:
		_mostrar_banner("ONDA %d CONCLUIDA" % onda)

func _eh_onda_chefe(onda: int) -> bool:
	return _gerenciador != null and _gerenciador.eh_onda_chefe(onda)

func _ao_ondas_paradas() -> void:
	rotulo_onda.text = "ONDA 1"
	rotulo_evento.hide()
	_mostrar_inimigos(false)
	esconder_chefe()

func _ao_inimigos_alterados(vivos: int, total: int) -> void:
	rotulo_inimigos.text = "%d/%d" % [maxi(vivos, 0), total]
	barra_inimigos.definir(maxi(vivos, 0), maxi(total, 1))

func _mostrar_inimigos(em_onda: bool) -> void:
	linha_inimigos.visible = em_onda
	rotulo_espera.visible = not em_onda

func _mostrar_banner(texto: String, subtitulo := "", tempo_visivel := 1.5) -> void:
	rotulo_banner.text = texto
	subtitulo_banner.text = subtitulo
	subtitulo_banner.visible = subtitulo != ""
	if _tween_banner:
		_tween_banner.kill()
	faixa_banner.show()
	faixa_banner.modulate.a = 0.0
	var na_metade := get_viewport().has_meta("dono")
	if na_metade:
		# A fita se ajusta pelo tamanho e pela quebra de linha, sem reamostrar letras ou pixels.
		var largura := floorf(get_viewport().get_visible_rect().size.x) - 16.0
		faixa_banner.get_node("Textos").custom_minimum_size.x = largura - 20.0
		rotulo_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitulo_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		faixa_banner.size = Vector2(largura, 0)
	faixa_banner.scale = Vector2.ONE if na_metade else ESCALA_BANNER * 1.3
	# Espera o PanelContainer recalcular o tamanho para o texto novo
	if is_inside_tree() and get_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if na_metade:
		# O PanelContainer só cresce sozinho: na primeira vez a quebra de linha ainda sem largura media o texto letra
		# por letra e a fita ficava da altura da tela (o "vermelho" cobrindo a metade). Volta ao tamanho mínimo real
		faixa_banner.reset_size()
		faixa_banner.position.x = floorf((get_viewport().get_visible_rect().size.x - faixa_banner.size.x) / 2.0)
		faixa_banner.position.y = floorf(faixa_banner.position.y)
	faixa_banner.pivot_offset = faixa_banner.size / 2.0
	_tween_banner = create_tween()
	_tween_banner.set_parallel()
	_tween_banner.tween_property(faixa_banner, "modulate:a", 1.0, 0.2)
	if not na_metade:
		_tween_banner.tween_property(faixa_banner, "scale", ESCALA_BANNER, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_banner.chain().tween_interval(tempo_visivel)
	_tween_banner.chain().tween_property(faixa_banner, "modulate:a", 0.0, 0.4)
	_tween_banner.chain().tween_callback(faixa_banner.hide)

func _pulsar_coracao() -> void:
	if _vida_baixa:
		return
	if _tween_coracao:
		_tween_coracao.kill()
	coracao.scale = Vector2(1.4, 1.4)
	_tween_coracao = create_tween()
	_tween_coracao.tween_property(coracao, "scale", Vector2.ONE, 0.2)

func _definir_vida_baixa(baixa: bool) -> void:
	if baixa == _vida_baixa:
		return
	_vida_baixa = baixa
	if _tween_coracao:
		_tween_coracao.kill()
	coracao.scale = Vector2.ONE
	if not baixa:
		return
	_tween_coracao = create_tween().set_loops()
	_tween_coracao.tween_property(coracao, "scale", Vector2(1.25, 1.25), 0.3)
	_tween_coracao.tween_property(coracao, "scale", Vector2.ONE, 0.3)
